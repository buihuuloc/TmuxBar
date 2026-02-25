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

    func testRelativeAgeMinutes() {
        let epoch = String(Int(Date().timeIntervalSince1970) - 300) // 5 minutes ago
        let session = TmuxSession(name: "dev", paneCount: 1, isAttached: false, createdAt: epoch)
        XCTAssertEqual(session.relativeAge, "5m")
    }

    func testRelativeAgeHours() {
        let epoch = String(Int(Date().timeIntervalSince1970) - 7200) // 2 hours ago
        let session = TmuxSession(name: "dev", paneCount: 1, isAttached: false, createdAt: epoch)
        XCTAssertEqual(session.relativeAge, "2h")
    }

    func testRelativeAgeDays() {
        let epoch = String(Int(Date().timeIntervalSince1970) - 259200) // 3 days ago
        let session = TmuxSession(name: "dev", paneCount: 1, isAttached: false, createdAt: epoch)
        XCTAssertEqual(session.relativeAge, "3d")
    }

    func testRelativeAgeUnderOneMinute() {
        let epoch = String(Int(Date().timeIntervalSince1970) - 30) // 30 seconds ago
        let session = TmuxSession(name: "dev", paneCount: 1, isAttached: false, createdAt: epoch)
        XCTAssertEqual(session.relativeAge, "<1m")
    }

    func testRelativeAgeInvalidCreatedAt() {
        let session = TmuxSession(name: "dev", paneCount: 1, isAttached: false, createdAt: "not-a-number")
        XCTAssertEqual(session.relativeAge, "")
    }

    func testDisplayTitleWithAge() {
        let epoch = String(Int(Date().timeIntervalSince1970) - 7200)
        let session = TmuxSession(name: "dev", paneCount: 2, isAttached: true, createdAt: epoch)
        XCTAssertEqual(session.displayTitle, "dev  (2 panes) · 2h ●")
    }
}
