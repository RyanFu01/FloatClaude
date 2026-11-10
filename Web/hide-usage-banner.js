/*
 * FloatClaude — hide the "You've used 83% of your weekly limit" reminder.
 * Only the percentage reminder is hidden; the message shown when you
 * actually hit the limit uses different wording and is left alone.
 */
(function () {
  var re = /used \d+% of your .*limit/i;
  function sweep() {
    document.querySelectorAll('[class*="rounded-composer"]').forEach(function (el) {
      if (el.style.display !== 'none' && re.test(el.textContent || '')) el.style.display = 'none';
    });
  }
  new MutationObserver(sweep).observe(document.documentElement, { childList: true, subtree: true });
  document.addEventListener('DOMContentLoaded', sweep);
})();
