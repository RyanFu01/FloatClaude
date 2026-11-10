# FloatClaude

**An always-on-top, frosted-glass Claude window for macOS.** Press **⌥ Space** to summon it over anything — a web page, your editor, even a full-screen Netflix video — ask a question, and press it again to tuck it away.

[中文说明](README.zh-CN.md)

<!-- Demo GIF goes here: ![FloatClaude demo](docs/demo.gif) -->

> **Unofficial project.** FloatClaude is a personal project and is not affiliated with, endorsed by, or supported by Anthropic. It loads [claude.ai](https://claude.ai) in a floating window; you sign in with your own account, and the app itself collects nothing.

## Features

- **⌥ Space to show / hide** from anywhere; **Esc** also hides it
- **Floats over everything**, including full-screen video — without kicking the video out of full screen
- **Native frosted glass** that follows Claude's light / dark theme, with an optional **moss-green tint**
- **Independent appearance switch** (System / Light / Dark) that doesn't touch your Claude account settings
- Conversation text **fades softly** under the header and above the composer — no hard edges
- Hides the "you've used N% of your weekly limit" reminder (the real limit message is untouched)
- Lives in the menu bar — no Dock icon. Menu and window follow your system language (English / 中文)

## How it works

FloatClaude is ~1,000 lines: native Swift/AppKit for the window, plus JavaScript and CSS injected into claude.ai to make a website feel like a native glass panel. A few of the problems that turned out to be interesting:

### Floating over full-screen apps without stealing focus

A normal window that takes keyboard focus *activates its app*, and activating an app knocks a full-screen video out of full screen. The panel is an `NSPanel` with the **`.nonactivatingPanel`** style: it can become the key window (so you can type into it) while the app stays inactive. Combined with `level = .floating` and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, it appears on top of every Space, including full-screen ones.

The global shortcut uses Carbon's `RegisterEventHotKey`, which, unlike an `NSEvent` global monitor, **needs no Accessibility permission**.

### Turning a web page into glass

The window stacks `NSVisualEffectView` (glass) → a gradient tint view → a `WKWebView` with `drawsBackground = false`. The hard part is that claude.ai paints opaque backgrounds on many nested layers, and its class names change between releases.

So instead of hard-coding selectors, [`Web/glass.js`](Web/glass.js) **classifies layers by shape**: anything that is wide (≥ 80% of the viewport), square-cornered and opaque gets made transparent. Rounded elements — the composer, cards, message bubbles — and the sidebar, dialogs and menus are left alone, so text stays readable. A `MutationObserver` re-runs the check inside `requestAnimationFrame`, i.e. *before the next paint*, so newly rendered layers never flash opaque. A `WeakSet` of already-classified elements keeps this cheap while replies stream in.

### Why there's no blur behind the header and composer

The first version put a CSS `backdrop-filter: blur()` behind the header and composer to hide text scrolling underneath. Over a colorful desktop it showed up as a **flat grey rectangle**: inside a transparent window, WebKit's backdrop filter can only sample the page, not the desktop, so it blurs "nothing" into grey.

The fix was to stop hiding content *behind* the bars and instead make content **fade out before it reaches them**: a CSS `mask-image` gradient on the scrolling transcript, with eased multi-stop curves (28 px under the header, 44 px above the composer). The mask's endpoints are recomputed every scroll frame in the element's own coordinates, and the bottom fade ends just *under* the composer's top edge so images dissolve into it with no visible gap.

### A theme feedback loop

The glass follows claude.ai's theme (detected from the luminance of the page's text color and posted back through a `WKScriptMessageHandler`). An early version applied the theme by setting the **window's** `appearance` — but a `WKWebView` inherits the window's appearance for `prefers-color-scheme`. That created a loop: page dark → window dark → page told the system is dark → stays dark, so "follow system" got stuck. Now only the glass view's appearance changes. Forcing Light / Dark sets the web view's appearance *and* pins `<html data-mode>`, in case the Claude account itself is set to a fixed theme.

### Smaller details

- **No flash on load:** the web view stays at alpha 0 until `glass.js` reports `ready`, then fades in (with a 2.5 s fallback).
- **Google sign-in:** the OAuth popup returns its result through `window.opener`, so popups get a real child `WKWebView` window instead of being loaded into the main one.
- **Sidebar:** in a narrow window it slides *over* the chat; when it's open the conversation underneath fades out so the transparent sidebar stays readable.
- **Build quirk:** some Command Line Tools releases ship a stale `module.modulemap` that breaks every Swift build. `build.sh` shadows it with a VFS overlay rather than modifying system files.

## Project layout

```
Sources/
  main.swift                    entry point
  AppDelegate.swift             window, web view, menus, Esc-to-hide
  AppDelegate+Appearance.swift  glass, tint, light/dark theme, fade-in
  AppDelegate+WebView.swift     WKWebView delegates: messages, popups, uploads
  Views.swift                   FloatingPanel, DragHandle, TintView
  HotKey.swift                  global shortcut (Carbon)
  PageScripts.swift             loads Web/ files as WKUserScripts
  Config.swift                  shortcut, URLs, tint presets, localization
Web/
  glass.js                      classifies layers, fades transcript, reports theme
  glass.css                     transparency, fade masks, chips, sidebar
  force-mode.js                 pins claude.ai's light/dark mode
  hide-usage-banner.js          hides the weekly-limit reminder
build.sh                        compiles, bundles, ad-hoc signs, installs
```

## Install

**Requirements:** macOS 13+ on Apple silicon (M1 or later).

1. Download `FloatClaude.zip` from [Releases](../../releases), unzip, and move `FloatClaude.app` to Applications.
2. The app isn't notarized, so the first launch is blocked. Either **right-click → Open → Open**, or open it once and then allow it in **System Settings → Privacy & Security**. If macOS says the app is damaged, run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/FloatClaude.app
   ```
3. Sign in to Claude in the window. The login is remembered.

### Build from source

Needs the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone <this repo>
cd FloatClaude
./build.sh        # installs to ~/Applications/FloatClaude.app
```

## Tips

- **Shortcut conflicts:** if ⌥ Space opens Claude desktop's Quick Entry or ChatGPT instead, change or disable their shortcut. To use a different shortcut here, edit `Config.swift` and rebuild.
- **Launch at login:** System Settings → General → Login Items → add FloatClaude.
- **Memory:** mostly claude.ai itself (≈ 600–700 MB, similar to a browser tab); idle CPU and energy use are near zero.
