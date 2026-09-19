import Foundation

/// Report queries over the archive. Port of stats.py — cross-browser fields
/// only; duration is deliberately absent from leaderboards (unreliable).
public struct ReportEngine: Sendable {
    private let db: SQLiteStore

    public init(store: ArchiveStore) { db = store.db }

    private static let hostSQL = """
        CASE WHEN url LIKE 'http%' THEN
            substr(substr(url, instr(url,'//')+2), 1,
                   instr(substr(url, instr(url,'//')+2)||'/', '/')-1)
        ELSE substr(url, 1, 40) END
    """

    public struct SourceSummary: Sendable {
        public var name: String
        public var visits: Int64
        public var first: String
        public var last: String
    }

    public struct Count: Sendable {
        public var label: String
        public var value: Int64
        public var extra: String = ""
    }

    public struct Session: Sendable {
        public var source: String
        public var visits: Int64
        public var domains: Int64
        public var spanSeconds: Double
        public var start: Date
    }

    public struct DayPoint: Sendable {
        public var date: String     // yyyy-MM-dd
        public var browser: String
        public var count: Int64
    }

    public struct FocusDay: Sendable {
        public var date: String
        public var activeSeconds: Double
        public var ticks: Int64
    }

    public struct Report: Sendable {
        public var totalVisits: Int64 = 0
        public var uniqueURLs: Int64 = 0
        public var uniqueDomains: Int64 = 0
        public var sources: [SourceSummary] = []
        public var monthlyShare: [String] = []
        public var topDomains: [Count] = []
        public var topSites: [Count] = []
        public var topPerBrowser: [Count] = []
        public var personalities: [Count] = []
        public var hourly: [Count] = []
        public var weekday: [Count] = []
        public var daily: [Count] = []
        public var habit: [Count] = []
        public var revisited: [Count] = []
        public var typedShare: [Count] = []
        public var sessionSummary: [Count] = []
        public var rabbitHoles: [Session] = []
        public var attentionApps: [Count] = []
        public var attentionSites: [Count] = []
        public var searches: [Count] = []
        // time series
        public var dailySeries: [DayPoint] = []      // day × browser counts
        public var heatmap: [Int64] = Array(repeating: 0, count: 7 * 24) // dow*24+hour
        public var focusDaily: [FocusDay] = []
        public var newDomainsPerWeek: [Count] = []
        public var cumulativeDomains: [Count] = []   // cumulative unique domains per month
        public var domainTrends: [(domain: String, monthly: [Count])] = []
    }

    public func build() throws -> Report {
        var r = Report()
        r.totalVisits = try db.scalar(
            "SELECT COUNT(*) FROM visits", as: { $0.int }) ?? 0
        r.uniqueURLs = try db.scalar(
            "SELECT COUNT(DISTINCT url) FROM visits", as: { $0.int }) ?? 0
        r.uniqueDomains = try db.scalar(
            "SELECT COUNT(DISTINCT \(Self.hostSQL)) FROM visits",
            as: { $0.int }) ?? 0

        r.sources = try db.query("""
            SELECT browser||'/'||profile src, COUNT(*) c,
                   substr(MIN(visit_time_utc),1,10) f,
                   substr(MAX(visit_time_utc),1,10) l
            FROM visits GROUP BY 1 ORDER BY 2 DESC
        """).map {
            SourceSummary(name: $0["src"]?.text ?? "?",
                          visits: $0["c"]?.int ?? 0,
                          first: $0["f"]?.text ?? "",
                          last: $0["l"]?.text ?? "")
        }

        let months = try db.query("""
            SELECT substr(visit_time_utc,1,7) m, browser, COUNT(*) c
            FROM visits GROUP BY m, browser ORDER BY m, c DESC
        """)
        var byMonth: [String: [(String, Int64)]] = [:]
        var order: [String] = []
        for row in months {
            let m = row["m"]?.text ?? ""
            if byMonth[m] == nil { order.append(m) }
            byMonth[m, default: []].append(
                (row["browser"]?.text ?? "?", row["c"]?.int ?? 0))
        }
        r.monthlyShare = order.map { m in
            let lst = byMonth[m]!
            let tot = lst.reduce(0) { $0 + $1.1 }
            let parts = lst.map { "\($0.0) \(Int(Double($0.1)/Double(tot)*100))%" }
                .joined(separator: " · ")
            return "\(m)  \(tot)  \(parts)"
        }

        let hostCounts = try db.query("""
            SELECT \(Self.hostSQL) h, COUNT(*) c FROM visits
            GROUP BY h
        """).map { ($0["h"]?.text ?? "?", $0["c"]?.int ?? 0) }
        r.topDomains = hostCounts.sorted { $0.1 > $1.1 }.prefix(20).map {
            Count(label: $0.0, value: $0.1)
        }
        var rollup: [String: Int64] = [:]
        for (h, c) in hostCounts { rollup[Domain.rollup(h), default: 0] += c }
        r.topSites = rollup.sorted { $0.value > $1.value }.prefix(20).map {
            Count(label: $0.key, value: $0.value)
        }

        for src in try db.query(
            "SELECT DISTINCT browser||'/'||profile s FROM visits") {
            let s = src["s"]?.text ?? ""
            let top = try db.query("""
                SELECT \(Self.hostSQL) h, COUNT(*) c FROM visits
                WHERE browser||'/'||profile = ?
                GROUP BY h ORDER BY c DESC LIMIT 5
            """, [.text(s)])
                .map { "\($0["h"]?.text ?? "?") (\($0["c"]?.int ?? 0))" }
                .joined(separator: ", ")
            r.topPerBrowser.append(Count(label: s, value: 0, extra: top))
        }

        r.personalities = try db.query("""
            SELECT browser||'/'||profile s, COUNT(*) c, COUNT(DISTINCT url) u,
                   ROUND(100.0*SUM(CASE WHEN CAST(strftime('%w',visit_time_utc)
                         AS INT) IN (0,6) THEN 1 ELSE 0 END)/COUNT(*),1) we,
                   ROUND(100.0*SUM(CASE WHEN CAST(strftime('%H',visit_time_utc)
                         AS INT) BETWEEN 18 AND 23 THEN 1 ELSE 0 END)/COUNT(*),1) ev
            FROM visits GROUP BY 1 ORDER BY 2 DESC
        """).map {
            Count(label: $0["s"]?.text ?? "?", value: $0["c"]?.int ?? 0,
                  extra: "\($0["u"]?.int ?? 0) urls · \($0["we"]?.double ?? 0)% wknd · \($0["ev"]?.double ?? 0)% eve")
        }

        r.hourly = try db.query("""
            SELECT CAST(strftime('%H', visit_time_utc) AS INT) h, COUNT(*) c
            FROM visits GROUP BY h ORDER BY h
        """).map {
            Count(label: String(format: "%02d:00", $0["h"]?.int ?? 0),
                  value: $0["c"]?.int ?? 0)
        }
        let dnames = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        r.weekday = try db.query("""
            SELECT strftime('%w', visit_time_utc) d, COUNT(*) c
            FROM visits GROUP BY d ORDER BY d
        """).map {
            Count(label: dnames[Int($0["d"]?.text ?? "0") ?? 0],
                  value: $0["c"]?.int ?? 0)
        }
        r.daily = try db.query("""
            SELECT substr(visit_time_utc,1,10) d, COUNT(*) c
            FROM visits GROUP BY d ORDER BY d DESC LIMIT 30
        """).reversed().map {
            Count(label: $0["d"]?.text ?? "", value: $0["c"]?.int ?? 0)
        }

        for (lo, hi, label) in [(1,1,"visited once"),(2,5,"2-5 times"),
                                (6,20,"6-20 times"),(21,Int.max,"20+ times")] {
            let n = try db.scalar("""
                SELECT COUNT(*) FROM (
                  SELECT \(Self.hostSQL) h, COUNT(*) n FROM visits GROUP BY h)
                WHERE n BETWEEN ? AND ?
            """,
                [.int(Int64(lo)), .int(Int64(hi))], as: { $0.int }) ?? 0
            r.habit.append(Count(label: label, value: n))
        }

        r.revisited = try db.query("""
            SELECT url, MAX(visit_count) c FROM visits
            GROUP BY url ORDER BY c DESC LIMIT 15
        """).map {
            Count(label: $0["url"]?.text ?? "?", value: $0["c"]?.int ?? 0)
        }

        r.typedShare = try db.query("""
            SELECT browser||'/'||profile s, SUM(vc) v, SUM(tc) t FROM (
              SELECT browser, profile, url,
                     MAX(visit_count) vc, MAX(typed_count) tc
              FROM visits GROUP BY browser, profile, url)
            GROUP BY 1 ORDER BY 2 DESC
        """).map {
            let v = $0["v"]?.double ?? 0, t = $0["t"]?.double ?? 0
            return Count(label: $0["s"]?.text ?? "?",
                         value: Int64(v),
                         extra: String(format: "%.1f%% typed", v > 0 ? t/v*100 : 0))
        }

        // Sessions: 30-min gap per source; rabbit holes = most distinct domains.
        let sess = try db.query("""
            WITH v AS (
              SELECT browser||'/'||profile src, julianday(visit_time_utc) jd,
                     \(Self.hostSQL) h FROM visits)
            , g AS (
              SELECT src, jd, h,
                     CASE WHEN jd - LAG(jd) OVER (PARTITION BY src ORDER BY jd)
                          > 1800.0/86400 THEN 1 ELSE 0 END ns
              FROM v)
            , s AS (
              SELECT src, jd, h,
                     SUM(ns) OVER (PARTITION BY src ORDER BY jd) sid FROM g)
            SELECT src, sid, COUNT(*) n, COUNT(DISTINCT h) dom,
                   (MAX(jd)-MIN(jd))*86400 span, MIN(jd) start_jd
            FROM s GROUP BY src, sid
        """)
        var agg: [String: (n: Int64, tot: Double, mx: Double)] = [:]
        for s in sess {
            let src = s["src"]?.text ?? "?"
            var a = agg[src] ?? (0, 0, 0)
            a.n += 1
            a.tot += s["span"]?.double ?? 0
            a.mx = max(a.mx, s["span"]?.double ?? 0)
            agg[src] = a
        }
        r.sessionSummary = agg.map { src, a in
            Count(label: src, value: a.n,
                  extra: "avg \(fmtDur(a.tot/Double(a.n))) · longest \(fmtDur(a.mx))")
        }.sorted { $0.value > $1.value }
        r.rabbitHoles = sess.sorted {
            ($0["dom"]?.int ?? 0, $0["span"]?.double ?? 0)
                > ($1["dom"]?.int ?? 0, $1["span"]?.double ?? 0)
        }.prefix(10).map {
            Session(source: $0["src"]?.text ?? "?",
                    visits: $0["n"]?.int ?? 0,
                    domains: $0["dom"]?.int ?? 0,
                    spanSeconds: $0["span"]?.double ?? 0,
                    start: Date(timeIntervalSince1970:
                        (($0["start_jd"]?.double ?? 0) - 2440587.5) * 86400))
        }

        r.attentionApps = try attentionApps()
        r.attentionSites = try attentionSites()

        r.searches = try db.query("""
            SELECT term, COUNT(*) c FROM searches
            GROUP BY lower(term) ORDER BY c DESC LIMIT 15
        """).map {
            Count(label: $0["term"]?.text ?? "?", value: $0["c"]?.int ?? 0)
        }

        // ---- time series ----

        r.dailySeries = try db.query("""
            SELECT substr(visit_time_utc,1,10) d, browser, COUNT(*) c
            FROM visits GROUP BY d, browser ORDER BY d
        """).map {
            DayPoint(date: $0["d"]?.text ?? "",
                     browser: $0["browser"]?.text ?? "?",
                     count: $0["c"]?.int ?? 0)
        }

        for row in try db.query("""
            SELECT CAST(strftime('%w',visit_time_utc) AS INT) d,
                   CAST(strftime('%H',visit_time_utc) AS INT) h, COUNT(*) c
            FROM visits GROUP BY d, h
        """) {
            let d = Int(row["d"]?.int ?? 0), h = Int(row["h"]?.int ?? 0)
            if (0...6).contains(d), (0...23).contains(h) {
                r.heatmap[d * 24 + h] = row["c"]?.int ?? 0
            }
        }

        r.focusDaily = try db.query("""
            SELECT substr(start_utc,1,10) d, SUM(active_s) a, SUM(ticks) t
            FROM focus GROUP BY d ORDER BY d
        """).map {
            FocusDay(date: $0["d"]?.text ?? "",
                     activeSeconds: $0["a"]?.double ?? 0,
                     ticks: $0["t"]?.int ?? 0)
        }

        // First-seen month per domain → exploration rate + cumulative coverage.
        let firstSeen = try db.query("""
            SELECT fs m, COUNT(*) c FROM (
              SELECT MIN(substr(visit_time_utc,1,7)) fs FROM visits
              GROUP BY \(Self.hostSQL)) GROUP BY fs ORDER BY fs
        """).map {
            Count(label: $0["m"]?.text ?? "", value: $0["c"]?.int ?? 0)
        }
        r.newDomainsPerWeek = firstSeen
        var running: Int64 = 0
        r.cumulativeDomains = firstSeen.map {
            running += $0.value
            return Count(label: $0.label, value: running)
        }

        // Monthly trend for the top host-level domains.
        for dom in r.topDomains.prefix(6) {
            let rows = try db.query("""
                SELECT substr(visit_time_utc,1,7) m, COUNT(*) c FROM visits
                WHERE \(Self.hostSQL) = ? GROUP BY m ORDER BY m
            """, [.text(dom.label)])
            r.domainTrends.append((dom.label, rows.map {
                Count(label: $0["m"]?.text ?? "", value: $0["c"]?.int ?? 0)
            }))
        }
        return r
    }

    public func attentionApps() throws -> [Count] {
        try db.query("""
            SELECT app, SUM(active_s) a, SUM(ticks)*2.0 o FROM focus
            GROUP BY app ORDER BY a DESC LIMIT 15
        """).map {
            Count(label: $0["app"]?.text ?? "?",
                  value: Int64($0["a"]?.double ?? 0),
                  extra: "open \(fmtDur($0["o"]?.double ?? 0))")
        }
    }

    public func attentionSites() throws -> [Count] {
        try db.query("""
            SELECT \(Self.hostSQL) h, SUM(active_s) a FROM focus
            WHERE url != '' GROUP BY h ORDER BY a DESC LIMIT 15
        """).map {
            Count(label: $0["h"]?.text ?? "?",
                  value: Int64($0["a"]?.double ?? 0))
        }
    }

    /// Unified history search for the History surface.
    public func searchHistory(term: String, browser: String? = nil,
                              limit: Int = 500) throws -> [[String: DBValue]] {
        var sql = """
            SELECT browser, profile, url, title, visit_time_utc
            FROM visits WHERE 1=1
        """
        var params: [DBValue] = []
        if !term.isEmpty {
            sql += " AND (url LIKE ? OR title LIKE ?)"
            params += [.text("%\(term)%"), .text("%\(term)%")]
        }
        if let browser, !browser.isEmpty, browser != "all" {
            sql += " AND browser = ?"
            params.append(.text(browser))
        }
        sql += " ORDER BY visit_time_utc DESC LIMIT ?"
        params.append(.int(Int64(limit)))
        return try db.query(sql, params)
    }

    public func browsers() throws -> [String] {
        try db.query("SELECT DISTINCT browser FROM visits ORDER BY 1")
            .compactMap { $0["browser"]?.text }
    }
}

public enum Domain {
    static let multipartTLDs: Set<String> = [
        "co.uk","co.in","co.jp","co.nz","com.au","com.br","com.sg",
        "org.uk","net.au","ac.uk","gov.uk",
        "github.io","gitlab.io","pages.dev","workers.dev","web.app",
        "vercel.app","netlify.app","herokuapp.com","blogspot.com",
        "appspot.com","myshopify.com","amazonaws.com","googleapis.com",
        "cloudfront.net","readthedocs.io","firebaseapp.com",
    ]

    /// Crude registrable-domain rollup; keeps localhost:port/IPs as-is.
    public static func rollup(_ host: String) -> String {
        let base = host.split(separator: ":")[0].description
        let labels = base.split(separator: ".")
        if labels.count <= 2 || labels.last!.allSatisfy(\.isNumber) {
            return host
        }
        let last2 = labels.suffix(2).joined(separator: ".")
        if multipartTLDs.contains(last2) {
            return labels.suffix(3).joined(separator: ".")
        }
        return last2
    }
}

public func fmtDur(_ s: Double) -> String {
    s >= 3600 ? String(format: "%.1fh", s/3600)
              : String(format: "%.0fm", s/60)
}
