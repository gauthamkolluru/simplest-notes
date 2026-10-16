import SwiftUI

/// Phase 0 blank shell. Editor UI arrives in Phase 2.
struct ContentView: View {
    var body: some View {
        ZStack {
            Color.white
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("blankRoot")
    }
}

#Preview {
    ContentView()
}
