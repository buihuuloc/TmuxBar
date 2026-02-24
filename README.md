# TmuxBar

A native macOS menu bar app for managing tmux sessions. Built with Swift and AppKit for Apple Silicon.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon-green)

## Features

- **Session count badge** — SF Symbol terminal icon with live session count in the menu bar
- **Colored status indicators** — green dot for attached sessions, gray for detached
- **Attach sessions** — click to open Terminal.app with the session attached
- **Create sessions** — new unnamed or named sessions from the menu
- **Rename sessions** — inline rename with input validation
- **Kill sessions** — with confirmation dialog
- **Window count** — shows number of windows per session
- **Quick-attach shortcuts** — Cmd+1 through Cmd+9 for the first 9 sessions
- **Auto-refresh** — polls tmux every 5 seconds, skips rebuild when unchanged
- **Launch at Login** — toggle via SMAppService
- **No dock icon** — runs as a menu bar-only agent app
- **Async refresh** — shell execution runs off the main thread
- **Accessibility** — VoiceOver labels on all session items

## Screenshot

```
┌─────────────────────────────┐
│  ⬚ 5                        │  ← Menu bar icon + count
├─────────────────────────────┤
│  TMUX SESSIONS              │
│  ─────────────────────────  │
│  ● dev      (3 windows)     │  ← Green = attached
│  ● staging  (1 window)      │  ← Gray = detached
│  ● kafka    (2 windows)     │
│  ─────────────────────────  │
│  New Session          ⌘N    │
│  New Session...       ⇧⌘N   │
│  ─────────────────────────  │
│  Refresh              ⌘R    │
│  Launch at Login      ✓     │
│  ─────────────────────────  │
│  Quit TmuxBar         ⌘Q    │
└─────────────────────────────┘
```

## Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon (arm64) or Intel
- [tmux](https://github.com/tmux/tmux) installed (`brew install tmux`)
- Swift 5.9+ / Xcode 15+

## Install

### Build from source

```bash
git clone git@github.com:buihuuloc/TmuxBar.git
cd TmuxBar
./scripts/bundle.sh
open .build/release/TmuxBar.app
```

### Development

```bash
# Debug build + run
swift run

# Run tests
swift test

# Release build only
swift build -c release
```

## Project Structure

```
├── Package.swift
├── Sources/TmuxBar/
│   ├── main.swift                 # App entry + AppDelegate
│   ├── Models.swift               # TmuxSession data model
│   ├── TmuxService.swift          # tmux shell interaction
│   ├── StatusBarController.swift  # Menu bar UI
│   └── Info.plist                 # LSUIElement (no dock icon)
├── Tests/TmuxBarTests/
│   ├── ModelsTests.swift          # Model + displayTitle tests
│   └── TmuxServiceTests.swift     # Parsing + validation tests
└── scripts/
    └── bundle.sh                  # Builds .app bundle with ad-hoc signing
```

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Attach session 1-9 | ⌘1 – ⌘9 |
| New Session | ⌘N |
| New Session (named) | ⇧⌘N |
| Refresh | ⌘R |
| Quit | ⌘Q |

## How It Works

- Uses `NSStatusItem` with `NSMenu` for a native Docker-like dropdown
- Shells out to tmux via `Process` (finds binary at `/opt/homebrew/bin/tmux` or via `which`)
- Parses `tmux list-sessions -F` with pipe-delimited format
- Attaches sessions by running `osascript` to tell Terminal.app to execute `tmux attach`
- Session names validated to `[a-zA-Z0-9_-]` to prevent injection

## License

MIT
