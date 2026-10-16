# ADR-0006: Disconnect and switch-account semantics

**Status:** Proposed  
**Date:** 2026-10-16

## Decision

### Disconnect

1. Flush pending push (best effort, 5 s cap).
2. Revoke token, sign out.
3. Clear `driveFileId` / sync base.
4. Keep `note.txt` on device.
5. Icon becomes dull. Drive file is left untouched.

### Switch account

1. Disconnect (as above).
2. Start sign-in.
3. If the user cancels the sign-in sheet → remain disconnected (not reconnected to the old account).
4. On success → run first-connect reconciliation ([ADR-0005](0005-sync-and-conflict-policy.md)) against the new account.

### Reconnect after disconnect

Same as first connect.

### Account sheet

- Shows the email from the signed-in user; if unavailable, shows "Google account".
- Sign-in cancelled or failed during onboarding / icon tap → stay disconnected; no error dialog for cancel; short inline message for real failures.
