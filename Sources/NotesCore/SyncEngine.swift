import Foundation

public enum SyncBanner: Equatable, Sendable {
    case conflictSavedAs(fileName: String)
}

public enum SyncEngineEvent: Equatable, Sendable {
    case editorTextReplaced(String)
    case banner(SyncBanner)
    case connectionHint(ConnectionState)
    case syncIssue(Bool)
}

/// Local ↔ Drive reconciliation (ADR-0005 / ADR-0006).
public final class SyncEngine: @unchecked Sendable {
    private let store: LocalNoteStore
    private let drive: DriveClient
    private let clock: any Clock
    private let deviceName: String
    private let pushDelay: TimeInterval

    private var pushDebouncer: Debouncer<Void>!
    private var gate = AsyncGate()
    private var backoff: TimeInterval = 2
    private var cancelled = false
    private var folderId: String?
    private var tokenRefresh: (() async -> Bool)?

    public var onEvent: ((SyncEngineEvent) -> Void)?

    public init(
        store: LocalNoteStore,
        drive: DriveClient,
        clock: any Clock,
        deviceName: String = "device",
        pushDelay: TimeInterval = 2,
        tokenRefresh: (() async -> Bool)? = nil
    ) {
        self.store = store
        self.drive = drive
        self.clock = clock
        self.deviceName = deviceName
        self.pushDelay = pushDelay
        self.tokenRefresh = tokenRefresh
        self.pushDebouncer = Debouncer(delay: pushDelay, clock: clock) { [weak self] _ in
            Task { await self?.pushNow() }
        }
    }

    public func noteLocalChanged() {
        pushDebouncer.schedule(())
    }

    public func flushPush() {
        pushDebouncer.flush()
    }

    public func cancel() {
        cancelled = true
        pushDebouncer.cancel()
    }

    public func pull() async {
        await serialize {
            await self.pullUnlocked()
        }
    }

    public func pushNow() async {
        await serialize {
            await self.pushUnlocked()
        }
    }

    public func firstConnect(localText: String) async {
        await serialize {
            await self.firstConnectUnlocked(localText: localText)
        }
    }

    // MARK: - Private

    private func serialize(_ work: @escaping () async -> Void) async {
        await gate.withExclusive(work)
    }

    private func pullUnlocked() async {
        guard !cancelled else { return }
        let state = store.loadSyncState()
        guard let fileId = state.driveFileId else { return }
        do {
            let meta = try await drive.metadata(fileId: fileId)
            if meta.version == state.lastSyncedRemoteVersion {
                return
            }
            let download = try await drive.download(fileId: fileId)
            let local = (try? store.load()) ?? ""
            let decision = ConflictResolver.decide(
                local: local,
                remote: download.text,
                baseHash: state.lastSyncedHash
            )
            try await apply(decision, local: local, remote: download.text, meta: meta)
        } catch DriveClientError.fileGone {
            await recreateFromLocal()
        } catch DriveClientError.unauthorized {
            await handleUnauthorized()
        } catch {
            onEvent?(.syncIssue(true))
        }
    }

    private func pushUnlocked() async {
        guard !cancelled else { return }
        let state = store.loadSyncState()
        guard state.dirty else { return }
        let local = (try? store.load()) ?? ""
        do {
            if let fileId = state.driveFileId {
                let meta = try await drive.metadata(fileId: fileId)
                if meta.version == state.lastSyncedRemoteVersion {
                    let uploaded = try await drive.upload(fileId: fileId, text: local)
                    try markSynced(text: local, meta: uploaded)
                    backoff = 2
                    onEvent?(.syncIssue(false))
                    return
                }
                let download = try await drive.download(fileId: fileId)
                let decision = ConflictResolver.decide(
                    local: local,
                    remote: download.text,
                    baseHash: state.lastSyncedHash
                )
                try await apply(decision, local: local, remote: download.text, meta: meta)
            } else {
                await firstConnectUnlocked(localText: local)
            }
        } catch DriveClientError.offline, DriveClientError.transient, DriveClientError.rateLimited {
            onEvent?(.syncIssue(true))
            scheduleBackoffRetry()
        } catch DriveClientError.quotaExceeded {
            onEvent?(.syncIssue(true))
        } catch DriveClientError.unauthorized {
            await handleUnauthorized()
        } catch DriveClientError.fileGone {
            await recreateFromLocal()
        } catch {
            onEvent?(.syncIssue(true))
            scheduleBackoffRetry()
        }
    }

    private func firstConnectUnlocked(localText: String) async {
        do {
            let folder = try await ensureFolderId()
            if let fileId = try await drive.findNoteFile(folderId: folder) {
                let download = try await drive.download(fileId: fileId)
                let meta = try await drive.metadata(fileId: fileId)
                switch ConflictResolver.decideFirstConnect(local: localText, remote: download.text) {
                case .createRemoteFromLocal:
                    break
                case .takeRemote:
                    try store.save(download.text)
                    try markSynced(text: download.text, meta: meta)
                    onEvent?(.editorTextReplaced(download.text))
                case .markSynced:
                    try markSynced(text: localText, meta: meta)
                case .takeRemoteSaveLocalAsConflict:
                    let name = ConflictResolver.conflictCopyFileName(now: clock.now, deviceName: deviceName, uniqueSalt: UUID().uuidString.prefix(4).description)
                    _ = try await drive.uploadConflictCopy(folderId: folder, text: localText, fileName: name)
                    try store.save(download.text)
                    try markSynced(text: download.text, meta: meta)
                    onEvent?(.editorTextReplaced(download.text))
                    onEvent?(.banner(.conflictSavedAs(fileName: name)))
                }
            } else {
                let meta = try await drive.createNoteFile(folderId: folder, text: localText)
                try markSynced(text: localText, meta: meta)
            }
        } catch {
            onEvent?(.syncIssue(true))
        }
    }

    private func apply(
        _ decision: ConflictDecision,
        local: String,
        remote: String,
        meta: DriveFileMetadata
    ) async throws {
        switch decision {
        case .nothing:
            return
        case .takeRemote:
            try store.save(remote)
            try markSynced(text: remote, meta: meta)
            onEvent?(.editorTextReplaced(remote))
        case .uploadLocal:
            let uploaded = try await drive.upload(fileId: meta.id, text: local)
            try markSynced(text: local, meta: uploaded)
        case .markSynced:
            try markSynced(text: local, meta: meta)
        case .keepRemoteSaveLocalAsConflict:
            let folderId = try await ensureFolderId()
            let name = ConflictResolver.conflictCopyFileName(
                now: clock.now,
                deviceName: deviceName,
                uniqueSalt: UUID().uuidString.prefix(4).description
            )
            _ = try await drive.uploadConflictCopy(folderId: folderId, text: local, fileName: name)
            try store.save(remote)
            try markSynced(text: remote, meta: meta)
            onEvent?(.editorTextReplaced(remote))
            onEvent?(.banner(.conflictSavedAs(fileName: name)))
        }
    }

    private func markSynced(text: String, meta: DriveFileMetadata) throws {
        var state = store.loadSyncState()
        state.driveFileId = meta.id
        state.lastSyncedRemoteVersion = meta.version
        state.lastSyncedHash = DriveClient.contentHash(text)
        state.dirty = false
        try store.saveSyncState(state)
    }

    private func ensureFolderId() async throws -> String {
        if let folderId { return folderId }
        if let existing = try await drive.findFolder() {
            folderId = existing
            return existing
        }
        let created = try await drive.createFolder()
        folderId = created
        return created
    }

    private func recreateFromLocal() async {
        do {
            let local = try store.load()
            var state = store.loadSyncState()
            state.driveFileId = nil
            state.lastSyncedRemoteVersion = nil
            state.lastSyncedHash = nil
            state.dirty = true
            try store.saveSyncState(state)
            await firstConnectUnlocked(localText: local)
        } catch {
            onEvent?(.syncIssue(true))
        }
    }

    private func handleUnauthorized() async {
        if let tokenRefresh, await tokenRefresh() {
            await pushUnlocked()
            return
        }
        onEvent?(.connectionHint(.authExpired))
    }

    private func scheduleBackoffRetry() {
        let delay = backoff
        backoff = min(backoff * 2, 300)
        _ = clock.schedule(after: delay) { [weak self] in
            Task { await self?.pushNow() }
        }
    }
}
