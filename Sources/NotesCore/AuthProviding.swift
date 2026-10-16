import Foundation

public enum AuthFailure: Error, Equatable, Sendable {
    case network
    case scopeDeclined
    case unknown
}

public enum AuthSignInResult: Equatable, Sendable {
    case success(email: String?)
    case cancelled
    case failure(AuthFailure)
}

public protocol AuthProviding: AnyObject {
    func signIn() async -> AuthSignInResult
    func disconnect() async
    func restorePreviousSignIn() async -> AuthSignInResult?
}

/// Deterministic auth double for tests and UI-test launch args.
public final class FakeAuth: AuthProviding, @unchecked Sendable {
    public var nextResult: AuthSignInResult = .success(email: "user@example.com")
    public var restoreResult: AuthSignInResult? = nil
    public var disconnectDelayNanoseconds: UInt64 = 0
    public private(set) var signInCallCount = 0
    public private(set) var disconnectCallCount = 0

    public init() {}

    public func signIn() async -> AuthSignInResult {
        signInCallCount += 1
        return nextResult
    }

    public func disconnect() async {
        if disconnectDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: disconnectDelayNanoseconds)
        }
        disconnectCallCount += 1
    }

    public func restorePreviousSignIn() async -> AuthSignInResult? {
        restoreResult
    }
}
