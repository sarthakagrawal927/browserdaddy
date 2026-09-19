import XCTest
import BrowserCore
@testable import BrowserDaddy

final class CollectionConsentTests: XCTestCase {
    @MainActor
    func testCollectionWaitsForOnboardingAndStartsOnlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserDaddy-consent-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ArchiveStore(url: directory.appendingPathComponent("fixture.db"))
        var starts = 0
        let model = AppModel(store: store, startCollection: { starts += 1 })
        model.boot()
        model.boot()
        model.runExtract()
        XCTAssertEqual(starts, 0)
        XCTAssertFalse(model.extracting)
        XCTAssertFalse(model.watcher.isRunning)
        model.finishOnboarding()
        model.boot()
        model.finishOnboarding()
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(store.metaGet("onboarded"), "1")
    }
}
