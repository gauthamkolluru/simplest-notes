import XCTest
@testable import NotesCore

final class OnboardingPolicyTests: XCTestCase {
    private var defaults: InMemoryOnboardingStore!

    override func setUp() {
        defaults = InMemoryOnboardingStore()
    }

    /// T2.01 Fresh install → show onboarding.
    func test_T2_01_freshInstallShowsOnboarding() {
        XCTAssertTrue(
            OnboardingPolicy.shouldShow(
                store: defaults,
                hasRestorableGoogleSession: false
            )
        )
    }

    /// T2.02 After "Connect" success → never show again.
    func test_T2_02_afterConnectSuccessNeverShowsAgain() {
        OnboardingPolicy.markCompleted(store: defaults)
        XCTAssertFalse(
            OnboardingPolicy.shouldShow(
                store: defaults,
                hasRestorableGoogleSession: true
            )
        )
    }

    /// T2.03 After "Not now" → never show again.
    func test_T2_03_afterNotNowNeverShowsAgain() {
        OnboardingPolicy.markCompleted(store: defaults)
        XCTAssertFalse(
            OnboardingPolicy.shouldShow(
                store: defaults,
                hasRestorableGoogleSession: false
            )
        )
    }

    /// T2.04 After Connect cancelled/failed → onboarding marked done, not-connected path.
    func test_T2_04_afterConnectCancelledOnboardingDone() {
        OnboardingPolicy.markCompleted(store: defaults)
        XCTAssertTrue(defaults.hasCompletedOnboarding)
        XCTAssertFalse(
            OnboardingPolicy.shouldShow(
                store: defaults,
                hasRestorableGoogleSession: false
            )
        )
    }

    /// T2.05 Reinstall wiped defaults but Keychain session remains → skip onboarding.
    func test_T2_05_restorableSessionSkipsOnboardingAndMarksComplete() {
        XCTAssertFalse(defaults.hasCompletedOnboarding)
        let show = OnboardingPolicy.shouldShow(
            store: defaults,
            hasRestorableGoogleSession: true
        )
        XCTAssertFalse(show)
        XCTAssertTrue(
            defaults.hasCompletedOnboarding,
            "Restoring a session should mark onboarding complete so it stays skipped"
        )
    }
}
