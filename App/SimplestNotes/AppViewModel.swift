import Foundation
import NotesCore
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var showOnboarding: Bool = false
    @Published var saveErrorMessage: String?

    private let store: LocalNoteStore
    private let autosave: AutosaveController
    private let onboardingStore: OnboardingStoring
    private let clock: any Clock

    init(
        store: LocalNoteStore? = nil,
        onboardingStore: OnboardingStoring = UserDefaultsOnboardingStore(),
        clock: any Clock = DispatchClock(),
        hasRestorableGoogleSession: Bool = false
    ) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = support.appendingPathComponent("SimplestNotes", isDirectory: true)
        let noteStore = store ?? LocalNoteStore(rootDirectory: root)
        UITestingBootstrap.applyLaunchConfiguration(
            onboardingStore: onboardingStore,
            noteStore: noteStore
        )
        self.store = noteStore
        self.onboardingStore = onboardingStore
        self.clock = clock
        self.autosave = AutosaveController(store: noteStore, delay: 0.3, clock: clock)

        self.text = (try? noteStore.load()) ?? ""
        self.showOnboarding = OnboardingPolicy.shouldShow(
            store: onboardingStore,
            hasRestorableGoogleSession: hasRestorableGoogleSession
        )

        autosave.onSaveErrorChange = { [weak self] error in
            Task { @MainActor in
                self?.saveErrorMessage = error.map { _ in "Couldn't save locally. Your next edit will retry." }
            }
        }
    }

    func textEdited(_ newValue: String) {
        text = newValue
        autosave.textDidChange(newValue)
    }

    func flush() {
        autosave.flush()
    }

    func finishOnboardingConnect() {
        OnboardingPolicy.markCompleted(store: onboardingStore)
        showOnboarding = false
        // Real connect arrives in Phase 4; Phase 2 only dismisses.
    }

    func finishOnboardingNotNow() {
        OnboardingPolicy.markCompleted(store: onboardingStore)
        showOnboarding = false
    }
}
