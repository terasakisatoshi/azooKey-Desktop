import XCTest
@testable import azooKeyMac

final class JuliaUnicodeSessionTests: XCTestCase {
    func testTabCommitsExactJuliaMatch() {
        let session = JuliaUnicodeSession(resolver: .standard)
        XCTAssertEqual(session.commitText(for: "\\alpha"), "α")
    }

    func testTabExpandsUniquePrefixBeforeSelection() {
        let result = JuliaUnicodeSession.tabAction(buffer: "\\alp", resolver: .standard)

        XCTAssertEqual(result.updatedBuffer, "\\alpha")
        XCTAssertNil(result.commitText)
    }

    func testEnterFallsBackToLiteralWhenNoJuliaMatchExists() {
        let result = JuliaUnicodeSession.enterAction(
            buffer: "\\notasymbol",
            selectedIndex: nil,
            resolver: .standard
        )

        XCTAssertEqual(result.commitText, "\\notasymbol")
    }

    func testEnterIgnoresImplicitSelectionWhileComposing() {
        var session = JuliaUnicodeSession(resolver: .standard)
        session.replaceBuffer("\\alp")

        let result = session.perform(.enter)

        XCTAssertEqual(result.commitText, "\\alp")
        XCTAssertEqual(result.mode, .none)
    }

    func testEnterPrefersExplicitSelectionInSelectingMode() {
        var session = JuliaUnicodeSession(resolver: .standard)
        session.replaceBuffer("\\al")
        let matches = session.matches
        XCTAssertGreaterThan(matches.count, 1)
        session.selectCandidate(at: 1, explicit: true)

        let result = session.perform(.enter)

        XCTAssertEqual(result.commitText, matches[1].text)
        XCTAssertEqual(result.mode, .none)
    }

    func testEnterPrefersExplicitCandidateWindowSelectionWhileComposing() {
        var session = JuliaUnicodeSession(resolver: .standard)
        session.replaceBuffer("\\al")
        let matches = session.matches
        XCTAssertGreaterThan(matches.count, 1)
        session.selectCandidate(at: 1, explicit: true)

        let result = session.perform(.enter)

        XCTAssertEqual(result.commitText, matches[1].text)
        XCTAssertEqual(result.mode, .none)
    }

    func testNextCandidateDoesNothingWhenNoMatchesExist() {
        var session = JuliaUnicodeSession(resolver: .standard)
        session.replaceBuffer("\\notasymbol")

        let result = session.perform(.nextCandidate)

        XCTAssertEqual(result.mode, .composing)
        XCTAssertEqual(result.updatedBuffer, "\\notasymbol")
        XCTAssertNil(result.commitText)
        XCTAssertTrue(session.matches.isEmpty)
        XCTAssertEqual(session.selectedIndex, 0)
    }

    func testAppendAndDeleteBackwardUpdateBuffer() {
        var session = JuliaUnicodeSession(resolver: .standard)
        session.replaceBuffer("\\al")

        session.append("p")
        XCTAssertEqual(session.buffer, "\\alp")

        session.deleteBackward()
        XCTAssertEqual(session.buffer, "\\al")
    }

    func testSelectionMovementClampsToAvailableMatches() {
        var session = JuliaUnicodeSession(resolver: .standard)
        session.replaceBuffer("\\al")
        XCTAssertFalse(session.matches.isEmpty)

        session.moveSelection(by: 100)
        XCTAssertEqual(session.selectedIndex, session.matches.count - 1)

        session.moveSelection(by: -100)
        XCTAssertEqual(session.selectedIndex, 0)
    }

    func testResetClearsJuliaSessionState() {
        var session = JuliaUnicodeSession(resolver: .standard)
        session.replaceBuffer("\\alpha")
        session.moveSelection(by: 1)
        session.reset()

        XCTAssertEqual(session.buffer, "")
        XCTAssertEqual(session.selectedIndex, 0)
        XCTAssertTrue(session.matches.isEmpty)
    }

    func testCommitTextAndResetClearsJuliaSessionState() {
        var session = JuliaUnicodeSession(resolver: .standard)
        session.replaceBuffer("\\alpha")

        let buffer = session.buffer
        XCTAssertEqual(session.commitTextAndReset(for: buffer), "α")
        XCTAssertEqual(session.buffer, "")
        XCTAssertEqual(session.selectedIndex, 0)
        XCTAssertTrue(session.matches.isEmpty)
    }

}
