#if os(macOS)

import Foundation
import SQLite3

/// Keeps this app's store out of the shared Application Support/default.store path.
enum MoviesPersistentStore {
    static func prepareStore() throws -> URL {
        let fileManager = FileManager.default
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("com.aryanrogye.MoviesAPIClient", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let destination = directory.appendingPathComponent("MoviesAPIClient.store")
        guard !fileManager.fileExists(atPath: destination.path) else { return destination }

        let oldContainer = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.aryanrogye.MoviesAPIClient/Data/Library/Application Support/default.store")
        let candidates = [support.appendingPathComponent("default.store"), oldContainer]
        let source = candidates.compactMap { url -> (URL, Int)? in
            guard let count = try? itemCount(at: url), count > 0 else { return nil }
            return (url, count)
        }.max { $0.1 < $1.1 }?.0

        if let source {
            let temporary = directory.appendingPathComponent(".migration-\(UUID().uuidString).store")
            do {
                try backup(from: source, to: temporary)
                guard try itemCount(at: temporary) > 0 else {
                    throw StoreError("The copied database has no history or library items.")
                }
                try fileManager.moveItem(at: temporary, to: destination)
            } catch {
                try? fileManager.removeItem(at: temporary)
                throw error
            }
        }

        return destination
    }

    private static func itemCount(at url: URL) throws -> Int {
        guard FileManager.default.fileExists(atPath: url.path) else { throw StoreError("Store is missing") }
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let database else {
            sqlite3_close(database)
            throw StoreError("Could not open \(url.path)")
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let query = "SELECT (SELECT count(*) FROM ZHISTORY) + (SELECT count(*) FROM ZFAVORITE) + (SELECT count(*) FROM ZCOLLECTION) + (SELECT count(*) FROM ZCOLLECTIONITEM)"
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError("Store does not contain this app's model tables")
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw StoreError("Could not count stored items") }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private static func backup(from sourceURL: URL, to destinationURL: URL) throws {
        var source: OpaquePointer?
        var destination: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &source, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let source else {
            sqlite3_close(source)
            throw StoreError("Could not read the existing store")
        }
        defer { sqlite3_close(source) }
        guard sqlite3_open_v2(destinationURL.path, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let destination else {
            sqlite3_close(destination)
            throw StoreError("Could not create the new store")
        }
        defer { sqlite3_close(destination) }

        sqlite3_busy_timeout(source, 5_000)
        guard let operation = sqlite3_backup_init(destination, "main", source, "main") else {
            throw StoreError("Could not start the store copy")
        }
        let result = sqlite3_backup_step(operation, -1)
        let finishResult = sqlite3_backup_finish(operation)
        guard result == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw StoreError("Could not finish the store copy")
        }
    }

    private struct StoreError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}

#endif
