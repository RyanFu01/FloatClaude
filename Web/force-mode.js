/*
 * FloatClaude — pin claude.ai's theme.
 * claude.ai switches themes via <html data-mode="light|dark">. When the user
 * picks Light or Dark in FloatClaude, keep that attribute pinned even if the
 * page tries to change it. `window.__fcMode` is set by the native side
 * ('system' | 'light' | 'dark') right before this script runs.
 */
(function () {
  function apply() {
    var h = document.documentElement;
    if (window.__fcMode !== 'system' && h.getAttribute('data-mode') !== window.__fcMode) {
      h.setAttribute('data-mode', window.__fcMode);
    }
  }
  apply();
  if (!window.__fcModeObs) {
    window.__fcModeObs = new MutationObserver(apply);
    window.__fcModeObs.observe(document.documentElement, { attributes: true, attributeFilter: ['data-mode'] });
  }
})();
