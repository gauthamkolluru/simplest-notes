import XCTest
@testable import NotesCore

final class ConnectionStateTests: XCTestCase {
    /// T3.01 .notConnected → dull icon, label "Connect Google Drive".
    func test_T3_01_notConnectedMapsToDullConnectLabel() {
        let style = DriveIconStyle.from(.notConnected)
        XCTAssertEqual(style.appearance, .dull)
        XCTAssertEqual(style.accessibilityLabel, "Connect Google Drive")
        XCTAssertFalse(style.showsSpinner)
        XCTAssertFalse(style.showsWarningBadge)
    }

    /// T3.02 .connecting → dull + spinner; taps ignored.
    func test_T3_02_connectingShowsSpinnerIgnoresTaps() {
        let style = DriveIconStyle.from(.connecting)
        XCTAssertEqual(style.appearance, .dull)
        XCTAssertTrue(style.showsSpinner)
        XCTAssertFalse(style.acceptsTap)
    }

    /// T3.03 .connected(email) → active icon, label includes email.
    func test_T3_03_connectedActiveLabelIncludesEmail() {
        let style = DriveIconStyle.from(.connected(email: "a@b.com"))
        XCTAssertEqual(style.appearance, .active)
        XCTAssertTrue(style.accessibilityLabel.contains("a@b.com"))
    }

    /// T3.04 connected + sync error/offline → active + warning badge.
    func test_T3_04_connectedWithSyncIssueShowsWarning() {
        let style = DriveIconStyle.from(.connected(email: "a@b.com", syncIssue: true))
        XCTAssertEqual(style.appearance, .active)
        XCTAssertTrue(style.showsWarningBadge)
    }

    /// T3.05 .authExpired → dull with warning; tap re-auths.
    func test_T3_05_authExpiredDullWithWarningAcceptsTap() {
        let style = DriveIconStyle.from(.authExpired)
        XCTAssertEqual(style.appearance, .dull)
        XCTAssertTrue(style.showsWarningBadge)
        XCTAssertTrue(style.acceptsTap)
    }
}
