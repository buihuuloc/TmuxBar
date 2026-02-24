import AppKit
import ServiceManagement

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
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
