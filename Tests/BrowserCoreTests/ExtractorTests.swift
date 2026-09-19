import XCTest
@testable import BrowserCore

final class ExtractorTests: XCTestCase {
    func testChromiumEpochConversion() {
        // 2021-01-01T00:00:00Z = 1609459200 unix = 13253932800000000 chromium µs
        let us: Double = 13_253_932_800_000_000
        let d = Date(timeIntervalSince1970:
            us / 1e6 - HistoryExtractor.chromiumEpochOffset)
        XCTAssertEqual(d.timeIntervalSince1970, 1_609_459_200, accuracy: 0.001)
    }

    func testSafariEpochConversion() {
        // 2021-01-01 = 1609459200 unix = 631152000 safari s
        let d = Date(timeIntervalSince1970:
            631_152_000 + HistoryExtractor.safariEpochOffset)
        XCTAssertEqual(d.timeIntervalSince1970, 1_609_459_200, accuracy: 0.001)
    }

    func testTransitionDecode() {
        XCTAssertEqual(HistoryExtractor.chromiumTransitions[1], "typed")
        XCTAssertEqual(HistoryExtractor.chromiumTransitions[8], "reload")
        XCTAssertEqual(HistoryExtractor.firefoxTransitions[7], "download")
    }
}
