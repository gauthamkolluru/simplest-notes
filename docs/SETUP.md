# Setup

## Prerequisites

- macOS with **Xcode 15+** (for the app and UI tests)
- Optional on Linux/macOS: **Swift 5.9+** toolchain for NotesCore unit tests only
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Clone & generate

```bash
git clone https://github.com/gauthamkolluru/simplest-notes.git
cd simplest-notes
swift test                          # NotesCore (T0.01+)
xcodegen generate
open SimplestNotes.xcodeproj
```

Public repo: https://github.com/gauthamkolluru/simplest-notes

## Run in Xcode (if “nothing happens”)

1. Pull latest, regenerate, reopen:
   ```bash
   git pull
   xcodegen generate
   open SimplestNotes.xcodeproj
   ```
2. Top toolbar: scheme **SimplestNotes**, destination an **iPhone simulator** (not “Any iOS Device”).
3. **Signing & Capabilities**: enable **Automatically manage signing**, pick your **Team** (Personal Team / Apple ID is fine).
4. Press ▶ (`Cmd+R`). Watch the top status bar — if it flashes red, open the **Issue navigator** (⚠ icon) for the error.
5. When it works you should see:
   - grey placeholder **Start typing…**
   - a Drive cloud icon top-right
   - on first launch, a **Connect Google Drive** sheet

If the Simulator app opens but stays on the home screen, look for the **Simplest Notes** icon and tap it.

## Google Cloud (Phase 4 — real sign-in)

You must create an OAuth client in Google Cloud and paste the **client ID** into this repo’s config. **Do not commit real client secrets** (there is no client secret for iOS public clients; still keep your client ID out of git if you prefer — `Config/Secrets.xcconfig` is gitignored).

### 1. Create the Cloud project & enable Drive

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project (or pick an existing one).
3. **APIs & Services → Library** → enable **Google Drive API**.

### 2. OAuth consent screen

1. **APIs & Services → OAuth consent screen**.
2. User type: **External** → Publishing status **Testing**.
3. App name: e.g. `Simplest Notes`.
4. Add yourself under **Test users**.
5. Scopes used by the app (requested at runtime by the Google Sign-In SDK):
   - `email` / profile (default)
   - `https://www.googleapis.com/auth/drive.file` (non-sensitive — no Google verification for personal use)

While the consent screen is in **Testing**, refresh tokens expire after **7 days**. Publishing to **Production** (still no verification needed for this scope) removes that limit.

### 3. Create an iOS OAuth client ID

1. **APIs & Services → Credentials → Create credentials → OAuth client ID**.
2. Application type: **iOS**.
3. Name: e.g. `Simplest Notes iOS`.
4. Bundle ID: **`app.simplestnotes.SimplestNotes`** (must match the Xcode target).
5. Create. Copy the **Client ID** — it looks like:
   ```
   1234567890-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com
   ```
6. (Optional, Mac builds) Create a second OAuth client of type **macOS** / **Desktop** if Google prompts for a Mac client; for GoogleSignIn-iOS the same **iOS** client ID + URL scheme usually works for Mac Catalyst-style flows when the bundle ID matches. If Mac sign-in fails with a client-type error, add a macOS client and use that client ID in `Secrets.xcconfig` for Mac-only builds, or keep one iOS client and verify the bundle ID.

### 4. Paste your OAuth client ID (required before real sign-in works)

**Where to paste**

| What | Where |
|------|--------|
| iOS OAuth **Client ID** | `Config/Secrets.xcconfig` → `GOOGLE_CLIENT_ID` |
| **Reversed** client ID | `Config/Secrets.xcconfig` → `GOOGLE_REVERSED_CLIENT_ID` |

Steps:

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Edit `Config/Secrets.xcconfig`:

```xcconfig
// Example — replace with YOUR values from Google Cloud → Credentials → iOS client
GOOGLE_CLIENT_ID = 1234567890-abcdefghijk.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234567890-abcdefghijk
```

**How to form the reversed client ID**

Take the Client ID, strip `.apps.googleusercontent.com`, and prefix `com.googleusercontent.apps.`:

| Client ID | Reversed (`CFBundleURLSchemes`) |
|-----------|----------------------------------|
| `123-abc.apps.googleusercontent.com` | `com.googleusercontent.apps.123-abc` |

Then regenerate and open Xcode:

```bash
xcodegen generate
open SimplestNotes.xcodeproj
```

`Config/Shared.xcconfig` includes `Secrets.xcconfig` when present. The Xcode target maps:

- `GOOGLE_CLIENT_ID` → Info.plist key **`GIDClientID`** (read by Google Sign-In SDK)
- `GOOGLE_REVERSED_CLIENT_ID` → **URL scheme** under `CFBundleURLTypes` (OAuth redirect back into the app)

`Config/Secrets.xcconfig` is **gitignored**. The example file and placeholder defaults in `Shared.xcconfig` stay in the repo.

### 5. Smoke-test sign-in

1. Run on a simulator or device (scheme **SimplestNotes**).
2. Tap **Connect Google Drive** (onboarding or dull Drive icon).
3. Complete the Google account picker and allow Drive.
4. Confirm the Drive icon becomes active and a `Simplest Notes/Notes.txt` file appears in your Drive.

UI tests keep using **FakeAuth** (`-ui-testing` launch argument) and never need a real client ID.

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| Sign-in returns immediately / “unknown” failure | Client ID still the `PASTE_IOS_CLIENT_ID` placeholder — paste a real ID into `Secrets.xcconfig`, regenerate. |
| Redirect / “browser” error after consent | Reversed client ID URL scheme mismatch — check `GOOGLE_REVERSED_CLIENT_ID`. |
| “Access blocked” / app not verified | Add your Google account as a **Test user** on the consent screen. |
| Drive scope declined message | Re-connect and leave Drive access enabled on the consent sheet. |
