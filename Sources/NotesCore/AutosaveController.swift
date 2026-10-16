import Foundation

/// Debounced local saves; flush on background/quit (Phase 1).
public final class AutosaveController {
    private let store: LocalNoteStore
    private var debouncer: Debouncer<String>!
    private var lastSaved: String?

    public private(set) var saveError: LocalNoteStoreError?
    public var onLocalChanged: (() -> Void)?
    public var onSaveErrorChange: ((LocalNoteStoreError?) -> Void)?

    public init(store: LocalNoteStore, delay: TimeInterval = 0.3, clock: any Clock) {
        self.store = store
        self.lastSaved = try? store.load()
        self.debouncer = Debouncer(delay: delay, clock: clock) { [weak self] text in
            self?.persist(text)
        }
    }

    public func textDidChange(_ text: String) {
        debouncer.schedule(text)
    }

    public func flush() {
        debouncer.flush()
    }

    private func persist(_ text: String) {
        if text == lastSaved {
            return
        }
        do {
            try store.save(text)
            lastSaved = text
            var state = store.loadSyncState()
            state.dirty = true
            try store.saveSyncState(state)
            setSaveError(nil)
            onLocalChanged?()
        } catch let error as LocalNoteStoreError {
            setSaveError(error)
        } catch {
            setSaveError(.writeFailed(underlyingDescription: String(describing: error)))
        }
    }

    private func setSaveError(_ error: LocalNoteStoreError?) {
        saveError = error
        onSaveErrorChange?(error)
    }
}
