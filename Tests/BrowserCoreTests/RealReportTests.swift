import XCTest
@testable import BrowserCore

final class RealReportTests: XCTestCase {
    func testBuildOnRealDB() throws {
        let url = URL(fileURLWithPath: NSHomeDirectory()
            + "/Library/Application Support/BrowserDaddy/browserdaddy.db")
        let store = try ArchiveStore(url: url)
        let r = try ReportEngine(store: store).build()
        XCTAssertGreaterThan(r.totalVisits, 0)
        print("totalVisits:", r.totalVisits)
        print("changedLately:", r.changedLately.count)
        print("categories:", r.categories.count)
        print("topics:", r.topics.count)
        print("weeklySeries:", r.weeklySeries.count)
    }
}
