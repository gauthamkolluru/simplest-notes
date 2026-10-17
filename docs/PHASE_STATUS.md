# Phase status

| Phase | Name | Status |
|-------|------|--------|
| Design | Requirements, ADRs, plan | Complete |
| 0 | Repository & scaffolding | Complete — T0.01 green on Linux; T0.02 UI tests for macOS CI |
| 1 | Local persistence & autosave | Complete — T1.01–T1.24 |
| 2 | Editor UI & first launch | Complete — unit + XCUITests authored |
| 3 | Connection state / Drive icon | Complete — T3.01–T3.14 + SwiftUI chrome (FakeAuth in UI tests) |
| 4 | Real Google sign-in | Complete in code — `LiveGoogleSignInAdapter` + GoogleSignIn SPM + composition root. **Blocked on your OAuth client ID** (paste into `Config/Secrets.xcconfig`; see [SETUP.md](SETUP.md)) |
| 5 | Drive client | Complete — T5.01–T5.10 with FakeHTTPTransport |
| 6 | Sync engine & conflicts | Complete — ConflictResolver + SyncEngine + **app wiring** (connect / typing / lifecycle / conflict banner / clear sync base). Edge tests T6.14–T6.25 + T7.03 lite |
| 7 | Hardening & release | Pending (perf T7.01, full offline day T7.02, broader two-device interleavings, a11y audit, TestFlight) |

**NotesCore:** `swift test` → **88 tests, 0 failures** (Linux, Swift 6.0).

**GitHub:** https://github.com/gauthamkolluru/simplest-notes

## What you must paste (Phase 4)

1. Google Cloud → iOS OAuth client ID for bundle `app.simplestnotes.SimplestNotes`
2. Into `Config/Secrets.xcconfig` as `GOOGLE_CLIENT_ID` and `GOOGLE_REVERSED_CLIENT_ID`
3. `xcodegen generate` → Run in Xcode

Details: [SETUP.md](SETUP.md).
