import Foundation

/// The permanent archive. Merges forever — rows pruned by browsers survive.
public final class ArchiveStore: @unchecked Sendable {
    public let db: SQLiteStore

    public static let defaultURL: URL = {
        let dir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrowserDaddy", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("browserdaddy.db")
    }()

    public init(url: URL = ArchiveStore.defaultURL) throws {
        db = try SQLiteStore(url: url)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS visits (
                browser TEXT, profile TEXT, visit_id INT, url TEXT, title TEXT,
                visit_time_utc TEXT, visit_count INT, typed_count INT,
                transition TEXT, duration_s REAL, from_visit INT)
        """)
        try db.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_visits_dedup
                ON visits(browser, profile, visit_id)
        """)
        try db.execute("CREATE INDEX IF NOT EXISTS idx_visits_time ON visits(visit_time_utc)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_visits_url ON visits(url)")
        try db.execute("""
            CREATE TABLE IF NOT EXISTS searches (
                browser TEXT, profile TEXT, term TEXT, url TEXT, title TEXT)
        """)
        try db.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_searches_dedup
                ON searches(browser, profile, term, url)
        """)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS focus (
                id INTEGER PRIMARY KEY,
                start_utc TEXT, end_utc TEXT, app TEXT, url TEXT, title TEXT,
                ticks INT DEFAULT 0, active_s REAL DEFAULT 0)
        """)
        try db.execute("CREATE INDEX IF NOT EXISTS idx_focus_start ON focus(start_utc)")
        try db.execute("""
            CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)
        """)
    }

    /// INSERT OR IGNORE; returns count actually inserted.
    @discardableResult
    public func merge(visits: [HistoryVisit], source: HistorySource) throws -> Int {
        try db.transaction {
            var inserted = 0
            try db.execute("BEGIN")
            for v in visits {
                inserted += try db.execute("""
                    INSERT OR IGNORE INTO visits
                    (browser, profile, visit_id, url, title, visit_time_utc,
                     visit_count, typed_count, transition, duration_s, from_visit)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?)
                """,
                    [.text(source.browser), .text(source.profile), .int(v.visitID),
                     .text(v.url), .text(v.title),
                     .text(ISO8601.format(v.visitedAt)), .int(Int64(v.visitCount)),
                     .int(Int64(v.typedCount)),
                     v.transition.map(DBValue.text) ?? .null,
                     v.duration.map(DBValue.double) ?? .null,
                     v.fromVisit.map(DBValue.int) ?? .null])
            }
            try db.execute("COMMIT")
            return inserted
        }
    }

    @discardableResult
    public func merge(searches: [(term: String, url: String, title: String)],
                      source: HistorySource) throws -> Int {
        try db.transaction {
            var inserted = 0
            try db.execute("BEGIN")
            for s in searches {
                inserted += try db.execute("""
                    INSERT OR IGNORE INTO searches
                    (browser, profile, term, url, title) VALUES (?,?,?,?,?)
                """,
                    [.text(source.browser), .text(source.profile), .text(s.term),
                     .text(s.url), .text(s.title)])
            }
            try db.execute("COMMIT")
            return inserted
        }
    }
}

public enum ISO8601 {
    nonisolated(unsafe) private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    public static func format(_ d: Date) -> String { formatter.string(from: d) }
    public static func parse(_ s: String) -> Date? { formatter.date(from: s) }
}
