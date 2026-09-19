import Foundation

/// Extracts visits + search terms from a snapshotted history DB.
/// Epochs: Chromium µs-since-1601, Firefox µs-unix, Safari s-since-2001.
public enum HistoryExtractor {
    static let chromiumEpochOffset: Double = 11_644_473_600
    static let safariEpochOffset: Double = 978_307_200

    static let chromiumTransitions: [Int: String] = [
        0: "link", 1: "typed", 2: "auto_bookmark", 3: "auto_subframe",
        4: "manual_subframe", 5: "generated", 6: "auto_toplevel",
        7: "form_submit", 8: "reload", 9: "keyword", 10: "keyword_generated",
    ]
    static let firefoxTransitions: [Int: String] = [
        1: "link", 2: "typed", 3: "bookmark", 4: "embed",
        5: "redirect_perm", 6: "redirect_temp", 7: "download",
        8: "framed_link", 9: "reload",
    ]

    public static func extract(
        snapshot dbPath: URL, source: HistorySource
    ) throws -> (visits: [HistoryVisit],
                 searches: [(term: String, url: String, title: String)]) {
        let db = try SQLiteStore(url: dbPath, readOnly: true)
        switch source.engine {
        case .chromium: return try chromium(db, source)
        case .firefox: return try firefox(db, source)
        case .safari: return try safari(db, source)
        }
    }

    private static func chromium(_ db: SQLiteStore, _ src: HistorySource)
        throws -> ([HistoryVisit], [(String, String, String)]) {
        let rows = try db.query("""
            SELECT v.id vid, u.url, u.title, v.visit_time t,
                   u.visit_count vc, u.typed_count tc,
                   v.transition tr, v.visit_duration dur, v.from_visit frm
            FROM visits v JOIN urls u ON u.id = v.url
        """)
        let visits = rows.map { r in
            HistoryVisit(
                browser: src.browser, profile: src.profile,
                visitID: r["vid"]?.int ?? 0,
                url: r["url"]?.text ?? "",
                title: r["title"]?.text ?? "",
                visitedAt: Date(timeIntervalSince1970:
                    (r["t"]?.double ?? 0) / 1e6 - chromiumEpochOffset),
                visitCount: Int(r["vc"]?.int ?? 0),
                typedCount: Int(r["tc"]?.int ?? 0),
                transition: chromiumTransitions[
                    Int(r["tr"]?.int ?? 0) & 0xFF] ?? "\(r["tr"]?.int ?? 0)",
                duration: (r["dur"]?.double).map { $0 / 1e6 },
                fromVisit: r["frm"]?.int)
        }
        var searches: [(String, String, String)] = []
        if let srows = try? db.query("""
            SELECT k.term, u.url, u.title
            FROM keyword_search_terms k JOIN urls u ON u.id = k.url_id
        """) {
            searches = srows.map {
                ($0["term"]?.text ?? "", $0["url"]?.text ?? "",
                 $0["title"]?.text ?? "")
            }
        }
        return (visits, searches)
    }

    private static func firefox(_ db: SQLiteStore, _ src: HistorySource)
        throws -> ([HistoryVisit], [(String, String, String)]) {
        let rows = try db.query("""
            SELECT h.id vid, p.url, p.title, h.visit_date t,
                   p.visit_count vc, p.typed tc, h.visit_type tr,
                   h.from_visit frm
            FROM moz_historyvisits h JOIN moz_places p ON p.id = h.place_id
        """)
        let visits = rows.map { r in
            HistoryVisit(
                browser: src.browser, profile: src.profile,
                visitID: r["vid"]?.int ?? 0,
                url: r["url"]?.text ?? "",
                title: r["title"]?.text ?? "",
                visitedAt: Date(timeIntervalSince1970:
                    (r["t"]?.double ?? 0) / 1e6),
                visitCount: Int(r["vc"]?.int ?? 0),
                typedCount: Int(r["tc"]?.int ?? 0),
                transition: firefoxTransitions[Int(r["tr"]?.int ?? 0)]
                    ?? "\(r["tr"]?.int ?? 0)",
                fromVisit: r["frm"]?.int)
        }
        return (visits, [])
    }

    private static func safari(_ db: SQLiteStore, _ src: HistorySource)
        throws -> ([HistoryVisit], [(String, String, String)]) {
        let rows = try db.query("""
            SELECT v.id vid, i.url, v.title, v.visit_time t, i.visit_count vc
            FROM history_visits v JOIN history_items i ON i.id = v.history_item
        """)
        let visits = rows.map { r in
            HistoryVisit(
                browser: src.browser, profile: src.profile,
                visitID: r["vid"]?.int ?? 0,
                url: r["url"]?.text ?? "",
                title: r["title"]?.text ?? "",
                visitedAt: Date(timeIntervalSince1970:
                    (r["t"]?.double ?? 0) + safariEpochOffset),
                visitCount: Int(r["vc"]?.int ?? 0), typedCount: 0,
                transition: nil, fromVisit: nil)
        }
        return (visits, [])
    }

    /// Full pipeline: discover → snapshot → extract → merge. Returns
    /// per-source results for the UI (blocked sources included).
    public static func run(
        into store: ArchiveStore,
        onProgress: ((String) -> Void)? = nil
    ) -> [(source: HistorySource, inserted: Int, error: String?)] {
        let sources = BrowserDiscovery.discover()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        var results: [(HistorySource, Int, String?)] = []
        for src in sources {
            do {
                let snap = try BrowserDiscovery.snapshot(src, into: tmp)
                let (visits, searches) = try extract(snapshot: snap, source: src)
                let n = try store.merge(visits: visits, source: src)
                let ns = try store.merge(searches: searches, source: src)
                results.append((src, n, nil))
                onProgress?("\(src.browser)/\(src.profile): +\(n) visits, +\(ns) searches")
            } catch let e as DBError {
                results.append((src, 0, e.message))
            } catch {
                results.append((src, 0, "permission denied (grant Full Disk Access)"))
            }
        }
        return results
    }
}
