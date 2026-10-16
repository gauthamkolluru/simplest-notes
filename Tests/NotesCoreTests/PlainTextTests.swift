import XCTest
@testable import NotesCore

final class PlainTextTests: XCTestCase {
    /// T2.10 — pasted content is treated as plain characters only.
    func test_T2_10_pasteKeepsPlainCharactersOnly() {
        let richLooking = "Hello https://example.com **bold**"
        XCTAssertEqual(PlainText.fromPasteboardString(richLooking), richLooking)
        XCTAssertTrue(PlainText.isEffectivelyPlain(richLooking))
        XCTAssertFalse(PlainText.isEffectivelyPlain("x\u{FFFC}y"))
    }
}
