# Simplest Notes — Application Design

**Status:** Proposed (awaiting approval)  
**Date:** 2026-10-16  
**Owner:** Gautham  
**Source sketch:** [assets/requirements-sketch.jpg](assets/requirements-sketch.jpg)

---

## 1. Product intent

A notes app that gets out of the way: open → type. No formatting, no file names, no save button. Text persists locally as you type and syncs to the user's Google Drive. No backend of our own.

---

## 2. Requirements

### Functional

| ID | Requirement |
|----|-------------|
| R1 | Single tap opens the app straight into editing. |
| R2 | Plain text editor only — no markdown, markup, or formatting of any kind. |
| R3 | No save button, no file names, no locations. Text saves as you type. |
| R4 | "Delete" is Select All (Ctrl/Cmd+A) + Delete. No delete feature exists. |
| R5 | The text is stored in the user's Google Drive. |
| R6 | Runs entirely on-device. No backend server of our own. |
| R7 | First launch: prompt to connect Google Drive and explain why it is useful (Connect / Not now). |
| R8 | After first launch (and after onboarding): open directly to the text interface; on iOS/iPadOS the keyboard is already up. |
| R9 | Top-right corner: small Google Drive icon. Dull = not connected, active = connected. |
| R10 | Tap icon when not connected → try connecting again. |
| R11 | Tap icon when connected → show connected account email, Disconnect, and Switch account. |
| R12 | If the app is deleted: text survives in Drive if connected; if never connected, text is gone (expected). |

### Non-functional

| ID | Requirement |
|----|-------------|
| N1 | Never lose text. Every keystroke is durably on disk within ~300 ms; Drive is eventually consistent with the device. |
| N2 | Offline-first. Editing never waits on the network. |
| N3 | Privacy. Least-privilege Drive scope; the app can see only files it created. |
| N4 | Testability. Every function has edge-case tests written before its implementation. |

### Assumptions (please confirm)

| ID | Assumption |
|----|------------|
| A1 | **One note.** "No file names" + "delete = select all" implies a single continuous text. Multiple notes are out of scope. |
| A2 | **Platforms:** iPhone, iPad, and Mac (one SwiftUI codebase). See [ADR-0001](adr/0001-native-swiftui-multiplatform.md). |
| A3 | Multi-device use (e.g. iPhone + iPad on the same Google account) should work; conflicts must never silently discard text. |

---

## 3. Architecture

All logic with branches lives in **NotesCore** behind protocols, so it is unit-tested without a device, network, or Google account. The app layer is thin glue, covered by XCUITests with fake auth/Drive.

```
┌────────────────────── App (SwiftUI, iOS/iPadOS/macOS) ──────────────────────┐
│ EditorView · DriveStatusButton (top-right) · AccountSheet · OnboardingView   │
│ AppViewModel (binds UI to core; handles scenePhase flushes)                  │
│ GoogleAuthService (GoogleSignIn SDK, Keychain) ← only Google-SDK code        │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    ▼
┌──────────────────── NotesCore (pure Swift package, Linux-testable) ─────────┐
│ LocalNoteStore      atomic file write/read of note.txt + sync-state.json     │
│ Debouncer           injectable clock                                         │
│ AutosaveController  text changes → debounced local save (+ forced flush)     │
│ ConnectionState     state → DriveIconStyle mapping                           │
│ OnboardingPolicy    first-launch flag logic                                  │
│ DriveClient         Drive v3 REST over injectable HTTPTransport              │
│ SyncEngine          local ↔ Drive reconciliation state machine               │
│ ConflictResolver    pure decision function (never discards text)             │
│ AuthProviding       protocol; app implements with GoogleSignIn               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Key flows

### Launch

1. Read `note.txt` → show `EditorView` with focus (keyboard up on iOS/iPadOS).
2. If first launch → present `OnboardingView` over the editor.
3. If connected → `SyncEngine.pull()` in background.

### Typing

1. `AutosaveController` debounces (300 ms) → `LocalNoteStore.save` (atomic).
2. Marks dirty → `SyncEngine` debounces push (2 s).
3. Upload if remote unchanged; else `ConflictResolver`.

### Lifecycle

- **Background / quit:** flush local save immediately → attempt push inside a background task.
- **Foreground:** pull; if remote changed and local not dirty → replace editor text (cursor preserved where possible); if both changed → conflict policy ([ADR-0005](adr/0005-sync-and-conflict-policy.md)).

### Connect / disconnect / switch

- **Connect** (onboarding or dull icon): Google sign-in → locate/create `Simplest Notes/Notes.txt` → initial reconciliation → icon active.
- **Disconnect:** stop sync, revoke token, sign out; local text stays; icon dull.
- **Switch account:** disconnect → sign in with a different account → first-connect reconciliation against that account's file.

---

## 5. Data on device

| Location | Contents |
|----------|----------|
| Application Support/`note.txt` | The note text (UTF-8) |
| Application Support/`sync-state.json` | `{ driveFileId, lastSyncedRemoteVersion, lastSyncedHash, dirty, accountEmail }` |
| UserDefaults | `hasCompletedOnboarding` |
| Keychain (GoogleSignIn SDK) | OAuth tokens |

---

## 6. Data in Drive

- Folder **Simplest Notes** containing **Notes.txt** (`text/plain`).
- Visible to the user in Drive; survives app deletion.
- Conflict copies (rare): `Notes (conflict 2026-10-16 14-03 iPad).txt` in the same folder.

---

## 7. Out of scope

Multiple notes, search, formatting, sharing, Android/Windows/web, any server of our own.

---

## 8. Related documents

- [ADR index](adr/README.md)
- [Phased development plan](DEVELOPMENT_PLAN.md) (tests before implementation in every phase)
- [Design review PDF](simplest-notes-design-review.pdf)
