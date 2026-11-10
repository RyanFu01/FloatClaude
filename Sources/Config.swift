import Cocoa
import Carbon.HIToolbox

/// User-tweakable settings. Change these and run ./build.sh.
enum Config {
    /// Global shortcut: ⌥ Space.
    static let hotKeyCode = UInt32(kVK_Space)
    static let hotKeyModifiers = UInt32(optionKey)
    static let hotKeyLabel = "⌥Space"

    static let homeURL = URL(string: "https://claude.ai/new")!

    /// claude.ai (and Google sign-in) behave best with a Safari user agent.
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    /// Popups from these hosts (sign-in flows) open inside the app;
    /// any other link opens in the default browser.
    static let authHosts = ["accounts.google.com", "appleid.apple.com", "claude.ai"]

    static let windowCornerRadius: CGFloat = 18
}

/// Picks the Chinese or English string based on the system language.
func L(_ en: String, _ zh: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
}

// MARK: - Tint presets

/// A color wash laid over the frosted glass. Each preset has a gradient for
/// Claude's dark theme and one for its light theme (top-left -> bottom-right).
struct TintPreset {
    let id: String
    let title: String
    let dark: [NSColor]
    let light: [NSColor]
}

private func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let tintPresets: [TintPreset] = [
    // Inspired by the Dia browser: deep moss green in dark mode
    // (lighter moss at top-left -> deeper pine at bottom-right), and a pale
    // mint in light mode so dark text stays readable.
    TintPreset(
        id: "moss", title: L("Moss", "墨绿"),
        dark: [rgba(42, 84, 58, 0.62), rgba(24, 50, 36, 0.70), rgba(14, 32, 23, 0.78)],
        light: [rgba(214, 236, 221, 0.62), rgba(200, 225, 208, 0.66), rgba(186, 214, 196, 0.70)]),
]
