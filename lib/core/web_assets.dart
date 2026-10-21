// The single self-contained web page served at `GET /` (DESIGN.md 4).
//
// Rules for this file (checked by test/web_test.dart):
// - no external requests: no absolute http(s) URLs anywhere in the asset;
// - user-controlled text (file names, sizes, codes, server messages) is only
//   ever put into the DOM with textContent / attributes, never as markup;
// - works without a secure context (plain HTTP listener): no clipboard API,
//   no service worker, no crypto.subtle.

/// The page. A raw string, so `$` is not interpolated.
const String webPageHtml = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<meta name="color-scheme" content="light dark">
<title>LanDrop</title>
<style>
:root {
  --bg: #f6f8f7; --card: #ffffff; --fg: #17201e; --muted: #4f5e5a;
  --accent: #00695c; --accent-fg: #ffffff; --border: #c9d3d0;
  --error: #b3261e; --ok: #1b5e20; --drop: #e6f2ef;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #101413; --card: #1a201e; --fg: #e3e9e7; --muted: #a9b6b2;
    --accent: #4db6ac; --accent-fg: #00201c; --border: #3a4542;
    --error: #ffb4ab; --ok: #a5d6a7; --drop: #1f2b28;
  }
}
* { box-sizing: border-box; }
[hidden] { display: none !important; }
html { -webkit-text-size-adjust: 100%; }
body {
  margin: 0; background: var(--bg); color: var(--fg);
  font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
}
main, header { max-width: 680px; margin: 0 auto; padding: 0 16px; }
header { padding-top: 20px; }
h1 { font-size: 1.5rem; margin: 0; }
h2 { font-size: 1.15rem; margin: 0 0 8px; }
section {
  background: var(--card); border: 1px solid var(--border);
  border-radius: 12px; padding: 16px; margin: 16px 0;
}
.muted { color: var(--muted); }
.small { font-size: .875rem; }
button, .button {
  display: inline-flex; align-items: center; justify-content: center;
  min-height: 44px; padding: 0 18px; border-radius: 22px; border: 0;
  background: var(--accent); color: var(--accent-fg); font: inherit;
  font-weight: 600; text-decoration: none; cursor: pointer;
}
button.secondary, .button.secondary {
  background: transparent; color: var(--accent);
  border: 1px solid var(--accent);
}
button:disabled { opacity: .5; cursor: default; }
:focus-visible { outline: 3px solid var(--accent); outline-offset: 2px; }
.code {
  font-size: 2.5rem; font-weight: 700; letter-spacing: .3em;
  font-variant-numeric: tabular-nums; margin: 8px 0;
}
.drop {
  display: block; border: 2px dashed var(--border); border-radius: 12px;
  padding: 24px 16px; text-align: center; background: var(--drop);
  cursor: pointer; margin-bottom: 12px;
}
.drop.over { border-color: var(--accent); }
.drop input {
  position: absolute; width: 1px; height: 1px; opacity: 0; overflow: hidden;
}
.files { list-style: none; margin: 8px 0 0; padding: 0; }
.files li { border-top: 1px solid var(--border); padding: 10px 0; }
.row { display: flex; gap: 12px; align-items: baseline; }
.name { flex: 1; min-width: 0; overflow-wrap: anywhere; }
.actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 8px; }
progress { width: 100%; height: 10px; margin-top: 6px; accent-color: var(--accent); }
.preview { display: block; max-width: 100%; max-height: 70vh; margin-top: 8px; border-radius: 8px; }
audio.preview { width: 100%; }
.error { color: var(--error); }
.ok { color: var(--ok); }
</style>
</head>
<body>
<header>
  <h1>LanDrop</h1>
  <p id="device" class="muted"></p>
</header>
<main>
  <section id="shared" hidden aria-labelledby="shared-h">
    <h2 id="shared-h">Shared with you</h2>
    <p id="shared-status" class="muted" role="status" aria-live="polite">Loading…</p>
    <ul id="shared-list" class="files"></ul>
  </section>

  <section id="send" aria-labelledby="send-h">
    <h2 id="send-h">Send files to this device</h2>
    <div id="pair">
      <p class="muted">First the device owner has to allow this browser.</p>
      <button id="pair-btn" type="button">Pair this browser</button>
      <div id="pair-code-box" hidden>
        <p>Check that the device shows this code, then the owner approves it there:</p>
        <p id="pair-code" class="code" aria-label="Pairing code"></p>
      </div>
      <p id="pair-status" role="status" aria-live="polite"></p>
    </div>
    <div id="upload" hidden>
      <label id="drop" class="drop" for="file-input">
        <span>Choose files, or drop them here</span>
        <input id="file-input" type="file" multiple>
      </label>
      <button id="send-btn" type="button" disabled>Send</button>
      <p id="upload-status" role="status" aria-live="polite"></p>
      <ul id="upload-list" class="files" aria-label="Files to send"></ul>
    </div>
  </section>
</main>
<script>
(function () {
  'use strict';
  var API = '/api/landrop/v1';
  var sessionToken = null; // also kept by the browser as an HttpOnly cookie
  var picked = [];
  var busy = false;

  function $(id) { return document.getElementById(id); }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = String(text);
    return e;
  }
  function setText(id, text, cls) {
    var e = $(id);
    e.textContent = text || '';
    if (cls !== undefined) e.className = cls;
  }
  function fmt(n) {
    if (typeof n !== 'number' || !isFinite(n)) return '';
    if (n < 1024) return n + ' B';
    var u = ['KB', 'MB', 'GB', 'TB'], i = -1;
    do { n = n / 1024; i++; } while (n >= 1024 && i < u.length - 1);
    return n.toFixed(n >= 100 ? 0 : 1) + ' ' + u[i];
  }
  function baseName(p) {
    var parts = String(p).split('/');
    return parts[parts.length - 1] || 'file';
  }
  function call(method, url, body, done, onProgress) {
    var x = new XMLHttpRequest();
    x.open(method, url);
    if (sessionToken) x.setRequestHeader('Authorization', 'Bearer ' + sessionToken);
    var payload = null;
    if (body instanceof Blob) {
      payload = body;
    } else if (body !== undefined && body !== null) {
      x.setRequestHeader('Content-Type', 'application/json');
      payload = JSON.stringify(body);
    }
    if (onProgress && x.upload) x.upload.onprogress = onProgress;
    x.onload = function () {
      var j = null;
      try { j = JSON.parse(x.responseText); } catch (e) { j = null; }
      done(x.status, j);
    };
    x.onerror = function () { done(0, null); };
    x.send(payload);
    return x;
  }

  // ---------------------------------------------------------------- device
  call('GET', API + '/web/info', null, function (st, j) {
    if (st === 200 && j && typeof j.alias === 'string') {
      setText('device', 'Connected to ' + j.alias);
    }
  });

  // ---------------------------------------------------------------- shares
  function shareToken() {
    var m = /(?:^#|&)s=([A-Za-z0-9_-]{16,64})(?:&|$)/.exec(location.hash);
    return m ? m[1] : null;
  }
  function previewKind(mime) {
    if (/^image\/(png|jpeg|gif|webp|avif|bmp)$/.test(mime)) return 'img';
    if (/^video\//.test(mime)) {
      return document.createElement('video').canPlayType(mime) ? 'video' : null;
    }
    if (/^audio\//.test(mime)) {
      return document.createElement('audio').canPlayType(mime) ? 'audio' : null;
    }
    if (mime === 'application/pdf' || mime === 'text/plain') return 'open';
    return null;
  }
  function fileItem(token, f) {
    var li = el('li');
    var url = API + '/shares/' + encodeURIComponent(token) + '/files/' +
        encodeURIComponent(f.id);
    var row = el('div', 'row');
    row.appendChild(el('span', 'name', f.name));
    row.appendChild(el('span', 'muted small', fmt(f.size)));
    li.appendChild(row);
    var actions = el('div', 'actions');
    var a = el('a', 'button', 'Download');
    a.href = url;
    a.rel = 'noreferrer';
    a.setAttribute('download', baseName(f.name));
    a.setAttribute('aria-label', 'Download ' + f.name);
    actions.appendChild(a);
    var kind = previewKind(String(f.mime || ''));
    if (kind === 'open') {
      var o = el('a', 'button secondary', 'Open');
      o.href = url + '?inline=1';
      o.target = '_blank';
      o.rel = 'noopener noreferrer';
      o.setAttribute('aria-label', 'Open ' + f.name);
      actions.appendChild(o);
    } else if (kind) {
      var b = el('button', 'secondary', kind === 'img' ? 'Show' : 'Play');
      b.type = 'button';
      b.setAttribute('aria-label', (kind === 'img' ? 'Show ' : 'Play ') + f.name);
      b.addEventListener('click', function () {
        b.disabled = true;
        var m = el(kind, 'preview');
        if (kind === 'img') {
          m.alt = f.name;
        } else {
          m.controls = true;
          m.preload = 'metadata';
          m.setAttribute('aria-label', f.name);
        }
        m.src = url + '?inline=1';
        li.appendChild(m);
        if (kind !== 'img' && m.play) {
          var p = m.play();
          if (p && p.catch) p.catch(function () {});
        }
      });
      actions.appendChild(b);
    }
    li.appendChild(actions);
    return li;
  }
  function loadShare(token) {
    $('shared').hidden = false;
    call('GET', API + '/shares/' + encodeURIComponent(token), null, function (st, j) {
      var list = $('shared-list');
      list.textContent = '';
      if (st !== 200 || !j || !j.files || !j.files.length) {
        setText('shared-status', st === 429
          ? 'Too many attempts. Wait a minute, then reload.'
          : 'This link does not work any more. It may have expired, reached its download limit, or the owner stopped sharing.',
          'error');
        return;
      }
      var parts = [j.files.length + (j.files.length === 1 ? ' file' : ' files')];
      if (typeof j.expiresIn === 'number') {
        var mins = Math.max(1, Math.round(j.expiresIn / 60));
        parts.push(mins >= 120 ? 'available for ' + Math.round(mins / 60) + ' more hours'
                               : 'available for ' + mins + ' more min');
      }
      if (typeof j.downloadsLeft === 'number') {
        parts.push(j.downloadsLeft + (j.downloadsLeft === 1 ? ' download left' : ' downloads left'));
      }
      setText('shared-status', parts.join(' · '), 'muted');
      for (var i = 0; i < j.files.length; i++) list.appendChild(fileItem(token, j.files[i]));
    });
  }
  var st0 = shareToken();
  if (st0) loadShare(st0);

  // ---------------------------------------------------------------- pairing
  function showUpload() {
    $('pair').hidden = true;
    $('upload').hidden = false;
  }
  function showPair(msg) {
    sessionToken = null;
    $('upload').hidden = true;
    $('pair').hidden = false;
    $('pair-code-box').hidden = true;
    $('pair-btn').disabled = false;
    setText('pair-status', msg || '', msg ? 'error' : '');
  }
  function poll(id) {
    call('GET', API + '/web/pair/' + encodeURIComponent(id), null, function (st, j) {
      if (st === 200 && j && j.status === 'approved') {
        sessionToken = typeof j.token === 'string' ? j.token : null;
        setText('pair-status', '');
        showUpload();
      } else if (st === 200 && j && j.status === 'pending') {
        poll(id);
      } else if (st === 0) {
        setTimeout(function () { poll(id); }, 2000);
      } else {
        showPair(j && j.status === 'expired'
          ? 'No answer from the device in time. Try again.'
          : (st === 429 ? 'Too many attempts. Wait a minute and try again.'
                        : 'The device did not allow this browser.'));
      }
    });
  }
  $('pair-btn').addEventListener('click', function () {
    var btn = $('pair-btn');
    btn.disabled = true;
    setText('pair-status', 'Asking the device…', '');
    call('POST', API + '/web/pair', {}, function (st, j) {
      if (st === 200 && j && typeof j.id === 'string') {
        setText('pair-code', String(j.code));
        $('pair-code-box').hidden = false;
        setText('pair-status', 'Waiting for the owner to approve…', '');
        poll(j.id);
      } else {
        btn.disabled = false;
        setText('pair-status', st === 429 ? 'Too many attempts. Wait a minute and try again.'
          : st === 409 ? 'A request from this device is already waiting on the owner\'s screen.'
          : st === 0 ? 'Could not reach the device.'
          : 'The device did not accept a pairing request.', 'error');
      }
    });
  });
  call('GET', API + '/web/session', null, function (st) {
    if (st === 200) showUpload(); else showPair();
  });

  // ---------------------------------------------------------------- upload
  function renderPicked() {
    var list = $('upload-list');
    list.textContent = '';
    for (var i = 0; i < picked.length; i++) {
      var f = picked[i];
      var li = el('li');
      var row = el('div', 'row');
      row.appendChild(el('span', 'name', f.file.name));
      f.label = el('span', 'muted small', fmt(f.file.size));
      row.appendChild(f.label);
      li.appendChild(row);
      f.bar = el('progress');
      f.bar.max = 1;
      f.bar.value = 0;
      f.bar.setAttribute('aria-label', 'Progress of ' + f.file.name);
      li.appendChild(f.bar);
      list.appendChild(li);
    }
    $('send-btn').disabled = busy || picked.length === 0;
  }
  function addFiles(fileList) {
    if (busy || !fileList) return;
    picked = [];
    for (var i = 0; i < fileList.length; i++) picked.push({ file: fileList[i] });
    setText('upload-status', picked.length ? picked.length + ' selected' : '', 'muted');
    renderPicked();
  }
  var input = $('file-input');
  input.addEventListener('change', function () { addFiles(input.files); });
  var drop = $('drop');
  ['dragenter', 'dragover'].forEach(function (t) {
    drop.addEventListener(t, function (e) { e.preventDefault(); drop.className = 'drop over'; });
  });
  ['dragleave', 'drop'].forEach(function (t) {
    drop.addEventListener(t, function (e) { e.preventDefault(); drop.className = 'drop'; });
  });
  drop.addEventListener('drop', function (e) {
    if (e.dataTransfer) addFiles(e.dataTransfer.files);
  });
  function finish(msg, cls) {
    busy = false;
    setText('upload-status', msg, cls);
    $('send-btn').disabled = picked.length === 0;
    input.disabled = false;
  }
  function uploadNext(sessionId, tokens, i, okCount) {
    if (i >= picked.length) {
      finish('Sent ' + okCount + ' of ' + picked.length + ' file(s).', 'ok');
      return;
    }
    var f = picked[i];
    var t = tokens[String(i)];
    if (typeof t !== 'string') { f.label.textContent = 'skipped'; uploadNext(sessionId, tokens, i + 1, okCount); return; }
    var q = '?sessionId=' + encodeURIComponent(sessionId) + '&fileId=' + encodeURIComponent(String(i)) +
        '&token=' + encodeURIComponent(t);
    setText('upload-status', 'Sending ' + (i + 1) + ' of ' + picked.length + '…', 'muted');
    call('POST', API + '/web/upload' + q, f.file, function (st) {
      if (st === 200) {
        f.bar.value = 1;
        f.label.textContent = 'done';
        uploadNext(sessionId, tokens, i + 1, okCount + 1);
      } else if (st === 401) {
        showPair('Pairing expired. Pair this browser again.');
        finish('', '');
      } else {
        f.label.textContent = 'failed';
        f.label.className = 'error small';
        finish(st === 0 ? 'The connection was lost.' : 'Sending stopped (error ' + st + ').', 'error');
      }
    }, function (e) {
      if (e.lengthComputable && e.total > 0) {
        f.bar.value = e.loaded / e.total;
        f.label.textContent = fmt(e.loaded) + ' / ' + fmt(e.total);
      }
    });
  }
  $('send-btn').addEventListener('click', function () {
    if (busy || picked.length === 0) return;
    busy = true;
    $('send-btn').disabled = true;
    input.disabled = true;
    var files = [];
    for (var i = 0; i < picked.length; i++) {
      var f = picked[i].file;
      files.push({ id: String(i), fileName: f.name, size: f.size,
                   fileType: f.type || 'application/octet-stream' });
    }
    setText('upload-status', 'Waiting for the owner to accept…', 'muted');
    call('POST', API + '/web/upload-prepare', { files: files }, function (st, j) {
      if (st === 200 && j && typeof j.sessionId === 'string' && j.files) {
        uploadNext(j.sessionId, j.files, 0, 0);
      } else if (st === 401) {
        showPair('Pairing expired. Pair this browser again.');
        finish('', '');
      } else {
        finish(st === 403 ? 'The owner declined the files.'
          : st === 409 ? 'The device is busy with another transfer. Try again shortly.'
          : st === 429 ? 'Too many attempts. Wait a minute and try again.'
          : st === 0 ? 'Could not reach the device.'
          : 'Could not start sending (error ' + st + ').', 'error');
      }
    });
  });
})();
</script>
</body>
</html>
''';
