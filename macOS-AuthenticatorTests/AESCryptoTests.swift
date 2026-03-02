import XCTest
import CryptoKit
@testable import macOS_Authenticator

final class AESCryptoTests: XCTestCase {

    func testRoundTrip() throws {
        let key  = AESCryptoManager.generateKey()
        let plain = Data("Hello, TOTP!".utf8)
        let (enc, nonce) = try AESCryptoManager.encrypt(data: plain, key: key)
        let dec  = try AESCryptoManager.decrypt(encrypted: enc, nonce: nonce, key: key)
        XCTAssertEqual(plain, dec)
    }

    func testWrongKeyFails() throws {
        let key1  = AESCryptoManager.generateKey()
        let key2  = AESCryptoManager.generateKey()
        let plain = Data("Secret data".utf8)
        let (enc, nonce) = try AESCryptoManager.encrypt(data: plain, key: key1)
        XCTAssertThrowsError(try AESCryptoManager.decrypt(encrypted: enc, nonce: nonce, key: key2)) { err in
            XCTAssert(err is AESCryptoManager.CryptoError)
        }
    }

    func testTamperingDetected() throws {
        let key   = AESCryptoManager.generateKey()
        let plain = Data("Tamper me!".utf8)
        var (enc, nonce) = try AESCryptoManager.encrypt(data: plain, key: key)
        enc[0] ^= 0xFF    // flip a byte in the ciphertext
        XCTAssertThrowsError(try AESCryptoManager.decrypt(encrypted: enc, nonce: nonce, key: key))
    }

    func testInvalidNonceLength() throws {
        let key      = AESCryptoManager.generateKey()
        let enc      = Data(repeating: 0, count: 32)
        let badNonce = Data(repeating: 0, count: 10)  // not 12 bytes
        XCTAssertThrowsError(try AESCryptoManager.decrypt(encrypted: enc, nonce: badNonce, key: key)) { err in
            if let ce = err as? AESCryptoManager.CryptoError {
                XCTAssertEqual(ce, .invalidNonce)
            }
        }
    }

    func testKeyFromRawData() throws {
        let raw = Data(repeating: 0xAB, count: 32)
        let key = try AESCryptoManager.key(from: raw)
        let plain = Data("test payload".utf8)
        let (enc, nonce) = try AESCryptoManager.encrypt(data: plain, key: key)
        let dec  = try AESCryptoManager.decrypt(encrypted: enc, nonce: nonce, key: key)
        XCTAssertEqual(plain, dec)
    }

    func testInvalidKeySizeThrows() {
        let badKey = Data(repeating: 0, count: 16)   // 128 bits
        XCTAssertThrowsError(try AESCryptoManager.key(from: badKey)) { err in
            if let ce = err as? AESCryptoManager.CryptoError {
                XCTAssertEqual(ce, .invalidKeySize)
            }
        }
    }

    func testNoncesAreUnique() throws {
        let key   = AESCryptoManager.generateKey()
        let plain = Data("uniqueness test".utf8)
        var nonces: [Data] = []
        for _ in 0..<20 {
            let (_, nonce) = try AESCryptoManager.encrypt(data: plain, key: key)
            nonces.append(nonce)
        }
        let uniqueNonces = Set(nonces.map { $0.base64EncodedString() })
        XCTAssertEqual(uniqueNonces.count, 20, "All nonces should be unique")
    }

    func testMultipleRoundTrips() throws {
        let key = AESCryptoManager.generateKey()
        for i in 0..<20 {
            let plain = Data("Message \(i) with some content here".utf8)
            let (enc, nonce) = try AESCryptoManager.encrypt(data: plain, key: key)
            let dec = try AESCryptoManager.decrypt(encrypted: enc, nonce: nonce, key: key)
            XCTAssertEqual(plain, dec, "Round-trip failed at iteration \(i)")
        }
    }

    func testEmptyDataRoundTrip() throws {
        let key   = AESCryptoManager.generateKey()
        let plain = Data()
        let (enc, nonce) = try AESCryptoManager.encrypt(data: plain, key: key)
        let dec   = try AESCryptoManager.decrypt(encrypted: enc, nonce: nonce, key: key)
        XCTAssertEqual(plain, dec)
    }
}

// Equatable conformance for test comparisons
extension AESCryptoManager.CryptoError {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.encryptionFailed, .encryptionFailed),
             (.decryptionFailed, .decryptionFailed),
             (.invalidNonce, .invalidNonce),
             (.invalidKeySize, .invalidKeySize),
             (.authenticationFailure, .authenticationFailure):
            return true
        default:
            return false
        }
    }
}
