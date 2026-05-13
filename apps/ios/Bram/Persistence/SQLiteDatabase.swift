import Foundation
import SQLite3

enum SQLiteDatabaseError: Error, Equatable {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
}

final class SQLiteDatabase {
    private let handle: OpaquePointer?

    init(path: String) throws {
        var db: OpaquePointer?
        if sqlite3_open(path, &db) != SQLITE_OK {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open SQLite database."
            sqlite3_close(db)
            throw SQLiteDatabaseError.openFailed(message)
        }
        handle = db
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? lastErrorMessage
            sqlite3_free(error)
            throw SQLiteDatabaseError.stepFailed(message)
        }
    }

    func withStatement<T>(_ sql: String, _ work: (OpaquePointer?) throws -> T) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteDatabaseError.prepareFailed(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        return try work(statement)
    }

    func step(_ statement: OpaquePointer?) throws -> Bool {
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW { return true }
        if result == SQLITE_DONE { return false }
        throw SQLiteDatabaseError.stepFailed(lastErrorMessage)
    }

    func bind(_ value: String?, to index: Int32, in statement: OpaquePointer?) throws {
        let result: Int32
        if let value {
            result = sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        } else {
            result = sqlite3_bind_null(statement, index)
        }
        guard result == SQLITE_OK else { throw SQLiteDatabaseError.bindFailed(lastErrorMessage) }
    }

    func bind(_ value: Int?, to index: Int32, in statement: OpaquePointer?) throws {
        guard let value else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw SQLiteDatabaseError.bindFailed(lastErrorMessage)
            }
            return
        }
        guard sqlite3_bind_int64(statement, index, sqlite3_int64(value)) == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(lastErrorMessage)
        }
    }

    func bind(_ value: Double?, to index: Int32, in statement: OpaquePointer?) throws {
        guard let value else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw SQLiteDatabaseError.bindFailed(lastErrorMessage)
            }
            return
        }
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(lastErrorMessage)
        }
    }

    func bind(_ value: Date?, to index: Int32, in statement: OpaquePointer?) throws {
        try bind(value.map { Self.dateString(from: $0) }, to: index, in: statement)
    }

    func string(at index: Int32, in statement: OpaquePointer?) -> String? {
        guard let value = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: value)
    }

    func int(at index: Int32, in statement: OpaquePointer?) -> Int? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(statement, index))
    }

    func double(at index: Int32, in statement: OpaquePointer?) -> Double? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : sqlite3_column_double(statement, index)
    }

    func date(at index: Int32, in statement: OpaquePointer?) -> Date? {
        string(at: index, in: statement).flatMap(Self.date(from:))
    }

    private static func dateString(from date: Date) -> String {
        makeDateFormatter().string(from: date)
    }

    private static func date(from string: String) -> Date? {
        makeDateFormatter().date(from: string)
    }

    private static func makeDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private var lastErrorMessage: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error."
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
