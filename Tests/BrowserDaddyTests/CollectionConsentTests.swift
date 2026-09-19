import XCTest
import BrowserCore
@testable import BrowserDaddy

final class CollectionConsentTests: XCTestCase {
    @MainActor
    func testArchiveFailureDoesNotCreateAnAppModelOrStartCollection() {
        let startup = AppStartup(openArchive: {
            throw CocoaError(.fileReadNoPermission)
        })
        XCTAssertNil(startup.model)
    }
    @MainActor
    func testLegacyOptInRequiresFreshConsentAndRevocationPersists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserDaddy-classification-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ArchiveStore(url: directory.appendingPathComponent("fixture.db"))
        store.metaSet("classify_optin", "1")
        let model = AppModel(store: store, startCollection: {})
        XCTAssertFalse(model.classifyOptin)
        model.runClassification()
        XCTAssertFalse(model.classifying)
        model.setClassifyOptin(true)
        XCTAssertTrue(AppModel(store: store, startCollection: {}).classifyOptin)
        model.setClassifyOptin(false)
        XCTAssertFalse(AppModel(store: store, startCollection: {}).classifyOptin)
        XCTAssertEqual(store.metaGet("classify_consent_version"), "")
    }
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
