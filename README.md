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

## Architecture

### Layer Overview

<!-- mermaid:
graph LR
    subgraph Presentation
        A[StatusBarController<br>@MainActor]
        B[NSStatusItem]
        C[NSMenu]
    end
    subgraph Service
        D[TmuxService<br>caseless enum]
    end
    subgraph System
        E[Process + Pipe]
        F[osascript]
        G[SMAppService]
    end
    subgraph External
        H[tmux CLI]
        I[Terminal.app]
    end
    A --> B
    A --> C
    A --> D
    A --> G
    D --> E
    D --> F
    E --> H
    F --> I
-->

```
┌───────────────────────────────────────────────┐ ┌────────────────────┐ ┌──────────────────┐
│                 Presentation                  │ │      System        │ │    External      │
│                                               │ │                    │ │                  │
│ ┌─────────────────────┐     ┌───────────────┐ │ │ ┌────────────────┐ │ │ ┌──────────────┐ │
│ │                     │     │               │ │ │ │                │ │ │ │              │ │
│ │ StatusBarController ├────►│  NSStatusItem │ │┌┼►│ Process + Pipe ├─┼─┼►│   tmux CLI   │ │
│ │      @MainActor     │     │               │ │││ │                │ │ │ │              │ │
│ └──────────┬──────────┘     └───────────────┘ │││ └────────────────┘ │ │ └──────────────┘ │
│            │                                  │││                    │ │                  │
│            │                ┌───────────────┐ │││ ┌────────────────┐ │ │ ┌──────────────┐ │
│            ├───────────────►│     NSMenu    │ │││ │                │ │ │ │              │ │
│            │                │               │ │││ │   osascript    ├─┼─┼►│ Terminal.app │ │
│            │                └───────────────┘ │││ │                │ │ │ │              │ │
└────────────┼──────────────────────────────────┘││ └────────────────┘ │ │ └──────────────┘ │
             │              ┌───────────────────┐│          ▲          │ └──────────────────┘
             │              │      Service      ││          │          │
             │              │ ┌───────────────┐ ││          │          │
             ├──────────────┼►│  TmuxService  ├─┼┼──────────┘          │
             │              │ │ caseless enum │ ││                     │
             │              │ └───────────────┘ ││                     │
             │              └───────────────────┘│                     │
             │                ┌───────────────┐  │                     │
             └───────────────►│  SMAppService │  │                     │
                              └───────────────┘  │                     │
                                                 └─────────────────────┘
```

The app follows a three-layer architecture:

| Layer | Component | Responsibility |
|-------|-----------|----------------|
| **Presentation** | `StatusBarController` | Menu bar icon, dropdown menu, user action handlers (`@MainActor`) |
| **Service** | `TmuxService` | Stateless tmux shell integration (caseless `enum` namespace) |
| **Model** | `TmuxSession` | Immutable value type (`struct`, `Equatable`, `Identifiable`) |

### Component Details

| File | Role |
|------|------|
| `main.swift` | Bootstraps `NSApplication` with `.accessory` policy (no Dock icon), creates `AppDelegate` |
| `Models.swift` | `TmuxSession` struct with `name`, `paneCount`, `isAttached`, `createdAt` + computed `displayTitle` |
| `TmuxService.swift` | Binary discovery (cached), session CRUD, `list-sessions`/`list-panes` parsing, input validation |
| `StatusBarController.swift` | `NSStatusItem` + `NSMenu` construction, 5-second polling timer, attach/rename/kill actions |
| `Info.plist` | `LSUIElement = true` (agent app), bundle metadata |

### Data Flow

<!-- mermaid:
sequenceDiagram
    participant Timer as Timer 5s interval
    participant SBC as StatusBarController MainActor
    participant BG as Background Thread
    participant TS as TmuxService
    participant Tmux as tmux CLI
    Timer->>SBC: refresh()
    SBC->>BG: Task.detached
    BG->>TS: listSessions()
    TS->>Tmux: list-sessions -F format
    Tmux- ->>TS: session output
    TS->>Tmux: list-panes -a -F name
    Tmux- ->>TS: pane output
    TS- ->>BG: [TmuxSession]
    BG->>SBC: MainActor.run
    SBC->>SBC: sessions != old?
    SBC->>SBC: updateIcon + buildMenu
-->

```
 ┌─────────────┐   ┌─────────────────────┐   ┌───────────────────┐   ┌─────────────┐   ┌──────────┐
 │    Timer    │   │ StatusBarController │   │ Background Thread │   │ TmuxService │   │ tmux CLI │
 │ 5s interval │   │      MainActor      │   └───────────────────┘   └─────────────┘   └──────────┘
 └──────┬──────┘   └──────────┬──────────┘             ┬                    ┬                ┬
        │                     │                        │                    │                │
        │      refresh()      │                        │                    │                │
        │─────────────────────▶                        │                    │                │
        │                     │                        │                    │                │
        │                     │     Task.detached      │                    │                │
        │                     │────────────────────────▶                    │                │
        │                     │                        │                    │                │
        │                     │                        │  listSessions()    │                │
        │                     │                        │────────────────────▶                │
        │                     │                        │                    │                │
        │                     │                        │                    │  list-sessions  │
        │                     │                        │                    │────────────────▶│
        │                     │                        │                    │                │
        │                     │                        │                    │ session output  │
        │                     │                        │                    ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│
        │                     │                        │                    │                │
        │                     │                        │                    │   list-panes   │
        │                     │                        │                    │────────────────▶│
        │                     │                        │                    │                │
        │                     │                        │                    │  pane output   │
        │                     │                        │                    ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│
        │                     │                        │                    │                │
        │                     │                        │   [TmuxSession]    │                │
        │                     │                        ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│                │
        │                     │                        │                    │                │
        │                     │     MainActor.run      │                    │                │
        │                     ◀────────────────────────│                    │                │
        │                     │                        │                    │                │
        │                     ├───┐                    │                    │                │
        │                     │   │ sessions != old?   │                    │                │
        │                     ◀───┘                    │                    │                │
        │                     │                        │                    │                │
        │                     ├───┐                    │                    │                │
        │                     │   │ updateIcon +       │                    │                │
        │                     │   │ buildMenu          │                    │                │
        │                     ◀───┘                    │                    │                │
        │                     │                        │                    │                │
```

**Refresh cycle:** Every 5 seconds, `StatusBarController` dispatches tmux queries to a background thread via `Task.detached`. `TmuxService` runs two tmux commands (`list-sessions` + `list-panes`) and parses the pipe-delimited output into `[TmuxSession]`. Results hop back to the main thread via `MainActor.run`, where an equality check skips UI rebuilds when data is unchanged.

**User actions** (attach, rename, kill, create) call `TmuxService` directly, then trigger `refreshForce()` which always rebuilds the UI without the equality guard.

### Design Decisions

| Decision | Rationale |
|----------|-----------|
| **AppKit over SwiftUI** | `NSStatusItem` + `NSMenu` gives native menu bar dropdown matching Docker Desktop, 1Password, etc. SwiftUI menus have layout limitations for this pattern. |
| **Caseless enum namespace** | `TmuxService` cannot be accidentally instantiated. All methods are static. Simpler than a singleton for a stateless I/O service. |
| **Direct `Process` subprocess** | Arguments passed as array, not shell-interpolated. Prevents shell injection entirely. |
| **`osascript` over `NSAppleScript`** | `NSAppleScript` in ad-hoc signed agent apps triggers macOS Automation permission dialogs. Subprocess `osascript` inherits the user's existing TCC permissions. |
| **Pure SPM (no Xcode project)** | Anyone can `swift build` / `swift test` without Xcode. The `.app` bundle is assembled by `bundle.sh` with ad-hoc signing. |
| **5-second polling** | Simpler than tmux hooks and requires no user-side tmux configuration. Equality guard on `[TmuxSession]` prevents unnecessary UI redraws. |
| **Session name validation** | `[a-zA-Z0-9_-]` whitelist with 256-char limit prevents injection in shell commands and AppleScript strings. |

## How It Works

- Uses `NSStatusItem` with `NSMenu` for a native Docker-like dropdown
- Shells out to tmux via `Process` (finds binary at `/opt/homebrew/bin/tmux` or via `which`)
- Parses `tmux list-sessions -F` with pipe-delimited format
- Attaches sessions by running `osascript` to tell Terminal.app to execute `tmux attach`
- Session names validated to `[a-zA-Z0-9_-]` to prevent injection

## License

MIT
