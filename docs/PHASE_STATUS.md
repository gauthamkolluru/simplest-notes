# Phase status

| Phase | Name | Status |
|-------|------|--------|
| Design | Requirements, ADRs, plan | Complete |
| 0 | Repository & scaffolding | Complete — T0.01 green on Linux; T0.02 UI tests for macOS CI |
| 1 | Local persistence & autosave | Complete — T1.01–T1.24 |
| 2 | Editor UI & first launch | Complete — unit + XCUITests authored |
| 3 | Connection state / Drive icon | Complete — T3.01–T3.14 + SwiftUI chrome (FakeAuth) |
| 4 | Real Google sign-in | Mapping + `GoogleAuthService` scaffold complete (T4.01–T4.06). Live GoogleSignIn SDK needs your OAuth client ID on a Mac |
| 5 | Drive client | Complete — T5.01–T5.10 with FakeHTTPTransport |
| 6 | Sync engine & conflicts | Complete — ConflictResolver + SyncEngine core tests green |
| 7 | Hardening & release | Pending (perf, two-device sim, a11y audit, TestFlight) |

**NotesCore:** `swift test` → **80 tests, 0 failures** (Linux).

**GitHub:** https://github.com/gauthamkolluru/simplest-notes exists (public). Agent push blocked until a `GITHUB_TOKEN` with repo write access is provided.
