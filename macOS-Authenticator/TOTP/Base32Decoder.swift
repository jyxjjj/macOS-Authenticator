import Foundation

struct Base32Decoder {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    static func decode(_ input: String) throws -> Data {
        let cleaned = input.uppercased().filter { $0 != "=" && $0 != " " && $0 != "-" }
        var bits      = 0
        var bitsCount = 0
        var output    = Data()

        for char in cleaned {
            guard let idx = alphabet.firstIndex(of: char) else {
                throw Base32Error.invalidCharacter(char)
            }
            let value = alphabet.distance(from: alphabet.startIndex, to: idx)
            bits       = (bits << 5) | value
            bitsCount += 5
            if bitsCount >= 8 {
                bitsCount -= 8
                output.append(UInt8((bits >> bitsCount) & 0xFF))
            }
        }
        return output
    }

    enum Base32Error: Error, LocalizedError {
        case invalidCharacter(Character)

        var errorDescription: String? {
            switch self {
            case .invalidCharacter(let c):
                return "Invalid Base32 character: '\(c)'"
            }
        }
    }
}
