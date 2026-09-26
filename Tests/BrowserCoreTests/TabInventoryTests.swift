import AppKit
import XCTest
@testable import BrowserCore

final class TabInventoryTests: XCTestCase {
    func testInstalledBrowserInventoryScriptsCompile() {
        var checked = 0
        for kind in [BrowserKind.safari, .chrome, .brave]
            where BrowserOpener.appURL(for: kind) != nil {
            guard let source = TabInventory.listScript(kind: kind),
                  let script = NSAppleScript(source: source) else {
                XCTFail("Missing inventory script for \(kind.displayName)")
                continue
            }
            var error: NSDictionary?
            XCTAssertTrue(script.compileAndReturnError(&error),
                          "\(kind.displayName): \(error?.description ?? "unknown error")")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 0)
    }
}
