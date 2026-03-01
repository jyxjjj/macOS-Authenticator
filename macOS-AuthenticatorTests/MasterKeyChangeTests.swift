import XCTest
import CryptoKit
@testable import macOS_Authenticator

/// Tests master key rotation without requiring Keychain or a running UI.
final class MasterKeyChangeTests: XCTestCase {

    // MARK: - Helpers

    private func makeEntry(secret: Data, key: SymmetricKey) throws -> TOTPEntry {
        let (enc, nonce) = try AESCryptoManager.encrypt(data: secret, key: key)
        return TOTPEntry(serviceName: "TestService", username: "user@test.com",
                         encryptedSecret: enc, nonce: nonce)
    }

    /// Re-encrypt all entries from oldKey to newKey (mirrors AppState logic).
    private func rotateKey(entries: [TOTPEntry],
                           oldKey: SymmetricKey,
                           newKey: SymmetricKey) throws -> [TOTPEntry] {
        try entries.map { entry in
            let plain = try AESCryptoManager.decrypt(
                encrypted: entry.encryptedSecret, nonce: entry.nonce, key: oldKey)
            let (enc, nonce) = try AESCryptoManager.encrypt(data: plain, key: newKey)
            var updated = entry
            updated.encryptedSecret = enc
            updated.nonce           = nonce
            return updated
        }
    }

    // MARK: - Tests

    func testKeyRotationPreservesSecrets() throws {
        let secrets: [Data] = [
            Data("TOTP_SECRET_ONE".utf8),
            Data("TOTP_SECRET_TWO".utf8),
            Data("TOTP_SECRET_THREE".utf8),
        ]
        let oldKey = AESCryptoManager.generateKey()
        let newKey = AESCryptoManager.generateKey()

        let entries = try secrets.map { try makeEntry(secret: $0, key: oldKey) }
        let rotated = try rotateKey(entries: entries, oldKey: oldKey, newKey: newKey)

        for (i, entry) in rotated.enumerated() {
            let dec = try AESCryptoManager.decrypt(
                encrypted: entry.encryptedSecret, nonce: entry.nonce, key: newKey)
            XCTAssertEqual(dec, secrets[i], "Secret \(i) mismatch after rotation")
        }
    }

    func testOldKeyCannotDecryptRotatedEntries() throws {
        let oldKey = AESCryptoManager.generateKey()
        let newKey = AESCryptoManager.generateKey()
        let secret = Data("ORIGINAL_SECRET".utf8)

        let entry   = try makeEntry(secret: secret, key: oldKey)
        let rotated = try rotateKey(entries: [entry], oldKey: oldKey, newKey: newKey)

        XCTAssertThrowsError(
            try AESCryptoManager.decrypt(
                encrypted: rotated[0].encryptedSecret,
                nonce: rotated[0].nonce,
                key: oldKey)
        )
    }

    func testRotationWithNoEntries() throws {
        let oldKey  = AESCryptoManager.generateKey()
        let newKey  = AESCryptoManager.generateKey()
        let rotated = try rotateKey(entries: [], oldKey: oldKey, newKey: newKey)
        XCTAssertTrue(rotated.isEmpty)
    }

    func testRotationWithManyEntries() throws {
        let count   = 50
        let oldKey  = AESCryptoManager.generateKey()
        let newKey  = AESCryptoManager.generateKey()
        let secrets = (0..<count).map { Data("SECRET_\($0)".utf8) }
        let entries = try secrets.map { try makeEntry(secret: $0, key: oldKey) }
        let rotated = try rotateKey(entries: entries, oldKey: oldKey, newKey: newKey)

        XCTAssertEqual(rotated.count, count)
        for (i, entry) in rotated.enumerated() {
            let dec = try AESCryptoManager.decrypt(
                encrypted: entry.encryptedSecret, nonce: entry.nonce, key: newKey)
            XCTAssertEqual(dec, secrets[i])
        }
    }

    func testWrongOldKeyFailsDuringRotation() throws {
        let realOldKey = AESCryptoManager.generateKey()
        let wrongKey   = AESCryptoManager.generateKey()
        let newKey     = AESCryptoManager.generateKey()
        let entry      = try makeEntry(secret: Data("SECRET".utf8), key: realOldKey)

        XCTAssertThrowsError(
            try rotateKey(entries: [entry], oldKey: wrongKey, newKey: newKey)
        )
    }

    func testPasswordDerivationIsDeterministic() {
        let pw = "MyS3curePassword!"
        let h1 = SHA256.hash(data: Data(pw.utf8))
        let h2 = SHA256.hash(data: Data(pw.utf8))
        XCTAssertEqual(Data(h1), Data(h2))
        XCTAssertEqual(Data(h1).count, 32)
    }

    func testDifferentPasswordsDifferentKeys() {
        let h1 = SHA256.hash(data: Data("password1".utf8))
        let h2 = SHA256.hash(data: Data("password2".utf8))
        XCTAssertNotEqual(Data(h1), Data(h2))
    }

    func testRotationPreservesMetadata() throws {
        let oldKey = AESCryptoManager.generateKey()
        let newKey = AESCryptoManager.generateKey()
        let secret = Data("SECRET".utf8)
        let entry  = try makeEntry(secret: secret, key: oldKey)
        let rotated = try rotateKey(entries: [entry], oldKey: oldKey, newKey: newKey)

        XCTAssertEqual(rotated[0].id,          entry.id)
        XCTAssertEqual(rotated[0].serviceName, entry.serviceName)
        XCTAssertEqual(rotated[0].username,    entry.username)
        XCTAssertEqual(rotated[0].algorithm,   entry.algorithm)
        XCTAssertEqual(rotated[0].digits,      entry.digits)
        XCTAssertEqual(rotated[0].period,      entry.period)
    }
}
