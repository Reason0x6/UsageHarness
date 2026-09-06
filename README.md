# Usage Harness

A small native macOS utility that hugs one edge of one display and shows local usage information for installed AI coding harnesses.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## What it does

- Lives in the menu bar and presents a compact, always-available edge shelf.
- Supports the left, right, top, or bottom edge of any connected display. Exactly one display/edge placement is active at a time.
- Detects Codex, Claude Code, GitHub Copilot, Gemini CLI, OpenCode, and Aider from executables and their standard local data directories.
- Reads Codex window limits from recent local session events when the CLI records them.
- Estimates Claude's current context use from its recent local JSONL session. This is labeled as an estimate—not an account quota.
- Reports Copilot installation status. Copilot's CLI does not currently expose a dependable local quota percentage, so the app does not fabricate one.
- Keeps processing local. It does not read credential files or make network requests.

## Build and run

Requirements: macOS 13 or newer, Xcode 15 or newer, and the Xcode command-line tools.

```sh
make test
make run
```

`make app` creates `.build/UsageHarness.app` and applies an ad-hoc signature. You can also open `Package.swift` directly in Xcode and run the `UsageHarness` executable scheme.

For reliable launch-at-login registration, move the built app to `/Applications` and launch it from there once before enabling the setting.

## Using the app

1. Launch Usage Harness. It appears in the menu bar and places the shelf on the right edge of the primary display.
2. Hover over or click a usage ring to view its detailed counters.
3. Open **Settings…** from the menu-bar item to choose the display and edge, change the refresh interval, or enable launch at login.
4. Choose **Refresh Usage** after starting a new harness session if you do not want to wait for the next automatic refresh.

## Data sources

| Harness | Detection | Usage source |
| --- | --- | --- |
| Codex | `codex` executable or `~/.codex` | Latest `~/.codex/sessions/**/*.jsonl` rate-limit event; context fallback |
| Claude Code | `claude` executable or `~/.claude` | Latest `~/.claude/projects/**/*.jsonl` message usage |
| GitHub Copilot | Copilot CLI, editor extension, or local config | Installation status only |
| Gemini CLI | `gemini` executable or `~/.gemini` | Installation status only |
| OpenCode | `opencode` executable or local config/data | Installation status only |
| Aider | `aider` executable or `~/.aider` | Installation status only |

The parsers intentionally tolerate missing and additional JSON fields so CLI upgrades fail soft. No secrets, prompts, or response content are retained by the app.

## Project layout

- `EdgePanelController.swift` owns the non-activating AppKit panel and display positioning.
- `EdgePanelView.swift` contains the native SwiftUI shelf, rings, and detail popovers.
- `UsageScanner.swift` discovers harnesses and parses local counters.
- `SettingsView.swift` contains placement, provider, privacy, refresh, and login settings.
- `UsageParsingTests.swift` covers representative Codex and Claude records.
