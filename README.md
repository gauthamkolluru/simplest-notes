# Simplest Notes

A minimal plain-text notes app: open → type. No formatting, no file names, no save button. Text autosaves on-device and syncs to your Google Drive. No backend of our own.

**Platform:** iPhone, iPad, and Mac (native SwiftUI)  
**License:** [MIT](LICENSE)

## Status

| Phase | Status |
|-------|--------|
| Design + ADRs + plan | Done |
| **Phase 0** — repo scaffolding & CI | In progress |
| Phase 1–7 | Not started |

## Docs

| Doc | Purpose |
|-----|---------|
| [docs/DESIGN.md](docs/DESIGN.md) | Requirements, architecture, flows |
| [docs/adr/](docs/adr/README.md) | Architecture Decision Records |
| [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | Phased plan (tests before implementation) |
| [docs/SETUP.md](docs/SETUP.md) | Local build & Google Cloud setup |

## Layout

```
Package.swift                 NotesCore (pure Swift, Linux-testable)
Sources/NotesCore/            Domain logic
Tests/NotesCoreTests/         Unit tests (T0.01+)
App/SimplestNotes/            SwiftUI app shell
App/SimplestNotesUITests/     XCUITests (T0.02+)
project.yml                   XcodeGen project definition
.github/workflows/ci.yml      Linux + macOS CI
docs/                         Design, ADRs, plan
```

## Develop

### NotesCore (Linux or macOS)

```bash
swift test
```

### Full app (macOS with Xcode 15+)

```bash
brew install xcodegen   # once
xcodegen generate
open SimplestNotes.xcodeproj
```

Or from the CLI:

```bash
xcodegen generate
xcodebuild -project SimplestNotes.xcodeproj -scheme SimplestNotes \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

## Development process

Each phase: edge-case tests → failing tests → implement → green → commit. See [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md).
