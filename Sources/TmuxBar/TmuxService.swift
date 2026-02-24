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
        let escapedName = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "tmux attach -t \(escapedName)"
        end tell
        """
        guard let appleScript = NSAppleScript(source: script) else { return }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
    }

    @discardableResult
    static func shell(_ command: String, arguments: [String] = []) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
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
