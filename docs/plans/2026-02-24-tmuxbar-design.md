# TmuxBar Design

## Overview
macOS menu bar app for Apple Silicon that shows tmux session count, lists sessions with window counts, and allows launching/renaming/killing sessions via a native dropdown menu.

## Requirements
- SF Symbol icon + session count badge in menu bar
- Dropdown listing all sessions with window count and attached indicator
- Click session → submenu with Attach / Rename / Kill
- Attach opens Terminal.app and runs `tmux attach -t <name>`
- New Session (unnamed) and New Session... (named with prompt)
- 5-second background polling refresh
- Launch at Login toggle
- No dock icon (LSUIElement)

## Architecture
- **Approach**: NSStatusItem + NSMenu (AppKit) for native Docker-like dropdown
- **tmux interaction**: `Process` shelling out to tmux binary
- **Session parsing**: `tmux list-sessions -F` with pipe-delimited format
- **Attach**: AppleScript → Terminal.app
- **Build system**: Swift Package Manager (no Xcode project)

## Components
| Component | Responsibility |
|-----------|---------------|
| TmuxBarApp.swift | App entry, AppDelegate, NSApp lifecycle |
| StatusBarController.swift | NSStatusItem, NSMenu, Timer, menu construction |
| TmuxService.swift | Shell interaction, session CRUD, Terminal.app launch |
| Models.swift | TmuxSession data model |

## Menu Layout
- Header: "Tmux Sessions"
- Session items with window count + attached indicator, each with submenu (Attach/Rename/Kill)
- Separator → New Session / New Session...
- Separator → Refresh / Launch at Login toggle
- Separator → Quit

## Testing
- Unit tests for tmux output parsing
- Build verification on arm64
