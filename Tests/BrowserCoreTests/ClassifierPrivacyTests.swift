import XCTest
@testable import BrowserCore

final class ClassifierPrivacyTests: XCTestCase {
    private func seededStore(_ url: URL) throws -> ArchiveStore {
        let store = try ArchiveStore(url: url)
        let source = HistorySource(browser: "chrome", profile: "Fixture", path: url, engine: .chromium)
        try store.merge(visits: [HistoryVisit(browser: "chrome", profile: "Fixture", visitID: 1,
            url: "https://example.com/document?token=secret", title: "Synthetic title", visitedAt: Date(),
            visitCount: 1, typedCount: 0, transition: "link", fromVisit: nil)], source: source)
        return store
    }

    func testCancellationDuringResponsePreventsPersistenceAndNextStage() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("classifier-flight-\(UUID()).db")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try seededStore(url)
        let classifier = Classifier(db: store.db, transport: { request in
            withUnsafeCurrentTask { $0?.cancel() }
            let data = Data(#"{"results":[{"label":"other","confidence":0.5}]}"#.utf8)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let task = Task { try await classifier.run(log: { _ in }) }
        do {
            _ = try await task.value
            XCTFail("A cancelled response must not be accepted")
        } catch is CancellationError { }
        XCTAssertEqual(try store.db.scalar("SELECT COUNT(*) FROM domain_categories", as: { $0.int }), 0)
        XCTAssertEqual(try store.db.scalar("SELECT COUNT(*) FROM page_categories", as: { $0.int }), 0)
    }

    func testExtraOrMissingResultsAreRejectedWithoutSavingTags() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("classifier-invalid-\(UUID()).db")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try seededStore(url)
        for body in [#"{"results":[]}"#,
                     #"{"results":[{"label":"other","confidence":0.5},{"label":"other","confidence":0.5}]}"#] {
            let classifier = Classifier(db: store.db, transport: { request in
                (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            })
            do {
                _ = try await classifier.run(log: { _ in })
                XCTFail("Invalid response must fail closed")
            } catch { XCTAssertEqual((error as NSError).code, 2) }
        }
        XCTAssertEqual(try store.db.scalar("SELECT COUNT(*) FROM domain_categories", as: { $0.int }), 0)
    }

    func testPayloadStripsURLCredentialsQueriesAndFragmentsButDisclosesText() {
        XCTAssertEqual(Classifier.pageInput(
            url: "https://alice:secret@example.com/document?token=private#fragment", title: "Personal title"),
            "example.com /document — Personal title")
        XCTAssertNil(Classifier.pageInput(url: "file:///Users/person/private.txt", title: "Private"))
        XCTAssertNil(Classifier.pageInput(url: "chrome://settings", title: "Settings"))
        XCTAssertTrue(Classifier.disclosure.contains("not anonymous"))
        XCTAssertTrue(Classifier.disclosure.contains("cannot be recalled"))
    }

    func testPayloadTruncatesPathsAndTitles() {
        let input = Classifier.pageInput(url: "https://example.com/" + String(repeating: "p", count: 100),
                                         title: String(repeating: "t", count: 200))
        XCTAssertEqual(input, "example.com /" + String(repeating: "p", count: 59)
                       + " — " + String(repeating: "t", count: 140))
    }

    func testCancelledRunDoesNotSendRequests() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("classifier-\(UUID()).db")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try ArchiveStore(url: url)
        let classifier = Classifier(db: store.db, transport: { _ in
            XCTFail("Cancelled classification must not send data")
            throw CancellationError()
        })
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await classifier.run(log: { _ in })
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError { }
    }
}
