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
.top { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.lang { min-width: 44px; padding: 0 12px; }
html:lang(fa) body { font-family: Tahoma, "Segoe UI", system-ui, -apple-system, sans-serif; }
body { text-align: start; }
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
  direction: ltr; unicode-bidi: isolate; text-align: start;
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
.name { flex: 1; min-width: 0; overflow-wrap: anywhere; unicode-bidi: isolate; text-align: start; }
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
  <div class="top">
    <h1>LanDrop</h1>
    <button id="lang-btn" class="secondary lang" type="button" data-ta="langLabel" aria-label="Change language">فا</button>
  </div>
  <p id="device" class="muted"></p>
</header>
<main>
  <section id="shared" hidden aria-labelledby="shared-h">
    <h2 id="shared-h" data-t="sharedWithYou">Shared with you</h2>
    <p id="shared-status" class="muted" role="status" aria-live="polite" data-t="loading">Loading…</p>
    <ul id="shared-list" class="files"></ul>
  </section>

  <section id="nearby" hidden aria-labelledby="nearby-h">
    <h2 id="nearby-h" data-t="nearbyTitle">Shared with this browser</h2>
    <p id="nearby-none" class="muted" hidden data-t="nearbyNone">Nothing shared yet</p>
    <ul id="nearby-list" class="files"></ul>
    <div class="actions">
      <button id="nearby-refresh" class="secondary" type="button" data-t="nearbyRefresh">Refresh</button>
    </div>
  </section>

  <section id="send" aria-labelledby="send-h">
    <h2 id="send-h" data-t="sendTitle">Send files to this device</h2>
    <div id="pair">
      <p class="muted" data-t="pairFirst">First the device owner has to allow this browser.</p>
      <button id="pair-btn" type="button" data-t="pairBtn">Pair this browser</button>
      <div id="pair-code-box" hidden>
        <p data-t="pairCheck">Check that the device shows this code, then the owner approves it there:</p>
        <p id="pair-code" class="code" dir="ltr" data-ta="pairCodeLabel" aria-label="Pairing code"></p>
      </div>
      <p id="pair-status" role="status" aria-live="polite"></p>
    </div>
    <div id="upload" hidden>
      <label id="drop" class="drop" for="file-input">
        <span data-t="chooseFiles">Choose files, or drop them here</span>
        <input id="file-input" type="file" multiple>
      </label>
      <button id="send-btn" type="button" data-t="send" disabled>Send</button>
      <p id="upload-status" role="status" aria-live="polite"></p>
      <ul id="upload-list" class="files" data-ta="filesToSend" aria-label="Files to send"></ul>
      <div class="actions">
        <button id="signout-btn" class="secondary" type="button" data-t="signOut">Sign out</button>
      </div>
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

  // ------------------------------------------------------------ dictionary
  // Every user-visible string of the page lives here. {0}, {1} are filled by
  // tr(); numbers passed as arguments are formatted by fmtNum().
  // REVIEW: Persian wording below is a first draft for native review:
  // pairBtn / pairCheck ("اتصال" for "pair"), pairCodeLabel ("کد اتصال"),
  // signOut ("خروج"), linkDead (long sentence), unpaired ("وصلش کنید" is
  // colloquial, maybe "دوباره متصل کنید"), the unit names in `units`
  // (کیلوبایت etc. versus KB), and "لینک" versus "پیوند".
  var T = {
    en: {
      sharedWithYou: 'Shared with you',
      nearbyTitle: 'Shared with this browser',
      nearbyNone: 'Nothing shared yet',
      nearbyPlay: 'Play',
      nearbyDownload: 'Download',
      nearbyRefresh: 'Refresh',
      loading: 'Loading…',
      sendTitle: 'Send files to this device',
      pairFirst: 'First the device owner has to allow this browser.',
      pairBtn: 'Pair this browser',
      pairCheck: 'Check that the device shows this code, then the owner approves it there:',
      pairCodeLabel: 'Pairing code',
      chooseFiles: 'Choose files, or drop them here',
      send: 'Send',
      signOut: 'Sign out',
      filesToSend: 'Files to send',
      langLabel: 'Change language',
      connectedTo: 'Connected to {0}',
      tooManyReload: 'Too many attempts. Wait a minute, then reload.',
      tooMany: 'Too many attempts. Wait a minute and try again.',
      linkDead: 'This link does not work any more. It may have expired, reached its download limit, or the owner stopped sharing.',
      files1: '{0} file',
      filesN: '{0} files',
      availHours: 'available for {0} more hours',
      availMin: 'available for {0} more min',
      dl1: '{0} download left',
      dlN: '{0} downloads left',
      downloadBtn: 'Download',
      openBtn: 'Open',
      showBtn: 'Show',
      playBtn: 'Play',
      ariaDownload: 'Download {0}',
      ariaOpen: 'Open {0}',
      ariaShow: 'Show {0}',
      ariaPlay: 'Play {0}',
      progressOf: 'Progress of {0}',
      pairExpired: 'No answer from the device in time. Try again.',
      pairDenied: 'The device did not allow this browser.',
      pairAsking: 'Asking the device…',
      pairWaiting: 'Waiting for the owner to approve…',
      pairConflict: 'A request from this device is already waiting on the owner\'s screen.',
      unreachable: 'Could not reach the device.',
      pairRejected: 'The device did not accept a pairing request.',
      signedOut: 'Signed out. This browser can no longer send files until it is paired again.',
      signoutFail: 'Could not sign out (error {0}).',
      selected: '{0} selected',
      skipped: 'skipped',
      done: 'done',
      failed: 'failed',
      sentOf: 'Sent {0} of {1} file(s).',
      sendingOf: 'Sending {0} of {1}…',
      unpaired: 'This browser is no longer paired (it expired or the owner disconnected it). Pair it again.',
      lost: 'The connection was lost.',
      stopped: 'Sending stopped (error {0}).',
      waitAccept: 'Waiting for the owner to accept…',
      declined: 'The owner declined the files.',
      busyDev: 'The device is busy with another transfer. Try again shortly.',
      startFail: 'Could not start sending (error {0}).',
      units: 'B,KB,MB,GB,TB'
    },
    fa: {
      sharedWithYou: 'به اشتراک گذاشته شده با شما',
      nearbyTitle: 'به اشتراک گذاشته‌شده با این مرورگر',
      nearbyNone: 'هنوز چیزی به اشتراک گذاشته نشده',
      nearbyPlay: 'پخش',
      nearbyDownload: 'دانلود',
      nearbyRefresh: 'تازه‌سازی',
      loading: 'در حال بارگذاری…',
      sendTitle: 'ارسال فایل به این دستگاه',
      pairFirst: 'ابتدا صاحب دستگاه باید به این مرورگر اجازه بدهد.',
      pairBtn: 'اتصال این مرورگر',
      pairCheck: 'مطمئن شوید دستگاه همین کد را نشان می‌دهد؛ سپس صاحب دستگاه آن را همان‌جا تأیید می‌کند:',
      pairCodeLabel: 'کد اتصال',
      chooseFiles: 'فایل‌ها را انتخاب کنید یا اینجا رها کنید',
      send: 'ارسال',
      signOut: 'خروج',
      filesToSend: 'فایل‌های آمادهٔ ارسال',
      langLabel: 'تغییر زبان',
      connectedTo: 'متصل به {0}',
      tooManyReload: 'تعداد تلاش‌ها زیاد بود. یک دقیقه صبر کنید و صفحه را دوباره باز کنید.',
      tooMany: 'تعداد تلاش‌ها زیاد بود. یک دقیقه صبر کنید و دوباره امتحان کنید.',
      linkDead: 'این لینک دیگر کار نمی‌کند. ممکن است منقضی شده باشد، به سقف دانلود رسیده باشد یا صاحب آن اشتراک‌گذاری را متوقف کرده باشد.',
      files1: '{0} فایل',
      filesN: '{0} فایل',
      availHours: 'تا {0} ساعت دیگر در دسترس است',
      availMin: 'تا {0} دقیقه دیگر در دسترس است',
      dl1: '{0} بار دانلود باقی مانده',
      dlN: '{0} بار دانلود باقی مانده',
      downloadBtn: 'دانلود',
      openBtn: 'باز کردن',
      showBtn: 'نمایش',
      playBtn: 'پخش',
      ariaDownload: 'دانلود {0}',
      ariaOpen: 'باز کردن {0}',
      ariaShow: 'نمایش {0}',
      ariaPlay: 'پخش {0}',
      progressOf: 'پیشرفت {0}',
      pairExpired: 'دستگاه به موقع پاسخ نداد. دوباره امتحان کنید.',
      pairDenied: 'دستگاه به این مرورگر اجازه نداد.',
      pairAsking: 'در حال پرسیدن از دستگاه…',
      pairWaiting: 'در انتظار تأیید صاحب دستگاه…',
      pairConflict: 'درخواستی از این مرورگر هم‌اکنون روی صفحهٔ صاحب دستگاه منتظر است.',
      unreachable: 'به دستگاه وصل نشد.',
      pairRejected: 'دستگاه درخواست اتصال را نپذیرفت.',
      signedOut: 'خارج شدید. این مرورگر تا اتصال دوباره نمی‌تواند فایل بفرستد.',
      signoutFail: 'خروج انجام نشد (خطای {0}).',
      selected: '{0} فایل انتخاب شد',
      skipped: 'رد شد',
      done: 'انجام شد',
      failed: 'ناموفق',
      sentOf: '{0} از {1} فایل ارسال شد.',
      sendingOf: 'در حال ارسال {0} از {1}…',
      unpaired: 'اتصال این مرورگر دیگر معتبر نیست (منقضی شده یا صاحب دستگاه آن را قطع کرده). دوباره آن را متصل کنید.',
      lost: 'ارتباط قطع شد.',
      stopped: 'ارسال متوقف شد (خطای {0}).',
      waitAccept: 'در انتظار پذیرفتن فایل‌ها توسط صاحب دستگاه…',
      declined: 'صاحب دستگاه فایل‌ها را نپذیرفت.',
      busyDev: 'دستگاه با انتقال دیگری مشغول است. کمی بعد دوباره امتحان کنید.',
      startFail: 'ارسال شروع نشد (خطای {0}).',
      units: 'بایت,کیلوبایت,مگابایت,گیگابایت,ترابایت'
    }
  };

  // ------------------------------------------------------------ language
  var lang = 'en';
  try {
    var saved = localStorage.getItem('landrop-lang');
    if (saved === 'fa' || saved === 'en') lang = saved;
    else lang = /^fa/i.test(navigator.language || '') ? 'fa' : 'en';
  } catch (e) {
    lang = /^fa/i.test(navigator.language || '') ? 'fa' : 'en';
  }

  function fmtNum(v) {
    var s = String(v);
    if (lang !== 'fa') return s;
    return s.replace(/[0-9]/g, function (d) {
      return String.fromCharCode(0x06F0 + Number(d));
    }).replace('.', '\u066B');
  }
  function tr(key, args) {
    var s = T[lang][key];
    if (s === undefined) s = T.en[key];
    if (s === undefined) return key;
    return s.replace(/\{(\d)\}/g, function (m, i) {
      var a = args ? args[Number(i)] : '';
      return typeof a === 'number' ? fmtNum(a) : String(a === undefined ? '' : a);
    });
  }
  function t(key) { return tr(key, null); }
  // Plural: keys base + '1' (exactly one) and base + 'N'.
  function tn(base, n) { return base + (n === 1 ? '1' : 'N'); }
  // First-strong isolate, so a file name cannot reorder the text around it.
  function iso(s) { return '\u2068' + s + '\u2069'; }

  function $(id) { return document.getElementById(id); }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = String(text);
    return e;
  }
  // Text bound to a dictionary key: refreshed when the language changes.
  function tx(e, key, args) {
    e.removeAttribute('data-sz');
    e.setAttribute('data-t', key);
    e._a = args || [];
    e.textContent = tr(key, e._a);
    return e;
  }
  function tel(tag, cls, key, args) { return tx(el(tag, cls), key, args); }
  // aria-label bound to a dictionary key.
  function ax(e, key, args) {
    e.setAttribute('data-ta', key);
    e._aa = args || [];
    e.setAttribute('aria-label', tr(key, e._aa));
  }
  function fmt(n) {
    if (typeof n !== 'number' || !isFinite(n)) return '';
    var u = t('units').split(',');
    if (n < 1024) return fmtNum(n) + ' ' + u[0];
    var i = 0;
    do { n = n / 1024; i++; } while (n >= 1024 && i < u.length - 1);
    return fmtNum(n.toFixed(n >= 100 ? 0 : 1)) + ' ' + u[i];
  }
  // A size (or "loaded / total") that is re-rendered on language change.
  function sz(e, a, b) {
    e.removeAttribute('data-t');
    e.setAttribute('data-sz', '1');
    e._s = [a, b];
    e.textContent = b === undefined ? fmt(a) : fmt(a) + ' / ' + fmt(b);
    return e;
  }
  // Message area: key null clears it.
  function setMsg(id, key, args, cls) {
    var e = $(id);
    if (key) {
      tx(e, key, args);
    } else {
      e.removeAttribute('data-t');
      e.textContent = '';
    }
    if (cls !== undefined) e.className = cls;
  }
  var alias = null;
  function showAlias() {
    var e = $('device');
    e.textContent = '';
    if (alias === null) return;
    var parts = t('connectedTo').split('{0}');
    e.appendChild(document.createTextNode(parts[0]));
    e.appendChild(el('bdi', '', alias));
    e.appendChild(document.createTextNode(parts[1] || ''));
  }
  function applyLang() {
    var root = document.documentElement;
    root.lang = lang;
    root.dir = lang === 'fa' ? 'rtl' : 'ltr';
    var i, n, list;
    list = document.querySelectorAll('[data-t]');
    for (i = 0; i < list.length; i++) {
      n = list[i];
      n.textContent = tr(n.getAttribute('data-t'), n._a);
    }
    list = document.querySelectorAll('[data-sz]');
    for (i = 0; i < list.length; i++) {
      n = list[i];
      n.textContent = n._s[1] === undefined ? fmt(n._s[0]) : fmt(n._s[0]) + ' / ' + fmt(n._s[1]);
    }
    list = document.querySelectorAll('[data-ta]');
    for (i = 0; i < list.length; i++) {
      n = list[i];
      n.setAttribute('aria-label', tr(n.getAttribute('data-ta'), n._aa));
    }
    showAlias();
    var lb = $('lang-btn');
    lb.textContent = lang === 'fa' ? 'EN' : 'فا';
    lb.lang = lang === 'fa' ? 'en' : 'fa';
  }
  $('lang-btn').addEventListener('click', function () {
    lang = lang === 'fa' ? 'en' : 'fa';
    try { localStorage.setItem('landrop-lang', lang); } catch (e) { /* private mode */ }
    applyLang();
  });
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
      alias = j.alias;
      showAlias();
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
  function nameSpan(name) {
    var s = el('span', 'name', name);
    s.setAttribute('dir', 'auto');
    return s;
  }
  function fileItem(token, f) {
    var li = el('li');
    var url = API + '/shares/' + encodeURIComponent(token) + '/files/' +
        encodeURIComponent(f.id);
    var row = el('div', 'row');
    row.appendChild(nameSpan(f.name));
    row.appendChild(sz(el('span', 'muted small'), f.size));
    li.appendChild(row);
    var actions = el('div', 'actions');
    var a = tel('a', 'button', 'downloadBtn');
    a.href = url;
    a.rel = 'noreferrer';
    a.setAttribute('download', baseName(f.name));
    ax(a, 'ariaDownload', [iso(f.name)]);
    actions.appendChild(a);
    var kind = previewKind(String(f.mime || ''));
    if (kind === 'open') {
      var o = tel('a', 'button secondary', 'openBtn');
      o.href = url + '?inline=1';
      o.target = '_blank';
      o.rel = 'noopener noreferrer';
      ax(o, 'ariaOpen', [iso(f.name)]);
      actions.appendChild(o);
    } else if (kind) {
      var b = tel('button', 'secondary', kind === 'img' ? 'showBtn' : 'playBtn');
      b.type = 'button';
      ax(b, kind === 'img' ? 'ariaShow' : 'ariaPlay', [iso(f.name)]);
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
  // The share summary is a row of bound spans joined by " \u00B7 ".
  function setParts(id, parts, cls) {
    var e = $(id);
    e.removeAttribute('data-t');
    e.textContent = '';
    e.className = cls;
    for (var i = 0; i < parts.length; i++) {
      if (i) e.appendChild(document.createTextNode(' \u00B7 '));
      e.appendChild(tel('span', '', parts[i][0], parts[i][1]));
    }
  }
  function loadShare(token) {
    $('shared').hidden = false;
    call('GET', API + '/shares/' + encodeURIComponent(token), null, function (st, j) {
      var list = $('shared-list');
      list.textContent = '';
      if (st !== 200 || !j || !j.files || !j.files.length) {
        setMsg('shared-status', st === 429 ? 'tooManyReload' : 'linkDead', null, 'error');
        return;
      }
      var parts = [[tn('files', j.files.length), [j.files.length]]];
      if (typeof j.expiresIn === 'number') {
        var mins = Math.max(1, Math.round(j.expiresIn / 60));
        parts.push(mins >= 120 ? ['availHours', [Math.round(mins / 60)]]
                               : ['availMin', [mins]]);
      }
      if (typeof j.downloadsLeft === 'number') {
        parts.push([tn('dl', j.downloadsLeft), [j.downloadsLeft]]);
      }
      setParts('shared-status', parts, 'muted');
      for (var i = 0; i < j.files.length; i++) list.appendChild(fileItem(token, j.files[i]));
    });
  }
  var st0 = shareToken();
  if (st0) loadShare(st0);

  // ---------------------------------------------------------------- nearby
  // Shares the owner offered to paired browsers (cookie session; the file
  // links work in <a download> and <video src>).
  function nearbyItem(shareId, f) {
    var li = el('li');
    var href = API + '/web/nearby/' + encodeURIComponent(shareId) + '/files/' +
        encodeURIComponent(f.id);
    var row = el('div', 'row');
    row.appendChild(nameSpan(f.name));
    row.appendChild(sz(el('span', 'muted small'), f.size));
    li.appendChild(row);
    var actions = el('div', 'actions');
    var a = tel('a', 'button', 'nearbyDownload');
    a.href = href;
    a.rel = 'noreferrer';
    a.setAttribute('download', baseName(f.name));
    ax(a, 'ariaDownload', [iso(f.name)]);
    actions.appendChild(a);
    var mime = String(f.mime || '');
    var kind = /^video\//.test(mime) ? 'video' : /^audio\//.test(mime) ? 'audio' : null;
    if (kind) {
      var b = tel('button', 'secondary', 'nearbyPlay');
      b.type = 'button';
      ax(b, 'ariaPlay', [iso(f.name)]);
      b.addEventListener('click', function () {
        b.disabled = true;
        var m = el(kind, 'preview');
        m.controls = true;
        m.preload = 'metadata';
        m.setAttribute('aria-label', f.name);
        m.src = href + '?inline=1';
        li.appendChild(m);
      });
      actions.appendChild(b);
    }
    li.appendChild(actions);
    return li;
  }
  function loadNearby() {
    call('GET', API + '/web/nearby', null, function (st, j) {
      var sec = $('nearby');
      var list = $('nearby-list');
      var none = $('nearby-none');
      list.textContent = '';
      if (st !== 200 || !j || !j.shares || !j.shares.length) {
        // Stays visible after a refresh that finds nothing (it had shares).
        none.hidden = false;
        if (st !== 200 || sec.hidden) sec.hidden = true;
        return;
      }
      none.hidden = true;
      for (var i = 0; i < j.shares.length; i++) {
        var s = j.shares[i];
        if (!s || typeof s.id !== 'string' || !s.files) continue;
        for (var k = 0; k < s.files.length; k++) list.appendChild(nearbyItem(s.id, s.files[k]));
      }
      sec.hidden = list.children.length === 0;
    });
  }
  $('nearby-refresh').addEventListener('click', loadNearby);

  // ---------------------------------------------------------------- pairing
  function showUpload() {
    $('pair').hidden = true;
    $('upload').hidden = false;
    loadNearby();
  }
  function showPair(key) {
    sessionToken = null;
    $('nearby').hidden = true;
    $('upload').hidden = true;
    $('pair').hidden = false;
    $('pair-code-box').hidden = true;
    $('pair-btn').disabled = false;
    setMsg('pair-status', key || null, null, key ? 'error' : '');
  }
  function poll(id) {
    call('GET', API + '/web/pair/' + encodeURIComponent(id), null, function (st, j) {
      if (st === 200 && j && j.status === 'approved') {
        sessionToken = typeof j.token === 'string' ? j.token : null;
        setMsg('pair-status', null);
        showUpload();
      } else if (st === 200 && j && j.status === 'pending') {
        poll(id);
      } else if (st === 0) {
        setTimeout(function () { poll(id); }, 2000);
      } else {
        showPair(j && j.status === 'expired'
          ? 'pairExpired'
          : (st === 429 ? 'tooMany' : 'pairDenied'));
      }
    });
  }
  $('pair-btn').addEventListener('click', function () {
    var btn = $('pair-btn');
    btn.disabled = true;
    setMsg('pair-status', 'pairAsking', null, '');
    call('POST', API + '/web/pair', {}, function (st, j) {
      if (st === 200 && j && typeof j.id === 'string') {
        // The code is digits that must match the device screen: always Latin.
        $('pair-code').textContent = String(j.code);
        $('pair-code-box').hidden = false;
        setMsg('pair-status', 'pairWaiting', null, '');
        poll(j.id);
      } else {
        btn.disabled = false;
        setMsg('pair-status', st === 429 ? 'tooMany'
          : st === 409 ? 'pairConflict'
          : st === 0 ? 'unreachable'
          : 'pairRejected', null, 'error');
      }
    });
  });
  call('GET', API + '/web/session', null, function (st) {
    if (st === 200) showUpload(); else showPair();
  });
  $('signout-btn').addEventListener('click', function () {
    if (busy) return;
    var btn = $('signout-btn');
    btn.disabled = true;
    // The server ends the session and clears the HttpOnly cookie.
    call('POST', API + '/web/logout', {}, function (st) {
      btn.disabled = false;
      if (st === 200) {
        picked = [];
        renderPicked();
        setMsg('upload-status', null);
        showPair();
        setMsg('pair-status', 'signedOut', null, '');
      } else if (st === 0) {
        setMsg('upload-status', 'unreachable', null, 'error');
      } else {
        setMsg('upload-status', 'signoutFail', [st], 'error');
      }
    });
  });

  // ---------------------------------------------------------------- upload
  function renderPicked() {
    var list = $('upload-list');
    list.textContent = '';
    for (var i = 0; i < picked.length; i++) {
      var f = picked[i];
      var li = el('li');
      var row = el('div', 'row');
      row.appendChild(nameSpan(f.file.name));
      f.label = sz(el('span', 'muted small'), f.file.size);
      row.appendChild(f.label);
      li.appendChild(row);
      f.bar = el('progress');
      f.bar.max = 1;
      f.bar.value = 0;
      ax(f.bar, 'progressOf', [iso(f.file.name)]);
      li.appendChild(f.bar);
      list.appendChild(li);
    }
    $('send-btn').disabled = busy || picked.length === 0;
  }
  function addFiles(fileList) {
    if (busy || !fileList) return;
    picked = [];
    for (var i = 0; i < fileList.length; i++) picked.push({ file: fileList[i] });
    if (picked.length) setMsg('upload-status', 'selected', [picked.length], 'muted');
    else setMsg('upload-status', null, null, 'muted');
    renderPicked();
  }
  var input = $('file-input');
  input.addEventListener('change', function () { addFiles(input.files); });
  var drop = $('drop');
  ['dragenter', 'dragover'].forEach(function (ev) {
    drop.addEventListener(ev, function (e) { e.preventDefault(); drop.className = 'drop over'; });
  });
  ['dragleave', 'drop'].forEach(function (ev) {
    drop.addEventListener(ev, function (e) { e.preventDefault(); drop.className = 'drop'; });
  });
  drop.addEventListener('drop', function (e) {
    if (e.dataTransfer) addFiles(e.dataTransfer.files);
  });
  function finish(key, args, cls) {
    busy = false;
    setMsg('upload-status', key, args, cls);
    $('send-btn').disabled = picked.length === 0;
    input.disabled = false;
  }
  function uploadNext(sessionId, tokens, i, okCount) {
    if (i >= picked.length) {
      finish('sentOf', [okCount, picked.length], 'ok');
      return;
    }
    var f = picked[i];
    var tk = tokens[String(i)];
    if (typeof tk !== 'string') { tx(f.label, 'skipped'); uploadNext(sessionId, tokens, i + 1, okCount); return; }
    var q = '?sessionId=' + encodeURIComponent(sessionId) + '&fileId=' + encodeURIComponent(String(i)) +
        '&token=' + encodeURIComponent(tk);
    setMsg('upload-status', 'sendingOf', [i + 1, picked.length], 'muted');
    call('POST', API + '/web/upload' + q, f.file, function (st) {
      if (st === 200) {
        f.bar.value = 1;
        tx(f.label, 'done');
        uploadNext(sessionId, tokens, i + 1, okCount + 1);
      } else if (st === 401) {
        showPair('unpaired');
        finish(null, null, '');
      } else {
        tx(f.label, 'failed');
        f.label.className = 'error small';
        if (st === 0) finish('lost', null, 'error');
        else finish('stopped', [st], 'error');
      }
    }, function (e) {
      if (e.lengthComputable && e.total > 0) {
        f.bar.value = e.loaded / e.total;
        sz(f.label, e.loaded, e.total);
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
    setMsg('upload-status', 'waitAccept', null, 'muted');
    call('POST', API + '/web/upload-prepare', { files: files }, function (st, j) {
      if (st === 200 && j && typeof j.sessionId === 'string' && j.files) {
        uploadNext(j.sessionId, j.files, 0, 0);
      } else if (st === 401) {
        showPair('unpaired');
        finish(null, null, '');
      } else if (st === 403) {
        finish('declined', null, 'error');
      } else if (st === 409) {
        finish('busyDev', null, 'error');
      } else if (st === 429) {
        finish('tooMany', null, 'error');
      } else if (st === 0) {
        finish('unreachable', null, 'error');
      } else {
        finish('startFail', [st], 'error');
      }
    });
  });

  applyLang();
})();
</script>
</body>
</html>
''';
