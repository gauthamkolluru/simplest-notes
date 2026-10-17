import NotesCore
import SwiftUI

/// SwiftUI observation wrapper around NotesCore `ConnectionController`.
@MainActor
final class ConnectionViewModel: ObservableObject {
    @Published private(set) var state: ConnectionState = .notConnected
    @Published private(set) var sheet: AccountSheet?
    @Published private(set) var inlineError: String?

    let controller: ConnectionController

    /// Called after a successful interactive sign-in (not restore).
    var onBecameConnected: (() async -> Void)?
    /// Called before auth disconnect completes clearing tokens (flush/clear sync).
    var onWillDisconnect: (() async -> Void)?
    /// Called before switch-account disconnect (same clear as disconnect).
    var onWillSwitchAccount: (() async -> Void)?

    init(auth: any AuthProviding = FakeAuth()) {
        self.controller = ConnectionController(auth: auth)
        self.controller.onChange = { [weak self] in
            Task { @MainActor in
                self?.pull()
            }
        }
        pull()
    }

    @discardableResult
    func restoreSession() async -> Bool {
        let ok = await controller.restoreSession()
        pull()
        return ok
    }

    func handleIconTap() async {
        let before = controller.isConnected
        await controller.handleIconTap()
        pull()
        if !before, controller.isConnected {
            await onBecameConnected?()
        }
    }

    func dismissSheet() {
        controller.dismissSheet()
        pull()
    }

    func disconnect() async {
        await onWillDisconnect?()
        await controller.disconnect()
        pull()
    }

    func switchAccount() async {
        await onWillSwitchAccount?()
        await controller.switchAccount()
        pull()
        if controller.isConnected {
            await onBecameConnected?()
        }
    }

    private func pull() {
        state = controller.state
        sheet = controller.sheet
        inlineError = controller.inlineError
    }
}
