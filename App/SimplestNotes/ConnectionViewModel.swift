import NotesCore
import SwiftUI

/// SwiftUI observation wrapper around NotesCore `ConnectionController`.
@MainActor
final class ConnectionViewModel: ObservableObject {
    @Published private(set) var state: ConnectionState = .notConnected
    @Published private(set) var sheet: AccountSheet?
    @Published private(set) var inlineError: String?

    let controller: ConnectionController

    init(auth: any AuthProviding = FakeAuth()) {
        self.controller = ConnectionController(auth: auth)
        self.controller.onChange = { [weak self] in
            Task { @MainActor in
                self?.pull()
            }
        }
        pull()
    }

    func handleIconTap() async {
        await controller.handleIconTap()
        pull()
    }

    func dismissSheet() {
        controller.dismissSheet()
        pull()
    }

    func disconnect() async {
        await controller.disconnect()
        pull()
    }

    func switchAccount() async {
        await controller.switchAccount()
        pull()
    }

    private func pull() {
        state = controller.state
        sheet = controller.sheet
        inlineError = controller.inlineError
    }
}
