import SwiftUI

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct SimplestNotesApp: App {
    init() {
        // GIDClientID is read from Info.plist (see project.yml / Config/*.xcconfig).
        // No hardcoded client IDs — paste yours into Config/Secrets.xcconfig (docs/SETUP.md).
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
