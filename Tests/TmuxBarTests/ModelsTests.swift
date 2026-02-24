import XCTest
@testable import TmuxBar

final class ModelsTests: XCTestCase {
    func testTmuxSessionInit() {
        let session = TmuxSession(name: "dev", windowCount: 3, isAttached: true, createdAt: "Mon Feb 24 10:00:00 2026")
        XCTAssertEqual(session.name, "dev")
        XCTAssertEqual(session.windowCount, 3)
        XCTAssertTrue(session.isAttached)
    }

    func testTmuxSessionEquatable() {
        let a = TmuxSession(name: "dev", windowCount: 1, isAttached: false, createdAt: "")
        let b = TmuxSession(name: "dev", windowCount: 1, isAttached: false, createdAt: "")
        XCTAssertEqual(a, b)
    }

    func testDisplayTitleSingularWindow() {
        let session = TmuxSession(name: "dev", windowCount: 1, isAttached: false, createdAt: "")
        XCTAssertEqual(session.displayTitle, "dev  (1 window)")
    }

    func testDisplayTitlePluralWindowsAttached() {
        let session = TmuxSession(name: "dev", windowCount: 3, isAttached: true, createdAt: "")
        XCTAssertEqual(session.displayTitle, "dev  (3 windows) ●")
    }
}
