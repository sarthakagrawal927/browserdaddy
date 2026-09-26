import XCTest
@testable import BrowserCore

final class FocusPrivacyTests: XCTestCase {
    func testStoppingAttentionClosesSegmentBeforeResuming() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserDaddy-pause-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ArchiveStore(url: directory.appendingPathComponent("fixture.db"))
        let watcher = FocusWatcher(store: store)
        watcher.start()
        for _ in 0..<2 {
            watcher.recordCapture(app: "Chrome", url: "https://fixture.example/",
                                  title: "Public", dt: 2, active: true)
        }
        watcher.stop()
        watcher.start()
        for _ in 0..<2 {
            watcher.recordCapture(app: "Chrome", url: "https://fixture.example/",
                                  title: "Public", dt: 2, active: true)
        }
        watcher.stop()
        let rows = try store.db.query("SELECT url, ticks, active_s FROM focus ORDER BY id")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.map { $0["ticks"]?.int }, [1, 1])
        XCTAssertEqual(rows.map { $0["active_s"]?.double }, [2, 2])
    }

    func testUnavailableTabClosesPreviousURLWithoutAttributingMoreTime() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserDaddy-focus-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ArchiveStore(url: directory.appendingPathComponent("fixture.db"))
        let watcher = FocusWatcher(store: store)
        var visibleURLs: [String] = []
        watcher.onTick = { _, url in visibleURLs.append(url) }
        for _ in 0..<2 {
            watcher.recordCapture(app: "Chrome", url: "https://fixture.example/",
                                  title: "Public", dt: 2, active: true)
        }
        for _ in 0..<3 {
            watcher.recordCapture(app: "Chrome", url: "", title: "", dt: 2, active: true)
        }
        let rows = try store.db.query("SELECT url, title, active_s FROM focus ORDER BY id")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["url"]?.text, "https://fixture.example/")
        XCTAssertEqual(rows[0]["active_s"]?.double, 2)
        XCTAssertEqual(rows[1]["url"]?.text, "")
        XCTAssertEqual(rows[1]["title"]?.text, "")
        XCTAssertEqual(Array(visibleURLs.suffix(3)), ["", "", ""])
    }

    func testUnqualifiedBrowsersNeverReceiveTabQuery() {
        for id in FocusWatcher.scriptableBrowsers.keys where id != "com.google.Chrome" {
            XCTAssertNil(FocusWatcher.tabScript(bundleID: id), id)
        }
        XCTAssertNil(FocusWatcher.tabScript(bundleID: "unknown.browser"))
    }

    func testChromePrivacyGatePrecedesTabRead() throws {
        let script = try XCTUnwrap(FocusWatcher.tabScript(bundleID: "com.google.Chrome"))
        let gate = try XCTUnwrap(script.range(of: "if (mode of captureWindow) is not \"normal\" then return \"\""))
        let read = try XCTUnwrap(script.range(of: "set captureTab to active tab of captureWindow"))
        XCTAssertLessThan(gate.lowerBound, read.lowerBound)
        XCTAssertNotNil(NSAppleScript(source: script))
    }

    func testUnavailableOrMalformedCaptureNeverRetainsTabData() {
        for value in [nil, "", "private", "\u{1f}private title"] as [String?] {
            let result = FocusWatcher.decodeTab(value)
            XCTAssertEqual(result.0, "")
            XCTAssertEqual(result.1, "")
        }
        let result = FocusWatcher.decodeTab("https://fixture.example/\u{1f}Fixture")
        XCTAssertEqual(result.0, "https://fixture.example/")
        XCTAssertEqual(result.1, "Fixture")
    }
}
