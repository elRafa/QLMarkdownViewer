import AppKit

// Minimal host app -- exists only to contain the Quick Look Preview Extension.
// The extension does all the work; this app just needs to be installed.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.run()
