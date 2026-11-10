import Cocoa
import WebKit
import Carbon.HIToolbox

/// Owns the floating panel, the web view, the menu bar item and the hotkey.
/// Appearance (glass / tint / theme) and web view delegate callbacks live in
/// extensions in their own files.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel!
    var webView: WKWebView!
    var glass: NSVisualEffectView!
    var tintView: TintView!
    var hotKey: HotKey?
    var statusItem: NSStatusItem!

    // Menu items whose check marks reflect current settings.
    var glassMenuItem: NSMenuItem!
    var appearanceItems: [NSMenuItem] = []
    var tintItems: [NSMenuItem] = []

    /// Whether claude.ai is currently showing its dark theme (reported by the page).
    var isDark = false
    var fallbackFade: DispatchWorkItem?
    var popups: [NSWindow] = []

    // MARK: Persisted settings

    var glassOn: Bool {
        get { UserDefaults.standard.object(forKey: "glass") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "glass") }
    }
    /// "system" (let claude.ai follow macOS), "light" or "dark".
    var appearanceMode: String {
        get { UserDefaults.standard.string(forKey: "appearanceMode") ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: "appearanceMode") }
    }
    /// "none" or a TintPreset id.
    var tintId: String {
        get { UserDefaults.standard.string(forKey: "tint") ?? "none" }
        set { UserDefaults.standard.set(newValue, forKey: "tint") }
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
        setupMainMenu()
        setupPanel()
        setupStatusItem()
        hotKey = HotKey(keyCode: Config.hotKeyCode, modifiers: Config.hotKeyModifiers) { [weak self] in
            self?.togglePanel()
        }
        setupEscToHide()
        showPanel()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Window

    func setupPanel() {
        panel = FloatingPanel()
        if !panel.setFrameUsingName("FloatClaudeWindow"), let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.maxX - 440, y: screen.maxY - 660))
        }

        // Layer stack, bottom to top: frosted glass -> tint -> web view -> drag handle.
        let root = NSView(frame: panel.contentView!.bounds)
        root.wantsLayer = true
        root.layer?.cornerRadius = Config.windowCornerRadius
        root.layer?.masksToBounds = true

        glass = NSVisualEffectView(frame: root.bounds)
        glass.autoresizingMask = [.width, .height]
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active   // keep blurring even when the window isn't key
        root.addSubview(glass)

        tintView = TintView(frame: root.bounds)
        tintView.autoresizingMask = [.width, .height]
        tintView.setColors(nil)
        root.addSubview(tintView)

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()   // persist the claude.ai login
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: root.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.customUserAgent = Config.userAgent
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")   // let the glass show through
        root.addSubview(webView)

        let handle = DragHandle(frame: NSRect(x: 0, y: root.bounds.height - 10, width: root.bounds.width, height: 10))
        handle.autoresizingMask = [.width, .minYMargin]
        root.addSubview(handle)

        panel.contentView = root
        installPageScripts()
        config.userContentController.add(self, name: "fc")
        webView.load(URLRequest(url: Config.homeURL))
    }

    @objc func togglePanel() {
        if panel.isVisible && panel.isKeyWindow { hidePanel() } else { showPanel() }
    }

    func showPanel() {
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(webView)
        webView.evaluateJavaScript("document.querySelector('[contenteditable=\"true\"], textarea')?.focus()")
    }

    @objc func hidePanel() { panel.orderOut(nil) }
    @objc func reload() { webView.reload() }
    @objc func newChat() { webView.load(URLRequest(url: Config.homeURL)); showPanel() }

    /// Esc hides the window, unless a menu or dialog is open in the page
    /// (then Esc goes to the page and closes that first).
    func setupEscToHide() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, e.keyCode == UInt16(kVK_Escape), e.window === self.panel else { return e }
            self.webView.evaluateJavaScript(
                "!!document.querySelector('[role=dialog],[role=menu],[role=listbox],[data-radix-popper-content-wrapper]')"
            ) { open, _ in
                if (open as? Bool) != true { self.hidePanel() }
            }
            return e
        }
    }

    // MARK: Menus

    /// An app with no main menu gets no ⌘C / ⌘V / ⌘Z in its web view.
    func setupMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("Hide Window", "隐藏窗口"), action: #selector(hidePanel), keyEquivalent: "w")
        appMenu.addItem(withTitle: L("Reload", "刷新"), action: #selector(reload), keyEquivalent: "r")
        appMenu.addItem(withTitle: L("New Chat", "新对话"), action: #selector(newChat), keyEquivalent: "n")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Quit FloatClaude", "退出 FloatClaude"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "FloatClaude")

        let menu = NSMenu()
        menu.addItem(withTitle: L("Show / Hide", "显示/隐藏") + "  (\(Config.hotKeyLabel))", action: #selector(togglePanel), keyEquivalent: "")
        menu.addItem(withTitle: L("New Chat", "新对话"), action: #selector(newChat), keyEquivalent: "")
        menu.addItem(withTitle: L("Reload", "刷新"), action: #selector(reload), keyEquivalent: "")
        menu.addItem(.separator())

        glassMenuItem = NSMenuItem(title: L("Frosted Glass", "毛玻璃背景"), action: #selector(toggleGlass), keyEquivalent: "")
        glassMenuItem.state = glassOn ? .on : .off
        menu.addItem(glassMenuItem)

        menu.addItem(submenu(L("Appearance", "外观"),
                             options: [("system", L("System", "跟随系统")), ("light", L("Light", "浅色")), ("dark", L("Dark", "深色"))],
                             selected: appearanceMode, action: #selector(setAppearanceMode(_:)), into: &appearanceItems))
        menu.addItem(submenu(L("Tint", "色调"),
                             options: [("none", L("None", "默认"))] + tintPresets.map { ($0.id, $0.title) },
                             selected: tintId, action: #selector(setTint(_:)), into: &tintItems))

        menu.addItem(.separator())
        menu.addItem(withTitle: L("Quit", "退出"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = menu
    }

    /// A submenu of mutually exclusive options; each item's representedObject is its id.
    private func submenu(_ title: String, options: [(id: String, title: String)], selected: String,
                         action: Selector, into items: inout [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for option in options {
            let item = NSMenuItem(title: option.title, action: action, keyEquivalent: "")
            item.representedObject = option.id
            item.state = option.id == selected ? .on : .off
            sub.addItem(item)
            items.append(item)
        }
        parent.submenu = sub
        return parent
    }
}
