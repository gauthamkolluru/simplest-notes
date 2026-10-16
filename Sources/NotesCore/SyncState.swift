import Foundation

/// Persisted sync bookkeeping (`sync-state.json`).
public struct SyncState: Codable, Equatable, Sendable {
    public var driveFileId: String?
    public var lastSyncedRemoteVersion: String?
    public var lastSyncedHash: String?
    public var dirty: Bool
    public var accountEmail: String?

    public init(
        driveFileId: String? = nil,
        lastSyncedRemoteVersion: String? = nil,
        lastSyncedHash: String? = nil,
        dirty: Bool = false,
        accountEmail: String? = nil
    ) {
        self.driveFileId = driveFileId
        self.lastSyncedRemoteVersion = lastSyncedRemoteVersion
        self.lastSyncedHash = lastSyncedHash
        self.dirty = dirty
        self.accountEmail = accountEmail
    }

    public static let defaults = SyncState()
}
