import AppKit

// Host app — exists primarily to deliver the Quick Look Preview Extension,
// but shows a small window so the user can confirm install and quit normally.

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let title = NSTextField(labelWithString: "QLMarkdownViewer")
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.alignment = .center

        let body = NSTextField(wrappingLabelWithString:
            "The Quick Look extension is installed.\n\n" +
            "Select a .md or .markdown file in Finder and press Space to preview.\n\n" +
            "If previews don't appear, enable the extension under\n" +
            "System Settings → General → Login Items & Extensions → Quick Look.")
        body.alignment = .center

        let stack = NSStackView(views: [title, body])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 260),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "QL Markdown Viewer"
        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)
let appMenu = NSMenu()
appMenuItem.submenu = appMenu
appMenu.addItem(NSMenuItem(title: "Quit \(ProcessInfo.processInfo.processName)",
                           action: #selector(NSApplication.terminate(_:)),
                           keyEquivalent: "q"))
let fileMenuItem = NSMenuItem()
mainMenu.addItem(fileMenuItem)
let fileMenu = NSMenu(title: "File")
fileMenuItem.submenu = fileMenu
fileMenu.addItem(NSMenuItem(title: "Close",
                            action: #selector(NSWindow.performClose(_:)),
                            keyEquivalent: "w"))
app.mainMenu = mainMenu

let delegate = AppDelegate()
app.delegate = delegate
app.run()
