import XCTest
@testable import NotesCore

final class GoogleAuthMappingTests: XCTestCase {
    /// T4.01 Maps SDK results → AuthProviding results.
    func test_T4_01_mapsSDKResults() {
        XCTAssertEqual(
            GoogleAuthMapping.mapSignIn(.success(email: "a@b.com", grantedDriveScope: true)),
            .success(email: "a@b.com")
        )
        XCTAssertEqual(GoogleAuthMapping.mapSignIn(.cancelled), .cancelled)
        XCTAssertEqual(GoogleAuthMapping.mapSignIn(.networkError), .failure(.network))
        XCTAssertEqual(GoogleAuthMapping.mapSignIn(.unknown), .failure(.unknown))
    }

    /// T4.02 Scope declined → failure + Drive message.
    func test_T4_02_scopeDeclinedIsFailureWithMessage() {
        XCTAssertEqual(
            GoogleAuthMapping.mapSignIn(.success(email: "a@b.com", grantedDriveScope: false)),
            .failure(.scopeDeclined)
        )
        XCTAssertTrue(GoogleAuthMapping.scopeDeclinedMessage().lowercased().contains("drive"))
    }

    /// T4.03 restorePreviousSignIn success → connected without UI.
    func test_T4_03_restoreSuccess() {
        XCTAssertEqual(
            GoogleAuthMapping.mapRestore(.success(email: "a@b.com")),
            .success(email: "a@b.com")
        )
    }

    /// T4.04 Restore fails (revoked) → not connected silently.
    func test_T4_04_restoreRevokedIsSilentNil() {
        XCTAssertNil(GoogleAuthMapping.mapRestore(.revoked))
        XCTAssertNil(GoogleAuthMapping.mapRestore(.unavailable))
    }

    /// T4.05 Access token refresh failure → authExpired.
    func test_T4_05_refreshFailureMapsToAuthExpired() {
        XCTAssertEqual(GoogleAuthMapping.mapToken(.refreshFailed), .authExpired)
        XCTAssertNil(GoogleAuthMapping.mapToken(.refreshed))
    }

    /// T4.06 Disconnect semantics: revoke failure still signs out locally (documented contract).
    func test_T4_06_disconnectAlwaysClearsLocalSession() async {
        let auth = FakeAuth()
        auth.nextResult = .success(email: "a@b.com")
        let controller = ConnectionController(auth: auth)
        await controller.handleIconTap()
        // Even if disconnect "fails" at SDK level, FakeAuth still increments; controller clears.
        await controller.disconnect()
        XCTAssertEqual(controller.state, .notConnected)
        XCTAssertEqual(auth.disconnectCallCount, 1)
    }
}
