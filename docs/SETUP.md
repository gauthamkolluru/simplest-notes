# Setup

## Prerequisites

- macOS with **Xcode 15+** (for the app and UI tests)
- Optional on Linux/macOS: **Swift 5.9+** toolchain for NotesCore unit tests only
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Clone & generate

```bash
git clone https://github.com/<you>/simplest-notes.git
cd simplest-notes
swift test                          # NotesCore (T0.01+)
xcodegen generate
open SimplestNotes.xcodeproj
```

## Google Cloud (needed from Phase 4)

1. Create a Google Cloud project.
2. Enable the **Google Drive API**.
3. Configure the OAuth consent screen (External → Testing; add yourself as a test user).
4. Create an **iOS** OAuth client ID (and macOS if prompted) for bundle id `app.simplestnotes.SimplestNotes`.
5. Add the client ID / URL scheme to the Xcode target (details filled in during Phase 4).

`drive.file` is a non-sensitive scope — no Google verification needed for personal use.

While the consent screen is in Testing, refresh tokens expire after 7 days; publishing to Production (still no verification for this scope) removes that limit.
