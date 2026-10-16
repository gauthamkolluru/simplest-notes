# ADR-0003: Serverless Google auth with GoogleSignIn SDK

**Status:** Proposed  
**Date:** 2026-10-16

## Context

R6 forbids a backend. Drive access needs OAuth 2.0.

## Decision

- Use Google's official **GoogleSignIn-iOS SDK** (supports iOS and macOS). It implements the OAuth 2.0 installed-app flow with PKCE; no client secret, no server.
- Tokens (including refresh token) are stored in Keychain by the SDK; `restorePreviousSignIn()` on launch.
- Scopes: `https://www.googleapis.com/auth/drive.file` + `email` (to display the account, R11).
- Auth sits behind an `AuthProviding` protocol in NotesCore; the app implements it with the SDK; tests use a fake.

## Consequences

- **User action needed:** create a Google Cloud project, enable the Drive API, create an iOS OAuth client ID, configure the consent screen (External, Testing, add yourself as test user). `drive.file` is a non-sensitive scope, so no Google verification is required for personal use.
- In "Testing" publishing status, refresh tokens expire after 7 days → re-sign-in weekly. Moving to "In production" (no verification needed for non-sensitive scopes) removes that.
