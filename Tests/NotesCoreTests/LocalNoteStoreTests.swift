import XCTest
@testable import NotesCore

final class LocalNoteStoreTests: XCTestCase {
    private var root: URL!
    private var store: LocalNoteStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotesCoreTests-\(UUID().uuidString)", isDirectory: true)
        store = LocalNoteStore(rootDirectory: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil
        store = nil
    }

    /// T1.01 Load when no file exists → "" (first launch).
    func test_T1_01_loadWhenNoFileExistsReturnsEmptyString() throws {
        XCTAssertEqual(try store.load(), "")
    }

    /// T1.02 Save then load round-trips exactly (incl. trailing newline, \\r\\n, tabs).
    func test_T1_02_saveLoadRoundTripsExactBytesIncludingNewlinesAndTabs() throws {
        let text = "hello\tworld\r\nline2\n"
        try store.save(text)
        XCTAssertEqual(try store.load(), text)
    }

    /// T1.03 Unicode: emoji, combining marks, RTL, CJK, ZWJ round-trip byte-exact.
    func test_T1_03_unicodeRoundTripsByteExact() throws {
        let text = "café 👨‍👩‍👧‍👦 العربية 日本語 é" // combining acute on e
        try store.save(text)
        let loaded = try store.load()
        XCTAssertEqual(loaded, text)
        XCTAssertEqual(loaded.utf8.map { $0 }, text.utf8.map { $0 })
    }

    /// T1.04 Empty string saves and loads as "" (select-all + delete, R4).
    func test_T1_04_emptyStringRoundTrips() throws {
        try store.save("something")
        try store.save("")
        XCTAssertEqual(try store.load(), "")
    }

    /// T1.05 Whitespace-only text is preserved, not trimmed.
    func test_T1_05_whitespaceOnlyPreserved() throws {
        let text = "  \n\t  "
        try store.save(text)
        XCTAssertEqual(try store.load(), text)
    }

    /// T1.06 Large text (5 MB) round-trips.
    func test_T1_06_largeTextRoundTrips() throws {
        let text = String(repeating: "a", count: 5 * 1024 * 1024)
        try store.save(text)
        XCTAssertEqual(try store.load().count, text.count)
        XCTAssertEqual(try store.load(), text)
    }

    /// T1.07 Atomicity: simulated failure mid-write leaves the previous content intact.
    func test_T1_07_failedWriteLeavesPreviousContentIntact() throws {
        try store.save("stable")
        let failing = LocalNoteStore(
            rootDirectory: root,
            writer: FailingWriter(error: CocoaError(.fileWriteUnknown))
        )
        XCTAssertThrowsError(try failing.save("should-not-land"))
        XCTAssertEqual(try store.load(), "stable")
    }

    /// T1.08 Directory missing → created on first save.
    func test_T1_08_missingDirectoryCreatedOnFirstSave() throws {
        let nested = root.appendingPathComponent("nested/deep", isDirectory: true)
        let nestedStore = LocalNoteStore(rootDirectory: nested)
        try nestedStore.save("ok")
        XCTAssertEqual(try nestedStore.load(), "ok")
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }

    /// T1.09 Corrupt/non-UTF-8 → lossy decode + backup raw file.
    func test_T1_09_corruptNonUTF8BacksUpAndLossyDecodes() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let noteURL = root.appendingPathComponent("note.txt")
        // Invalid UTF-8 sequence
        let raw = Data([0x48, 0x69, 0xFF, 0xFE, 0x21]) // "Hi" + invalid + "!"
        try raw.write(to: noteURL)
        let loaded = try store.load()
        XCTAssertTrue(loaded.contains("Hi"))
        let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("note.corrupt-") && $0.pathExtension == "bin" }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: backups[0]), raw)
    }

    /// T1.10 Read-only / disk-full error surfaces as typed error; original untouched.
    func test_T1_10_writeErrorIsTypedAndLeavesOriginalUntouched() throws {
        try store.save("original")
        let failing = LocalNoteStore(
            rootDirectory: root,
            writer: FailingWriter(error: CocoaError(.fileWriteOutOfSpace))
        )
        do {
            try failing.save("new")
            XCTFail("expected error")
        } catch let error as LocalNoteStoreError {
            guard case .writeFailed = error else {
                return XCTFail("unexpected \(error)")
            }
        }
        XCTAssertEqual(try store.load(), "original")
    }

    /// T1.11 Sync-state JSON: missing → defaults; corrupt → defaults + dirty; round-trip.
    func test_T1_11_syncStateMissingCorruptAndRoundTrip() throws {
        let missing = store.loadSyncState()
        XCTAssertEqual(missing, SyncState.defaults)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: root.appendingPathComponent("sync-state.json"))
        let corrupt = store.loadSyncState()
        XCTAssertTrue(corrupt.dirty)
        XCTAssertNil(corrupt.driveFileId)

        var state = SyncState.defaults
        state.driveFileId = "abc"
        state.lastSyncedRemoteVersion = "12"
        state.lastSyncedHash = "deadbeef"
        state.dirty = true
        state.accountEmail = "a@b.com"
        try store.saveSyncState(state)
        XCTAssertEqual(store.loadSyncState(), state)
    }
}

// MARK: - Test doubles

private struct FailingWriter: NoteFileWriting {
    let error: Error
    func writeAtomically(_ data: Data, to url: URL) throws {
        throw error
    }
}
