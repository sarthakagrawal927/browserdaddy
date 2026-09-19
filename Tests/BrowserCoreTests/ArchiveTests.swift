import XCTest
@testable import BrowserCore

final class ArchiveTests: XCTestCase {
    private var tmp: URL!
    private var store: ArchiveStore!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".db")
        store = try ArchiveStore(url: tmp)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func visit(_ id: Int64, url: String = "https://a.example/")
        -> HistoryVisit {
        HistoryVisit(browser: "chrome", profile: "Default", visitID: id,
                     url: url, title: "t", visitedAt: Date(),
                     visitCount: 1, typedCount: 0,
                     transition: "link", fromVisit: nil)
    }

    func testMergeDedupesOnVisitID() throws {
        let src = HistorySource(browser: "chrome", profile: "Default",
                                path: tmp, engine: .chromium)
        let first = try store.merge(visits: [visit(1), visit(2), visit(3)],
                                    source: src)
        XCTAssertEqual(first, 3)
        // re-merge same ids + one new: only the new one lands
        let second = try store.merge(
            visits: [visit(1), visit(2), visit(4)], source: src)
        XCTAssertEqual(second, 1)
        let total = try store.db.scalar("SELECT COUNT(*) FROM visits",
                                        as: { $0.int })
        XCTAssertEqual(total, 4)
    }

    func testSameVisitIDDifferentSourceKept() throws {
        let chrome = HistorySource(browser: "chrome", profile: "Default",
                                   path: tmp, engine: .chromium)
        let safari = HistorySource(browser: "safari", profile: "default",
                                   path: tmp, engine: .safari)
        try store.merge(visits: [visit(1)], source: chrome)
        let n = try store.merge(visits: [visit(1)], source: safari)
        XCTAssertEqual(n, 1)  // (browser, profile, visit_id) is the key
    }

    func testSearchDedupe() throws {
        let src = HistorySource(browser: "chrome", profile: "Default",
                                path: tmp, engine: .chromium)
        try store.merge(searches: [("q", "https://x/", "t")], source: src)
        let n = try store.merge(searches: [("q", "https://x/", "t")],
                                source: src)
        XCTAssertEqual(n, 0)
    }
}
