# ADR-0005: Sync and conflict policy — never discard text

**Status:** Proposed  
**Date:** 2026-10-16

## Context

Same account may be used on several devices, and edits happen offline. N1: never lose text.

## Decision

State kept per device: `lastSyncedRemoteVersion` (Drive file `version`), `lastSyncedHash` (SHA-256 of last synced text), `dirty`.

### Push

Debounced 2 s after local save, and on background:

1. Fetch remote metadata.
2. If `remote version == lastSyncedRemoteVersion` → upload; record new version/hash; `dirty=false`.
3. If remote changed → Reconcile.

### Pull

On launch, foreground, after connect: fetch metadata → if version unchanged, nothing. Else Reconcile.

### Reconcile

Pure `ConflictResolver.decide(local, remote, base)`:

| Local changed since base | Remote changed since base | Action |
|--------------------------|---------------------------|--------|
| no | no | nothing |
| no | yes | take remote into editor |
| yes | no | upload local |
| yes | yes, texts identical | mark synced |
| yes | yes, texts differ | keep remote as `Notes.txt` in editor; upload local as a conflict copy file; show a one-line dismissible banner |

### First connect / switch account (no base)

| Local | Remote | Action |
|-------|--------|--------|
| any | missing | create remote from local |
| empty | exists | take remote |
| non-empty, identical | exists | mark synced |
| non-empty, differs | exists | take remote; save local as conflict copy |

### Network errors

Keep `dirty=true`, retry with exponential backoff (2 s → 5 min cap) and on next foreground.  
401 → one silent token refresh, then show icon dull-with-warning and keep editing locally.

## Consequences

- No 3-way text merge (kept simple); worst case the user sees a second file in Drive.
- Small race between metadata check and upload (Drive v3 has no reliable If-Match on upload); a later pull detects it via version mismatch and applies the table.
