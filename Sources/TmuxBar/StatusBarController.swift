import AppKit
import ServiceManagement

@MainActor
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

    deinit {
        refreshTimer?.invalidate()
    }

    func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    @objc func refresh() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let newSessions = TmuxService.listSessions()
            await MainActor.run {
                guard let self = self else { return }
                guard newSessions != self.sessions else { return }
                self.sessions = newSessions
                self.updateIcon()
                self.buildMenu()
            }
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "TmuxBar")
        image?.size = NSSize(width: 18, height: 18)
        button.image = image
        button.imagePosition = .imageLeft
        button.title = sessions.count > 0 ? " \(sessions.count)" : ""
        button.setAccessibilityLabel("TmuxBar, \(sessions.count) tmux sessions")
    }

    // MARK: - Colored Status Dot

    private func coloredDot(color: NSColor, size: CGFloat = 8) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    // MARK: - Menu Construction

    private func buildMenu() {
        let menu = NSMenu()

        // Header
        let header = NSMenuItem(title: "Tmux Sessions", action: nil, keyEquivalent: "")
        header.isEnabled = false
        let headerFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        header.attributedTitle = NSAttributedString(string: "TMUX SESSIONS", attributes: [.font: headerFont, .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        if sessions.isEmpty {
            let noSessions: NSMenuItem
            if TmuxService.findTmuxPath() == nil {
                noSessions = NSMenuItem(title: "tmux not found", action: nil, keyEquivalent: "")
            } else {
                noSessions = NSMenuItem(title: "No sessions running", action: nil, keyEquivalent: "")
            }
            noSessions.isEnabled = false
            menu.addItem(noSessions)
        } else {
            for (index, session) in sessions.enumerated() {
                let label = "\(session.name)  (\(session.windowCount) window\(session.windowCount == 1 ? "" : "s"))"
                let key = index < 9 ? "\(index + 1)" : ""
                let item = NSMenuItem(title: label, action: nil, keyEquivalent: "")
                item.image = coloredDot(color: session.isAttached ? .systemGreen : .tertiaryLabelColor)
                item.setAccessibilityLabel("\(session.name), \(session.windowCount) windows, \(session.isAttached ? "attached" : "detached")")

                let submenu = NSMenu()

                let attachItem = NSMenuItem(title: "Attach", action: #selector(attachSession(_:)), keyEquivalent: key)
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

        let newSession = NSMenuItem(title: "New Session", action: #selector(createSession), keyEquivalent: "n")
        newSession.target = self
        newSession.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "New Session")
        newSession.image?.size = NSSize(width: 14, height: 14)
        menu.addItem(newSession)

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshManual), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLogin.target = self
        launchAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLogin)

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
                if !TmuxService.isValidSessionName(newName) {
                    let errAlert = NSAlert()
                    errAlert.messageText = "Invalid Name"
                    errAlert.informativeText = "Session names can only contain letters, numbers, dashes, and underscores."
                    errAlert.alertStyle = .warning
                    errAlert.runModal()
                    return
                }
                TmuxService.renameSession(oldName: oldName, newName: newName)
                refreshForce()
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
        alert.buttons[0].hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            TmuxService.killSession(name: name)
            refreshForce()
        }
    }

    @objc private func createSession() {
        TmuxService.createSession(name: nil)
        refreshForce()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Launch at Login"
            alert.informativeText = "Failed to update login item: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
        refreshForce()
    }

    /// Manual refresh from menu (forces reload even if sessions unchanged)
    @objc private func refreshManual() {
        refreshForce()
    }

    /// Force refresh bypassing equality check
    private func refreshForce() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let newSessions = TmuxService.listSessions()
            await MainActor.run {
                self?.sessions = newSessions
                self?.updateIcon()
                self?.buildMenu()
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
