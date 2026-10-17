import Foundation
import NotesCore
import SwiftUI

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Composition root: auth, local store, SyncEngine, and UI view models.
@MainActor
final class AppSession: ObservableObject {
    let store: LocalNoteStore
    let app: AppViewModel
    let connection: ConnectionViewModel

    @Published var conflictFileName: String?

    private let clock: any Clock
    private let auth: any AuthProviding
    private let googleAuth: GoogleAuthService?
    private var syncEngine: SyncEngine?
    private let syncEnabled: Bool

    private init(
        store: LocalNoteStore,
        app: AppViewModel,
        connection: ConnectionViewModel,
        auth: any AuthProviding,
        googleAuth: GoogleAuthService?,
        syncEnabled: Bool,
        clock: any Clock
    ) {
        self.store = store
        self.app = app
        self.connection = connection
        self.auth = auth
        self.googleAuth = googleAuth
        self.syncEnabled = syncEnabled
        self.clock = clock

        app.onLocalChanged = { [weak self] in
            self?.syncEngine?.noteLocalChanged()
        }
        connection.onBecameConnected = { [weak self] in
            await self?.handleConnected()
        }
        connection.onWillDisconnect = { [weak self] in
            await self?.handleDisconnect()
        }
        connection.onWillSwitchAccount = { [weak self] in
            await self?.handleDisconnect()
        }
    }

    static func make() -> AppSession {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = support.appendingPathComponent("SimplestNotes", isDirectory: true)
        let store = LocalNoteStore(rootDirectory: root)
        let clock = DispatchClock()
        let uiTesting = UITestingBootstrap.isUITesting

        let auth: any AuthProviding
        let googleAuth: GoogleAuthService?
        if uiTesting {
            auth = FakeAuth()
            googleAuth = nil
        } else {
#if canImport(GoogleSignIn)
            let sdk = LiveGoogleSignInAdapter()
            let service = GoogleAuthService(sdk: sdk)
            auth = service
            googleAuth = service
#else
            auth = FakeAuth()
            googleAuth = nil
#endif
        }

        let connection = ConnectionViewModel(auth: auth)
        let app = AppViewModel(
            store: store,
            onboardingStore: UserDefaultsOnboardingStore(),
            clock: clock,
            hasRestorableGoogleSession: false
        )

        return AppSession(
            store: store,
            app: app,
            connection: connection,
            auth: auth,
            googleAuth: googleAuth,
            syncEnabled: !uiTesting && googleAuth != nil,
            clock: clock
        )
    }

    func start() async {
        let restored = await connection.restoreSession()
        if restored {
            app.noteHasRestorableSession()
            if syncEnabled {
                ensureSyncEngine()
                await syncEngine?.pull()
            }
        } else {
            // Re-evaluate onboarding now that restore completed.
            app.refreshOnboarding(hasRestorableGoogleSession: false)
        }
    }

    func handleOpenURL(_ url: URL) {
#if canImport(GoogleSignIn)
        _ = GIDSignIn.sharedInstance.handle(url)
#endif
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task { await syncEngine?.pull() }
        case .inactive, .background:
            app.flush()
            syncEngine?.flushPush()
        @unknown default:
            break
        }
    }

    func dismissConflictBanner() {
        conflictFileName = nil
    }

    // MARK: - Sync lifecycle

    private func handleConnected() async {
        guard syncEnabled else { return }
        ensureSyncEngine()
        let text = (try? store.load()) ?? app.text
        await syncEngine?.firstConnect(localText: text)
    }

    private func handleDisconnect() async {
        app.flush()
        if let engine = syncEngine {
            // Best-effort flush before clearing base (ADR-0006).
            engine.flushPush()
            try? await withTimeout(seconds: 5) {
                await engine.pushNow()
            }
            engine.clearSyncBaseAndCancel()
        } else {
            try? store.clearSyncBase()
        }
        syncEngine = nil
        conflictFileName = nil
        connection.controller.setSyncIssue(false)
    }

    private func ensureSyncEngine() {
        guard syncEnabled, syncEngine == nil, let googleAuth else { return }
        let drive = DriveClient(
            transport: URLSessionTransport(),
            accessTokenProvider: { [weak googleAuth] in
                guard let googleAuth else { throw AuthFailure.unknown }
                return try await googleAuth.freshAccessToken()
            }
        )
        let engine = SyncEngine(
            store: store,
            drive: drive,
            clock: clock,
            deviceName: Self.deviceName(),
            pushDelay: 2,
            tokenRefresh: { [weak googleAuth] in
                guard let googleAuth else { return false }
                return await googleAuth.refreshAccessToken()
            }
        )
        engine.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.applySyncEvent(event)
            }
        }
        syncEngine = engine
    }

    private func applySyncEvent(_ event: SyncEngineEvent) {
        switch event {
        case .editorTextReplaced(let text):
            app.applyRemoteText(text)
        case .banner(.conflictSavedAs(let name)):
            conflictFileName = name
        case .connectionHint(.authExpired):
            connection.controller.applyAuthExpired()
        case .connectionHint:
            break
        case .syncIssue(let issue):
            connection.controller.setSyncIssue(issue)
        }
    }

    private static func deviceName() -> String {
#if os(iOS)
        return UIDevice.current.model
#elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
#else
        return "device"
#endif
    }

    private func withTimeout(seconds: TimeInterval, operation: @escaping () async -> Void) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }
            _ = try await group.next()
            group.cancelAll()
        }
    }
}
