import XCTest
@testable import azooKeyMac

final class JuliaUnicodeSessionTests: XCTestCase {
    func testTabCommitsExactJuliaMatch() {
        let session = JuliaUnicodeSession(resolver: .standard)
        XCTAssertEqual(session.commitText(for: "\\alpha"), "α")
    }
}
