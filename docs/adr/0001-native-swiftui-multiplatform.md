# ADR-0001: Native SwiftUI multiplatform app (iOS, iPadOS, macOS)

**Status:** Proposed  
**Date:** 2026-10-16

## Context

The sketch requires the keyboard to already be up on iOS/iPadOS at launch (R8), a single tap to start editing (R1), Google Drive storage (R5), and no server (R6).

## Options

| Option | Keyboard auto-shown on iOS | Stays signed in w/o server | Testable here |
|--------|----------------------------|----------------------------|---------------|
| **A. Native SwiftUI** | Yes (`@FocusState` on appear) | Yes — GoogleSignIn SDK keeps a refresh token in Keychain | Core: yes (`swift test`); UI: on macOS CI |
| **B. PWA (static web app)** | No — iOS Safari refuses programmatic focus without a tap | No — browser OAuth gives 1-hour tokens; silent renewal needs popups that iOS standalone PWAs block | Yes |
| **C. Capacitor (web in native shell)** | Only via WKWebView private-API workaround | Needs native Google plugin anyway | Partly |

## Decision

**Option A.** It is the only option that satisfies R8 and R5+R6 together without hacks. One SwiftUI codebase targets iPhone, iPad, and Mac.

## Consequences

- Requires Xcode (Mac) to build/install; free Apple ID installs for 7 days; paid developer account ($99/yr) for permanent install / TestFlight.
- No Android/Windows/web. Revisit only if needed.
- Branching logic goes in a pure Swift package so it is tested on Linux and macOS ([ADR-0007](0007-testing-strategy.md)).
