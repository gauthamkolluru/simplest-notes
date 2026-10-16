import Foundation

/// Persistence seam for the first-launch flag (UserDefaults in the app).
public protocol OnboardingStoring: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
}

/// In-memory store for unit tests.
public final class InMemoryOnboardingStore: OnboardingStoring {
    public var hasCompletedOnboarding: Bool

    public init(hasCompletedOnboarding: Bool = false) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

/// First-launch onboarding decisions (R7, R8).
public enum OnboardingPolicy {
    /// Whether to present the Connect / Not now sheet.
    ///
    /// If a Google session can be restored from Keychain after a reinstall
    /// (UserDefaults wiped), skip onboarding and mark it complete (T2.05).
    @discardableResult
    public static func shouldShow(
        store: OnboardingStoring,
        hasRestorableGoogleSession: Bool
    ) -> Bool {
        if hasRestorableGoogleSession {
            store.hasCompletedOnboarding = true
            return false
        }
        return !store.hasCompletedOnboarding
    }

    public static func markCompleted(store: OnboardingStoring) {
        store.hasCompletedOnboarding = true
    }
}
