// FloatClaude — an always-on-top floating Claude window for macOS.
// Press ⌥ Space to show or hide it over anything, including full-screen video.

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
