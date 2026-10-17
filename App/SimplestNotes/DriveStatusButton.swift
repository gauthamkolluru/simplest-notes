import NotesCore
import SwiftUI

struct DriveStatusButton: View {
    @ObservedObject var connection: ConnectionViewModel

    var body: some View {
        let style = DriveIconStyle.from(connection.state)
        Button {
            Task { await connection.handleIconTap() }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "externaldrive.fill.badge.icloud")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(style.appearance == .active ? Color.accentColor : Color.primary.opacity(0.55))
                    .font(.system(size: 22))
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
                if style.showsSpinner {
                    ProgressView()
                        .controlSize(.mini)
                        .offset(x: 12, y: -10)
                }
                if style.showsWarningBadge {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .offset(x: 10, y: -8)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!style.acceptsTap)
        .accessibilityIdentifier("driveStatusButton")
        .accessibilityLabel(style.accessibilityLabel)
    }
}
