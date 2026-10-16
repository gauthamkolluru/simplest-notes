# ADR-0004: Drive location and least-privilege scope

**Status:** Proposed  
**Date:** 2026-10-16

## Context

R5 says the file lives in the user's Drive; R12 says it must survive app deletion; N3 asks for least privilege.

## Options

- **`appDataFolder`:** hidden from the user — fails "the file resides on GDrive" in a useful sense.
- **Full `drive` scope:** restricted scope, needs Google security assessment — overkill.
- **`drive.file` + visible file:** app sees only files it created.

## Decision

- Visible folder **Simplest Notes** in My Drive containing **Notes.txt** (`text/plain`), created by the app under `drive.file`.
- `driveFileId` is cached in `sync-state.json`.
- On (re)connect or if the cached id 404s / is trashed: search `name='Notes.txt' and '<folderId>' in parents and trashed=false` (only app-created files are visible). If several exist, pick the most recently modified and log the others.
- If none exist: create folder (if missing) then file.

## Consequences

- After reinstall, the app finds its old file again because it is the same OAuth client.
- If the user renames/moves the file in Drive, the cached id still works; if they delete it, the app recreates it from local text.
- If the user hand-creates a `Notes.txt` in Drive, the app cannot see it (by design).
