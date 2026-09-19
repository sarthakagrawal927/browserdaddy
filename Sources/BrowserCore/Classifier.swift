import Foundation

/// Optional enrichment via classifier.dev. Runs ONLY when the user has
/// opted in during onboarding (meta.classify_optin) or explicitly taps
/// "Classify" — the app makes no other network calls.
public struct Classifier: Sendable {
    public let db: SQLiteStore
    private static let endpoint = URL(
        string: "https://classifier.dev/v1/classify")!

    public static let domainLabels = [
        "development", "ai-tools", "cloud-infra", "documentation",
        "social-media", "video", "music", "news", "shopping", "finance",
        "communication", "productivity", "search", "gaming",
        "entertainment", "education", "travel", "health", "other",
    ]
    public static let pageLabels = [
        "programming", "devops-infra", "ai-ml", "web-dev", "data",
        "news", "entertainment", "gaming", "finance", "shopping",
        "social-media", "music", "video-entertainment", "tutorial-docs",
        "science", "politics", "sports", "health", "travel", "food",
        "productivity", "communication", "search-homepage", "nsfw", "other",
    ]

    public init(db: SQLiteStore) { self.db = db }

    public struct Result: Sendable {
        public var domains = 0
        public var pages = 0
        public var coveragePct = 0.0
    }

    /// Classify every unclassified domain, then top-N unclassified pages.
    /// Progress strings go to `log`.
    public func run(pageLimit: Int = 5000,
                    log: @Sendable (String) -> Void) async throws -> Result {
        var out = Result()

        let hosts = try db.query("""
            SELECT \(ReportEngine.hostSQL) h, COUNT(*) c FROM visits
            GROUP BY h ORDER BY c DESC
        """).map { $0["h"]?.text ?? "" }
        let knownD = Set(try db.query("SELECT host FROM domain_categories")
            .compactMap { $0["host"]?.text })
        let newHosts = hosts.filter { !$0.isEmpty && !knownD.contains($0) }
        if !newHosts.isEmpty {
            let pairs = try await classify(texts: newHosts,
                                   labels: Self.domainLabels, log: log)
            try db.transaction {
                for p in pairs {
                    try db.execute("""
                        INSERT OR REPLACE INTO domain_categories
                        (host, category, confidence) VALUES (?,?,?)
                    """, [.text(p.0), .text(p.1), .double(p.2)])
                }
            }
            out.domains = pairs.count
            log("\(pairs.count) domains classified")
        }

        let pages = try db.query("""
            SELECT url, MAX(title) t, COUNT(*) c FROM visits
            WHERE title != '' AND url LIKE 'http%'
            GROUP BY url ORDER BY c DESC LIMIT ?
        """, [.int(Int64(pageLimit))])
        let knownP = Set(try db.query("SELECT url FROM page_categories")
            .compactMap { $0["url"]?.text })
        let newPages = pages.compactMap { r -> (String, String)? in
            guard let u = r["url"]?.text, !u.isEmpty, !knownP.contains(u),
                  let t = r["t"]?.text, !t.isEmpty else { return nil }
            let host = URL(string: u)?.host ?? u
            return (u, "\(host) — \(t.prefix(160))")
        }
        if !newPages.isEmpty {
            let pairs = try await classify(texts: newPages.map(\.1),
                                   labels: Self.pageLabels, log: log)
            try db.transaction {
                for (i, p) in pairs.enumerated() {
                    try db.execute("""
                        INSERT OR REPLACE INTO page_categories
                        (url, category, confidence) VALUES (?,?,?)
                    """, [.text(newPages[i].0), .text(p.1), .double(p.2)])
                }
            }
            out.pages = pairs.count
            log("\(pairs.count) pages classified")
        }

        let covered = try db.scalar("""
            SELECT COUNT(*) FROM visits v JOIN domain_categories c
            ON c.host = CASE WHEN v.url LIKE 'http%' THEN
                substr(substr(v.url, instr(v.url,'//')+2), 1,
                       instr(substr(v.url, instr(v.url,'//')+2)||'/', '/')-1)
                ELSE substr(v.url,1,40) END
        """, as: { $0.int }) ?? 0
        let tot = try db.scalar("SELECT COUNT(*) FROM visits",
                                as: { $0.int }) ?? 1
        out.coveragePct = 100.0 * Double(covered) / Double(tot)
        return out
    }

    private func classify(texts: [String], labels: [String],
                          log: @Sendable (String) -> Void) async throws
        -> [(String, String, Double)] {
        var out: [(String, String, Double)] = []
        for chunkStart in stride(from: 0, to: texts.count, by: 1000) {
            let chunk = Array(texts[chunkStart..<min(chunkStart + 1000,
                                                    texts.count)])
            var req = URLRequest(url: Self.endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "inputs": chunk, "labels": labels])
            log("classifying \(chunk.count)…")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200
            else {
                throw NSError(domain: "classifier", code: 1,
                              userInfo: [NSLocalizedDescriptionKey:
                                  "classifier.dev request failed"])
            }
            let json = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
            let results = json?["results"] as? [[String: Any]] ?? []
            for (i, r) in results.enumerated() {
                out.append((chunk[i],
                            r["label"] as? String ?? "other",
                            r["confidence"] as? Double ?? 0))
            }
        }
        return out
    }
}
