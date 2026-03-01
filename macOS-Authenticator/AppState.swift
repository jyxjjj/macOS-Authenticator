import Foundation
import CryptoKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var isLocked: Bool = true
    @Published var entries: [TOTPEntry] = []

    private(set) var masterKey: SymmetricKey?
    let database = DatabaseManager()

    init() {
        try? database.open()
    }

    // MARK: - Auth

    var isFirstLaunch: Bool { !KeychainManager.masterKeyExists() }

    func setupMasterPassword(_ password: String) throws {
        let key     = deriveKey(from: password)
        let keyData = key.withUnsafeBytes { Data($0) }
        try KeychainManager.saveMasterKey(keyData)
        masterKey = key
        isLocked  = false
        entries   = []
    }

    func unlock(password: String) throws {
        let stored        = try KeychainManager.loadMasterKey()
        let candidate     = deriveKey(from: password)
        let candidateData = candidate.withUnsafeBytes { Data($0) }
        guard candidateData == stored else { throw AuthError.wrongPassword }
        masterKey = candidate
        isLocked  = false
        try reloadEntries()
    }

    func lock() {
        masterKey = nil
        isLocked  = true
        entries   = []
    }

    // MARK: - Entry management

    func reloadEntries() throws {
        entries = try database.fetchAll()
    }

    func addEntry(serviceName: String, username: String, secret: String,
                  algorithm: TOTPAlgorithm, digits: Int, period: Int) throws {
        guard let key = masterKey else { throw AuthError.notUnlocked }
        let secretData       = try Base32Decoder.decode(secret)
        let (enc, nonce)     = try AESCryptoManager.encrypt(data: secretData, key: key)
        let entry = TOTPEntry(serviceName: serviceName, username: username,
                              encryptedSecret: enc, nonce: nonce,
                              algorithm: algorithm, digits: digits, period: period)
        try database.insert(entry)
        try reloadEntries()
    }

    func updateEntry(_ entry: TOTPEntry) throws {
        var updated = entry
        updated.updatedAt = Date()
        try database.update(updated)
        try reloadEntries()
    }

    func deleteEntry(id: UUID) throws {
        try database.delete(id: id)
        try reloadEntries()
    }

    func decryptSecret(for entry: TOTPEntry) throws -> Data {
        guard let key = masterKey else { throw AuthError.notUnlocked }
        return try AESCryptoManager.decrypt(encrypted: entry.encryptedSecret,
                                             nonce: entry.nonce, key: key)
    }

    // MARK: - Master key change

    func changeMasterPassword(oldPassword: String, newPassword: String) throws {
        let storedData   = try KeychainManager.loadMasterKey()
        let oldKey       = deriveKey(from: oldPassword)
        let oldKeyData   = oldKey.withUnsafeBytes { Data($0) }
        guard oldKeyData == storedData else { throw AuthError.wrongPassword }

        let newKey       = deriveKey(from: newPassword)
        let allEntries   = try database.fetchAll()
        var reEncrypted: [TOTPEntry] = []

        for entry in allEntries {
            let plain            = try AESCryptoManager.decrypt(
                encrypted: entry.encryptedSecret, nonce: entry.nonce, key: oldKey)
            let (enc, nonce)     = try AESCryptoManager.encrypt(data: plain, key: newKey)
            var newEntry         = entry
            newEntry.encryptedSecret = enc
            newEntry.nonce       = nonce
            newEntry.updatedAt   = Date()
            reEncrypted.append(newEntry)
        }

        try database.replaceAll(reEncrypted)
        let newKeyData = newKey.withUnsafeBytes { Data($0) }
        try KeychainManager.saveMasterKey(newKeyData)
        masterKey = newKey
        try reloadEntries()
    }

    // MARK: - Export / Import

    struct ExportPayload: Codable {
        let magic: String
        let entries: [ExportEntry]
    }

    struct ExportEntry: Codable {
        let id: String
        let serviceName: String
        let username: String
        let secret: String       // plain Base32
        let algorithm: String
        let digits: Int
        let period: Int
    }

    func exportData() throws -> Data {
        guard let key = masterKey else { throw AuthError.notUnlocked }
        let all = try database.fetchAll()
        let exportEntries: [ExportEntry] = try all.map { entry in
            let secretData = try AESCryptoManager.decrypt(
                encrypted: entry.encryptedSecret, nonce: entry.nonce, key: key)
            return ExportEntry(id: entry.id.uuidString,
                               serviceName: entry.serviceName,
                               username: entry.username,
                               secret: base32Encode(secretData),
                               algorithm: entry.algorithm.rawValue,
                               digits: entry.digits,
                               period: entry.period)
        }
        let payload  = ExportPayload(magic: "NACOS-AUTH-v1", entries: exportEntries)
        let jsonData = try JSONEncoder().encode(payload)
        let (enc, nonce) = try AESCryptoManager.encrypt(data: jsonData, key: key)
        return nonce + enc    // file = nonce(12) | ciphertext+tag
    }

    func importData(_ fileData: Data) throws {
        guard let key = masterKey else { throw AuthError.notUnlocked }
        guard fileData.count > 12 else { throw ImportError.invalidFormat }
        let nonce      = fileData.prefix(12)
        let ciphertext = fileData.dropFirst(12)
        let jsonData   = try AESCryptoManager.decrypt(
            encrypted: Data(ciphertext), nonce: Data(nonce), key: key)
        let payload    = try JSONDecoder().decode(ExportPayload.self, from: jsonData)
        guard payload.magic == "NACOS-AUTH-v1" else { throw ImportError.invalidMagic }

        let existing = Set((try database.fetchAll()).map { $0.id.uuidString })
        for exported in payload.entries {
            if existing.contains(exported.id) { continue }
            let secretData   = try Base32Decoder.decode(exported.secret)
            let (enc, nonce2) = try AESCryptoManager.encrypt(data: secretData, key: key)
            let algo = TOTPAlgorithm(rawValue: exported.algorithm) ?? .sha1
            let entry = TOTPEntry(
                id: UUID(uuidString: exported.id) ?? UUID(),
                serviceName: exported.serviceName,
                username: exported.username,
                encryptedSecret: enc, nonce: nonce2,
                algorithm: algo,
                digits: exported.digits,
                period: exported.period)
            try database.insert(entry)
        }
        try reloadEntries()
    }

    // MARK: - Private helpers

    private func deriveKey(from password: String) -> SymmetricKey {
        let hash = SHA256.hash(data: Data(password.utf8))
        return SymmetricKey(data: Data(hash))
    }

    private func base32Encode(_ data: Data) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var result   = ""
        var buffer   = 0
        var bitsLeft = 0
        for byte in data {
            buffer    = (buffer << 8) | Int(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                result.append(alphabet[(buffer >> bitsLeft) & 0x1F])
            }
        }
        if bitsLeft > 0 {
            result.append(alphabet[(buffer << (5 - bitsLeft)) & 0x1F])
        }
        return result
    }

    // MARK: - Errors

    enum AuthError: Error, LocalizedError {
        case wrongPassword
        case notUnlocked
        var errorDescription: String? {
            switch self {
            case .wrongPassword: return "Incorrect master password"
            case .notUnlocked:   return "App is locked"
            }
        }
    }

    enum ImportError: Error, LocalizedError {
        case invalidFormat
        case invalidMagic
        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Invalid export file format"
            case .invalidMagic:  return "Export file magic header mismatch"
            }
        }
    }
}
