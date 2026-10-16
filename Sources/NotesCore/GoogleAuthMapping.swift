import Foundation

/// SDK-agnostic sign-in outcomes from a thin GoogleSignIn adapter (ADR-0003).
public enum GoogleSDKSignInEvent: Equatable, Sendable {
    case success(email: String?, grantedDriveScope: Bool)
    case cancelled
    case networkError
    case unknown
}

public enum GoogleSDKRestoreEvent: Equatable, Sendable {
    case success(email: String?)
    case unavailable
    case revoked
}

public enum GoogleSDKTokenEvent: Equatable, Sendable {
    case refreshed
    case refreshFailed
}

/// Pure mapping from SDK adapter events → AuthProviding results / connection hints.
public enum GoogleAuthMapping {
    public static func mapSignIn(_ event: GoogleSDKSignInEvent) -> AuthSignInResult {
        switch event {
        case .success(_, false):
            return .failure(.scopeDeclined)
        case .success(let email, true):
            return .success(email: email)
        case .cancelled:
            return .cancelled
        case .networkError:
            return .failure(.network)
        case .unknown:
            return .failure(.unknown)
        }
    }

    public static func mapRestore(_ event: GoogleSDKRestoreEvent) -> AuthSignInResult? {
        switch event {
        case .success(let email):
            return .success(email: email)
        case .unavailable, .revoked:
            return nil
        }
    }

    public static func mapToken(_ event: GoogleSDKTokenEvent) -> ConnectionState? {
        switch event {
        case .refreshed:
            return nil
        case .refreshFailed:
            return .authExpired
        }
    }

    public static func scopeDeclinedMessage() -> String {
        "Drive access is required to back up your note. Please allow Google Drive when signing in."
    }
}
