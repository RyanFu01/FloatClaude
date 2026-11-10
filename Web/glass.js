/*
 * FloatClaude — page-side glass logic, injected into claude.ai at document start.
 *
 * Rather than hard-coding claude.ai class names (which change between
 * releases), this finds opaque layers by *shape*:
 *   - wide (>= 80% of the viewport), square-cornered, opaque  -> make transparent
 *   - rounded things (composer, cards, message blocks), the sidebar,
 *     dialogs and menus are left alone
 *
 * Wide layers that hug the top or bottom edge ("bars": the header and the
 * composer dock) normally exist to hide content scrolling underneath. Once
 * they're transparent, that job is done instead by a CSS mask on the
 * transcript, so text fades out before it ever reaches them.
 *
 * Also reports Claude's light/dark theme and "ready" to the native side
 * via webkit.messageHandlers.fc.
 */
(function () {
  if (window.__fcSweep) return;
  window.__fcSweep = true;

  // ---------- helpers ----------

  // Alpha of a computed CSS color (rgb/rgba/color()/oklab all appear in practice).
  function alpha(c) {
    if (!c || c === 'transparent') return 0;
    var m = c.match(/\/\s*([\d.]+%?)\s*\)$/);
    if (m) return m[1].endsWith('%') ? parseFloat(m[1]) / 100 : parseFloat(m[1]);
    m = c.match(/^rgba\((?:[^,]+,){3}\s*([\d.]+)\)/);
    return m ? parseFloat(m[1]) : 1;
  }

  // Relative lightness 0..1 of a computed CSS color, or -1 if unknown.
  function lightness(c) {
    var m;
    if ((m = c.match(/^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)/)))
      return (0.2126 * m[1] + 0.7152 * m[2] + 0.0722 * m[3]) / 255;
    if ((m = c.match(/^color\(srgb\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)/)))
      return 0.2126 * m[1] + 0.7152 * m[2] + 0.0722 * m[3];
    if ((m = c.match(/^ok(?:lab|lch)\(\s*([\d.]+)(%?)/)))
      return m[2] ? m[1] / 100 : +m[1];
    return -1;
  }

  // Only write a style property when it actually changes, so our own writes
  // don't keep re-triggering the MutationObserver.
  function setVar(el, k, v) {
    if (el.style.getPropertyValue(k) !== v) el.style.setProperty(k, v);
  }

  function post(msg) {
    try { webkit.messageHandlers.fc.postMessage(msg); } catch (e) {}
  }

  function scrollerOf(el) {
    for (var p = el.parentElement; p && p !== document.body; p = p.parentElement) {
      var o = getComputedStyle(p).overflowY;
      if (o === 'auto' || o === 'scroll') return p;
    }
    return null;
  }

  // ---------- 1. tag opaque layers ----------

  var SKIP = '[class*="sidebar"],[role=dialog],[role=menu],[role=listbox],[role=tooltip],[data-radix-popper-content-wrapper]';
  var checked = new WeakSet(); // elements already classified (keeps streaming replies cheap)

  function tagLayers() {
    var W = innerWidth, H = innerHeight;
    document.querySelectorAll('body div, body header, body footer, body section, body nav').forEach(function (el) {
      if (checked.has(el) || el.hasAttribute('data-fc-glass')) return;
      var r = el.getBoundingClientRect();
      if (r.width === 0 && r.height === 0) return; // not laid out yet; look again later
      checked.add(el);
      if (r.width < W * 0.8 || r.height < 24 || r.right <= 0 || r.left >= W) return;
      var cs = getComputedStyle(el);
      if (cs.borderTopLeftRadius !== '0px' || cs.borderBottomLeftRadius !== '0px') return;
      if (alpha(cs.backgroundColor) < 0.8) return;
      if (el.closest(SKIP)) return;
      var isBar = r.height < H * 0.3 && (r.top <= 2 || r.top > H * 0.5);
      el.setAttribute('data-fc-glass', isBar ? 'bar' : 'clear');
    });
  }

  // ---------- 2. fade the transcript at the header and composer ----------

  // Walk up from each bottom bar to its scroll container; every *preceding*
  // sibling along the way is scrolling content. Mask those (and only those),
  // so the composer itself is never faded.
  function updateFade() {
    var H = innerHeight, targets = new Set(), fadeBottom = Infinity, headerBottom = -10000;

    document.querySelectorAll('[data-fc-glass=bar]').forEach(function (b) {
      var r = b.getBoundingClientRect();
      if (r.top <= 2) { headerBottom = Math.max(headerBottom, r.bottom); return; }
      if (r.top <= H * 0.5) return;
      fadeBottom = Math.min(fadeBottom, r.top);
      var sc = scrollerOf(b);
      if (!sc) return;
      for (var node = b; node && node !== sc; node = node.parentElement) {
        for (var sib = node.previousElementSibling; sib; sib = sib.previousElementSibling) {
          if (sib.matches('[data-fc-glass=bar]') || sib.querySelector('[data-fc-glass=bar],[contenteditable]')) continue;
          // Floating overlays (e.g. the "scroll to bottom" button) aren't content.
          var pos = getComputedStyle(sib).position;
          if (pos === 'absolute' || pos === 'fixed' || pos === 'sticky') continue;
          targets.add(sib);
        }
      }
    });

    var ed = document.querySelector('[contenteditable="true"]');
    if (ed && fadeBottom !== Infinity) {
      var box = ed.closest('[class*="rounded"]') || ed;
      fadeBottom = Math.min(fadeBottom, box.getBoundingClientRect().top);
    }

    document.querySelectorAll('[data-fc-fade]').forEach(function (el) {
      if (targets.has(el)) return;
      el.removeAttribute('data-fc-fade');
      el.style.removeProperty('--fc-mt');
      el.style.removeProperty('--fc-mb');
    });

    targets.forEach(function (el) {
      var r = el.getBoundingClientRect();
      setVar(el, '--fc-mt', Math.round(headerBottom - r.top) + 'px');
      // End the fade a little *under* the composer's top edge (hidden by the
      // opaque composer) so content dissolves right into it with no gap.
      setVar(el, '--fc-mb', (fadeBottom === Infinity ? 99999 : Math.round(fadeBottom + 10 - r.top)) + 'px');
      if (!el.hasAttribute('data-fc-fade')) el.setAttribute('data-fc-fade', '');
    });
  }

  // ---------- 3. remove the header divider ----------

  // The line can be the element's own border-bottom or a ::before/::after.
  function removeHeaderLine() {
    var W = innerWidth, headerBottom = -1;
    document.querySelectorAll('[data-fc-glass=bar]').forEach(function (b) {
      var r = b.getBoundingClientRect();
      if (r.top <= 2) headerBottom = Math.max(headerBottom, r.bottom);
    });
    if (headerBottom < 0) return;
    document.querySelectorAll('body div, body header, body nav').forEach(function (el) {
      if (el.hasAttribute('data-fc-noline')) return;
      var r = el.getBoundingClientRect();
      if (r.width < W * 0.8 || Math.abs(r.bottom - headerBottom) > 2 || r.top > headerBottom) return;
      var cs = getComputedStyle(el);
      var hasLine = parseFloat(cs.borderBottomWidth) > 0 || (cs.boxShadow && cs.boxShadow !== 'none');
      ['::before', '::after'].forEach(function (p) {
        var pc = getComputedStyle(el, p);
        if (pc.content !== 'none' && parseFloat(pc.borderBottomWidth) > 0) hasLine = true;
      });
      if (hasLine) el.setAttribute('data-fc-noline', '');
    });
  }

  // ---------- 4. sidebar overlay ----------

  // In a narrow window the sidebar slides *over* the conversation. When it
  // covers the window, flag <html> so CSS fades the conversation out.
  function updateSidebar() {
    var W = innerWidth;
    var sb = document.querySelector('.dframe-sidebar-body'), pane = document.querySelector('.dframe-pane');
    var covering = false;
    if (sb && pane && !sb.contains(pane) && !pane.contains(sb)) {
      covering = !sb.hasAttribute('inert') &&
                 getComputedStyle(sb).visibility !== 'hidden' &&
                 sb.getBoundingClientRect().width >= W * 0.8;
    }
    var h = document.documentElement;
    if (covering !== h.hasAttribute('data-fc-sb-open')) {
      if (covering) h.setAttribute('data-fc-sb-open', '');
      else h.removeAttribute('data-fc-sb-open');
    }
  }

  // ---------- 5. report theme / ready to native ----------

  // Bright body text means a dark theme.
  var lastTheme = '';
  function reportTheme() {
    if (!document.body) return;
    var l = lightness(getComputedStyle(document.body).color);
    if (l < 0) return;
    var t = l > 0.5 ? 'dark' : 'light';
    if (t !== lastTheme) { lastTheme = t; post('theme:' + t); }
  }

  // The native side keeps the web view hidden until this fires, so users
  // never see the page flash opaque before turning to glass.
  var ready = false;
  function reportReady() {
    if (!ready && document.querySelector('[data-fc-glass]') && document.querySelector('main, [contenteditable]')) {
      ready = true;
      post('ready');
    }
  }

  // ---------- scheduling ----------

  function sweep() {
    tagLayers();
    updateFade();
    removeHeaderLine();
    reportTheme();
    updateSidebar();
    reportReady();
  }

  // Run right before the next paint, so new opaque layers never get a frame
  // on screen.
  var pending = false;
  function soon() {
    if (pending) return;
    pending = true;
    requestAnimationFrame(function () { pending = false; sweep(); });
  }

  new MutationObserver(function (list) {
    var relevant = false;
    list.forEach(function (m) {
      if (m.type === 'attributes') {
        var t = m.target;
        // Ignore style writes we made ourselves.
        if (t.hasAttribute && (t.hasAttribute('data-fc-glass') || t.hasAttribute('data-fc-fade') || t.hasAttribute('data-fc-noline'))) return;
        checked.delete(t);
      }
      relevant = true;
    });
    if (relevant) soon();
  }).observe(document.documentElement, {
    childList: true, subtree: true, attributes: true,
    attributeFilter: ['class', 'style', 'data-mode', 'inert']
  });

  addEventListener('resize', function () { checked = new WeakSet(); soon(); });
  // Sidebar open/close is animated; re-check once the animation settles.
  document.addEventListener('transitionend', soon, true);
  document.addEventListener('animationend', soon, true);

  // Fade positions depend on scroll offset; update them every scroll frame
  // (cheap: only touches a handful of elements).
  var fadePending = false;
  addEventListener('scroll', function () {
    if (fadePending) return;
    fadePending = true;
    requestAnimationFrame(function () { fadePending = false; updateFade(); });
  }, { capture: true, passive: true });

  document.addEventListener('DOMContentLoaded', sweep);
})();
