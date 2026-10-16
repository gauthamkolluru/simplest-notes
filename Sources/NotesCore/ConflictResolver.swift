import Foundation

public enum ConflictDecision: Equatable, Sendable {
    case nothing
    case takeRemote
    case uploadLocal
    case markSynced
    case keepRemoteSaveLocalAsConflict
}

public enum FirstConnectDecision: Equatable, Sendable {
    case createRemoteFromLocal
    case takeRemote
    case markSynced
    case takeRemoteSaveLocalAsConflict
}

/// Pure conflict policy (ADR-0005). Never discards text.
public enum ConflictResolver {
    public static func decide(local: String, remote: String, baseHash: String?) -> ConflictDecision {
        let localHash = DriveClient.contentHash(local)
        let remoteHash = DriveClient.contentHash(remote)
        let localChanged = baseHash.map { $0 != localHash } ?? (local != "")
        let remoteChanged = baseHash.map { $0 != remoteHash } ?? true

        switch (localChanged, remoteChanged) {
        case (false, false):
            return .nothing
        case (false, true):
            return .takeRemote
        case (true, false):
            return .uploadLocal
        case (true, true):
            if local == remote {
                return .markSynced
            }
            return .keepRemoteSaveLocalAsConflict
        }
    }

    public static func decideFirstConnect(local: String, remote: String?) -> FirstConnectDecision {
        guard let remote else {
            return .createRemoteFromLocal
        }
        if local.isEmpty {
            return .takeRemote
        }
        if local == remote {
            return .markSynced
        }
        return .takeRemoteSaveLocalAsConflict
    }

    public static func conflictCopyFileName(now: Date, deviceName: String, uniqueSalt: String = "") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH-mm"
        let stamp = formatter.string(from: now)
        let device = sanitizeDriveName(deviceName)
        let salt = uniqueSalt.isEmpty ? "" : " \(sanitizeDriveName(uniqueSalt))"
        return "Notes (conflict \(stamp) \(device)\(salt)).txt"
    }

    public static func sanitizeDriveName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*:|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "device" : cleaned
    }
}
