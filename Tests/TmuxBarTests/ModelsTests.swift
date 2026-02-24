import XCTest
@testable import TmuxBar

final class ModelsTests: XCTestCase {
    func testTmuxSessionInit() {
        let session = TmuxSession(name: "dev", paneCount: 3, isAttached: true, createdAt: "Mon Feb 24 10:00:00 2026")
        XCTAssertEqual(session.name, "dev")
        XCTAssertEqual(session.paneCount, 3)
        XCTAssertTrue(session.isAttached)
    }

    func testTmuxSessionEquatable() {
        let a = TmuxSession(name: "dev", paneCount: 1, isAttached: false, createdAt: "")
        let b = TmuxSession(name: "dev", paneCount: 1, isAttached: false, createdAt: "")
        XCTAssertEqual(a, b)
    }

    func testDisplayTitleSingularPane() {
        let session = TmuxSession(name: "dev", paneCount: 1, isAttached: false, createdAt: "")
        XCTAssertEqual(session.displayTitle, "dev  (1 pane)")
    }

    func testDisplayTitlePluralPanesAttached() {
        let session = TmuxSession(name: "dev", paneCount: 3, isAttached: true, createdAt: "")
        XCTAssertEqual(session.displayTitle, "dev  (3 panes) ●")
    }
}
