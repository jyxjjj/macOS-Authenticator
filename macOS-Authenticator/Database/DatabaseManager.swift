import Foundation
import SQLite3

final class DatabaseManager {
    private var db: OpaquePointer?
    private let dbURL: URL

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("com.desmg.macos.authenticator", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport,
                                                 withIntermediateDirectories: true)
        dbURL = appSupport.appendingPathComponent("entries.db")
    }

    // MARK: - Lifecycle

    func open() throws {
        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else {
            throw DBError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        try createTable()
    }

    func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    // MARK: - Schema

    private func createTable() throws {
        let sql = "CREATE TABLE IF NOT EXISTS totp_entries ("
            + "id              TEXT    PRIMARY KEY NOT NULL,"
            + "service_name    TEXT    NOT NULL,"
            + "username        TEXT    NOT NULL DEFAULT '',"
            + "encrypted_secret BLOB   NOT NULL,"
            + "nonce           BLOB    NOT NULL,"
            + "algorithm       TEXT    NOT NULL DEFAULT 'SHA1',"
            + "digits          INTEGER NOT NULL DEFAULT 6,"
            + "period          INTEGER NOT NULL DEFAULT 30,"
            + "created_at      REAL    NOT NULL,"
            + "updated_at      REAL    NOT NULL"
            + ");"
        try exec(sql)
    }

    // MARK: - CRUD

    func insert(_ entry: TOTPEntry) throws {
        let sql = "INSERT INTO totp_entries"
            + "(id, service_name, username, encrypted_secret, nonce,"
            + " algorithm, digits, period, created_at, updated_at)"
            + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError())
        }
        bindText(stmt, 1, entry.id.uuidString)
        bindText(stmt, 2, entry.serviceName)
        bindText(stmt, 3, entry.username)
        bindBlob(stmt, 4, entry.encryptedSecret)
        bindBlob(stmt, 5, entry.nonce)
        bindText(stmt, 6, entry.algorithm.rawValue)
        sqlite3_bind_int64(stmt, 7, Int64(entry.digits))
        sqlite3_bind_int64(stmt, 8, Int64(entry.period))
        sqlite3_bind_double(stmt, 9,  entry.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 10, entry.updatedAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.stepFailed(lastError())
        }
    }

    func update(_ entry: TOTPEntry) throws {
        let sql = "UPDATE totp_entries SET"
            + " service_name=?, username=?, encrypted_secret=?, nonce=?,"
            + " algorithm=?, digits=?, period=?, updated_at=?"
            + " WHERE id=?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError())
        }
        bindText(stmt, 1, entry.serviceName)
        bindText(stmt, 2, entry.username)
        bindBlob(stmt, 3, entry.encryptedSecret)
        bindBlob(stmt, 4, entry.nonce)
        bindText(stmt, 5, entry.algorithm.rawValue)
        sqlite3_bind_int64(stmt, 6, Int64(entry.digits))
        sqlite3_bind_int64(stmt, 7, Int64(entry.period))
        sqlite3_bind_double(stmt, 8, entry.updatedAt.timeIntervalSince1970)
        bindText(stmt, 9, entry.id.uuidString)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.stepFailed(lastError())
        }
    }

    func delete(id: UUID) throws {
        let sql = "DELETE FROM totp_entries WHERE id=?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError())
        }
        bindText(stmt, 1, id.uuidString)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.stepFailed(lastError())
        }
    }

    func fetchAll() throws -> [TOTPEntry] {
        let sql = "SELECT * FROM totp_entries ORDER BY created_at ASC;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError())
        }
        var entries: [TOTPEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let entry = rowToEntry(stmt) { entries.append(entry) }
        }
        return entries
    }

    func fetchById(_ id: UUID) throws -> TOTPEntry? {
        let sql = "SELECT * FROM totp_entries WHERE id=?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError())
        }
        bindText(stmt, 1, id.uuidString)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return rowToEntry(stmt)
    }

    /// Replace all entries atomically (used for master key rotation).
    func replaceAll(_ entries: [TOTPEntry]) throws {
        try exec("BEGIN TRANSACTION;")
        do {
            try exec("DELETE FROM totp_entries;")
            for entry in entries { try insert(entry) }
            try exec("COMMIT;")
        } catch {
            try exec("ROLLBACK;")
            throw error
        }
    }

    // MARK: - Row mapping

    private func rowToEntry(_ stmt: OpaquePointer?) -> TOTPEntry? {
        guard
            let idStr   = columnText(stmt, 0),
            let id      = UUID(uuidString: idStr),
            let svcName = columnText(stmt, 1),
            let uname   = columnText(stmt, 2),
            let encData = columnBlob(stmt, 3),
            let nonceD  = columnBlob(stmt, 4),
            let algStr  = columnText(stmt, 5)
        else { return nil }

        let algorithm = TOTPAlgorithm(rawValue: algStr) ?? .sha1
        let digits    = Int(sqlite3_column_int64(stmt, 6))
        let period    = Int(sqlite3_column_int64(stmt, 7))
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))
        let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))

        var entry = TOTPEntry(id: id, serviceName: svcName, username: uname,
                              encryptedSecret: encData, nonce: nonceD,
                              algorithm: algorithm, digits: digits, period: period)
        entry.createdAt = createdAt
        entry.updatedAt = updatedAt
        return entry
    }

    // MARK: - SQLite helpers

    @discardableResult
    private func exec(_ sql: String) throws -> Int32 {
        var errMsg: UnsafeMutablePointer<Int8>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errMsg)
            throw DBError.execFailed(msg)
        }
        return rc
    }

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String) {
        // SQLITE_TRANSIENT (-1) tells SQLite to copy the string immediately
        sqlite3_bind_text(stmt, idx, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func bindBlob(_ stmt: OpaquePointer?, _ idx: Int32, _ value: Data) {
        // SQLITE_TRANSIENT ensures SQLite copies the blob before we release the Data buffer
        value.withUnsafeBytes { ptr -> Void in
            sqlite3_bind_blob(stmt, idx, ptr.baseAddress, Int32(value.count),
                              unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
    }

    private func columnText(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: ptr)
    }

    private func columnBlob(_ stmt: OpaquePointer?, _ col: Int32) -> Data? {
        guard let ptr = sqlite3_column_blob(stmt, col) else { return nil }
        let bytes = sqlite3_column_bytes(stmt, col)
        return Data(bytes: ptr, count: Int(bytes))
    }

    private func lastError() -> String {
        return String(cString: sqlite3_errmsg(db))
    }

    // MARK: - Errors

    enum DBError: Error, LocalizedError {
        case openFailed(String)
        case prepareFailed(String)
        case stepFailed(String)
        case execFailed(String)

        var errorDescription: String? {
            switch self {
            case .openFailed(let m):    return "DB open failed: \(m)"
            case .prepareFailed(let m): return "DB prepare failed: \(m)"
            case .stepFailed(let m):    return "DB step failed: \(m)"
            case .execFailed(let m):    return "DB exec failed: \(m)"
            }
        }
    }
}
