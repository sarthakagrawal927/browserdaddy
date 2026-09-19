import XCTest
@testable import BrowserCore

final class ModelsTests: XCTestCase {
    func testHistoryVisitHoldsFields() {
        let visit = HistoryVisit(
            browser: "chrome", profile: "Default", visitID: 7,
            url: "https://example.com", title: "Example",
            visitedAt: Date(timeIntervalSince1970: 0), visitCount: 3,
            typedCount: 1, transition: "typed", fromVisit: nil)
        XCTAssertEqual(visit.visitID, 7)
        XCTAssertEqual(visit.transition, "typed")
    }
}
