// A Copy button on each command box (<pre class="cmd">): copies the command, then says so for
// two seconds. The labels follow the page's language. Without JavaScript the boxes stay as
// they are, and the command can still be selected by hand.
(function () {
  var zh = document.documentElement.lang.indexOf('zh') === 0;
  var label = zh ? '複製' : 'Copy';
  var done = zh ? '已複製' : 'Copied';
  var failed = zh ? '請手動選取' : 'Select it';

  function copy(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    // Older browsers: a hidden text area and the copy command.
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

  var boxes = document.querySelectorAll('pre.cmd');
  for (var i = 0; i < boxes.length; i++) {
    (function (pre) {
      var text = pre.textContent.trim();
      var button = document.createElement('button');
      button.type = 'button';
      button.className = 'copy';
      button.textContent = label;
      button.setAttribute('aria-label', label + ': ' + text);
      var timer = null;
      button.addEventListener('click', function () {
        copy(text).then(function () {
          button.textContent = done;
        }, function () {
          button.textContent = failed;
        }).then(function () {
          clearTimeout(timer);
          timer = setTimeout(function () { button.textContent = label; }, 2000);
        });
      });
      pre.appendChild(button);
    })(boxes[i]);
  }
})();
