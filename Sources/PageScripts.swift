import Foundation
import WebKit

/// The JavaScript and CSS injected into claude.ai. The sources live in Web/
/// and are copied into the app bundle's Resources by build.sh.
enum PageScripts {
    private static func resource(_ name: String, _ ext: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("FloatClaude: missing resource \(name).\(ext)")
            return ""
        }
        return text
    }

    /// A JS string literal, safely escaped (JSON strings are valid JS strings).
    private static func jsString(_ s: String) -> String {
        let data = try! JSONEncoder().encode(s)
        return String(data: data, encoding: .utf8)!
    }

    private static func atStart(_ source: String) -> WKUserScript {
        WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    /// Tags opaque layers, fades the transcript, reports theme / ready.
    static let glassLogic = atStart(resource("glass", "js"))

    /// Hides the "you've used N% of your weekly limit" reminder.
    static let hideUsageBanner = atStart(resource("hide-usage-banner", "js"))

    /// Injects glass.css as a <style id="floatclaude-glass"> element.
    static let glassStyleSource = """
        (function(){
          if (document.getElementById('floatclaude-glass')) return;
          var s = document.createElement('style');
          s.id = 'floatclaude-glass';
          s.textContent = \(jsString(resource("glass", "css")));
          (document.head || document.documentElement).appendChild(s);
        })();
        """
    static let glassStyle = atStart(glassStyleSource)
    static let removeGlassStyle = "document.getElementById('floatclaude-glass')?.remove()"

    /// Pins claude.ai's theme. `mode` is "system", "light" or "dark".
    static func forceModeSource(_ mode: String) -> String {
        "window.__fcMode = \(jsString(mode));\n" + resource("force-mode", "js")
    }
    static func forceMode(_ mode: String) -> WKUserScript { atStart(forceModeSource(mode)) }
}
