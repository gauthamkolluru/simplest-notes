import SwiftUI

struct OnboardingView: View {
    var onConnect: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Connect Google Drive")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            Text(
                "Your note stays on this device while you write. Connecting Google Drive keeps a backup in your Drive so it survives if you delete the app, and stays available on your other devices."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("onboardingBenefit")

            VStack(spacing: 12) {
                Button("Connect", action: onConnect)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("onboardingConnect")

                Button("Not now", action: onNotNow)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("onboardingNotNow")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .accessibilityIdentifier("onboardingSheet")
    }
}
