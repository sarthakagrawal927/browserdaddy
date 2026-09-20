import XCTest
@testable import BrowserCore

final class BrowserAccessTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserDaddy-access-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testChromiumRootDiscoversOnlyHistoryBelowSelectedFolder() throws {
        let profile = root.appendingPathComponent("Default")
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        try Data().write(to: profile.appendingPathComponent("History"))

        let selected = BrowserRoot(kind: .chrome, url: root)
        XCTAssertTrue(BrowserDiscovery.isValid(root: selected))
        XCTAssertEqual(BrowserDiscovery.discover(root: selected).map(\.profile), ["Default"])

        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserDaddy-outside-\(UUID())")
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data().write(to: outside.appendingPathComponent("History"))
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("Profile 1"), withDestinationURL: outside)
        XCTAssertEqual(BrowserDiscovery.discover(root: selected).map(\.profile), ["Default"])
    }

    func testKindSpecificValidationRejectsWrongFolder() throws {
        try Data().write(to: root.appendingPathComponent("History.db"))
        XCTAssertTrue(BrowserDiscovery.isValid(root: BrowserRoot(kind: .safari, url: root)))
        XCTAssertFalse(BrowserDiscovery.isValid(root: BrowserRoot(kind: .chrome, url: root)))
    }

    func testReadOnlyBookmarkPersistsResolvesAndCanBeRemoved() throws {
        let profile = root.appendingPathComponent("Default")
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        try Data().write(to: profile.appendingPathComponent("History"))
        let suite = "BrowserDaddyTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = BrowserGrantStore(defaults: defaults)

        try store.save(kind: .chrome, selectedURL: root)
        XCTAssertEqual(store.grants().map(\.kind), [.chrome])
        let statuses = store.statuses(for: [.chrome, .safari])
        guard case .connected(let path) = statuses[0].state else {
            return XCTFail("Expected the selected Chrome folder to resolve")
        }
        XCTAssertEqual(URL(fileURLWithPath: path).lastPathComponent, root.lastPathComponent)
        XCTAssertEqual(statuses[1].state, .notConnected)
        let count = store.withAccessibleRoots { roots, failures in
            XCTAssertTrue(failures.isEmpty)
            XCTAssertEqual(roots.map(\.kind), [.chrome])
            XCTAssertEqual(roots.first?.url.lastPathComponent, root.lastPathComponent)
            return BrowserDiscovery.discover(roots: roots).count
        }
        XCTAssertEqual(count, 1)

        store.remove(kind: .chrome)
        XCTAssertTrue(store.grants().isEmpty)
    }

    func testInvalidFolderIsNeverPersisted() throws {
        let suite = "BrowserDaddyTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = BrowserGrantStore(defaults: defaults)
        XCTAssertThrowsError(try store.save(kind: .firefox, selectedURL: root))
        XCTAssertTrue(store.grants().isEmpty)
    }
}
