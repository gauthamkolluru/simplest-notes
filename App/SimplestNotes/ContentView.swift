import NotesCore
import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppViewModel()
    @StateObject private var connection = ConnectionViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .topTrailing) {
            EditorView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            DriveStatusButton(connection: connection)
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("blankRoot")
        .sheet(isPresented: $model.showOnboarding) {
            OnboardingView(
                onConnect: {
                    model.finishOnboardingConnect()
                    Task { await connection.handleIconTap() }
                },
                onNotNow: { model.finishOnboardingNotNow() }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: Binding(
            get: { connection.sheet.map(AccountSheetItem.init) },
            set: { if $0 == nil { connection.dismissSheet() } }
        )) { item in
            AccountSheetView(
                email: item.email,
                onDisconnect: { Task { await connection.disconnect() } },
                onSwitchAccount: { Task { await connection.switchAccount() } }
            )
            .presentationDetents([.medium])
        }
        .safeAreaInset(edge: .bottom) {
            if let message = connection.inlineError {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("authInlineError")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                model.flush()
            }
        }
    }
}

private struct AccountSheetItem: Identifiable {
    let email: String
    var id: String { email }
    init(_ sheet: AccountSheet) {
        switch sheet {
        case .account(let email): self.email = email
        }
    }
}

#Preview {
    ContentView()
}
