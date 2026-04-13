import XCTest
@testable import azooKeyMac

final class JuliaUnicodeSessionTests: XCTestCase {
    func testTabCommitsExactJuliaMatch() {
        let session = JuliaUnicodeSession(resolver: .standard)
        XCTAssertEqual(session.commitText(for: "\\alpha"), "α")
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
