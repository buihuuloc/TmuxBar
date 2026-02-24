import XCTest
@testable import TmuxBar

final class TmuxServiceTests: XCTestCase {
    func testParseSessionsOutput() {
        let output = """
        dev|3|1|1708770000
        staging|1|0|1708770100
        """
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].name, "dev")
        XCTAssertEqual(sessions[0].windowCount, 3)
        XCTAssertTrue(sessions[0].isAttached)
        XCTAssertEqual(sessions[1].name, "staging")
        XCTAssertEqual(sessions[1].windowCount, 1)
        XCTAssertFalse(sessions[1].isAttached)
    }

    func testParseEmptyOutput() {
        let sessions = TmuxService.parseSessions(from: "")
        XCTAssertTrue(sessions.isEmpty)
    }

    func testParseMalformedLine() {
        let output = "bad-line\ngood|2|1|123456"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].name, "good")
    }

    func testTmuxBinaryPath() {
        let path = TmuxService.findTmuxPath()
        XCTAssertNotNil(path)
    }
}
