import Foundation
import NotesCore

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Thin seam over GoogleSignIn so mapping stays unit-tested (ADR-0003 / Phase 4).
protocol GoogleSignInSDKAdapting: AnyObject {
    func presentSignIn() async -> GoogleSDKSignInEvent
    func restorePrevious() async -> GoogleSDKRestoreEvent
    func refreshAccessToken() async -> GoogleSDKTokenEvent
    func disconnectAndSignOut() async
}

/// Production adapter — compiled when GoogleSignIn is linked (Phase 4 device setup).
#if canImport(GoogleSignIn)
final class LiveGoogleSignInAdapter: GoogleSignInSDKAdapting {
    func presentSignIn() async -> GoogleSDKSignInEvent {
        // Wired when OAuth client ID is configured (docs/SETUP.md).
        .unknown
    }

    func restorePrevious() async -> GoogleSDKRestoreEvent { .unavailable }

    func refreshAccessToken() async -> GoogleSDKTokenEvent { .refreshFailed }

    func disconnectAndSignOut() async {
        GIDSignIn.sharedInstance.signOut()
    }
}
#endif

/// AuthProviding implementation used by the app.
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
}
