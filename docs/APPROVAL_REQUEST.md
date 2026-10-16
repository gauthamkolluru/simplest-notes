# Approval request — Simplest Notes

**Please reply in chat to approve (or amend) before any code is written.**

This repository currently contains **design documentation only**. No application code, packages, or CI have been scaffolded yet, per your instruction to design → ADR → plan → seek permission.

## What is ready for your review

1. **[DESIGN.md](DESIGN.md)** — requirements (R1–R12, N1–N4), assumptions A1–A3, architecture, flows, on-device and Drive data layout, out of scope.
2. **[ADR-0001 … ADR-0007](adr/README.md)** — platform, single-note local-first, serverless Google auth, Drive location/scope, sync/conflict policy, disconnect/switch-account, testing strategy.
3. **[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)** — Phases 0–7; each phase lists edge-case test IDs **before** implementation steps.

## Decisions that need your explicit OK

| # | Decision | Proposed default |
|---|----------|------------------|
| 1 | Approve the design + ADRs + phased plan? | Yes / with listed changes |
| 2 | **A1** — exactly one note (no multi-note UI)? | Confirm |
| 3 | **A2** — native SwiftUI for iPhone, iPad, Mac (not PWA/web)? | Confirm |
| 4 | GitHub.com repo **name** and **visibility** (public/private)? | e.g. `simplest-notes`, private |
| 5 | License | MIT |
| 6 | Phase 4 prerequisite: you will create the Google Cloud OAuth client when we reach that phase? | Yes |

## GitHub repository

This cloud session does **not** have a logged-in GitHub CLI (`gh auth status` → not logged in), so a GitHub.com repository could not be created from the agent automatically.

**Ways to proceed after you approve:**

- Use Cursor’s **Create repo** control to attach a GitHub repository to this project, **or**
- Tell me the exact repo name/visibility and provide GitHub access for the agent (e.g. authenticated `gh`), then I will create/push.

Until then, design docs are committed on the current project branch.

## What I will do after you say “approved”

1. Create/link the GitHub repo (once auth or Create-repo is available).  
2. Start **Phase 0**: scaffolding + CI wiring tests (T0.01–T0.02) **before** any product logic.  
3. Proceed phase-by-phase with tests-first as documented.  
4. Pause before Phase 4 until Google Cloud OAuth credentials are ready.

---

**Reply with something like:**  
`Approved as written` — or list changes (e.g. “use web/PWA instead”, “public repo named …”, “skip macOS”).
