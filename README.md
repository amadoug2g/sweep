# Sweep

> A Claude-powered file assistant for macOS. Lives in your menu bar. Knows your system. Never asks you to explain it twice.

---

Sweep organizes your Downloads folder using Claude's intelligence and a persistent local "brain" — a JSON config that captures your folder logic, rules, and preferences, and loads it silently on every run.

Unlike other tools, Sweep never re-asks what you already told it. It proposes or executes actions based on what it already knows, and gets smarter with every correction you make.

## Features

- **Menu bar presence** — always one click away, never in your way
- **Claude-powered** — understands context, not just filenames
- **Persistent memory** — your folder rules stored locally, loaded automatically on every run
- **Confidence tiers** — high-confidence files act automatically; uncertain files go to a batch Review queue
- **Undo everything** — every action logged and reversible; undo is the safety net, not approval gates
- **Trust-earning model** — Sweep proposes for the first 7 days, then earns the right to auto-act
- **Token-efficient** — context cached between calls; Claude only processes what's new
- **Zero telemetry** — your files, your rules, your machine

## How it works

1. **Onboard once** — paste your API key, grant folder access, review starter rules
2. **Sweep runs** — manually triggered or on interval, scans ~/Downloads
3. **Claude proposes** — each file gets an action and a confidence tier (high / medium / low)
4. **High confidence auto-acts** — file moves immediately, you get a notification with an undo link
5. **Medium confidence stages** — file goes to `~/Documents/Sweep/Review/` for weekly batch review
6. **Low confidence skips** — left untouched until the next run

## Requirements

- macOS 13 Ventura or later
- Claude API key (get one at [console.anthropic.com](https://console.anthropic.com))

## Installation

Download the latest `.dmg` from [Releases](../../releases), open it, and drag Sweep to your Applications folder.

## Building from source

```bash
git clone https://github.com/amadoug2g/sweep.git
cd sweep
make dev      # run in development mode
make build    # build release binary
make test     # run tests
```

Requires Swift 5.9+ (Xcode 15 or later).

## Configuration

Sweep's "brain" lives at:

```
~/Library/Application Support/Sweep/context.json
```

You can edit it directly or use **Settings → Edit context.json**. It contains your folder map, rules, and preferences. Changes take effect on the next scan.

## Privacy

- All context stored locally — no cloud sync, no telemetry, no analytics
- Claude API calls include only file metadata (names, sizes, dates) — never file contents
- API key stored in macOS Keychain

## Roadmap

See [Issues](../../issues) and [Milestones](../../milestones) for what's planned.

V1 scope: Downloads folder, manual trigger, confidence-tier model, trust phase, Review panel, undo log.

Post-V1: scheduled runs, multi-folder support, learning from corrections, Google Drive destinations.

## License

MIT
