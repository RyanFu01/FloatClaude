import Cocoa
import WebKit

/// WKWebView delegates: page messages, popups (sign-in), file uploads, crash recovery.
extension AppDelegate: WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    /// Messages from glass.js: "ready" and "theme:light" / "theme:dark".
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "fc", let body = message.body as? String else { return }
        if body == "ready" { fadeIn() }
        if body.hasPrefix("theme:") { applyTheme(dark: body == "theme:dark") }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if webView === self.webView { hideUntilReady() }
    }

    /// Reload automatically if the web content process crashes.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    /// Sign-in popups (e.g. "Continue with Google") need a real child window:
    /// the provider hands the result back via `window.opener`, which would be
    /// lost if the popup were loaded into the main web view. Any other link
    /// opens in the default browser so it doesn't replace the chat.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let host = navigationAction.request.url?.host ?? ""
        if let url = navigationAction.request.url, !host.isEmpty,
           !Config.authHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            NSWorkspace.shared.open(url)
            return nil
        }

        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                             styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.title = L("Sign in", "登录")

        let popup = WKWebView(frame: window.contentView!.bounds, configuration: configuration)
        popup.autoresizingMask = [.width, .height]
        popup.customUserAgent = Config.userAgent
        popup.uiDelegate = self
        window.contentView = popup
        window.center()
        window.orderFrontRegardless()
        window.makeKey()
        popups.append(window)
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        guard let window = webView.window, window !== panel else { return }
        window.orderOut(nil)
        popups.removeAll { $0 === window }
        showPanel()
    }

    /// <input type="file"> support (attaching files to a message).
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let open = NSOpenPanel()
        open.allowsMultipleSelection = parameters.allowsMultipleSelection
        open.canChooseDirectories = parameters.allowsDirectories
        open.level = .modalPanel
        open.begin { completionHandler($0 == .OK ? open.urls : nil) }
    }
}
