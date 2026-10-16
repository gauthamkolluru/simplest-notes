# ADR-0007: Testing strategy

**Status:** Proposed  
**Date:** 2026-10-16

## Decision

- **Test-first per phase:** each phase lists edge cases → tests written and failing → implementation → green.
- **NotesCore** (pure Swift package, no UIKit/AppKit/Google SDK): `swift test` with XCTest. Clock, file system root, HTTP transport, and auth are injected, so tests are deterministic and offline.
- **App layer:** XCUITests on iOS Simulator (iPhone + iPad) and macOS, with launch arguments that swap in `FakeAuth` and `FakeDriveTransport`.
- **CI:** GitHub Actions — `swift test` on `ubuntu-latest` and `macos-latest`; `xcodebuild test` for iOS/iPadOS simulators and macOS. Project file generated with XcodeGen (`project.yml`) to avoid hand-editing `.pbxproj`.
- Real Google/Drive calls are exercised only by a **manual smoke checklist** (no live credentials in CI).
- **Coverage target:** ≥90% lines in NotesCore.
