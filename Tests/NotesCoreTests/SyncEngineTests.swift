import XCTest
@testable import NotesCore

final class SyncEngineTests: XCTestCase {
    private var root: URL!
    private var store: LocalNoteStore!
    private var http: FakeHTTPTransport!
    private var clock: ManualClock!
    private var events: [SyncEngineEvent]!
    private var engine: SyncEngine!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString)", isDirectory: true)
        store = LocalNoteStore(rootDirectory: root)
        http = FakeHTTPTransport()
        clock = ManualClock()
        events = []
        let drive = DriveClient(transport: http, accessTokenProvider: { "token" })
        engine = SyncEngine(store: store, drive: drive, clock: clock, deviceName: "iPad", pushDelay: 2)
        engine.onEvent = { [weak self] in self?.events.append($0) }
    }

    override func tearDownWithError() throws {
        engine.cancel()
        try? FileManager.default.removeItem(at: root)
    }

    /// T6.12 Local edit → push after 2s; burst → one upload.
    func test_T6_12_pushDebounceCoalesces() async throws {
        try seedSynced(text: "a", fileId: "f", version: "1")
        try store.save("b")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)

        enqueueMetadata(id: "f", version: "1")
        enqueueUpload(id: "f", version: "2")
        enqueueMetadata(id: "f", version: "2")
        enqueueUpload(id: "f", version: "3")

        engine.noteLocalChanged()
        engine.noteLocalChanged()
        clock.advance(by: 2.01)
        // Allow async push task
        try await Task.sleep(nanoseconds: 50_000_000)
        let uploads = http.recorded.filter { $0.method == "PATCH" }
        XCTAssertEqual(uploads.count, 1)
    }

    /// T6.13 Background flush → immediate push.
    func test_T6_13_flushPushesImmediately() async throws {
        try seedSynced(text: "a", fileId: "f", version: "1")
        try store.save("b")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)
        enqueueMetadata(id: "f", version: "1")
        enqueueUpload(id: "f", version: "2")
        engine.noteLocalChanged()
        engine.flushPush()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(http.recorded.contains { $0.method == "PATCH" })
    }

    /// T6.15 Pull unchanged version → no download.
    func test_T6_15_pullUnchangedSkipsDownload() async throws {
        try seedSynced(text: "a", fileId: "f", version: "1")
        enqueueMetadata(id: "f", version: "1")
        await engine.pull()
        XCTAssertFalse(http.recorded.contains { $0.url.contains("alt=media") })
    }

    /// T6.16 Remote changed, local clean → editor replaced.
    func test_T6_16_pullTakesRemoteWhenLocalClean() async throws {
        try seedSynced(text: "a", fileId: "f", version: "1")
        enqueueMetadata(id: "f", version: "2")
        http.enqueue(status: 200, body: Data("remote".utf8))
        await engine.pull()
        XCTAssertEqual(try store.load(), "remote")
        XCTAssertTrue(events.contains(.editorTextReplaced("remote")))
    }

    /// T6.17 Remote changed while dirty → conflict path, local preserved as copy.
    func test_T6_17_conflictPreservesLocalCopy() async throws {
        try seedSynced(text: "base", fileId: "f", version: "1")
        try store.save("local-edit")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)

        enqueueMetadata(id: "f", version: "2")
        http.enqueue(status: 200, body: Data("remote-edit".utf8))
        // ensureFolder for conflict upload
        http.enqueueJSON(status: 200, object: ["files": [["id": "folder"]]])
        http.enqueueJSON(status: 200, object: [
            "id": "conflict", "version": "1", "modifiedTime": "t", "trashed": false,
        ])
        // mark synced uses remote meta already fetched

        await engine.pull()
        XCTAssertEqual(try store.load(), "remote-edit")
        XCTAssertTrue(events.contains { if case .banner = $0 { return true }; return false })
    }

    /// T6.18 File deleted → recreate from local.
    func test_T6_18_recreateWhenFileGone() async throws {
        try seedSynced(text: "keep", fileId: "gone", version: "1")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)
        http.enqueue(status: 404, body: Data())
        http.enqueueJSON(status: 200, object: ["files": [["id": "folder"]]])
        http.enqueueJSON(status: 200, object: ["files": []])
        http.enqueueJSON(status: 200, object: [
            "id": "new", "version": "1", "modifiedTime": "t", "trashed": false,
        ])
        await engine.pushNow()
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(store.loadSyncState().driveFileId, "new")
        XCTAssertEqual(try store.load(), "keep")
    }

    /// T6.23 Push and pull never concurrent — serialised.
    func test_T6_23_pushAndPullSerialised() async throws {
        try seedSynced(text: "a", fileId: "f", version: "1")
        enqueueMetadata(id: "f", version: "1")
        enqueueMetadata(id: "f", version: "1")
        async let p: Void = engine.pull()
        async let q: Void = engine.pull()
        _ = await (p, q)
        XCTAssertEqual(http.recorded.count, 2)
    }

    /// T6.24 dirty survives process: next push after relaunch.
    func test_T6_24_dirtySurvivesRelaunchSemantics() throws {
        try seedSynced(text: "a", fileId: "f", version: "1")
        try store.save("b")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)
        let reloaded = LocalNoteStore(rootDirectory: root).loadSyncState()
        XCTAssertTrue(reloaded.dirty)
    }

    // MARK: - Helpers

    private func seedSynced(text: String, fileId: String, version: String) throws {
        try store.save(text)
        try store.saveSyncState(
            SyncState(
                driveFileId: fileId,
                lastSyncedRemoteVersion: version,
                lastSyncedHash: DriveClient.contentHash(text),
                dirty: false
            )
        )
    }

    private func enqueueMetadata(id: String, version: String, trashed: Bool = false) {
        http.enqueueJSON(status: 200, object: [
            "id": id, "version": version, "modifiedTime": "t", "trashed": trashed,
        ])
    }

    private func enqueueUpload(id: String, version: String) {
        http.enqueueJSON(status: 200, object: [
            "id": id, "version": version, "modifiedTime": "t", "trashed": false,
        ])
    }
}
