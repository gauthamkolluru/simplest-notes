import Foundation
import NotesCore

enum UITestingBootstrap {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    static func applyLaunchConfiguration(
        onboardingStore: OnboardingStoring,
        noteStore: LocalNoteStore
    ) {
        guard isUITesting else { return }
        let args = ProcessInfo.processInfo.arguments

        if args.contains("-force-onboarding") {
            onboardingStore.hasCompletedOnboarding = false
        }
        if args.contains("-skip-onboarding") {
            onboardingStore.hasCompletedOnboarding = true
        }
        if args.contains("-reset-note") {
            try? noteStore.save("")
            try? noteStore.saveSyncState(.defaults)
        }
        if let idx = args.firstIndex(of: "-seed-text"), args.indices.contains(idx + 1) {
            try? noteStore.save(args[idx + 1])
        }
    }
}
