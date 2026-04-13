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

    func testSelectedJuliaCandidateWinsOverExactMatchWhenSelecting() {
        var session = JuliaUnicodeSession(resolver: .standard)
        session.replaceBuffer("\\alpha")
        session.matches = [
            JuliaUnicodeEntry(trigger: "\\alpha", text: "α"),
            JuliaUnicodeEntry(trigger: "\\alpha-custom", text: "alt")
        ]
        session.selectedIndex = 1

        XCTAssertEqual(session.commitText(for: session.buffer, preferSelectedEntry: true), "alt")
    }
}
