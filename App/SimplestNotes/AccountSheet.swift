import NotesCore
import SwiftUI

struct AccountSheetView: View {
    let email: String
    var onDisconnect: () -> Void
    var onSwitchAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(ConnectionController.displayEmail(email))
                .font(.headline)
                .accessibilityLabel(ConnectionController.accessibilityEmail(email))
                .accessibilityIdentifier("accountEmail")

            Button("Disconnect", role: .destructive, action: onDisconnect)
                .accessibilityIdentifier("disconnectButton")

            Button("Switch account", action: onSwitchAccount)
                .accessibilityIdentifier("switchAccountButton")
        }
        .padding(24)
        .frame(maxWidth: 360)
    }
}
