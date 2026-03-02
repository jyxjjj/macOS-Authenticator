import Foundation

enum TOTPAlgorithm: String, Codable, CaseIterable {
    case sha1   = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

struct TOTPEntry: Identifiable, Codable {
    var id: UUID
    var serviceName: String
    var username: String
    var encryptedSecret: Data  // AES-256-GCM ciphertext + tag
    var nonce: Data            // 12-byte random nonce
    var algorithm: TOTPAlgorithm
    var digits: Int
    var period: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         serviceName: String,
         username: String,
         encryptedSecret: Data,
         nonce: Data,
         algorithm: TOTPAlgorithm = .sha1,
         digits: Int = 6,
         period: Int = 30) {
        self.id              = id
        self.serviceName     = serviceName
        self.username        = username
        self.encryptedSecret = encryptedSecret
        self.nonce           = nonce
        self.algorithm       = algorithm
        self.digits          = digits
        self.period          = period
        self.createdAt       = Date()
        self.updatedAt       = Date()
    }
}
