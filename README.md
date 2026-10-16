# Simplest Notes

A minimal plain-text notes app: open → type. No formatting, no file names, no save button. Text autosaves on-device and syncs to your Google Drive. No backend of our own.

**Current status: design & plan only — awaiting approval before implementation.**

## Documents (read these first)

| Doc | Purpose |
|-----|---------|
| [docs/DESIGN.md](docs/DESIGN.md) | Requirements, architecture, flows, data model |
| [docs/adr/](docs/adr/README.md) | Architecture Decision Records (ADR-0001 … 0007) |
| [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | Phased plan: **tests first**, then implementation, every phase |
| [docs/simplest-notes-design-review.pdf](docs/simplest-notes-design-review.pdf) | Full design review PDF |
| [docs/assets/requirements-sketch.jpg](docs/assets/requirements-sketch.jpg) | Original requirements sketch |

## Proposed stack (ADR-0001)

- Native **SwiftUI** app for **iPhone, iPad, and Mac**
- Pure **NotesCore** Swift package (unit-tested on Linux + macOS)
- Google Drive via **GoogleSignIn** SDK + Drive API (`drive.file` scope)
- Offline-first local file + sync engine that never silently discards text

## How development will proceed (after approval)

Each phase in [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md):

1. Document edge cases and write failing tests  
2. Implement the functionality  
3. Turn tests green, run CI, commit  

## Local run (after Phase 0+)

Will require Xcode 15+ on macOS. Details land in the README when scaffolding is approved and implemented.

## License

TBD on approval (recommend MIT unless you prefer otherwise).
