# Simplest Notes — Phased Development Plan

**Status:** Awaiting approval — **do not implement until explicitly approved**  
**Date:** 2026-10-16

Every phase follows the same order:

1. **Test plan** with edge cases documented  
2. **Write tests**, confirm they fail  
3. **Implement** the use case / function / functionality  
4. **Green** + CI + commit  

Test IDs are referenced in test names (e.g. `test_T1_03_saveIsAtomicWhenWriteInterrupted`).

Related: [DESIGN.md](DESIGN.md) · [ADR index](adr/README.md)

---

## Phase 0 — Repository & scaffolding

### Tests first

| ID | Case |
|----|------|
| T0.01 | `swift test` runs a trivial test on Linux and macOS (CI wiring proof). |
| T0.02 | iOS, iPadOS, and macOS app targets build and launch to a blank screen in UI test. |

### Then implement

GitHub repo, NotesCore Swift package, XcodeGen `project.yml` (iOS 17 / macOS 14), GitHub Actions workflow, README, LICENSE, docs.

### Exit

CI green on all jobs.

---

## Phase 1 — Local persistence & autosave (R3, N1, N2)

### 1A LocalNoteStore — edge-case tests first

| ID | Case |
|----|------|
| T1.01 | Load when no file exists → `""` (first launch). |
| T1.02 | Save then load round-trips exactly (incl. trailing newline, `\r\n`, tabs). |
| T1.03 | Unicode: emoji, combining marks, RTL, CJK, zero-width joiners round-trip byte-exact. |
| T1.04 | Empty string saves and loads as `""` (select-all + delete, R4). |
| T1.05 | Whitespace-only text is preserved, not trimmed. |
| T1.06 | Large text (5 MB) round-trips. |
| T1.07 | Atomicity: simulated failure mid-write leaves the previous content intact. |
| T1.08 | Directory missing → created on first save. |
| T1.09 | Corrupt/non-UTF-8 file on disk → load returns lossy-decoded text and backs the raw file up as `note.corrupt-<ts>.bin` (never silently drops data). |
| T1.10 | Read-only / disk-full error surfaces as a typed error, original file untouched. |
| T1.11 | Sync-state JSON: missing → defaults; corrupt → defaults + `dirty=true` (forces a safe reconcile); round-trips all fields. |

### 1B Debouncer (injected clock) — tests first

| ID | Case |
|----|------|
| T1.12 | Single call fires once after the delay. |
| T1.13 | Burst of calls fires once, with the last value. |
| T1.14 | Calls spaced beyond the delay each fire. |
| T1.15 | `flush()` fires the pending value immediately and cancels the timer. |
| T1.16 | `flush()` with nothing pending does nothing. |
| T1.17 | `cancel()` drops pending value. |
| T1.18 | Delay of zero fires synchronously-next-tick. |
| T1.19 | Deallocation with pending work does not crash or fire afterwards. |

### 1C AutosaveController — tests first

| ID | Case |
|----|------|
| T1.20 | Typing triggers exactly one save per debounce window. |
| T1.21 | Text identical to last saved → no write. |
| T1.22 | Background/quit event flushes pending text immediately. |
| T1.23 | Save failure retries on next change and reports `saveError` state; recovers when write succeeds. |
| T1.24 | Every successful save marks sync state `dirty=true` and emits a "local changed" event. |

### Then implement

`LocalNoteStore`, `Debouncer`, `AutosaveController` in NotesCore.

---

## Phase 2 — Editor UI & first launch (R1, R2, R7, R8)

### 2A OnboardingPolicy — tests first

| ID | Case |
|----|------|
| T2.01 | Fresh install → show onboarding. |
| T2.02 | After "Connect" success → never show again. |
| T2.03 | After "Not now" → never show again (icon remains the path to connect). |
| T2.04 | After Connect cancelled/failed → onboarding marked done, app is in not-connected state. |
| T2.05 | Reinstall (UserDefaults wiped) but Keychain still has a Google session → skip onboarding, restore session silently. |

### 2B UI tests (XCUITest, fake auth) — tests first

| ID | Case |
|----|------|
| T2.06 | Launch (not first) → editor visible and focused; on iOS/iPadOS the software keyboard is shown without any tap. |
| T2.07 | First launch → onboarding text explains the benefit (backup, survives app deletion, other devices) with Connect / Not now. |
| T2.08 | After onboarding dismissal → editor focused, keyboard up. |
| T2.09 | Editor renders no formatting toolbar, no title, no file name, no save button. |
| T2.10 | Pasting rich text (bold/links) inserts plain characters only. |
| T2.11 | Cmd/Ctrl+A then Delete empties the note and the empty note persists after relaunch. |
| T2.12 | Type → kill app → relaunch → text present. |
| T2.13 | iPad external keyboard and Mac: typing works immediately, shortcuts work. |
| T2.14 | Rotation / Split View / Stage Manager resize keeps text and cursor. |
| T2.15 | Dynamic Type & dark mode render legibly; VoiceOver reads the editor and the Drive button label. |
| T2.16 | Typing at the end of a long note keeps the cursor visible above the keyboard. |

### Then implement

`EditorView`, `OnboardingView`, `AppViewModel`, `scenePhase` flush wiring.

---

## Phase 3 — Connection state, Drive icon, account sheet (R9–R11) with fake auth

### 3A ConnectionState → icon mapping — tests first

| ID | Case |
|----|------|
| T3.01 | `.notConnected` → dull icon, label "Connect Google Drive". |
| T3.02 | `.connecting` → dull icon + spinner, taps ignored (no double sign-in). |
| T3.03 | `.connected(email)` → active icon, label includes email. |
| T3.04 | `.connected` + sync error/offline → active icon with small warning badge. |
| T3.05 | `.authExpired` → dull icon with warning; tap re-auths. |

### 3B Interaction state machine — tests first

| ID | Case |
|----|------|
| T3.06 | Tap when not connected → starts sign-in. |
| T3.07 | Sign-in cancelled → back to `.notConnected`, no error shown. |
| T3.08 | Sign-in fails (network) → `.notConnected` + inline message. |
| T3.09 | Tap when connected → account sheet shows email, Disconnect, Switch account. |
| T3.10 | Email missing from profile → sheet shows "Google account". |
| T3.11 | Very long email truncates in the middle, full text in accessibility label. |
| T3.12 | Disconnect → `.notConnected`, sheet closes, local text unchanged. |
| T3.13 | Switch account → disconnect then sign-in; cancel leaves `.notConnected` (not the old account). |
| T3.14 | Rapid repeated taps on Disconnect/Switch don't run the action twice. |

### Then implement

`ConnectionState`, `ConnectionController`, `DriveStatusButton`, `AccountSheet`, `AuthProviding` protocol, `FakeAuth`.

---

## Phase 4 — Real Google sign-in (ADR-0003)

**Prerequisite (you):** Google Cloud project, Drive API enabled, iOS OAuth client ID, consent screen with you as test user. Exact steps will be written in `docs/SETUP.md` during this phase.

### Tests first

| ID | Case |
|----|------|
| T4.01 | `GoogleAuthService` maps SDK results → `AuthProviding` results (success, cancel, network error, scope declined) — via a thin SDK adapter protocol so mapping is unit-tested. |
| T4.02 | Scope declined (user unticks Drive) → treated as failure, message asks to allow Drive. |
| T4.03 | `restorePreviousSignIn` success at launch → `.connected` without UI. |
| T4.04 | Restore fails (revoked externally) → `.notConnected` silently. |
| T4.05 | Access token refresh failure → `.authExpired`. |
| T4.06 | Disconnect calls SDK `disconnect` (revoke) and `signOut`; revoke failure still signs out locally. |

### Manual smoke

Real sign-in on iPhone, iPad, Mac.

### Then implement

GoogleSignIn SPM dependency, URL scheme, `GoogleAuthService`.

---

## Phase 5 — Drive client (ADR-0004), mocked HTTP

### Edge-case tests first (`FakeHTTPTransport`)

| ID | Case |
|----|------|
| T5.01 | Find folder: exists → id; missing → nil; multiple → oldest. |
| T5.02 | Create folder then file with correct metadata/MIME (`text/plain`, parent). |
| T5.03 | Find file: none / one / multiple (most recently modified chosen) / trashed ignored. |
| T5.04 | Download returns exact bytes as UTF-8 (incl. empty file, BOM stripped, non-UTF-8 → lossy + flag). |
| T5.05 | Upload (multipart / media) sends exact body and returns new `version`. |
| T5.06 | Metadata fetch returns `version`, `modifiedTime`, `trashed`. |
| T5.07 | Cached file id returns 404 or `trashed=true` → caller gets `.fileGone`. |
| T5.08 | 401 → `.unauthorized`; 403 rate-limit / `userRateLimitExceeded` → `.rateLimited(retryAfter)`; 403 storage quota → `.quotaExceeded`; 5xx → `.transient`; timeouts/offline → `.offline`. |
| T5.09 | Query strings are escaped (names with quotes/backslashes). |
| T5.10 | Auth header uses a fresh token each request. |

### Then implement

`DriveClient`, `HTTPTransport`, `URLSessionTransport`.

---

## Phase 6 — Sync engine & conflicts (ADR-0005, ADR-0006)

### 6A ConflictResolver (pure; table-driven) — tests first

| ID | Case |
|----|------|
| T6.01–T6.05 | Steady-state table rows (5 cases from ADR-0005). |
| T6.06–T6.09 | First-connect table rows (4 cases from ADR-0005). |
| T6.10 | Texts differing only by line endings are treated as different (no normalisation) — documented choice. |
| T6.11 | Conflict copy name includes timestamp + device name, is unique when called twice in the same minute, and sanitises characters Drive dislikes. |

### 6B SyncEngine (fake Drive + fake clock) — tests first

| ID | Case |
|----|------|
| T6.12 | Local edit → push after 2 s debounce; burst of edits → one upload. |
| T6.13 | Background event → immediate push. |
| T6.14 | Offline → stays `dirty`; backoff 2 s, 4 s, … capped at 5 min; reconnect triggers push. |
| T6.15 | Pull on launch/foreground with unchanged version → no download. |
| T6.16 | Remote changed, local clean → editor text replaced; cursor position clamped to new length. |
| T6.17 | Remote changed while user is mid-typing (`dirty`) → conflict path, no keystrokes lost. |
| T6.18 | File deleted/trashed in Drive → recreated from local text, new id cached. |
| T6.19 | 401 → one refresh + retry; second 401 → `.authExpired`, edits continue locally. |
| T6.20 | Quota exceeded → warning badge, local saving unaffected. |
| T6.21 | Disconnect during in-flight upload → upload cancelled or completed, never writes to the new account after switch. |
| T6.22 | Switch account → first-connect table against new account; old account's file untouched. |
| T6.23 | Push and pull never run concurrently (serialised). |
| T6.24 | App killed between local save and push → next launch sees `dirty=true` and pushes. |
| T6.25 | Upload succeeded but response lost → next metadata check sees our own content hash and marks synced (no false conflict). |

### Then implement

`ConflictResolver`, `SyncEngine`, wiring into `AppViewModel`, conflict banner.

---

## Phase 7 — Hardening & release

### Tests first

| ID | Case |
|----|------|
| T7.01 | 5 MB note: typing latency acceptable; save under 100 ms (performance test). |
| T7.02 | Full offline day simulation then reconnect (fake clock) → single correct push. |
| T7.03 | Two-device simulation (two engines, one fake Drive) across interleavings → no text lost in any interleaving. |
| T7.04 | Accessibility audit (`XCUITest` `performAccessibilityAudit`). |

### Then implement / ship

Manual smoke checklist on real devices; README usage + install guide; tag `v1.0.0`.

---

## Approval checklist

Before any implementation begins, please confirm:

1. **Approve this plan** (or list changes).
2. Confirm assumptions **A1** (one note) and **A2** (native iOS/iPad/Mac SwiftUI).
3. **GitHub repo name & visibility** (this workspace currently has no authenticated `gh` session for creating a GitHub.com repo from the agent).
4. Before Phase 4: Google Cloud OAuth client ID (setup steps provided in that phase).
5. To run the app on devices: a Mac with Xcode. CI runs automated tests on GitHub's macOS runners.
