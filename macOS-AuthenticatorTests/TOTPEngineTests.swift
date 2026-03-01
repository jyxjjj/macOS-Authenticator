import XCTest
import CryptoKit
@testable import macOS_Authenticator

/// RFC 6238 Appendix B test vectors
final class TOTPEngineTests: XCTestCase {

    // Test secrets (ASCII bytes, as specified in RFC 6238 Appendix B)
    private let sha1Secret   = Data("12345678901234567890".utf8)            // 20 bytes
    private let sha256Secret = Data("12345678901234567890123456789012".utf8) // 32 bytes
    private let sha512Secret = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8) // 64 bytes

    // MARK: - SHA1 vectors

    func testSHA1Vectors() {
        let vectors: [(time: TimeInterval, expected: String)] = [
            (59,          "94287082"),
            (1111111109,  "07081804"),
            (1111111111,  "14050471"),
            (1234567890,  "89005924"),
            (2000000000,  "69279037"),
            (20000000000, "65353130"),
        ]
        for v in vectors {
            let code = TOTPEngine.generateCode(secret: sha1Secret, algorithm: .sha1,
                                              digits: 8, period: 30,
                                              date: Date(timeIntervalSince1970: v.time))
            XCTAssertEqual(code, v.expected, "SHA1 at T=\(Int(v.time))")
        }
    }

    // MARK: - SHA256 vectors

    func testSHA256Vectors() {
        let vectors: [(time: TimeInterval, expected: String)] = [
            (59,          "46119246"),
            (1111111109,  "68084774"),
            (1111111111,  "67062674"),
            (1234567890,  "91819424"),
            (2000000000,  "90698825"),
            (20000000000, "77737706"),
        ]
        for v in vectors {
            let code = TOTPEngine.generateCode(secret: sha256Secret, algorithm: .sha256,
                                              digits: 8, period: 30,
                                              date: Date(timeIntervalSince1970: v.time))
            XCTAssertEqual(code, v.expected, "SHA256 at T=\(Int(v.time))")
        }
    }

    // MARK: - SHA512 vectors

    func testSHA512Vectors() {
        let vectors: [(time: TimeInterval, expected: String)] = [
            (59,          "90693936"),
            (1111111109,  "25091201"),
            (1111111111,  "99943326"),
            (1234567890,  "93441116"),
            (2000000000,  "38618901"),
            (20000000000, "47863826"),
        ]
        for v in vectors {
            let code = TOTPEngine.generateCode(secret: sha512Secret, algorithm: .sha512,
                                              digits: 8, period: 30,
                                              date: Date(timeIntervalSince1970: v.time))
            XCTAssertEqual(code, v.expected, "SHA512 at T=\(Int(v.time))")
        }
    }

    // MARK: - Other tests

    func testSixDigitCodeLength() {
        let code = TOTPEngine.generateCode(secret: sha1Secret, algorithm: .sha1,
                                          digits: 6, period: 30,
                                          date: Date(timeIntervalSince1970: 59))
        XCTAssertEqual(code.count, 6)
        XCTAssert(code.allSatisfy { $0.isNumber })
    }

    func testTimeRemaining() {
        let remaining = TOTPEngine.timeRemaining(period: 30, date: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(remaining, 20.0, accuracy: 0.001)
    }

    func testTimeFraction() {
        let fraction = TOTPEngine.timeFraction(period: 30, date: Date(timeIntervalSince1970: 15))
        XCTAssertEqual(fraction, 0.5, accuracy: 0.001)
    }

    func testBase32DecodeRoundtrip() throws {
        // "MFRA" decodes to bytes [0x61, 0x42] i.e. "aB"
        let decoded = try Base32Decoder.decode("MFRA")
        XCTAssertEqual(decoded, Data([0x61, 0x42]))
    }

    func testBase32InvalidCharacter() {
        XCTAssertThrowsError(try Base32Decoder.decode("INVALID!")) { err in
            XCTAssert(err is Base32Decoder.Base32Error)
        }
    }

    func testBase32PaddingIgnored() throws {
        // Padding characters should be stripped
        let a = try Base32Decoder.decode("MFRA")
        let b = try Base32Decoder.decode("MFRA====")
        XCTAssertEqual(a, b)
    }

    func testParseOTPAuthURI() throws {
        let uri = "otpauth://totp/GitHub:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA256&digits=6&period=30"
        let r   = try TOTPEngine.parseOTPAuthURI(uri)
        XCTAssertEqual(r.secret,    "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(r.issuer,    "GitHub")
        XCTAssertEqual(r.algorithm, .sha256)
        XCTAssertEqual(r.digits,    6)
        XCTAssertEqual(r.period,    30)
    }

    func testParseURIMissingSecret() {
        let uri = "otpauth://totp/Test?issuer=X"
        XCTAssertThrowsError(try TOTPEngine.parseOTPAuthURI(uri))
    }

    func testParseInvalidScheme() {
        XCTAssertThrowsError(try TOTPEngine.parseOTPAuthURI("https://example.com"))
    }
}
