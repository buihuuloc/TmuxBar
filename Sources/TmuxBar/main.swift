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
