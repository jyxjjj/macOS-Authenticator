import Foundation
import CryptoKit

struct TOTPEngine {

    static func generateCode(secret: Data,
                             algorithm: TOTPAlgorithm,
                             digits: Int,
                             period: Int,
                             date: Date = Date()) -> String {
        let counter = UInt64(date.timeIntervalSince1970) / UInt64(period)
        return hotp(secret: secret, counter: counter, algorithm: algorithm, digits: digits)
    }

    static func timeRemaining(period: Int, date: Date = Date()) -> Double {
        let elapsed = date.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(period))
        return Double(period) - elapsed
    }

    static func timeFraction(period: Int, date: Date = Date()) -> Double {
        let elapsed = date.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(period))
        return elapsed / Double(period)
    }

    // MARK: - HOTP (RFC 4226)

    private static func hotp(secret: Data,
                             counter: UInt64,
                             algorithm: TOTPAlgorithm,
                             digits: Int) -> String {
        var counterBE = counter.bigEndian
        let counterData = withUnsafeBytes(of: &counterBE) { Data($0) }

        let key = SymmetricKey(data: secret)
        let hmacBytes: Data
        switch algorithm {
        case .sha1:
            hmacBytes = Data(HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key))
        case .sha256:
            hmacBytes = Data(HMAC<SHA256>.authenticationCode(for: counterData, using: key))
        case .sha512:
            hmacBytes = Data(HMAC<SHA512>.authenticationCode(for: counterData, using: key))
        }

        // Dynamic truncation (RFC 4226 §5.4)
        let offset   = Int(hmacBytes[hmacBytes.count - 1] & 0x0F)
        let truncated = UInt32(hmacBytes[offset]     & 0x7F) << 24
                      | UInt32(hmacBytes[offset + 1])        << 16
                      | UInt32(hmacBytes[offset + 2])        <<  8
                      | UInt32(hmacBytes[offset + 3])

        let modulo = UInt32(pow(10.0, Double(digits)))
        let code   = truncated % modulo
        return String(format: "%0\(digits)d", code)
    }

    // MARK: - OTP Auth URI parser

    static func parseOTPAuthURI(_ uri: String) throws -> (
        secret: String, issuer: String, account: String,
        algorithm: TOTPAlgorithm, digits: Int, period: Int
    ) {
        guard let url = URL(string: uri),
              url.scheme == "otpauth",
              url.host == "totp" else {
            throw TOTPError.invalidURI
        }

        let rawPath = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        let label   = rawPath.removingPercentEncoding ?? rawPath

        var issuer  = ""
        var account = label
        if label.contains(":") {
            let parts = label.split(separator: ":", maxSplits: 1)
            issuer  = String(parts[0])
            account = parts.count > 1 ? String(parts[1]) : label
        }

        guard let comps = URLComponents(string: uri) else { throw TOTPError.invalidURI }

        var secret    = ""
        var algorithm = TOTPAlgorithm.sha1
        var digits    = 6
        var period    = 30

        for item in comps.queryItems ?? [] {
            switch item.name {
            case "secret":    secret = item.value ?? ""
            case "issuer":    issuer = item.value ?? issuer
            case "algorithm":
                switch item.value?.uppercased() {
                case "SHA256": algorithm = .sha256
                case "SHA512": algorithm = .sha512
                default:       algorithm = .sha1
                }
            case "digits": digits = Int(item.value ?? "6") ?? 6
            case "period": period = Int(item.value ?? "30") ?? 30
            default: break
            }
        }

        guard !secret.isEmpty else { throw TOTPError.missingSecret }
        return (secret, issuer, account, algorithm, digits, period)
    }

    // MARK: - Errors

    enum TOTPError: Error, LocalizedError {
        case invalidURI
        case missingSecret

        var errorDescription: String? {
            switch self {
            case .invalidURI:    return "Invalid OTP Auth URI"
            case .missingSecret: return "Missing secret in URI"
            }
        }
    }
}
