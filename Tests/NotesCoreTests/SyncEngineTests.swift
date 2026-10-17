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

    /// T6.14 Offline → dirty stays; backoff doubles (2s → 4s, cap 5 min); reconnect push succeeds.
    func test_T6_14_offlineBackoffThenRetry() async throws {
        try seedSynced(text: "a", fileId: "f", version: "1")
        try store.save("b")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)

        XCTAssertEqual(engine.nextBackoffDelay, 2)
        http.throwOffline = true
        await engine.pushNow()
        XCTAssertTrue(events.contains(.syncIssue(true)))
        XCTAssertTrue(store.loadSyncState().dirty)
        XCTAssertEqual(engine.nextBackoffDelay, 4, "backoff should double after a failed push")

        await engine.pushNow()
        XCTAssertEqual(engine.nextBackoffDelay, 8)

        http.throwOffline = false
        enqueueMetadata(id: "f", version: "1")
        enqueueUpload(id: "f", version: "2")
        // Reconnect / scheduled retry path: push succeeds and resets backoff.
        await engine.pushNow()
        XCTAssertFalse(store.loadSyncState().dirty)
        XCTAssertEqual(store.loadSyncState().lastSyncedRemoteVersion, "2")
        XCTAssertEqual(engine.nextBackoffDelay, 2)
    }

    /// T6.19 401 → one refresh + retry; second 401 → authExpired.
    func test_T6_19_unauthorizedRefreshThenAuthExpired() async throws {
        var refreshCalls = 0
        let drive = DriveClient(transport: http, accessTokenProvider: { "token" })
        engine = SyncEngine(
            store: store,
            drive: drive,
            clock: clock,
            deviceName: "iPad",
            pushDelay: 2,
            tokenRefresh: {
                refreshCalls += 1
                return refreshCalls == 1
            }
        )
        events = []
        engine.onEvent = { [weak self] in self?.events.append($0) }

        try seedSynced(text: "a", fileId: "f", version: "1")
        try store.save("b")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)

        http.enqueue(status: 401, body: Data())
        http.enqueue(status: 401, body: Data())
        await engine.pushNow()
        XCTAssertEqual(refreshCalls, 2)
        XCTAssertTrue(events.contains(.connectionHint(.authExpired)))
        XCTAssertTrue(store.loadSyncState().dirty)
    }

    /// T6.19 happy path: 401 then refresh succeeds and push completes.
    func test_T6_19_unauthorizedRefreshSucceeds() async throws {
        var refreshCalls = 0
        let drive = DriveClient(transport: http, accessTokenProvider: { "token" })
        engine = SyncEngine(
            store: store,
            drive: drive,
            clock: clock,
            deviceName: "iPad",
            pushDelay: 2,
            tokenRefresh: {
                refreshCalls += 1
                return true
            }
        )
        events = []
        engine.onEvent = { [weak self] in self?.events.append($0) }

        try seedSynced(text: "a", fileId: "f", version: "1")
        try store.save("b")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)

        http.enqueue(status: 401, body: Data())
        enqueueMetadata(id: "f", version: "1")
        enqueueUpload(id: "f", version: "2")
        await engine.pushNow()
        XCTAssertEqual(refreshCalls, 1)
        XCTAssertFalse(store.loadSyncState().dirty)
        XCTAssertEqual(store.loadSyncState().lastSyncedRemoteVersion, "2")
    }

    /// T6.20 Quota exceeded → sync issue, local text unchanged.
    func test_T6_20_quotaExceededSetsSyncIssue() async throws {
        try seedSynced(text: "a", fileId: "f", version: "1")
        try store.save("b")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)
        enqueueMetadata(id: "f", version: "1")
        http.enqueue(status: 403, body: Data("storageQuotaExceeded".utf8))
        await engine.pushNow()
        XCTAssertTrue(events.contains(.syncIssue(true)))
        XCTAssertEqual(try store.load(), "b")
        XCTAssertTrue(store.loadSyncState().dirty)
    }

    /// T6.21 Disconnect / cancel during in-flight upload → never writes sync base after cancel.
    func test_T6_21_cancelMidUploadDoesNotMarkSynced() async throws {
        try seedSynced(text: "a", fileId: "f", version: "1")
        try store.save("b")
        var state = store.loadSyncState(); state.dirty = true; try store.saveSyncState(state)

        enqueueMetadata(id: "f", version: "1")
        http.armHold()
        enqueueUpload(id: "f", version: "99")

        let push = Task { await engine.pushNow() }
        try await Task.sleep(nanoseconds: 30_000_000)
        engine.clearSyncBaseAndCancel()
        http.releaseHold()
        await push.value

        let synced = store.loadSyncState()
        XCTAssertNil(synced.driveFileId)
        XCTAssertNotEqual(synced.lastSyncedRemoteVersion, "99")
    }

    /// T6.22 Switch account clears sync base; new first-connect uses fresh Drive location.
    func test_T6_22_switchAccountClearsBaseThenFirstConnect() async throws {
        try seedSynced(text: "local", fileId: "old-account-file", version: "1")
        engine.clearSyncBaseAndCancel()
        XCTAssertNil(store.loadSyncState().driveFileId)

        let drive = DriveClient(transport: http, accessTokenProvider: { "token" })
        let fresh = SyncEngine(store: store, drive: drive, clock: clock, deviceName: "iPad", pushDelay: 2)
        http.enqueueJSON(status: 200, object: ["files": []]) // find folder miss
        http.enqueueJSON(status: 200, object: ["id": "new-folder"]) // create folder
        http.enqueueJSON(status: 200, object: ["files": []]) // find note miss
        http.enqueueJSON(status: 200, object: [
            "id": "new-file", "version": "1", "modifiedTime": "t", "trashed": false,
        ])
        await fresh.firstConnect(localText: "local")
        XCTAssertEqual(store.loadSyncState().driveFileId, "new-file")
        XCTAssertNotEqual(store.loadSyncState().driveFileId, "old-account-file")
        fresh.cancel()
    }

    /// T6.25 Upload succeeded but response lost → next check sees our hash and marks synced.
    func test_T6_25_lostUploadResponseMarksSyncedOnNextPush() async throws {
        try store.save("uploaded")
        try store.saveSyncState(
            SyncState(
                driveFileId: "f",
                lastSyncedRemoteVersion: "1",
                lastSyncedHash: DriveClient.contentHash("old"),
                dirty: true
            )
        )
        // Server already has our bytes at version 2; client never saw the upload response.
        enqueueMetadata(id: "f", version: "2")
        http.enqueue(status: 200, body: Data("uploaded".utf8))
        await engine.pushNow()
        let state = store.loadSyncState()
        XCTAssertFalse(state.dirty)
        XCTAssertEqual(state.lastSyncedRemoteVersion, "2")
        XCTAssertEqual(state.lastSyncedHash, DriveClient.contentHash("uploaded"))
        XCTAssertFalse(http.recorded.contains { $0.method == "PATCH" })
    }

    /// T7.03 (lite) Two engines, one fake Drive — sequential edits don't lose text.
    func test_T7_03_twoDeviceSequentialNoLoss() async throws {
        try seedSynced(text: "base", fileId: "f", version: "1")

        let httpB = FakeHTTPTransport()
        let clockB = ManualClock()
        let storeBRoot = FileManager.default.temporaryDirectory.appendingPathComponent("syncB-\(UUID().uuidString)", isDirectory: true)
        let storeB = LocalNoteStore(rootDirectory: storeBRoot)
        try storeB.save("base")
        try storeB.saveSyncState(store.loadSyncState())

        let driveA = DriveClient(transport: http, accessTokenProvider: { "token" })
        let driveB = DriveClient(transport: httpB, accessTokenProvider: { "token" })
        let engineA = SyncEngine(store: store, drive: driveA, clock: clock, deviceName: "A", pushDelay: 2)
        let engineB = SyncEngine(store: storeB, drive: driveB, clock: clockB, deviceName: "B", pushDelay: 2)
        defer {
            engineA.cancel()
            engineB.cancel()
            try? FileManager.default.removeItem(at: storeBRoot)
        }

        try store.save("from-A")
        var sa = store.loadSyncState(); sa.dirty = true; try store.saveSyncState(sa)
        enqueueMetadata(id: "f", version: "1")
        enqueueUpload(id: "f", version: "2")
        await engineA.pushNow()

        // Device B pulls A's version then pushes its own edit.
        httpB.enqueueJSON(status: 200, object: [
            "id": "f", "version": "2", "modifiedTime": "t", "trashed": false,
        ])
        httpB.enqueue(status: 200, body: Data("from-A".utf8))
        await engineB.pull()
        XCTAssertEqual(try storeB.load(), "from-A")

        try storeB.save("from-B")
        var sb = storeB.loadSyncState(); sb.dirty = true; try storeB.saveSyncState(sb)
        httpB.enqueueJSON(status: 200, object: [
            "id": "f", "version": "2", "modifiedTime": "t", "trashed": false,
        ])
        httpB.enqueueJSON(status: 200, object: [
            "id": "f", "version": "3", "modifiedTime": "t", "trashed": false,
        ])
        await engineB.pushNow()
        XCTAssertEqual(try storeB.load(), "from-B")
        XCTAssertFalse(storeB.loadSyncState().dirty)
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
