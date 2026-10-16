import XCTest
@testable import NotesCore

final class AutosaveControllerTests: XCTestCase {
    private var root: URL!
    private var store: LocalNoteStore!
    private var clock: ManualClock!
    private var controller: AutosaveController!
    private var localChangedCount = 0

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Autosave-\(UUID().uuidString)", isDirectory: true)
        store = LocalNoteStore(rootDirectory: root)
        clock = ManualClock()
        localChangedCount = 0
        controller = AutosaveController(store: store, delay: 0.3, clock: clock)
        controller.onLocalChanged = { [weak self] in
            self?.localChangedCount += 1
        }
    }

    override func tearDownWithError() throws {
        controller = nil
        try? FileManager.default.removeItem(at: root)
    }

    /// T1.20 Typing triggers exactly one save per debounce window.
    func test_T1_20_typingTriggersOneSavePerDebounceWindow() throws {
        controller.textDidChange("a")
        controller.textDidChange("ab")
        controller.textDidChange("abc")
        clock.advance(by: 0.31)
        XCTAssertEqual(try store.load(), "abc")
        // One debounce fire → one save
        XCTAssertEqual(localChangedCount, 1)
    }

    /// T1.21 Text identical to last saved → no write.
    func test_T1_21_identicalTextSkipsWrite() throws {
        try store.save("same")
        var state = store.loadSyncState()
        state.dirty = false
        try store.saveSyncState(state)
        // Controller must observe the already-persisted snapshot.
        controller = AutosaveController(store: store, delay: 0.3, clock: clock)
        localChangedCount = 0
        controller.onLocalChanged = { [weak self] in
            self?.localChangedCount += 1
        }

        controller.textDidChange("same")
        clock.advance(by: 0.31)
        XCTAssertEqual(localChangedCount, 0)
        XCTAssertFalse(store.loadSyncState().dirty)
    }

    /// T1.22 Background/quit event flushes pending text immediately.
    func test_T1_22_flushPersistsPendingImmediately() throws {
        controller.textDidChange("flushed")
        controller.flush()
        XCTAssertEqual(try store.load(), "flushed")
        clock.advance(by: 1)
        XCTAssertEqual(localChangedCount, 1)
    }

    /// T1.23 Save failure retries on next change; reports saveError; recovers.
    func test_T1_23_saveFailureRetriesAndRecovers() throws {
        let writer = ToggleWriter()
        let failingStore = LocalNoteStore(rootDirectory: root, writer: writer)
        let c = AutosaveController(store: failingStore, delay: 0.3, clock: clock)
        var errors: [LocalNoteStoreError?] = []
        c.onSaveErrorChange = { errors.append($0) }

        writer.shouldFail = true
        c.textDidChange("one")
        clock.advance(by: 0.31)
        XCTAssertNotNil(c.saveError)

        writer.shouldFail = false
        c.textDidChange("two")
        clock.advance(by: 0.31)
        XCTAssertNil(c.saveError)
        XCTAssertEqual(try failingStore.load(), "two")
        XCTAssertTrue(errors.contains { $0 != nil })
        XCTAssertTrue(errors.contains { $0 == nil })
    }

    /// T1.24 Successful save marks dirty=true and emits local-changed.
    func test_T1_24_successfulSaveMarksDirtyAndEmitsEvent() throws {
        var state = store.loadSyncState()
        state.dirty = false
        try store.saveSyncState(state)

        controller.textDidChange("note")
        clock.advance(by: 0.31)
        XCTAssertTrue(store.loadSyncState().dirty)
        XCTAssertEqual(localChangedCount, 1)
    }
}

/// Writer that can be toggled to fail.
private final class ToggleWriter: NoteFileWriting {
    var shouldFail = false
    private let inner = AtomicFileWriter()

    func writeAtomically(_ data: Data, to url: URL) throws {
        if shouldFail {
            throw CocoaError(.fileWriteUnknown)
        }
        try inner.writeAtomically(data, to: url)
    }
}
