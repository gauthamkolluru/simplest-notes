import Foundation
import NotesCore

final class UserDefaultsOnboardingStore: OnboardingStoring {
    private let defaults: UserDefaults
    private let key = "hasCompletedOnboarding"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}
