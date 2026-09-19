import XCTest
@testable import BrowserCore

final class DomainTests: XCTestCase {
    func testRollup() {
        XCTAssertEqual(Domain.rollup("mail.google.com"), "google.com")
        XCTAssertEqual(Domain.rollup("x.com"), "x.com")
        XCTAssertEqual(Domain.rollup("app-staging.vaultwealth.com"),
                       "vaultwealth.com")
        XCTAssertEqual(Domain.rollup("feat-x.vault-webapp.pages.dev"),
                       "vault-webapp.pages.dev")
        XCTAssertEqual(Domain.rollup("user.github.io"), "user.github.io")
        XCTAssertEqual(Domain.rollup("localhost:8082"), "localhost:8082")
        XCTAssertEqual(Domain.rollup("127.0.0.1:4321"), "127.0.0.1:4321")
        XCTAssertEqual(Domain.rollup("news.bbc.co.uk"), "bbc.co.uk")
    }
}
