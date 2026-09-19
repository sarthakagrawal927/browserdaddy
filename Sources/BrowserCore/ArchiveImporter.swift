import Foundation

/// One-time import of the Python prototype archive
/// (~/browserdaddy/out/browserdaddy.db) — schema is identical, so this is a
/// straight INSERT OR IGNORE across all three tables.
public enum ArchiveImporter {
    public static let pythonDB = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("browserdaddy/out/browserdaddy.db")

    public static var needsImport: Bool {
        FileManager.default.fileExists(atPath: pythonDB.path)
    }

    @discardableResult
    public static func importIfNeeded(into store: ArchiveStore) throws -> Bool {
        let done = try store.db.scalar(
            "SELECT value FROM meta WHERE key='imported_python'",
            as: { $0.text })
        if done == "1" || !needsImport { return false }

        try store.db.transaction {
            try store.db.execute("ATTACH DATABASE ? AS old", [.text(pythonDB.path)])
            defer { _ = try? store.db.execute("DETACH DATABASE old") }
            try store.db.execute(
                "INSERT OR IGNORE INTO visits SELECT * FROM old.visits")
            try store.db.execute(
                "INSERT OR IGNORE INTO searches SELECT * FROM old.searches")
            try store.db.execute("""
                INSERT OR IGNORE INTO focus
                (start_utc, end_utc, app, url, title, ticks, active_s)
                SELECT start_utc, end_utc, app, url, title, ticks, active_s
                FROM old.focus
            """)
            try store.db.execute(
                "INSERT OR REPLACE INTO meta (key, value) VALUES ('imported_python','1')")
        }
        return true
    }
}
