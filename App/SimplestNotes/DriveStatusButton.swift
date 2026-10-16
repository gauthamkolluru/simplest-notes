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
                    .foregroundStyle(style.appearance == .active ? Color.accentColor : Color.secondary.opacity(0.45))
                    .font(.system(size: 18))
                if style.showsSpinner {
                    ProgressView()
                        .controlSize(.mini)
                        .offset(x: 10, y: -8)
                }
                if style.showsWarningBadge {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                        .offset(x: 8, y: -6)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!style.acceptsTap)
        .accessibilityIdentifier("driveStatusButton")
        .accessibilityLabel(style.accessibilityLabel)
    }
}
