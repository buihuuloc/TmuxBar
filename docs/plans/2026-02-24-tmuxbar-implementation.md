# TmuxBar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that shows tmux session count, lists sessions, and allows attach/rename/kill via a native dropdown.

**Architecture:** NSStatusItem + NSMenu for the dropdown (AppKit). TmuxService shells out to tmux via Process. SwiftUI used only for rename/new-session dialogs via NSAlert. No dock icon (LSUIElement). 5-second Timer refresh.

**Tech Stack:** Swift 6.2, AppKit, Swift Package Manager, XCTest

---

### Task 1: Project Scaffold — Package.swift & Info.plist

**Files:**
- Create: `Package.swift`
- Create: `Sources/TmuxBar/Info.plist`
- Create: `Sources/TmuxBar/main.swift` (minimal entry point)

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TmuxBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TmuxBar",
            path: "Sources/TmuxBar",
            resources: [.copy("Info.plist")]
        ),
        .testTarget(
            name: "TmuxBarTests",
            dependencies: ["TmuxBar"],
            path: "Tests/TmuxBarTests"
        ),
    ]
)
```

**Step 2: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleName</key>
    <string>TmuxBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.tmuxbar.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
```

**Step 3: Create minimal main.swift**

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("TmuxBar launched")
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**Step 4: Verify build**

Run: `cd /Users/huuloc/Documents/macbar && swift build 2>&1`
Expected: Build succeeds, binary at `.build/debug/TmuxBar`

**Step 5: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "feat: scaffold TmuxBar Swift package with Info.plist"
```

---

### Task 2: Models — TmuxSession data model

**Files:**
- Create: `Sources/TmuxBar/Models.swift`
- Create: `Tests/TmuxBarTests/ModelsTests.swift`

**Step 1: Write failing test for TmuxSession model**

```swift
import XCTest
@testable import TmuxBar

final class ModelsTests: XCTestCase {
    func testTmuxSessionInit() {
        let session = TmuxSession(name: "dev", windowCount: 3, isAttached: true, createdAt: "Mon Feb 24 10:00:00 2026")
        XCTAssertEqual(session.name, "dev")
        XCTAssertEqual(session.windowCount, 3)
        XCTAssertTrue(session.isAttached)
    }

    func testTmuxSessionEquatable() {
        let a = TmuxSession(name: "dev", windowCount: 1, isAttached: false, createdAt: "")
        let b = TmuxSession(name: "dev", windowCount: 1, isAttached: false, createdAt: "")
        XCTAssertEqual(a, b)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/huuloc/Documents/macbar && swift test --filter ModelsTests 2>&1`
Expected: FAIL — `TmuxSession` not found

**Step 3: Write Models.swift**

```swift
import Foundation

struct TmuxSession: Equatable, Identifiable {
    let name: String
    let windowCount: Int
    let isAttached: Bool
    let createdAt: String

    var id: String { name }

    var displayTitle: String {
        let attached = isAttached ? " \u{25CF}" : ""
        return "\(name)  (\(windowCount) window\(windowCount == 1 ? "" : "s"))\(attached)"
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/huuloc/Documents/macbar && swift test --filter ModelsTests 2>&1`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add Sources/TmuxBar/Models.swift Tests/TmuxBarTests/ModelsTests.swift
git commit -m "feat: add TmuxSession data model with tests"
```

---

### Task 3: TmuxService — Session parsing and shell commands

**Files:**
- Create: `Sources/TmuxBar/TmuxService.swift`
- Create: `Tests/TmuxBarTests/TmuxServiceTests.swift`

**Step 1: Write failing tests for parsing**

```swift
import XCTest
@testable import TmuxBar

final class TmuxServiceTests: XCTestCase {
    func testParseSessionsOutput() {
        let output = """
        dev|3|1|1708770000
        staging|1|0|1708770100
        """
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].name, "dev")
        XCTAssertEqual(sessions[0].windowCount, 3)
        XCTAssertTrue(sessions[0].isAttached)
        XCTAssertEqual(sessions[1].name, "staging")
        XCTAssertEqual(sessions[1].windowCount, 1)
        XCTAssertFalse(sessions[1].isAttached)
    }

    func testParseEmptyOutput() {
        let sessions = TmuxService.parseSessions(from: "")
        XCTAssertTrue(sessions.isEmpty)
    }

    func testParseMalformedLine() {
        let output = "bad-line\ngood|2|1|123456"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].name, "good")
    }

    func testTmuxBinaryPath() {
        let path = TmuxService.findTmuxPath()
        XCTAssertNotNil(path)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/huuloc/Documents/macbar && swift test --filter TmuxServiceTests 2>&1`
Expected: FAIL — `TmuxService` not found

**Step 3: Write TmuxService.swift**

```swift
import AppKit

final class TmuxService {
    static let sessionFormat = "#{session_name}|#{session_windows}|#{session_attached}|#{session_created}"

    static func findTmuxPath() -> String? {
        let candidates = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Fallback: use `which`
        let result = shell("/usr/bin/which", arguments: ["tmux"])
        let path = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    static func parseSessions(from output: String) -> [TmuxSession] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line -> TmuxSession? in
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: "|", maxSplits: 3)
                guard parts.count == 4,
                      let windowCount = Int(parts[1]),
                      let attached = Int(parts[2]) else { return nil }
                return TmuxSession(
                    name: String(parts[0]),
                    windowCount: windowCount,
                    isAttached: attached != 0,
                    createdAt: String(parts[3])
                )
            }
    }

    static func listSessions() -> [TmuxSession] {
        guard let tmux = findTmuxPath() else { return [] }
        let output = shell(tmux, arguments: ["list-sessions", "-F", sessionFormat])
        return parseSessions(from: output)
    }

    static func createSession(name: String?) {
        guard let tmux = findTmuxPath() else { return }
        var args = ["new-session", "-d"]
        if let name = name, !name.isEmpty {
            args += ["-s", name]
        }
        _ = shell(tmux, arguments: args)
    }

    static func renameSession(oldName: String, newName: String) {
        guard let tmux = findTmuxPath() else { return }
        _ = shell(tmux, arguments: ["rename-session", "-t", oldName, newName])
    }

    static func killSession(name: String) {
        guard let tmux = findTmuxPath() else { return }
        _ = shell(tmux, arguments: ["kill-session", "-t", name])
    }

    static func attachSession(name: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "tmux attach -t \(name)"
        end tell
        """
        guard let appleScript = NSAppleScript(source: script) else { return }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
    }

    @discardableResult
    private static func shell(_ command: String, arguments: [String] = []) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        // Inherit PATH for tmux to find its dependencies
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd /Users/huuloc/Documents/macbar && swift test --filter TmuxServiceTests 2>&1`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add Sources/TmuxBar/TmuxService.swift Tests/TmuxBarTests/TmuxServiceTests.swift
git commit -m "feat: add TmuxService with session parsing, CRUD, and shell execution"
```

---

### Task 4: StatusBarController — Menu bar icon, dropdown menu, refresh timer

**Files:**
- Create: `Sources/TmuxBar/StatusBarController.swift`
- Modify: `Sources/TmuxBar/main.swift` (wire up StatusBarController)

**Step 1: Write StatusBarController.swift**

```swift
import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private var sessions: [TmuxSession] = []
    private var refreshTimer: Timer?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        updateIcon()
        buildMenu()
        startRefreshTimer()
    }

    func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc func refresh() {
        sessions = TmuxService.listSessions()
        updateIcon()
        buildMenu()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "TmuxBar")
        image?.size = NSSize(width: 18, height: 18)
        button.image = image
        button.imagePosition = .imageLeft
        button.title = " \(sessions.count)"
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Header
        let header = NSMenuItem(title: "Tmux Sessions", action: nil, keyEquivalent: "")
        header.isEnabled = false
        let headerFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        header.attributedTitle = NSAttributedString(string: "Tmux Sessions", attributes: [.font: headerFont, .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        if sessions.isEmpty {
            let noSessions = NSMenuItem(title: "No sessions running", action: nil, keyEquivalent: "")
            noSessions.isEnabled = false
            menu.addItem(noSessions)
        } else {
            for session in sessions {
                let item = NSMenuItem(title: session.displayTitle, action: nil, keyEquivalent: "")
                let submenu = NSMenu()

                let attachItem = NSMenuItem(title: "Attach", action: #selector(attachSession(_:)), keyEquivalent: "")
                attachItem.target = self
                attachItem.representedObject = session.name
                submenu.addItem(attachItem)

                let renameItem = NSMenuItem(title: "Rename...", action: #selector(renameSession(_:)), keyEquivalent: "")
                renameItem.target = self
                renameItem.representedObject = session.name
                submenu.addItem(renameItem)

                submenu.addItem(NSMenuItem.separator())

                let killItem = NSMenuItem(title: "Kill Session", action: #selector(killSession(_:)), keyEquivalent: "")
                killItem.target = self
                killItem.representedObject = session.name
                submenu.addItem(killItem)

                item.submenu = submenu
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let newSession = NSMenuItem(title: "New Session", action: #selector(createUnnamedSession), keyEquivalent: "n")
        newSession.target = self
        menu.addItem(newSession)

        let newNamedSession = NSMenuItem(title: "New Session...", action: #selector(createNamedSession), keyEquivalent: "N")
        newNamedSession.target = self
        menu.addItem(newNamedSession)

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit TmuxBar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func attachSession(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        TmuxService.attachSession(name: name)
    }

    @objc private func renameSession(_ sender: NSMenuItem) {
        guard let oldName = sender.representedObject as? String else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Session"
        alert.informativeText = "Enter a new name for session '\(oldName)':"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.stringValue = oldName
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty && newName != oldName {
                TmuxService.renameSession(oldName: oldName, newName: newName)
                refresh()
            }
        }
    }

    @objc private func killSession(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let alert = NSAlert()
        alert.messageText = "Kill Session?"
        alert.informativeText = "Are you sure you want to kill session '\(name)'? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Kill")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            TmuxService.killSession(name: name)
            refresh()
        }
    }

    @objc private func createUnnamedSession() {
        TmuxService.createSession(name: nil)
        refresh()
    }

    @objc private func createNamedSession() {
        let alert = NSAlert()
        alert.messageText = "New Session"
        alert.informativeText = "Enter a name for the new session:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.placeholderString = "session-name"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            TmuxService.createSession(name: name.isEmpty ? nil : name)
            refresh()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

**Step 2: Update main.swift to wire up StatusBarController**

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        statusBarController?.refresh()
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**Step 3: Build and verify**

Run: `cd /Users/huuloc/Documents/macbar && swift build 2>&1`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/TmuxBar/StatusBarController.swift Sources/TmuxBar/main.swift
git commit -m "feat: add StatusBarController with full menu bar UI"
```

---

### Task 5: Integration testing — Build, run, verify all tests pass

**Step 1: Run all tests**

Run: `cd /Users/huuloc/Documents/macbar && swift test 2>&1`
Expected: All tests pass

**Step 2: Build release binary**

Run: `cd /Users/huuloc/Documents/macbar && swift build -c release 2>&1`
Expected: Release build succeeds at `.build/release/TmuxBar`

**Step 3: Commit any fixes needed**

---

### Task 6: App bundle packaging

**Files:**
- Create: `scripts/bundle.sh`

**Step 1: Create bundle script**

```bash
#!/bin/bash
set -e

APP_NAME="TmuxBar"
BUILD_DIR=".build/release"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"

swift build -c release

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/"
cp Sources/TmuxBar/Info.plist "$BUNDLE_DIR/Contents/"

echo "Built $BUNDLE_DIR"
echo "Run with: open $BUNDLE_DIR"
```

**Step 2: Make executable and test**

Run: `chmod +x scripts/bundle.sh && cd /Users/huuloc/Documents/macbar && ./scripts/bundle.sh 2>&1`
Expected: `.build/release/TmuxBar.app` created

**Step 3: Commit**

```bash
git add scripts/bundle.sh
git commit -m "feat: add app bundle packaging script"
```
