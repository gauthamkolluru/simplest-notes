import XCTest
@testable import NotesCore

final class ConnectionControllerTests: XCTestCase {
    private var auth: FakeAuth!
    private var controller: ConnectionController!

    override func setUp() {
        auth = FakeAuth()
        controller = ConnectionController(auth: auth)
    }

    /// T3.06 Tap when not connected → starts sign-in.
    func test_T3_06_tapNotConnectedStartsSignIn() async {
        await controller.handleIconTap()
        XCTAssertEqual(auth.signInCallCount, 1)
        XCTAssertEqual(controller.state, .connected(email: "user@example.com"))
    }

    /// T3.07 Sign-in cancelled → notConnected, no error.
    func test_T3_07_signInCancelledNoError() async {
        auth.nextResult = .cancelled
        await controller.handleIconTap()
        XCTAssertEqual(controller.state, .notConnected)
        XCTAssertNil(controller.inlineError)
    }

    /// T3.08 Sign-in fails (network) → notConnected + inline message.
    func test_T3_08_signInNetworkFailureShowsInlineError() async {
        auth.nextResult = .failure(.network)
        await controller.handleIconTap()
        XCTAssertEqual(controller.state, .notConnected)
        XCTAssertNotNil(controller.inlineError)
    }

    /// T3.09 Tap when connected → account sheet with email, Disconnect, Switch.
    func test_T3_09_tapConnectedShowsAccountSheet() async {
        auth.nextResult = .success(email: "a@b.com")
        await controller.handleIconTap()
        await controller.handleIconTap()
        XCTAssertEqual(controller.sheet, .account(email: "a@b.com"))
    }

    /// T3.10 Email missing → sheet shows "Google account".
    func test_T3_10_missingEmailUsesFallbackLabel() async {
        auth.nextResult = .success(email: nil)
        await controller.handleIconTap()
        await controller.handleIconTap()
        XCTAssertEqual(controller.sheet, .account(email: "Google account"))
    }

    /// T3.11 Very long email truncates in middle; full text in a11y label.
    func test_T3_11_longEmailTruncatesMiddle() {
        let email = "verylongaddressname@examplecompanydomain.com"
        let display = ConnectionController.displayEmail(email, maxLength: 24)
        XCTAssertLessThanOrEqual(display.count, 24)
        XCTAssertTrue(display.contains("…") || display.contains("..."))
        XCTAssertEqual(ConnectionController.accessibilityEmail(email), email)
    }

    /// T3.12 Disconnect → notConnected, sheet closes, local text unchanged.
    func test_T3_12_disconnectClearsConnectionKeepsLocalNoteFlag() async {
        auth.nextResult = .success(email: "a@b.com")
        await controller.handleIconTap()
        var localKept = true
        await controller.disconnect(keepingLocalNote: &localKept)
        XCTAssertEqual(controller.state, .notConnected)
        XCTAssertNil(controller.sheet)
        XCTAssertTrue(localKept)
        XCTAssertEqual(auth.disconnectCallCount, 1)
    }

    /// T3.13 Switch account → disconnect then sign-in; cancel leaves notConnected.
    func test_T3_13_switchAccountCancelLeavesDisconnected() async {
        auth.nextResult = .success(email: "old@example.com")
        await controller.handleIconTap()
        auth.nextResult = .cancelled
        await controller.switchAccount()
        XCTAssertEqual(controller.state, .notConnected)
        XCTAssertEqual(auth.disconnectCallCount, 1)
        XCTAssertEqual(auth.signInCallCount, 2)
    }

    /// T3.14 Rapid repeated taps on Disconnect don't run the action twice.
    func test_T3_14_rapidDisconnectDoesNotDoubleRun() async {
        auth.nextResult = .success(email: "a@b.com")
        await controller.handleIconTap()
        auth.disconnectDelayNanoseconds = 50_000_000
        async let d1: Void = controller.disconnect()
        async let d2: Void = controller.disconnect()
        _ = await (d1, d2)
        XCTAssertEqual(auth.disconnectCallCount, 1)
    }
}
