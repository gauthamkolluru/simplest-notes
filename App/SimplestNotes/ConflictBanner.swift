import SwiftUI

struct ConflictBanner: View {
    let fileName: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Edits from another device conflicted — your version saved as \(fileName)")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", action: onDismiss)
                .font(.footnote.weight(.semibold))
        }
        .padding(10)
        .background(.yellow.opacity(0.25))
        .accessibilityIdentifier("conflictBanner")
    }
}
