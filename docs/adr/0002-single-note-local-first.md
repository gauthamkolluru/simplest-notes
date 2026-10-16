# ADR-0002: One plain-text note, local-first

**Status:** Proposed  
**Date:** 2026-10-16

## Context

R2–R4 forbid formatting, file names, save buttons, and a delete feature. R6/N2 require offline editing.

## Decision

- The app holds exactly **one** UTF-8 plain-text note.
- The on-device file `note.txt` is written on every edit (debounced 300 ms, atomic write via temp file + rename) and is the **source of truth while editing**. Drive is a synced replica.
- Editor is SwiftUI `TextEditor` bound to a `String` — no attributed text; pasted formatting is stripped by construction.
- Forced flush on `scenePhase` → `.inactive` / `.background` and on macOS window close / app quit.

## Consequences

- Never-connected users lose text if they delete the app (accepted, R12).
- Crash between keystroke and debounce loses ≤300 ms of typing; acceptable.
- Very large text (multi-MB) still works; editor performance is a Phase 7 hardening check.
