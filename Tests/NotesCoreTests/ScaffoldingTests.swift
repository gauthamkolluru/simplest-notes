import XCTest
@testable import NotesCore

/// Phase 0 scaffolding tests (T0.01).
final class ScaffoldingTests: XCTestCase {
    /// T0.01 — `swift test` runs a trivial test on Linux and macOS (CI wiring proof).
    func test_T0_01_swiftTestRunsTrivialAssertion() {
        XCTAssertEqual(NotesCore.packageName, "NotesCore")
    }
}
