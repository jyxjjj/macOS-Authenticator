import Foundation
import CryptoKit

struct AESCryptoManager {

    /// Encrypt `data` with AES-256-GCM.
    /// Returns `(ciphertext+tag, 12-byte nonce)`.
    static func encrypt(data: Data, key: SymmetricKey) throws -> (encrypted: Data, nonce: Data) {
        let nonce     = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        // combined layout: nonce(12) | ciphertext | tag(16)
        let nonceData = Data(nonce)
        let encrypted = Data(combined.dropFirst(12))   // ciphertext + tag
        return (encrypted, nonceData)
    }

    /// Decrypt AES-256-GCM `encrypted` (= ciphertext + tag, no nonce prefix).
    static func decrypt(encrypted: Data, nonce: Data, key: SymmetricKey) throws -> Data {
        guard nonce.count == 12    else { throw CryptoError.invalidNonce }
        guard encrypted.count >= 16 else { throw CryptoError.decryptionFailed }

        let gcmNonce  = try AES.GCM.Nonce(data: nonce)
        let ciphertext = encrypted.dropLast(16)
        let tag        = encrypted.suffix(16)
        let sealedBox  = try AES.GCM.SealedBox(nonce: gcmNonce,
                                               ciphertext: ciphertext,
                                               tag: tag)
        do {
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw CryptoError.authenticationFailure
        }
    }

    static func generateKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }

    static func key(from data: Data) throws -> SymmetricKey {
        guard data.count == 32 else { throw CryptoError.invalidKeySize }
        return SymmetricKey(data: data)
    }

    // MARK: - Errors

    enum CryptoError: Error, LocalizedError {
        case encryptionFailed
        case decryptionFailed
        case invalidNonce
        case invalidKeySize
        case authenticationFailure

        var errorDescription: String? {
            switch self {
            case .encryptionFailed:      return "Encryption failed"
            case .decryptionFailed:      return "Decryption failed"
            case .invalidNonce:          return "Invalid nonce (must be 12 bytes)"
            case .invalidKeySize:        return "Key must be 256 bits (32 bytes)"
            case .authenticationFailure: return "Authentication tag verification failed"
            }
        }
    }
}
