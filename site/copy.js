// A copy button on each command box (<pre class="cmd">): an icon on the box's right edge that
// copies the command and shows a check mark for two seconds. The word ("Copy", "複製") is only
// its tooltip and its name for screen readers, in the page's language. Without JavaScript the
// boxes stay as they are, and the command can still be selected by hand.
(function () {
  var zh = document.documentElement.lang.indexOf('zh') === 0;
  var label = zh ? '複製' : 'Copy';
  var done = zh ? '已複製' : 'Copied';
  var failed = zh ? '無法複製，請手動選取' : 'Could not copy: select it by hand';

  var SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">';
  var copyIcon = SVG + '<rect x="9" y="9" width="12" height="12" rx="2"/>' +
    '<path d="M5 15H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1"/></svg>';
  var doneIcon = SVG + '<path d="M4 12.5l5 5L20 6.5"/></svg>';

  function copy(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    // Older browsers, or a page opened from a file: a hidden text area and the copy command.
    return new Promise(function (resolve, reject) {
      var area = document.createElement('textarea');
      area.value = text;
      area.setAttribute('readonly', '');
      area.style.position = 'fixed';
      area.style.opacity = '0';
      document.body.appendChild(area);
      area.select();
      var ok = false;
      try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
      document.body.removeChild(area);
      if (ok) { resolve(); } else { reject(); }
    });
  }

  function show(button, icon, words) {
    button.innerHTML = icon;
    button.title = words;
    button.setAttribute('aria-label', words);
  }

  var boxes = document.querySelectorAll('pre.cmd');
  for (var i = 0; i < boxes.length; i++) {
    (function (pre) {
      var text = pre.textContent.trim();
      var button = document.createElement('button');
      button.type = 'button';
      button.className = 'copy';
      show(button, copyIcon, label);
      var timer = null;
      button.addEventListener('click', function () {
        copy(text).then(function () {
          show(button, doneIcon, done);
        }, function () {
          show(button, copyIcon, failed);
        }).then(function () {
          clearTimeout(timer);
          timer = setTimeout(function () { show(button, copyIcon, label); }, 2000);
        });
      });
      pre.appendChild(button);
    })(boxes[i]);
  }
})();
