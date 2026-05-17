# Contributing to Sweep

Sweep is a small, opinionated macOS app. Before contributing, read the architecture plan to understand the confidence-tier model, trust phase, and service layer.

## Setup

```bash
git clone https://github.com/amadoug2g/sweep.git
cd sweep
make dev
```

Requires Swift 5.9+ (Xcode 15+), macOS 13+.

## Branch strategy

- `main` — always stable, CI must pass
- `claude/*` — AI-assisted development branches
- Feature branches — `feat/<short-name>`, merged via PR

No direct pushes to `main`. All changes go through pull requests.

## Development patterns

- All services defined by a protocol (`DownloadsScanning`, `ClaudeClienting`, etc.) so they can be mocked in tests
- Composition root lives in `AppContainer.swift` — inject dependencies there, not inside views
- Use `os.Logger` for logging (`subsystem: "com.sweep.app"`)
- No third-party dependencies without a strong reason

## File system safety rules — non-negotiable

- **Never propose `delete`** — only `move`, `archive`, `reviewLater`, or `keep`
- **Write the undo record before the file move** — never after; if the move fails, the record is harmless
- **Never touch files less than 60 seconds old** — they may still be downloading
- **Only operate within the user's `folderMap` destinations plus `~/Documents/Sweep/`**
- **Nothing runs without an explicit trigger** — no background daemons, no Launch Agents in V1

## Commit style

```
<type>(<scope>): <short description>

Types: feat, fix, ci, docs, test, refactor, chore

Examples:
  feat(executor): write undo record before move
  fix(scanner): skip .crdownload and .part files
  ci: pin Xcode selection to latest installed version
  docs: update README install instructions
```

## Reporting issues

Use the issue templates — [bug report](.github/ISSUE_TEMPLATE/bug_report.yml) or [feature request](.github/ISSUE_TEMPLATE/feature_request.yml).
