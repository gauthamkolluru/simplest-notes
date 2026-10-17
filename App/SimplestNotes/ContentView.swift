import NotesCore
import SwiftUI

struct ContentView: View {
    @StateObject private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase

    init(session: AppSession = .make()) {
        _session = StateObject(wrappedValue: session)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if let conflictFileName = session.conflictFileName {
                    ConflictBanner(fileName: conflictFileName) {
                        session.dismissConflictBanner()
                    }
                }
                EditorView(model: session.app)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            DriveStatusButton(connection: session.connection)
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("blankRoot")
        .modifier(OnboardingSheetModifier(
            isPresented: Binding(
                get: { session.app.showOnboarding },
                set: { session.app.showOnboarding = $0 }
            ),
            onConnect: {
                session.app.finishOnboardingConnect()
                Task { await session.connection.handleIconTap() }
            },
            onNotNow: { session.app.finishOnboardingNotNow() }
        ))
        .sheet(item: Binding(
            get: { session.connection.sheet.map(AccountSheetItem.init) },
            set: { if $0 == nil { session.connection.dismissSheet() } }
        )) { item in
            AccountSheetView(
                email: item.email,
                onDisconnect: { Task { await session.connection.disconnect() } },
                onSwitchAccount: { Task { await session.connection.switchAccount() } }
            )
#if os(iOS)
            .presentationDetents([.medium])
#endif
        }
        .safeAreaInset(edge: .bottom) {
            if let message = session.connection.inlineError {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("authInlineError")
            }
        }
        .task {
            await session.start()
        }
        .onChange(of: scenePhase) { _, phase in
            session.scenePhaseChanged(phase)
        }
        .onOpenURL { url in
            session.handleOpenURL(url)
        }
    }
}

private struct OnboardingSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onConnect: () -> Void
    var onNotNow: () -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            OnboardingView(onConnect: onConnect, onNotNow: onNotNow)
#if os(iOS)
                .presentationDetents([.medium])
#endif
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
