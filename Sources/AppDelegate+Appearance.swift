import Cocoa
import WebKit

/// Glass, tint and light/dark theme.
///
/// Design notes:
/// - The glass follows *claude.ai's* theme (reported by glass.js), not the
///   macOS one, so the page and the glass always match.
/// - Only `glass.appearance` is changed, never the window's. The web view
///   inherits the window's appearance for `prefers-color-scheme`, so changing
///   the window would feed back into the page ("page dark -> window dark ->
///   page stays dark") and break "follow system".
extension AppDelegate {

    /// (Re)installs every injected script and applies the current settings.
    /// WKUserContentController can't remove a single script, so we rebuild
    /// the whole set whenever a setting changes.
    func installPageScripts() {
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(PageScripts.hideUsageBanner)
        ucc.addUserScript(PageScripts.glassLogic)
        glass.isHidden = !glassOn
        if glassOn {
            ucc.addUserScript(PageScripts.glassStyle)
            webView.evaluateJavaScript(PageScripts.glassStyleSource)
        } else {
            webView.evaluateJavaScript(PageScripts.removeGlassStyle)
        }
        glassMenuItem?.state = glassOn ? .on : .off
        applyAppearanceMode()
    }

    // MARK: Appearance mode (System / Light / Dark)

    func applyAppearanceMode() {
        let mode = appearanceMode
        // prefers-color-scheme inside the page follows the web view's appearance.
        webView.appearance = mode == "light" ? NSAppearance(named: .aqua)
                           : mode == "dark"  ? NSAppearance(named: .darkAqua)
                           : nil
        // ...and pin <html data-mode>, in case the Claude account itself is set to a fixed theme.
        webView.configuration.userContentController.addUserScript(PageScripts.forceMode(mode))
        webView.evaluateJavaScript(PageScripts.forceModeSource(mode))

        let systemDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if mode == "system" {
            // Hand data-mode back to claude.ai, starting from the current system theme.
            webView.evaluateJavaScript("document.documentElement.setAttribute('data-mode', '\(systemDark ? "dark" : "light")')")
        }
        for item in appearanceItems { item.state = (item.representedObject as? String) == mode ? .on : .off }

        // Best guess now so the glass is right immediately; the page corrects it once loaded.
        applyTheme(dark: mode == "dark" || (mode == "system" && systemDark))
    }

    @objc func setAppearanceMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        appearanceMode = mode
        installPageScripts()
    }

    // MARK: Theme / glass / tint

    func applyTheme(dark: Bool) {
        glass.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        glass.material = dark ? .hudWindow : .popover
        isDark = dark
        applyTint()
    }

    func applyTint() {
        let preset = tintPresets.first { $0.id == tintId }
        tintView.setColors(glassOn ? (isDark ? preset?.dark : preset?.light) : nil)
        for item in tintItems { item.state = (item.representedObject as? String) == tintId ? .on : .off }
    }

    @objc func setTint(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        tintId = id
        applyTint()
    }

    @objc func toggleGlass() {
        glassOn.toggle()
        installPageScripts()
        applyTint()
        if !glassOn { fadeIn() }
    }

    // MARK: Fade-in on load

    /// Keep the page invisible until glass.js has made its layers transparent,
    /// so it never flashes opaque first. Falls back after 2.5 s.
    func hideUntilReady() {
        guard glassOn else { return }
        webView.alphaValue = 0
        fallbackFade?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.fadeIn() }
        fallbackFade = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }

    func fadeIn() {
        fallbackFade?.cancel()
        guard webView.alphaValue < 1 else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            webView.animator().alphaValue = 1
        }
    }
}
