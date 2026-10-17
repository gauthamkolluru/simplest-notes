import Foundation
import NotesCore

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Thin seam over GoogleSignIn so mapping stays unit-tested (ADR-0003 / Phase 4).
protocol GoogleSignInSDKAdapting: AnyObject {
    func presentSignIn() async -> GoogleSDKSignInEvent
    func restorePrevious() async -> GoogleSDKRestoreEvent
    func refreshAccessToken() async -> GoogleSDKTokenEvent
    func disconnectAndSignOut() async
    func currentAccessToken() async throws -> String
}

enum GoogleAuthConstants {
    static let driveFileScope = "https://www.googleapis.com/auth/drive.file"
}

/// Production adapter — compiled when GoogleSignIn is linked.
#if canImport(GoogleSignIn)
final class LiveGoogleSignInAdapter: GoogleSignInSDKAdapting {
    func presentSignIn() async -> GoogleSDKSignInEvent {
        do {
            let result = try await presentInteractiveSignIn()
            let user = result.user
            let email = user.profile?.email
            let granted = user.grantedScopes?.contains(where: { $0 == GoogleAuthConstants.driveFileScope }) == true
            if !granted {
                // Request Drive scope if basic sign-in succeeded without it.
                let scoped = try await addDriveScope(to: user)
                let ok = scoped.user.grantedScopes?.contains(where: { $0 == GoogleAuthConstants.driveFileScope }) == true
                return .success(email: scoped.user.profile?.email ?? email, grantedDriveScope: ok)
            }
            return .success(email: email, grantedDriveScope: true)
        } catch {
            return mapSignInError(error)
        }
    }

    func restorePrevious() async -> GoogleSDKRestoreEvent {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            return .success(email: user.profile?.email)
        } catch {
            let ns = error as NSError
            if ns.domain == "com.google.GIDSignIn", ns.code == GIDSignInError.hasNoAuthInKeychain.rawValue {
                return .unavailable
            }
            if ns.domain == "com.google.GIDSignIn", ns.code == GIDSignInError.canceled.rawValue {
                return .unavailable
            }
            return .revoked
        }
    }

    func refreshAccessToken() async -> GoogleSDKTokenEvent {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            return .refreshFailed
        }
        do {
            _ = try await user.refreshTokensIfNeeded()
            return .refreshed
        } catch {
            return .refreshFailed
        }
    }

    func disconnectAndSignOut() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            GIDSignIn.sharedInstance.disconnect { _ in
                GIDSignIn.sharedInstance.signOut()
                cont.resume()
            }
        }
    }

    func currentAccessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw AuthFailure.unknown
        }
        let fresh = try await user.refreshTokensIfNeeded()
        return fresh.accessToken.tokenString
    }

    // MARK: - Private

    private func presentInteractiveSignIn() async throws -> GIDSignInResult {
        let scopes = [GoogleAuthConstants.driveFileScope]
#if os(iOS)
        guard let presenter = await PresentingHost.viewController() else {
            throw AuthFailure.unknown
        }
        return try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presenter,
            hint: nil,
            additionalScopes: scopes
        )
#elseif os(macOS)
        guard let window = await PresentingHost.window() else {
            throw AuthFailure.unknown
        }
        return try await GIDSignIn.sharedInstance.signIn(
            withPresenting: window,
            hint: nil,
            additionalScopes: scopes
        )
#else
        throw AuthFailure.unknown
#endif
    }

    private func addDriveScope(to user: GIDGoogleUser) async throws -> GIDSignInResult {
        let scopes = [GoogleAuthConstants.driveFileScope]
#if os(iOS)
        guard let presenter = await PresentingHost.viewController() else {
            throw AuthFailure.unknown
        }
        return try await user.addScopes(scopes, presenting: presenter)
#elseif os(macOS)
        guard let window = await PresentingHost.window() else {
            throw AuthFailure.unknown
        }
        return try await user.addScopes(scopes, presenting: window)
#else
        throw AuthFailure.unknown
#endif
    }

    private func mapSignInError(_ error: Error) -> GoogleSDKSignInEvent {
        let ns = error as NSError
        if ns.domain == "com.google.GIDSignIn", ns.code == GIDSignInError.canceled.rawValue {
            return .cancelled
        }
        if ns.domain == NSURLErrorDomain {
            return .networkError
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return .networkError
            default:
                break
            }
        }
        return .unknown
    }
}

/// Finds a presenter for the Google Sign-In sheet (iOS UIViewController / macOS NSWindow).
enum PresentingHost {
#if os(iOS)
    @MainActor
    static func viewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        let key = windows.first(where: \.isKeyWindow) ?? windows.first
        return key?.rootViewController?.topMost
    }
#elseif os(macOS)
    @MainActor
    static func window() -> NSWindow? {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first
    }
#endif
}

#if os(iOS)
private extension UIViewController {
    var topMost: UIViewController {
        if let presented = presentedViewController {
            return presented.topMost
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMost
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMost
        }
        return self
    }
}
#endif
#endif

/// AuthProviding implementation used by the app (production).
final class GoogleAuthService: AuthProviding {
    private let sdk: any GoogleSignInSDKAdapting

    init(sdk: any GoogleSignInSDKAdapting) {
        self.sdk = sdk
    }

    func signIn() async -> AuthSignInResult {
        GoogleAuthMapping.mapSignIn(await sdk.presentSignIn())
    }

    func disconnect() async {
        await sdk.disconnectAndSignOut()
    }

    func restorePreviousSignIn() async -> AuthSignInResult? {
        GoogleAuthMapping.mapRestore(await sdk.restorePrevious())
    }

    func refreshAccessToken() async -> Bool {
        GoogleAuthMapping.mapToken(await sdk.refreshAccessToken()) == nil
    }

    func freshAccessToken() async throws -> String {
        try await sdk.currentAccessToken()
    }
}
