# Usage Harness

A small native macOS utility that hugs one edge of one display and shows Claude usage at a glance.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## What it does

- Lives in the menu bar and presents a compact, always-available edge shelf.
- Supports the left, right, top, or bottom edge of any connected display. Exactly one display/edge placement is active at a time.
- Shows Claude's five-hour usage window, weekly usage window, and most recent Claude Code session token total.
- Reads the account counters from Anthropic's authenticated usage endpoint—the same data presented by Claude Code's `/usage` command.
- Deduplicates streamed Claude messages when totaling the most recent local JSONL session.
- Displays reset times for the five-hour and weekly windows.
- Shows `Unavailable` instead of estimating an account percentage when Claude credentials or the usage service cannot be reached.

## Build and run

Requirements: macOS 13 or newer, Xcode 15 or newer, and the Xcode command-line tools.

```sh
make test
make run
```

`make app` compiles the sources directly with the active Apple command-line toolchain, creates `.build/UsageHarness.app`, and applies an ad-hoc signature. It intentionally does not rely on SwiftPM for the app bundle, so it also works around mismatched `PackageDescription` installations. You can alternatively open `Package.swift` directly in Xcode and run the `UsageHarness` executable scheme.

For reliable launch-at-login registration, move the built app to `/Applications` and launch it from there once before enabling the setting.

## Using the app

1. Launch Usage Harness. It appears in the menu bar and places the shelf on the right edge of the primary display.
2. Hover over or click the Claude usage ring to view the five-hour, weekly, and session counters.
3. Open **Settings…** from the menu-bar item to choose the display and edge, change the refresh interval, or enable launch at login.
4. Choose **Refresh Usage** after starting a new harness session if you do not want to wait for the next automatic refresh.

## Data and privacy

| Counter | Source |
| --- | --- |
| Five-hour window | Anthropic usage endpoint, with Claude Code's `~/.claude.json` cache as fallback |
| Weekly window | Anthropic usage endpoint, with Claude Code's `~/.claude.json` cache as fallback |
| Session usage | Latest `~/.claude/projects/**/*.jsonl` transcript |

The app retrieves Claude Code's OAuth access token from `~/.claude/.credentials.json` or the macOS Keychain item named `Claude Code-credentials`. The token is held only in memory and sent only to Anthropic's HTTPS usage endpoint. macOS may ask you to allow Keychain access on first launch. Local session prompts and responses are never transmitted or retained by Usage Harness.

## Project layout

- `EdgePanelController.swift` owns the non-activating AppKit panel and display positioning.
- `EdgePanelView.swift` contains the native SwiftUI shelf, rings, and detail popovers.
- `UsageScanner.swift` fetches Claude account windows and parses local session counters.
- `SettingsView.swift` contains placement, provider, privacy, refresh, and login settings.
- `UsageParsingTests.swift` covers Claude account, credential, and session records.
