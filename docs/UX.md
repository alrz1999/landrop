# LanDrop UX review, redesign and Persian (fa) / RTL plan

Status: proposal (design only, no code changed). Scope: Flutter app in `lib/ui/`, browser page in
`lib/core/web_assets.dart`, diagnosis texts in `lib/core/diagnosis.dart`.

## Table of contents

1. [Audit of the current UI](#1-audit-of-the-current-ui)
2. [Design principles](#2-design-principles)
3. [Information architecture and screens](#3-information-architecture-and-screens)
4. [Persian and RTL support](#4-persian-and-rtl-support)
5. [Visual design and accessibility](#5-visual-design-and-accessibility)
6. [Implementation plan](#6-implementation-plan)
7. [Quick wins](#7-quick-wins)
8. [Open questions for the product owner](#8-open-questions-for-the-product-owner)

## 1. Audit of the current UI

The app works and its error handling is careful, but it was built feature by feature (DESIGN.md 3.8 to
4.9), and each feature added its own card, button or Settings row. The result talks to a network
engineer, not to someone who wants to move a photo from a phone to a laptop. Everything below was
read from the code; widget keys are given so the developer can find each spot.

### 1.1 Screen inventory

| # | Screen / surface | File and widget | Reached from |
|---|---|---|---|
| S1 | Home (phone: one long `ListView`; wide >= 840 px: two columns) | `home_page.dart` `HomePage` | app start |
| S2 | Self card (name, `IP · port`, status dot) | `widgets.dart` `SelfCard` | home |
| S3 | Nearby devices list + Rescan / Add by IP | `home_page.dart` `peersSection`, `PeerTile` | home |
| S4 | Empty state with 5 bullet tips + 3 buttons | `widgets.dart` `EmptyPeersHelp` | home, no peers |
| S5 | Send flow: picker, then `showPeerPicker`, then snackbar | `home_page.dart` `_sendFlow`, `_sendFolderFlow`; `dialogs.dart` | 3 FABs, `PeerTile` Send |
| S6 | Incoming request dialog | `dialogs.dart` `showIncomingDialog` | core event |
| S7 | Browser pairing dialog | `dialogs.dart` `_PairingDialog` | core event |
| S8 | Transfer cards | `widgets.dart` `TransferSessionCard` | home |
| S9 | Share sheet, share options dialog, share cards | `home_page.dart` `_shareSheet`; `shares.dart` | `shareFab`, `shareFiles`, Shares page |
| S10 | Shares page | `shares.dart` `SharesPage` | app-bar `sharesAction` |
| S11 | "Use from a browser" card, connected browsers | `shares.dart` `WebAccessCard`, `ConnectedBrowsersCard` | home (twice on wide), Shares page, Settings |
| S12 | "Connect manually" QR card | `widgets.dart` `QrCard` | home |
| S13 | Add by IP, Add failed | `dialogs.dart` `_AddByIpDialog`, `showAddFailedDialog` | `addByIp` |
| S14 | Diagnosis dialog | `diagnosis_dialog.dart` `DiagnosisDialog`, `FindingTile` | `whyNoDevices`, `diagnoseSettings`, `diagnoseIp` |
| S15 | Hotspot wizard ("Connect without Wi-Fi") | `hotspot_wizard.dart` `HotspotWizardPage`, `HotspotCard`, `FindDevicePanel` | `hotspotHelp`, `hotspotSettings`, finding action, banner "Show" |
| S16 | Cable wizard | `cable_wizard.dart` `CableWizardPage` | `cableHelp`, `cableSettings`, `cableInstead`, finding action |
| S17 | Wi-Fi Direct (Android) | `wifi_direct_page.dart` `WifiDirectPage` | `wifiDirectSettings` only |
| S18 | Join a hotspot by QR (Android) | `wifi_join_page.dart` `WifiJoinPage` | `wifiJoinSettings`, `scanHotspotQr` |
| S19 | Settings (19 rows, one flat list) | `settings_page.dart` `SettingsPage` | app-bar gear |
| S20 | Browser page | `lib/core/web_assets.dart` `webPageHtml` | URL / QR |

### 1.2 Cross-cutting problems

**P1. Technical words everywhere, often first.**
- `SelfCard` shows `192.168.1.10 · port 53317` directly under the name, on the first screen.
- `PeerTile` subtitle: `ip:port`, "direct cable link", "+2 more addresses".
- `showIncomingDialog`: the first line under the title is `ip · fingerprint 3F2A…`, before the
  file list. For a non-technical user "fingerprint" means a finger.
- `EmptyPeersHelp` bullets: "AP isolation", "client isolation", "VPNs", "TCP/UDP port 53317".
- `showPeerPicker` shows `ip:port` as each device's subtitle.
- Settings: "Certificate fingerprint", "Address", "Restart service" with `c.status.name` as
  subtitle (shows the enum name `running`), "plain HTTP".
- Diagnosis texts (`lib/core/diagnosis.dart`): "multicast and broadcast", "mDNS / Bonjour", "/24",
  "AP isolation", "security key". `networkSummary` always adds a "Your network" finding with raw
  interface names (`en0`, `utun3`) to every run, also in the dialog, not only in the copied report.
- The hotspot wizard asks Linux users to run `nmcli` commands.

**P2. Seven entry points for one problem: "I can't see the other device".**
`whyNoDevices`, `hotspotHelp`, `cableHelp` (empty state); `diagnoseSettings`, `hotspotSettings`,
`cableSettings`, `wifiDirectSettings`, `wifiJoinSettings` (Settings); `diagnoseIp` (after a failed
Add by IP); plus `cableInstead` inside the hotspot wizard and two finding actions. The user must
know in advance whether the cure is a "diagnosis", a "hotspot", a "cable", "Wi-Fi Direct" or a "QR
join". These are four wizards (S15 to S18) plus a dialog (S14), each with its own search UI:
`FindDevicePanel` in S15/S16/S18, a separate `_findDevices` in S17. Wi-Fi Direct and Join-by-QR
are only reachable from Settings, so a user stuck on the home screen never finds them.

**P3. The main action competes with advanced features.**
The FAB area holds three extended FABs (`shareFab`, `sendFolderFab`, `sendFab`) in a `Wrap`. On a
375 px phone they wrap to two rows, which is why the list needs `168` px bottom padding. "Share"
(browser links) sits next to "Send files" with the same visual weight, though the two are very
different concepts. "Send folder" is a rarely used variant of "Send files" and does not need its own
FAB.

**P4. Long scrolling home page.** On a phone `HomePage` stacks: Self card, discovery banner,
"Nearby devices", Rescan/Add by IP, hotspot banner, peers or empty state (about 400 px of text),
Transfers, "Share with a browser" section with its own two buttons, "Use from a browser" card (a
160 px QR and a 90-word paragraph about certificate warnings), "Connected browsers" card,
"Connect manually" with another 160 px QR. Two QR codes on one screen, both shown "without
context": `QrCard` is titled "This device" and encodes `https://ip:port`, which only another LanDrop
can use; `WebAccessCard` encodes the web page, which any camera can open. They look identical.

**P5. Share was hard to find, and has three homes.** The user could not find Share. It now exists
as the `sharesAction` app-bar icon (an `ios_share` icon with only a tooltip), the `shareFab`, and the
`SharesSection` buttons in the home list, which is the same `startShareFlow`. `ConnectedBrowsersCard`
appears on home, Shares page and Settings. Three copies of a thing still means none of them is
obviously "the" place.

**P6. Where did my file go?** `TransferSessionCard` prints `Saved to /storage/emulated/0/Download/LanDrop`
as selectable text, with no "Open" or "Show in folder" action. On Android, `defaultSaveDir()` falls
back to the app's hidden external folder when "All files access" was refused, and the user is never
told. `ensureStorageAccess()` is called from `AppController.init()` on first start, so Android throws
the user into the system "All files access" screen with no explanation, before they have seen
the app.

**P7. Dialogs lead with detail.** `showIncomingDialog` (fingerprint line), `showAddFailedDialog`
(`Could not reach 10.0.0.8:5000 — SocketException: ...` raw exception text), `FindingTile` (title,
detail, "What to do:", then raw technical text, all at once), `SelfCard` error state
(`Error: ${c.lastError}`), snackbars like `Could not open file picker: $e`.

**P8. No "what happens next".** After Send, the only feedback is a transfer card further down the
list and a snackbar at the end. The waiting state says "Waiting for X to accept…", good, but there
is no cancel. Incoming transfers have no cancel either. After "Accept" a snackbar says "Receiving 2
file(s)". Nothing tells the receiver where files go before accepting.

**P9. Blame and dead ends.** "Sending to X failed or was declined" mixes two very different
outcomes. `showPeerPicker` with no peers shows a dead-end text 'Try "Rescan" or "Add by IP"' with no
buttons.

**P10. No i18n and no RTL at all.** About 470 user-visible English literals across 20 files
(section 4.3), string concatenation with plural hacks (`file${n == 1 ? '' : 's'}` appears at least
8 times), `EdgeInsets.fromLTRB` and `Alignment` everywhere, `TextAlign.end` used once, raw `Row`
ordering for icon + text. `MaterialApp` in `app.dart` has no `localizationsDelegates`. Kotlin
notification text in `LanDropService.kt` is hard-coded English.

### 1.3 Screen-by-screen notes

**Home (S1 to S4).**
- Status is a 10 px dot plus "Ready to receive" in `bodySmall`: the single most reassuring fact
  ("others can find me") is the smallest text on screen.
- `discoveryBanner` content interpolates the raw error (`Failed to create datagram socket ...`).
- `rescan` reports `Scan finished: 0 device(s) found` as a snackbar, then nothing else changes.
- `EmptyPeersHelp` is a wall of five bullets, then three outline buttons of equal weight.
- Wide layout puts `SelfCard` in the right column, so the "who am I" anchor moves between layouts.

**Send (S5).** Picking happens before choosing the device when using the FAB, but after when tapping
a device's Send button. Two orders for the same task. The picker dialog title `Send 2 files to…` is
fine; the list shows IPs instead of a device type label. There is no drag and drop on desktop, no
"recent devices", no system share-sheet entry on mobile.

**Receive (S6).** Title "Pixel 9 wants to send you 2 files" is good. Problems: fingerprint line;
no indication whether this sender was seen before; no "always accept from this device"; the save
folder is not shown; the dialog cannot time out visibly (the core times it out silently).

**Transfers (S8).** Shows bytes but no speed, no time left, no cancel, no "Open" / "Show in folder",
"Clear done" only. Status text "Failed: <exception>" in red at the end of the title row, truncated
to one line. Direction icons `call_received` / `call_made` are phone-call icons and are not
mirrored for RTL.

**Shares and browser access (S9 to S11).** The concept is split into "Share" (they download from me)
and "Use from a browser" (they upload to me), but both are labelled with browser jargon. The share
options dialog asks "Link works for" and "Downloads allowed" with good defaults (1 h, unlimited). The
`WebAccessCard` paragraph explains certificate warnings per browser before the user has tried. The
pairing dialog copy is good but shows `userAgent · remoteIp`.

**Diagnosis (S14).** Strong engine, weak presentation: every finding shows all four text layers;
the "Your network" technical block is always last and visible; severity is colour only plus an icon;
`Colors.orange.shade800` is hard-coded (low contrast in dark mode). The only actions are the
hotspot and cable wizards; findings like `vpn-active` or `probe-refused` have no button at all.

**Wizards (S15 to S18).** Each starts with a 40 to 60 word paragraph, then a `SegmentedButton`
whose labels are long sentences ("This device shares the hotspot") that wrap badly at 375 px. The
"other device" instructions for five OSes sit in an `ExpansionTile`. `FindDevicePanel` is good and
reusable. Wi-Fi Direct shows "Create group here" and "Host address: 192.168.49.1". Join-by-QR is
the friendliest of the four (stages, clear copy) but is hidden in Settings.

**Settings (S19).** One flat list mixing personal (name, folder), troubleshooting (5 rows),
lifecycle (background, quit, restart) and security (plain HTTP, keep shares, browsers). No language
row. "Reset to default folder" is a separate row instead of an option inside the folder row.

**Browser page (S20).** Clear and accessible (44 px buttons, `aria-live`, focus ring), English only,
`<html lang="en">`, sizes and counts built by concatenation (`' files'`, `' min'`), no `dir`
handling. The `.row` uses flex, which mirrors correctly once `dir="rtl"` is set.

### 1.4 What already works well (keep it)

- `Key`s on nearly every interactive widget: a redesign can keep them and keep tests green.
- Platform error texts are already mapped from codes (the `'permission' => ...` code switch in
  `hotspot_service.dart`, `wifiJoinMessage`, `wifiDirectMessage`): ideal for localisation.
- `Finding.code` is stable and documented as "used by tests and reports".
- The pairing dialog's `Semantics` label that spells the code digit by digit.
- The web page's rules (no `innerHTML` for user text, no external requests).
- `FindDevicePanel` as one search routine: the base for the merged helper (3.4).

## 2. Design principles

1. **One primary action per screen.** Home = "Send". Every other action is secondary (text or
   tonal button) or lives one level deeper. Justified by P3 (three FABs) and P4 (long home).
2. **Progressive disclosure.** Plain sentence first, "Details" behind a tap. IPs, ports,
   fingerprints, interface names and exception texts only appear under "Details" or in Advanced.
   Justified by P1 and P7.
3. **Plain words.** Say "the other device", "Wi-Fi", "same network", "this phone's hotspot". Never
   "multicast", "subnet", "AP isolation", "fingerprint", "port", "TLS", "mDNS" outside Advanced.
   Every finding title must make sense to someone who has never configured a router.
4. **Always show what happens next.** Every waiting state names who we wait for and offers Cancel;
   every finished state offers the next step ("Open", "Show in folder", "Send more").
5. **Never blame the user.** Errors describe the situation and the fix ("The other device didn't
   answer. Is LanDrop open on it?"), not the fault ("Invalid IP"). Keep declined and failed apart.
6. **Safe defaults, explicit risk.** Encryption on, plain HTTP off, shares expire in 1 hour, every
   transfer asks for approval unless the user marked the sender as trusted. Risky switches live in
   Advanced with a one-line consequence.
7. **One door per problem.** One "Can't find the other device?" helper replaces seven entry points.
8. **Same experience in both languages.** Every screen is designed and tested in English (LTR) and
   Persian (RTL) at 375 px and 1000 px.

## 3. Information architecture and screens

### 3.1 New structure

```
Home
├── [primary] Send            → pick files (or drop) → choose device → transfer card
├── Nearby devices            → tap device = send to it
├── "Can't find the other device?"  → Connection helper (3.4)
├── Activity (transfers, newest first; open / show in folder / cancel)
└── App bar: [Share link] [Settings]
Share link page (3.8)
├── Send a link        (was "Share": others download from me)
└── Use from a browser (was WebAccessCard: others upload to me) + connected browsers
Settings
├── Device name · Save folder (with "Reset") · Language · Theme
├── Trusted devices
├── Android: Keep running in background · Quit
└── Advanced ▸ address & port, security code (fingerprint), plain HTTP, keep shares,
               restart service, connection report (diagnosis), all connection methods
```

What moves where:

| Today | Proposed |
|---|---|
| `QrCard` ("Connect manually", home) | Connection helper, step "Type the address / scan"; Advanced |
| `SelfCard` `IP · port` line | Advanced; home shows name + "Visible to nearby devices" |
| `WebAccessCard`, `ConnectedBrowsersCard` on home | Share link page only (Settings keeps a link to it) |
| `SharesSection` on home | Active shares appear as one compact "Sharing 2 links" row on home, opening the Share page |
| `sendFolderFab`, `shareFab` | Removed; Send sheet offers "Files" / "Folder"; Share = app-bar action with a text label on wide screens |
| 5 troubleshooting rows in Settings | One row "Can't find the other device?" + Advanced ▸ "Connection report" |
| `EmptyPeersHelp` bullets | Short empty state + one button to the helper |

### 3.2 Home

Phone (< 840 px). One extended FAB "Send" (`Key('sendFab')` kept). Text wireframes; RTL mirrors
the whole layout, the FAB moves to the bottom-left automatically with `Directionality`.

**State A, first run / searching (no devices yet, under 10 s since start)**

```
┌────────────────────────────────────────┐
│ LanDrop                    [🔗] [⚙]    │
├────────────────────────────────────────┤
│ (📱) Ali's Pixel  ✎                     │
│ ● Visible to nearby devices             │
├────────────────────────────────────────┤
│ Nearby devices                          │
│   ◌ Looking for devices…                │
│   Open LanDrop on the other device too. │
│                                         │
│                          [ ⬆ Send  ]    │
└────────────────────────────────────────┘
```

| Element | English | Persian |
|---|---|---|
| status ok | Visible to nearby devices | برای دستگاه‌های اطراف قابل مشاهده است |
| status starting | Getting ready… | در حال آماده شدن… |
| status error | Can't receive right now. [Try again] | الان امکان دریافت نیست. [دوباره امتحان کنید] |
| searching | Looking for devices… | در حال جست‌وجوی دستگاه‌ها… |
| hint | Open LanDrop on the other device too. | LanDrop را روی دستگاه دیگر هم باز کنید. |
| FAB | Send | ارسال |

**State B, devices nearby**

```
│ Nearby devices                          │
│ (💻) Work Laptop          [ Send ]      │
│      Computer                           │
│ (📱) سارا                  [ Send ]      │
│      Phone · trusted                    │
│ Recent: Home PC (not nearby)            │
│ Can't find a device?                    │
│ Activity                                │
│ ⬇ From Pixel 9 · 2 files   ✓ Done [Open]│
```

Subtitle shows the device kind ("Computer", "Phone", "Browser") and "trusted", never the IP.
Long-press / right-click on a device opens "Details" (address, other addresses, security code).
"+N more addresses" and "direct cable link" move to that sheet.

| Element | English | Persian |
|---|---|---|
| section | Nearby devices | دستگاه‌های اطراف |
| kind | Phone / Computer / Browser | گوشی / رایانه / مرورگر |
| trusted | Trusted | مورد اعتماد |
| send button | Send | ارسال |
| helper link | Can't find the other device? | دستگاه دیگر را پیدا نمی‌کنید؟ |
| activity | Activity | فعالیت‌ها |

**State C, nothing found after 10 s**

```
│        (wifi_find icon, 48)             │
│   No devices found yet                  │
│   Make sure LanDrop is open on the      │
│   other device and both are on the      │
│   same Wi-Fi.                           │
│   [ Help me connect ]   (tonal, primary)│
│   Search again                          │
```

| English | Persian |
|---|---|
| No devices found yet | هنوز دستگاهی پیدا نشد |
| Make sure LanDrop is open on the other device and both are on the same Wi-Fi. | مطمئن شوید LanDrop روی دستگاه دیگر باز است و هر دو به یک وای‌فای وصل هستند. |
| Help me connect | کمکم کنید وصل شوم |
| Search again | دوباره جست‌وجو کن |

Keys: `whyNoDevices` moves to "Help me connect"; `rescan` to "Search again"; `addByIp` moves into
the helper (test updated to open the helper first, or keep a hidden-on-phone overflow menu item
"Add by address" with the same key, see 6.3). The discovery error banner becomes one line, "Automatic
search is off on this device. [Help]", raw error under the helper's Details.

Wide (>= 840 px): left column = devices + activity; right column (320 px) = a large drop zone
"Drop files here to send" plus self card. Share/browser cards leave home.

### 3.3 Send experience

Flow: **Send → what → to whom → progress**. One order everywhere: if the user tapped a device,
skip "to whom"; if they used the FAB, ask "what" first (bottom sheet), then "to whom".

```
Send sheet                         Choose device (dialog / sheet)
┌──────────────────────────┐       ┌──────────────────────────────┐
│ What do you want to send?│       │ Send 3 files to…             │
│ [📄 Files]  [📁 Folder]   │       │ (💻) Work Laptop   Computer   │
│ (desktop) or drop files  │       │ (📱) Sara          Phone      │
│ anywhere in this window  │       │ No device? Help me connect   │
└──────────────────────────┘       └──────────────────────────────┘
```

- Desktop drag and drop: wrap `HomePage` body in a drop target (package `desktop_drop` or
  `super_drag_and_drop`; product decision on the dependency). Drop on a device row sends straight to
  it; drop elsewhere opens "Choose device". Overlay copy: "Drop to send" / «رها کنید تا ارسال شود».
- Mobile share sheet: register LanDrop as a share target (Android `ACTION_SEND`/`SEND_MULTIPLE`
  intent filter, later iOS Share Extension). Opening from it goes straight to "Choose device".
  Not in the first iterations (needs native code); listed as step U8.
- Recent devices: remember the last 5 fingerprints + alias in the settings JSON (`recent`), show
  them first in the picker, greyed with "Not nearby" when absent.
- Empty picker: replace the dead-end text with a button to the helper.

| Element | English | Persian |
|---|---|---|
| sheet title | What do you want to send? | چه چیزی می‌خواهید بفرستید؟ |
| files / folder | Files / Folder | فایل‌ها / پوشه |
| picker title | Send {count, plural, =1{1 file} other{{count} files}} to… | ارسال {count} فایل به… |
| folder title | Send folder "{name}" to… | ارسال پوشهٔ «{name}» به… |
| waiting | Waiting for {name} to accept… [Cancel] | منتظر تأیید {name}… [لغو] |
| declined | {name} declined. | {name} نپذیرفت. |
| failed | Couldn't reach {name}. Is LanDrop still open there? [Try again] [Help] | به {name} دسترسی نداریم. آیا LanDrop هنوز آنجا باز است؟ [دوباره] [راهنما] |
| sent | Sent to {name}. | به {name} ارسال شد. |

Splitting "declined" from "failed" needs `SendResult.error` to carry a code (the core already knows
403 vs connection error). Small core change, see 4.10.

### 3.4 "Can't find the other device?" helper

One full-screen page `ConnectHelperPage` replaces the entry points listed in P2. It reuses
`FindDevicePanel`, `HotspotCard`, `WifiJoinPage` stages and `WifiDirectPage` content as sub-steps,
so no networking logic changes.

**Step 0, automatic check (runs at once, about 5 s).** Calls `runDiagnosis()` and a rescan. If a
device appears: "Found Work Laptop!" [Send to it]. If the diagnosis has a `problem` finding with a
clear fix (server-down, no-lan, vpn-active, discovery-failed), show that one finding as a plain card
with its button before asking any question.

**Question 1: "Are both devices on the same Wi-Fi?"**
- *Yes, same Wi-Fi* → likely blocked network or app closed. Show checklist (LanDrop open on the
  other device, VPN off) + [Search again]. If still nothing → "This Wi-Fi may keep devices apart.
  Let's connect them directly." → Question 2.
- *No / not sure / there is no Wi-Fi* → Question 2.
- *I have a cable* → cable steps (current `CableWizardPage` content).

**Question 2: "What is the other device?"** (answers chosen by this device's platform)
- *An Android phone* + this is Android → Recommended: "Use this phone's hotspot" (Start hotspot,
  QR shown, other phone scans with LanDrop = Join-by-QR). Alternative: Wi-Fi Direct.
- *An Android phone* + this is a computer → "Turn on the phone's hotspot and join it from here"
  (hotspot steps, join role).
- *An iPhone* → iPhone shares Personal Hotspot, this device joins.
- *A computer* → if this is a phone: phone shares hotspot, computer joins. If both computers:
  cable, or one computer's hotspot.
- *Something else / a browser* → "Use from a browser" page.

Everything ends in the same `FindDevicePanel` "I'm connected, find the other device", with the
result card and, on failure, the plain diagnosis plus [Copy report for support] (Advanced
details collapsed).

```
┌─ Help me connect ─────────────────────────┐
│ Checking your connection…  ◌              │
│ ───────────────────────────────────────── │
│ Are both devices on the same Wi-Fi?       │
│  ( ) Yes, same Wi-Fi                      │
│  ( ) No, or there is no Wi-Fi             │
│  ( ) I'll use a cable                     │
│                                [Next]     │
│ Details ▸ (connection report)             │
└───────────────────────────────────────────┘
```

| Element | English | Persian |
|---|---|---|
| title | Help me connect | کمک برای اتصال |
| checking | Checking your connection… | در حال بررسی اتصال شما… |
| found | Found {name}! | {name} پیدا شد! |
| Q1 | Are both devices on the same Wi-Fi? | آیا هر دو دستگاه به یک وای‌فای وصل هستند؟ |
| Q1 a | Yes, same Wi-Fi | بله، یک وای‌فای |
| Q1 b | No, or there is no Wi-Fi | نه، یا وای‌فای نداریم |
| Q1 c | I'll use a cable | با کابل وصل می‌کنم |
| checklist | Open LanDrop on the other device and keep its screen on. Turn off any VPN. | LanDrop را روی دستگاه دیگر باز کنید و صفحه‌اش را روشن نگه دارید. اگر VPN (فیلترشکن) روشن است، خاموشش کنید. |
| blocked | This Wi-Fi may keep devices apart. Let's connect them directly. | ممکن است این وای‌فای اجازهٔ ارتباط دستگاه‌ها با هم را ندهد. بیایید آن‌ها را مستقیم به هم وصل کنیم. |
| Q2 | What is the other device? | دستگاه دیگر چیست؟ |
| Q2 answers | An Android phone / An iPhone / A computer / Only a browser | گوشی اندروید / آیفون / رایانه / فقط مرورگر |
| hotspot rec. | Recommended: share a hotspot from this phone | پیشنهاد: از این گوشی هات‌اسپات بسازید |
| hotspot body | No internet is used. The other phone scans the code to join. | از اینترنت استفاده نمی‌شود. گوشی دیگر کد را اسکن می‌کند تا وصل شود. |
| join | Join the other device's hotspot | به هات‌اسپات دستگاه دیگر وصل شوید |
| find | I'm connected, find the other device | وصل شدم، دستگاه دیگر را پیدا کن |
| nothing | Still not found. Here is what we checked: | هنوز پیدا نشد. این‌ها را بررسی کردیم: |
| copy | Copy report for support | کپی گزارش برای پشتیبانی |

Note: in Iran "VPN" is commonly called «فیلترشکن»; the copy shows both (flag for review).

### 3.5 Advanced area

`AdvancedSettingsPage` (Settings ▸ Advanced): Address and port (`selfUrl`, QR from `QrCard`),
"Security code" (fingerprint, explained: "Compare this code with the other device to be sure it's
really yours" / «این کد را با دستگاه دیگر مقایسه کنید تا مطمئن شوید واقعاً همان دستگاه است»), plain
HTTP switch (keep `webHttpSwitch`, `confirmWebHttp`), keep shares (`keepSharesSwitch`), restart
service, "Connection report" (opens `DiagnosisDialog`, keep `diagnoseSettings` key), "All connection
methods" (direct links to hotspot, cable, Wi-Fi Direct, Join by QR, keeping `hotspotSettings`,
`cableSettings`, `wifiDirectSettings`, `wifiJoinSettings`). Experts lose nothing; they gain one tap.

### 3.6 First-run onboarding (max 3 screens, skippable)

Stored as `onboarded: true` in the settings JSON. No permission is asked during onboarding.

| # | English | Persian |
|---|---|---|
| 1 title | Send files to your nearby devices | فایل‌ها را به دستگاه‌های نزدیک خود بفرستید |
| 1 body | No internet, no account. Files go straight from one device to the other. | بدون اینترنت و بدون حساب کاربری. فایل‌ها مستقیم از یک دستگاه به دستگاه دیگر می‌روند. |
| 2 title | Open LanDrop on both devices | LanDrop را روی هر دو دستگاه باز کنید |
| 2 body | Connect them to the same Wi-Fi. No Wi-Fi? LanDrop can help you connect directly. | آن‌ها را به یک وای‌فای وصل کنید. وای‌فای ندارید؟ LanDrop کمک می‌کند مستقیم وصل شوید. |
| 3 title | Name this device | برای این دستگاه یک نام انتخاب کنید |
| 3 body | Others will see this name. | دیگران این نام را می‌بینند. |
| buttons | Next / Skip / Start | بعدی / رد شدن / شروع |

**Permissions at the moment they are needed:**

| When | Pre-prompt (English) | Persian |
|---|---|---|
| Android, first time a file is received or the folder row is opened: All files access | Save received files in Downloads? To put files in your Downloads folder, where your other apps can find them, Android needs you to allow "All files access" for LanDrop on the next screen. Without it, files are kept inside LanDrop's own folder. [Allow] [Not now] | فایل‌های دریافتی در پوشهٔ Downloads ذخیره شوند؟ برای اینکه فایل‌ها در پوشهٔ دانلودها و در دسترس برنامه‌های دیگر باشند، اندروید در صفحهٔ بعد از شما می‌خواهد «دسترسی به همهٔ فایل‌ها» را برای LanDrop روشن کنید. بدون آن، فایل‌ها در پوشهٔ خود LanDrop می‌مانند. [اجازه می‌دهم] [الان نه] |
| Android 13+, first start of the background service: notifications | LanDrop shows a small notification while it's ready to receive, so Android doesn't stop it. | LanDrop هنگام آماده بودن برای دریافت، یک اعلان کوچک نشان می‌دهد تا اندروید آن را متوقف نکند. |
| Start hotspot / Wi-Fi Direct: Nearby devices or Location | To create a hotspot, Android asks for permission to find nearby devices. LanDrop doesn't track your location. | برای ساختن هات‌اسپات، اندروید اجازهٔ پیدا کردن دستگاه‌های اطراف را می‌خواهد. LanDrop موقعیت مکانی شما را دنبال نمی‌کند. |
| Join by QR: camera | LanDrop uses the camera only to scan the Wi-Fi code. | LanDrop فقط برای اسکن کد وای‌فای از دوربین استفاده می‌کند. |
| macOS/iOS local network prompt (before the first discovery) | Your computer will ask whether LanDrop may find devices on your local network. Choose Allow, or nearby devices won't appear. | رایانهٔ شما می‌پرسد آیا LanDrop اجازه دارد دستگاه‌های شبکهٔ محلی را پیدا کند. «اجازه» را انتخاب کنید، وگرنه دستگاه‌های اطراف نمایش داده نمی‌شوند. |

This needs `AppController.init()` to stop calling `ensureStorageAccess()` implicitly: start with
the app-private folder (or the previously granted public one) and ask only through the pre-prompt.
Existing users who already granted the permission keep `Downloads/LanDrop`.

### 3.7 Receive experience

```
┌──────────────────────────────────────────┐
│               ⬇                          │
│  Sara wants to send you 2 files          │
│  (📱) Phone · first time / trusted ✓      │
│  ┌──────────────────────────────────────┐│
│  │ 📄 holiday.jpg                3.1 MB ││
│  │ 📁 Docs/  (12 files)          8 MB   ││
│  └──────────────────────────────────────┘│
│  Total 11.1 MB · Saves to Downloads/LanDrop│
│  ☐ Always accept from Sara               │
│  Details ▸ (address, security code)      │
│                    [Decline] [Accept]    │
└──────────────────────────────────────────┘
```

- Trusted devices: fingerprint list in settings JSON (`trusted: [{fp, alias}]`); when the sender's
  fingerprint is trusted, auto-accept and show a snackbar "Receiving from Sara" with [Stop]. Managed
  in Settings ▸ Trusted devices (remove). Browsers can never be trusted (session-bound).
- "First time" badge when the fingerprint was never seen before (recent list).
- Folder path shown with a short friendly name ("Downloads/LanDrop") and LTR-isolated.

| Element | English | Persian |
|---|---|---|
| title | {name} wants to send you {count, plural, =1{1 file} other{{count} files}} | {name} می‌خواهد {count} فایل برای شما بفرستد |
| first time | First time from this device | اولین بار از این دستگاه |
| trusted | Trusted device | دستگاه مورد اعتماد |
| browser | A web browser ({browser}) | یک مرورگر وب ({browser}) |
| total | Total {size} · Saves to {folder} | مجموع {size} · ذخیره در {folder} |
| always | Always accept from {name} | همیشه از {name} بپذیر |
| buttons | Decline / Accept | رد کردن / پذیرفتن |
| pairing title | Allow this browser to send you files? | به این مرورگر اجازه می‌دهید برایتان فایل بفرستد؟ |
| pairing body | Approve only if the browser shows the same code. | فقط اگر مرورگر همین کد را نشان می‌دهد، تأیید کنید. |

### 3.8 Transfer cards

```
┌──────────────────────────────────────────┐
│ ⬇ From Sara                     1:20 left│
│ holiday.jpg and 11 more                  │
│ ███████████░░░░░░░  64% · 4.2 MB/s       │
│ 7.1 MB of 11.1 MB                [Cancel]│
└──────────────────────────────────────────┘
done:   ✓ From Sara · 12 files · Done   [Open] [Show in folder]
failed: ⚠ To Work Laptop · Stopped: connection lost   [Try again] [Details]
```

- Speed and time left: computed in `TransferSession` from a 3 s moving window of `sent` bytes
  (UI-only, no core change).
- Cancel: the wire protocol has `cancel` (session + `cancelSecret`, DESIGN.md 2.9), but
  `LanDropCore` in `api.dart` exposes no cancel method today. Add `Future<void> cancelSession(String
  sessionId)` to the core (sender: abort upload + call cancel; receiver: drop session, delete
  `.part`), then `AppController.cancel(sessionId)`. This is the only core change in the redesign
  besides 4.10.
- Open / Show in folder: `open_filex` or `url_launcher` with `file://` on desktop; Android needs a
  `FileProvider` (product decision on the dependency; on desktop `Process.run('open'|'explorer'|'xdg-open')`
  is enough).
- Icons: `Icons.download` / `Icons.upload` (not phone-call icons), no mirroring needed.

| State | English | Persian |
|---|---|---|
| waiting | Waiting for {name} to accept… | منتظر تأیید {name}… |
| running | {percent}% · {speed} | ٪{percent} · {speed} |
| time left | {time} left | {time} مانده |
| done in | Done | انجام شد |
| declined | Declined by {name} | {name} نپذیرفت |
| failed | Stopped: {reason} | متوقف شد: {reason} |
| cancelled | Cancelled | لغو شد |
| buttons | Cancel / Open / Show in folder / Try again / Clear finished | لغو / باز کردن / نمایش در پوشه / دوباره / پاک کردن تمام‌شده‌ها |
| summary | {done} of {total} files | {done} از {total} فایل |

### 3.9 Share link and browser access

Rename the concepts around what the user wants:

- **Send a link** (was "Share"): "Anyone on this Wi-Fi can download these files from a browser."
- **Use from a browser** (was WebAccessCard): "Send files to this device from any browser."

`SharePage` (keeps `sharesAction` key) has two tabs or two cards. Links: one big QR, the link, [Copy
link] [Share…] (system share on mobile), remaining time and downloads, [Stop]. The certificate
explanation becomes a collapsed "The browser shows a warning?" item, with the per-browser steps
inside. The `WebAccessCard` QR on home goes away (P4).

| Element | English | Persian |
|---|---|---|
| tab 1 | Send a link | ارسال لینک |
| tab 1 body | Anyone on this Wi-Fi with the link can download the files from a browser. | هر کس در این وای‌فای لینک را داشته باشد، می‌تواند فایل‌ها را با مرورگر دانلود کند. |
| button | Choose files to share | انتخاب فایل برای اشتراک |
| options | Link works for: 15 min · 1 hour · 24 hours · Until I stop | اعتبار لینک: ۱۵ دقیقه · ۱ ساعت · ۲۴ ساعت · تا وقتی متوقفش کنم |
| downloads | Downloads allowed: Unlimited · 1 · 5 | تعداد دانلود مجاز: نامحدود · ۱ · ۵ |
| card time | Ends in {time} | {time} دیگر تمام می‌شود |
| card left | {left} of {max} downloads left | {left} از {max} دانلود باقی مانده |
| stop | Stop sharing | توقف اشتراک |
| tab 2 | Use from a browser | استفاده از مرورگر |
| tab 2 body | Open this address on another phone or computer to send files here. Nothing to install. | این نشانی را روی گوشی یا رایانهٔ دیگر باز کنید تا به اینجا فایل بفرستید. نیازی به نصب چیزی نیست. |
| warning help | The browser shows a warning? | مرورگر هشدار نشان می‌دهد؟ |
| warning body | That's expected: LanDrop uses its own security certificate. Choose "Advanced", then "Proceed". | این طبیعی است: LanDrop از گواهی امنیتی خودش استفاده می‌کند. «Advanced» و سپس «Proceed» را بزنید. |
| browsers | Connected browsers / Disconnect | مرورگرهای متصل / قطع اتصال |

(The Persian warning body keeps the browser's button names in English because most Iranian
users run English browser UIs; flag for review.)

### 3.10 Settings

```
Settings
  Device name                      Ali's Pixel        ›
  Save received files to           Downloads/LanDrop  ›
  Language                         System             ›
  Trusted devices                  2                  ›
  Can't find the other device?                         ›
  Keep running in background (Android)               [on]
  Quit LanDrop (Android)
  Advanced                                             ›
```

| English | Persian |
|---|---|
| Settings | تنظیمات |
| Device name | نام دستگاه |
| Save received files to | محل ذخیرهٔ فایل‌های دریافتی |
| Use default folder | استفاده از پوشهٔ پیش‌فرض |
| Language | زبان |
| System default / English / فارسی | پیش‌فرض سیستم / English / فارسی |
| Trusted devices | دستگاه‌های مورد اعتماد |
| Keep running in background | اجرا در پس‌زمینه |
| Stays reachable with the screen off. Shows a notification. | با صفحهٔ خاموش هم در دسترس می‌ماند. یک اعلان نشان می‌دهد. |
| Quit LanDrop | خروج از LanDrop |
| Advanced | پیشرفته |
| Security code | کد امنیتی |
| Address | نشانی |
| Allow browsers without a warning (not encrypted) | اجازه به مرورگرها بدون هشدار (بدون رمزگذاری) |
| Keep share links after restart | نگه داشتن لینک‌ها پس از راه‌اندازی دوباره |
| Restart LanDrop service | راه‌اندازی دوبارهٔ سرویس LanDrop |
| Connection report | گزارش اتصال |
| All connection methods | همهٔ روش‌های اتصال |

## 4. Persian and RTL support

### 4.1 Approach

Use Flutter's standard gen-l10n: `flutter_localizations` (SDK) + `intl` + ARB files. No third-party
l10n package: gen-l10n is built into Flutter 3.47, type-safe, supports ICU plurals and selects, and
needs no runtime asset loading. Material and Cupertino widgets (date pickers, `Tooltip`s of back
buttons, `TextField` context menus, "Paste"/"Copy") get Persian for free from
`GlobalMaterialLocalizations`, which ships `fa`.

### 4.2 Setup

`pubspec.yaml`:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any        # pinned by flutter_localizations; "any" avoids version fights
flutter:
  generate: true
```

`l10n.yaml` (project root):

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: L10n
nullable-getter: false
untranslated-messages-file: build/untranslated.json
```

Since Flutter 3.29 the generated code goes next to the ARB files (`lib/l10n/`), not into a synthetic
package; import it as `import '../l10n/app_localizations.dart';`. Add a tiny extension so call
sites stay short: `extension L10nX on BuildContext { L10n get l => L10n.of(this); }`.

`app.dart` `MaterialApp`:

```dart
MaterialApp(
  onGenerateTitle: (ctx) => ctx.l.appTitle,
  localizationsDelegates: L10n.localizationsDelegates, // includes Global* delegates
  supportedLocales: L10n.supportedLocales,             // [en, fa]
  locale: controller.localeOverride,                   // null = follow system
  localeResolutionCallback: (device, supported) =>
      supported.firstWhere((l) => l.languageCode == device?.languageCode,
          orElse: () => const Locale('en')),
  theme: buildTheme(Brightness.light, controller.effectiveLocale),
  darkTheme: buildTheme(Brightness.dark, controller.effectiveLocale),
  ...
)
```

`MaterialApp` must listen to the controller for `locale` (wrap it in `ListenableBuilder`; today
`AppScope` sits above `MaterialApp`, so it already rebuilds when the controller notifies).

Locale picker: Settings ▸ Language, a `RadioListTile` dialog with "System default", "English",
"فارسی" (each language name written in itself, never translated). Persisted in the existing JSON
written by `AppController._persist()` as `'locale': 'system' | 'en' | 'fa'`; read in `init()`;
`AppController.setLocale(String)` → `_persist()` + `_notify()`. No restart needed. `MemorySettingsStore`
covers it in tests.

### 4.3 Extracting the strings

Approximate count of user-visible literals (grep of capitalised string literals, so +-15%):

| File | ~strings | Notes |
|---|---|---|
| `lib/core/diagnosis.dart` | 80 | move to codes, 4.10 |
| `lib/ui/hotspot_wizard.dart` | 59 | long per-OS steps |
| `lib/ui/cable_wizard.dart` | 45 | long per-OS steps |
| `lib/ui/home_page.dart` | 38 | snackbars with plurals |
| `lib/ui/settings_page.dart` | 38 | |
| `lib/ui/shares.dart` | 37 | time formatting `_remaining`, `_ago`, `_clock` |
| `lib/core/web_assets.dart` | 37 | separate JS dictionary, 4.9 |
| `lib/ui/dialogs.dart` | 24 | plurals |
| `lib/ui/widgets.dart` | 23 | |
| `lib/ui/wifi_join_page.dart` | 22 | |
| `lib/ui/wifi_direct_page.dart` | 20 | |
| `lib/ui/hotspot_service.dart`, `wifi_join_service.dart`, `wifi_direct_service.dart` | 33 | already code→message switches |
| `lib/ui/diagnosis_dialog.dart` | 13 | |
| `lib/ui/app_controller.dart`, `app.dart`, `storage_access.dart` | 6 | `lastError` strings |
| **Total** | **~475** | `fake_core.dart` excluded (test data) |

Method, one file per PR: (1) copy each literal into `app_en.arb` with the exact current English text
(byte-identical, so `find.text` in the 94 text-based test assertions keeps passing); (2) replace with
`context.l.key`; (3) run `flutter test`; (4) add the Persian entry. A grep check in CI keeps new
literals out: `grep -nE "Text\\('[A-Z]" lib/ui` must be empty (allow-list for brand "LanDrop").

Naming scheme: `screenElementPurpose`, lower camel case, screen prefix first, so the ARB sorts by
screen: `homeSendButton`, `homeEmptyTitle`, `incomingTitle`, `transferWaiting`, `shareOptionsTtl1h`,
`helperQ1Title`, `settingsLanguage`, `diagFindingVpnActiveTitle`, `errHotspotPermission`. Every entry
gets an `@key` with a `description` for the translator (where it appears, max length when it is a
button).

Plurals and placeholders, replacing the 8+ `file${n == 1 ? '' : 's'}` hacks:

```json
"incomingTitle": "{name} wants to send you {count, plural, =1{1 file} other{{count} files}}",
"@incomingTitle": {
  "description": "Incoming request dialog title",
  "placeholders": {"name": {"type": "String"}, "count": {"type": "int", "format": "decimalPattern"}}
},
"transferSpeed": "{speed}/s",
"shareEndsIn": "Ends in {time}"
```

Persian has only the `other` plural category in CLDR (nouns after numbers stay singular: «۳ فایل»),
so the fa entries are simpler: `"{name} می‌خواهد {count} فایل برای شما بفرستد"`. Keep the ICU form in
fa anyway (`{count, plural, other{...}}`) for consistency.

Never build sentences by concatenation (`'From ' + alias`, `'$done of ${n} files'`): Persian word
order differs, so each sentence is one ARB message with placeholders. Lists like
`[a, b, c].join(' · ')` in `PeerTile` are fine (the separator is neutral) but each part must be
translated whole.

Per-OS wizard steps (`hotspotSteps`, `cableSteps`) become one ARB key per step
(`hotspotShareAndroid1` …). OS menu paths ("Settings > Network & internet") are what the user sees on
the device: in fa, keep the English path in quotes when the OS is likely in English (macOS, Windows,
Linux) and translate it for Android/iOS, where Persian system UI is common. Flag all of them for
native review against a real Persian Android (Samsung/Xiaomi menus differ).

### 4.4 RTL layout rules

`MaterialApp` sets `Directionality` from the locale; Material widgets (`ListTile`, `AppBar`,
`SnackBar`, `AlertDialog` actions, FAB location, `Drawer`, `SegmentedButton`, `LinearProgressIndicator`)
mirror automatically. Our own code must follow these rules:

| Do not use | Use | Current offenders |
|---|---|---|
| `EdgeInsets.fromLTRB`, `.only(left:/right:)` | `EdgeInsetsDirectional.fromSTEB`, `.only(start:/end:)` | `SectionHeader` (16,16,8,4), `home_page.dart` list paddings (12,8,12,168 / 16,8,8,96 / 8,8,16,96), `shares.dart` (16,0,16,8 / 16,4,16,4 / 12,0,12,24), `settings_page.dart` (12,8,12,16), wizards (16,8,16,32), `wifi_join_page.dart` |
| `Alignment.centerLeft/Right`, `TextAlign.left/right` | `AlignmentDirectional.centerStart`, `TextAlign.start/end` | `TransferSessionCard` uses `TextAlign.end` (correct already) |
| `Positioned(left:)` | `PositionedDirectional(start:)` | none today; watch the drop overlay |
| hard-coded arrows `Icons.arrow_forward`, `chevron_right` | Material icons that auto-mirror (`Icons.chevron_right`, `arrow_back` are in `matchTextDirection` set) — verify each; or `Transform.flip` under `Directionality.of(ctx) == TextDirection.rtl` | `settings_page.dart` `chevron_right` (auto-mirrors, OK) |
| `Row` that assumes left = first | `Row` is direction-aware by default; just never pass `textDirection: TextDirection.ltr` unless content is technical (4.5) | — |

Icons that must **not** mirror: `upload`, `download`, `send` (Material mirrors `send` automatically
— acceptable, it points "forward" in reading order), QR codes, `fingerprint`, media controls, the
pairing code. Progress bars fill from the start side in RTL, which is correct for Persian readers.

`QrImageView` never mirrors (it is a painted image), good. Keep its white background (`Colors.white`)
in both themes for scanner contrast.

### 4.5 Technical strings inside Persian text (bidi)

The Unicode bidi algorithm reorders neutral characters (`.`, `:`, `/`, `-`) around numbers, so an IP
`192.168.1.10:53317` inside an RTL paragraph can render as `53317:192.168.1.10` or with dots in the
wrong place, and a path `/storage/emulated/0/Download` flips its slashes. Rules:

1. **Standalone technical values** (IP, port, URL, fingerprint, pairing code, hotspot SSID and
   password, file paths, `selfUrl`, `webUrl`, share links): wrap the widget in
   `Directionality(textDirection: TextDirection.ltr, child: ...)` and align it to the start of the
   surrounding layout. Make a helper `LtrText(String, {style, key, selectable})` in `widgets.dart` and
   use it at: `SelfCard` `selfAddress`, `QrCard` `selfUrl`, `WebAccessCard` `webUrl`/`webHttpUrl`,
   `ShareCard` `shareUrl-*`, Settings address and fingerprint, `HotspotCard` SSID/password,
   `wifi_direct_page.dart` host address, pairing code (`pairingCode`), transfer "Saved to" path.
2. **Technical values inside a translated sentence** (`"No device answered at {address}."`): wrap the
   placeholder value in Unicode isolates before interpolation: `'⁦$value⁩'` (LRI…PDI). Helper
   `String ltr(String s) => '⁦$s⁩';` in `lib/l10n/bidi.dart`. Isolates are invisible, do
   not break `SelectableText` copying in practice (they are copied too; strip them in "Copy"
   handlers with `replaceAll(RegExp('[⁦-⁩]'), '')`).
3. **User-generated names** (device alias, file names, browser user-agent summary) can be Persian,
   Latin or mixed (`لپ‌تاپ Ali`, `گزارش-final.pdf`). Wrap them in *first-strong* isolates
   `'⁨$s⁩'` (FSI…PDI) so each name takes its own direction without disturbing the sentence.
   Helper `String iso(String s)`. As a standalone `Text`, give `textDirection: null` and let Flutter
   detect; for file names in lists use `Text(name, textDirection: Bidi.estimateDirectionOfText(name) ...)`
   from `intl` (`Bidi.detectRtlDirectionality`).
4. **File name truncation**: `TextOverflow.ellipsis` cuts the end; for LTR names in RTL lists the
   extension disappears. Use middle-ellipsis for file names (keep last 8 chars: `holiday-in-ki….jpg`),
   implemented in a small `ellipsizeMiddle(name, maxChars)` used in `TransferSessionCard` and the
   incoming dialog.
5. Input fields for technical values (Add by IP, manual SSID/password in `wifi_join_page.dart`, alias
   is *not* technical): set `textDirection: TextDirection.ltr` and `keyboardType: TextInputType.url`
   so the caret and digits behave. The alias field keeps automatic direction.

### 4.6 Numerals

Decision: **Latin digits for anything the user might type or compare with another device**; Persian
digits (۰۱۲۳۴۵۶۷۸۹) for quantities that are only read.

| Value | fa digits |
|---|---|
| IP, port, URL, pairing code, fingerprint, SSID, password, Wi-Fi channel | Latin (`192.168.1.10`, `4821`) |
| file sizes, counts, percentages, speeds, time left, minutes in share options, dates/times | Persian (`۳٫۱ مگابایت`, `۱۲ فایل`, `٪۶۴`) |

Reason: the pairing code is compared with a browser that may show Latin digits; IPs are typed on
keyboards where Persian digits produce a different string. Also accept Persian/Arabic-Indic digits in
the Add-by-IP field and convert them (`'۱۹۲'` → `'192'`) before the regex in `_AddByIpDialog._submit`.

Formatter utility `lib/ui/format.dart` (extend the existing file, which already has `formatBytes`):

```dart
String localDigits(String s, Locale l) => l.languageCode != 'fa' ? s :
    s.replaceAllMapped(RegExp(r'[0-9]'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
String latinDigits(String s) => s.replaceAllMapped(RegExp('[۰-۹٠-٩]'), ...);
String formatBytes(int bytes, L10n l, Locale loc)   // "3.1 MB" / "۳٫۱ مگابایت"
String formatSpeed(double bytesPerSec, L10n l, Locale loc)
String formatDuration(Duration d, L10n l, Locale loc) // "1 h 20 min" / "۱ ساعت و ۲۰ دقیقه"
String formatCount(int n, Locale loc)                 // NumberFormat.decimalPattern('fa')
```

Use `NumberFormat.decimalPattern('fa')` from `intl` for counts: it emits Persian digits, `٫` decimal
separator and `٬` grouping. Keep the old `formatBytes(int)` signature as a thin English wrapper so
the core and existing tests (`'1.2 GB'` in `ui_test.dart`) still compile and pass in `en`.

### 4.7 Units, dates and the Jalali calendar

Size and speed units in Persian (full words read better than Latin abbreviations in RTL text):

| en | fa |
|---|---|
| B / KB / MB / GB / TB | بایت / کیلوبایت / مگابایت / گیگابایت / ترابایت |
| MB/s | مگابایت بر ثانیه |
| min / h / s | دقیقه / ساعت / ثانیه |
| just now / {n} min ago | همین الان / {n} دقیقه پیش |
| less than a minute | کمتر از یک دقیقه |

Dates: the app shows only times and durations today (`_clock`, `_ago`, `_remaining` in `shares.dart`).
Recommendation: **no Jalali calendar in v1**. Use relative wording ("2 hours ago", «۲ ساعت پیش») and
`DateFormat.Hm('fa')` for clock times (Persian digits). If absolute dates are added later (transfer
history), use the `shamsi_date` package (pure Dart, MIT, ~40 KB) behind a `formatDate()` helper and
show Jalali for `fa`, Gregorian for `en`. Trade-off: Jalali is what Persian users expect on every
calendar date (showing Gregorian looks foreign), but it is another dependency and needs month names
(فروردین…اسفند); since no screen shows a date today, defer it.

### 4.8 Fonts, text scaling and input fields

- **Font**: bundle **Vazirmatn** (SIL Open Font License 1.1, which allows bundling in apps; include
  `OFL.txt` in the licence registry via `LicenseRegistry.addLicense`). Use the variable font
  `Vazirmatn[wght].ttf` (~120 KB) or Regular + Bold static files (~2 × 90 KB); either adds well under
  0.5 MB to the app. Reason to bundle: Android's default Persian fallback (Noto Naskh/Sans Arabic)
  varies by vendor, macOS falls back to Geeza Pro/Arial with poor Persian kerning, Windows to Segoe UI
  (acceptable), Linux often to DejaVu (poor). Vazirmatn also contains Latin glyphs designed to match,
  so mixed aliases look consistent.
- Apply it **only for fa**: in `buildTheme(brightness, locale)` set `fontFamily: locale.languageCode
  == 'fa' ? 'Vazirmatn' : null` so English keeps the platform font (Roboto / SF).
- **Line height**: Persian has taller ascenders/descenders and dots. Set `height: 1.5` for body
  styles and `1.35` for titles in fa via `textTheme.apply(heightFactor ...)` — or simply a fa-only
  `TextTheme` copy. Vazirmatn at the same point size looks larger than Roboto; keep sizes, do not
  shrink.
- **Text scaling**: test with `MediaQuery.textScaler` 1.3 (common on Android for older users) in both
  languages. Persian strings are typically 10-30% shorter than English, but buttons with two words
  can be wider; never fix button widths, always allow wrapping (`Wrap`, not `Row`) as `home_page.dart`
  already does for the FABs.
- **No letter-spacing** on Persian text: `letterSpacing: 8` on the pairing code is fine because the
  code stays Latin digits in an LTR box; never add letter-spacing to `SectionHeader` or titles
  (it breaks Persian joining).
- **ZWNJ**: Persian copy uses the zero-width non-joiner (`‌`, U+200C) in words like «می‌خواهد»,
  «دستگاه‌ها». It must stay in the ARB files (JSON keeps it; make sure editors do not strip it).
- **Input fields in dialogs** (alias, Add by IP, SSID/password): labels and hints translate, technical
  inputs are LTR (4.5 rule 5). `maxLength: 40` on the alias counts UTF-16 units; Persian with ZWNJ is
  fine within 40.

### 4.9 The browser page (`lib/core/web_assets.dart`)

The page stays one self-contained string (the test rules in `web_test.dart` stay valid). Add:

1. A small dictionary object in the script: `var T = {en: {...}, fa: {...}};` with ~37 keys
   (`sharedWithYou`, `sendFilesTitle`, `pairFirst`, `pairBtn`, `checkCode`, `chooseFiles`, `send`,
   `signOut`, `download`, `open`, `show`, `play`, status messages, `filesCount` as a function
   `n => ...`).
2. Language: `var lang = (navigator.languages || [navigator.language || 'en'])
   .map(l => l.slice(0,2)).find(l => T[l]) || 'en';` then `document.documentElement.lang = lang;
   document.documentElement.dir = lang === 'fa' ? 'rtl' : 'ltr';`. Optionally a `?lang=fa` override.
3. Static text in the HTML gets `data-t="key"` attributes and one loop sets `textContent` on load
   (never `innerHTML`, keeps the existing safety rule).
4. CSS: replace `text-align` / margins that assume LTR with logical properties
   (`margin-inline-start`, `padding-inline`); `.row` flex already mirrors. Add
   `font-family: Vazirmatn, Tahoma, system-ui` for `:lang(fa)` — but the page must not load external
   fonts, so it uses system fonts only (Tahoma exists on Windows; Android and iOS have Persian system
   fonts). Do not embed the font (size).
5. Numbers in fa: `n.toLocaleString('fa-IR')` for sizes and counts; the pairing code stays Latin
   (`.code` element gets `dir="ltr"`); file names get `dir="auto"` on their `<span class="name">`.
6. The page currently says "Connected to {alias}": alias inside `<bdi>` (`el('bdi', ...)`).

### 4.10 Diagnosis findings and other core texts

`lib/core/diagnosis.dart` is pure Dart and must stay Flutter-free, so it cannot use `L10n`. Proposal:

- Keep `Finding.code` (already stable) and add `final Map<String, String> params` (e.g. `{'ip':
  '10.0.0.8', 'port': '5000', 'error': 'timeout'}`). Keep `title/detail/fix/technical` as the English
  fallback (used by `formatDiagnosisReport`, CLI and the existing 16 diagnosis tests).
- In the UI, `lib/ui/finding_text.dart`: `FindingText localizeFinding(Finding f, L10n l)` switches on
  `f.code` and returns localised title/detail/fix using `f.params`; unknown codes fall back to the
  English fields. `FindingTile` uses it. `technical` is never translated (it is for support).
- "Copy report" stays English on purpose: support staff read it, and it is pasted into issues. Add
  one translated line at the top in fa ("این گزارش به انگلیسی است تا پشتیبانی بتواند آن را بخواند").
- Same pattern for `SendResult.error`: add `String? errorCode` (`declined`, `busy`, `unreachable`,
  `timeout`, `cancelled`, `fingerprint`) so the UI can say "declined" vs "failed" (3.3).
- The code switches in `hotspot_service.dart`, `wifi_join_service.dart`, `wifi_direct_service.dart`
  already take a `code`; move their bodies into ARB (`errHotspotPermission`, …) and pass `L10n` in.

Persian copy for the top findings (title / what it means + what to do; one combined sentence where
possible, plain words, technical words removed):

| code | English (new plain copy) | Persian |
|---|---|---|
| `server-down` | This device can't receive files right now. Restart LanDrop. [Restart] | این دستگاه الان نمی‌تواند فایل دریافت کند. LanDrop را دوباره راه‌اندازی کنید. [راه‌اندازی دوباره] |
| `discovery-failed` | Automatic search isn't working on this device. You can still connect with the other device's address. | جست‌وجوی خودکار روی این دستگاه کار نمی‌کند. هنوز می‌توانید با نشانی دستگاه دیگر وصل شوید. |
| `no-lan` | This device isn't connected to Wi-Fi. Connect both devices to the same Wi-Fi, or connect them directly. [Connect directly] | این دستگاه به وای‌فای وصل نیست. هر دو دستگاه را به یک وای‌فای وصل کنید یا مستقیم به هم وصلشان کنید. [اتصال مستقیم] |
| `vpn-active` | A VPN is on. It can hide nearby devices. Turn it off and try again. | یک VPN (فیلترشکن) روشن است و ممکن است دستگاه‌های اطراف را پنهان کند. آن را خاموش کنید و دوباره امتحان کنید. |
| `announce-blocked` | Devices only appear after a search. This Wi-Fi blocks automatic finding, but sending still works. | دستگاه‌ها فقط بعد از جست‌وجو ظاهر می‌شوند. این وای‌فای پیدا شدن خودکار را مسدود می‌کند، ولی ارسال همچنان کار می‌کند. |
| `probe-refused` | The other device is there, but LanDrop isn't open on it. Open LanDrop on it. | دستگاه دیگر در دسترس است، ولی LanDrop روی آن باز نیست. LanDrop را روی آن باز کنید. |
| `probe-timeout` | No answer from {address}. The Wi-Fi may keep devices apart, or a firewall blocks LanDrop. Try connecting directly. [Connect directly] | پاسخی از {address} نیامد. ممکن است وای‌فای اجازهٔ ارتباط دستگاه‌ها را ندهد یا دیوار آتش LanDrop را مسدود کرده باشد. اتصال مستقیم را امتحان کنید. [اتصال مستقیم] |
| `probe-unreachable` | That address can't be reached from here. The devices are probably on different networks. | از اینجا نمی‌توان به آن نشانی رسید. احتمالاً دستگاه‌ها در شبکه‌های مختلف هستند. |
| `probe-fingerprint-mismatch` | A different device is now at this address. If LanDrop was reinstalled there, that's expected: search again. | اکنون دستگاه دیگری در این نشانی است. اگر LanDrop آنجا دوباره نصب شده، طبیعی است: دوباره جست‌وجو کنید. |
| `different-subnet` | The devices seem to be on different Wi-Fi networks. Connect both to the same one (not a guest network). | به نظر می‌رسد دستگاه‌ها به وای‌فای‌های مختلف وصل‌اند. هر دو را به یک شبکه وصل کنید (نه شبکهٔ مهمان). |
| `mdns-visible-unreachable` | The other device is on your Wi-Fi, but a firewall blocks LanDrop. Allow LanDrop in the firewall on both devices. | دستگاه دیگر در وای‌فای شماست، ولی دیوار آتش جلوی LanDrop را گرفته است. در هر دو دستگاه به LanDrop در دیوار آتش اجازه دهید. |
| `hotspot-likely-fix` | No other device found yet. If LanDrop is open on it, this Wi-Fi probably keeps devices apart. A hotspot usually fixes it. [Connect directly] | هنوز دستگاه دیگری پیدا نشد. اگر LanDrop روی آن باز است، احتمالاً این وای‌فای دستگاه‌ها را از هم جدا نگه می‌دارد. معمولاً هات‌اسپات مشکل را حل می‌کند. [اتصال مستقیم] |
| `link-local-only` | Connected by cable. Give both devices a minute to get ready. | با کابل وصل است. یک دقیقه به هر دو دستگاه فرصت دهید تا آماده شوند. |
| `all-good` | Everything looks fine on this device. Make sure LanDrop is open on the other one. | همه‌چیز روی این دستگاه درست است. مطمئن شوید LanDrop روی دستگاه دیگر باز است. |

`network`, `udp-only-no-mdns`, `mdns-only`, `some-peers-silent`, `mdns-unavailable` are info-only:
hide them from the normal view (they live under "Details" and in the report).

### 4.11 Platform strings and packaging

- **Android notification** (`LanDropService.kt`): move "LanDrop is running", "Ready to receive files
  on your network", "Ready to receive", "{n} active shares", "{n} browser connected" into
  `android/app/src/main/res/values/strings.xml` (with `<plurals>`) and
  `android/app/src/main/res/values-fa/strings.xml`; use `getString` / `resources.getQuantityString`.
  Android picks the language from the system, or from the per-app language when set (below). The
  notification channel name ("LanDrop service") also goes there.
  fa: «LanDrop در حال اجراست»، «آمادهٔ دریافت فایل در شبکهٔ شما»، «آمادهٔ دریافت»، «{n} لینک فعال»، «{n} مرورگر متصل».
- **Android per-app language (13+)**: add `res/xml/locales_config.xml` with `en` and `fa` and
  `android:localeConfig` in the manifest, so the system "App language" setting lists Persian. When
  the user picks a language in LanDrop's own picker, mirror it with
  `AppCompatDelegate.setApplicationLocales` only if the app moves to AppCompat; otherwise the in-app
  picker alone is enough (Flutter renders its own UI). Keep it simple: in-app picker + `values-fa`.
- **Android manifest**: add `android:supportsRtl="true"` to `<application>` (absent today in
  `AndroidManifest.xml`; needed for the notification and system surfaces to mirror).
- **iOS** (`ios/Runner/Info.plist`): add `CFBundleLocalizations` = `[en, fa]` (without it iOS shows
  English system dialogs and lists no Persian in Settings ▸ LanDrop ▸ Language). Add
  `ios/Runner/fa.lproj/InfoPlist.strings` with `NSLocalNetworkUsageDescription` (the only usage
  string today) in Persian: «LanDrop دستگاه‌های دیگر شما را در این شبکهٔ وای‌فای پیدا می‌کند و فایل‌ها را
  مستقیم و بدون اینترنت برایشان می‌فرستد.» Register the `fa.lproj` folder in the Xcode project.
- **macOS** (`macos/Runner/Info.plist`): same `CFBundleLocalizations` key and `fa.lproj/InfoPlist.strings`
  (for the local network prompt text, if added). `CFBundleDevelopmentRegion` stays `en`.
- **Windows**: the runner's `Runner.rc` has English version strings only; nothing user-facing needs
  translation. Ensure the MSIX/installer (when added) declares `fa` as a supported language.
- **Linux**: nothing beyond Flutter.

### 4.12 Terminology (for native review)

| English | Chosen Persian | Alternatives / note |
|---|---|---|
| Send / Receive | ارسال / دریافت | — |
| Device | دستگاه | — |
| Nearby devices | دستگاه‌های اطراف | دستگاه‌های نزدیک |
| Hotspot | هات‌اسپات | نقطهٔ اتصال (formal, less known) — **review** |
| Wi-Fi | وای‌فای | — |
| VPN | VPN (فیلترشکن) | colloquial; may read as political — **review** |
| Firewall | دیوار آتش | فایروال (more common in speech) — **review** |
| Share link | لینک اشتراک | پیوند (formal) |
| Trusted device | دستگاه مورد اعتماد | — |
| Security code (fingerprint) | کد امنیتی | اثر انگشت گواهی (technical) |
| Pair a browser | اتصال مرورگر | جفت کردن (literal, awkward) — **review** |
| Accept / Decline | پذیرفتن / رد کردن | قبول / رد |
| Cable / USB tethering | کابل / اشتراک اینترنت با USB | — **review** against Android fa menus |
| Wi-Fi Direct | وای‌فای دایرکت | keep brand name |
| Folder | پوشه | — |

## 5. Visual design and accessibility

**Color.** Keep the Material 3 `ColorScheme.fromSeed(0xFF00897B)` in `app.dart`. Use roles, never raw
colors: primary actions `primary`, secondary `secondaryContainer` (tonal), surfaces
`surfaceContainerLow` for cards. Replace `Colors.orange.shade800` in `FindingTile` with a
`StatusColors` `ThemeExtension` (success / warning / error / info, light and dark values, each
>= 4.5:1 on `surface`). Status always uses **icon + text + color**, never color alone:

| Status | Icon | Token |
|---|---|---|
| Ready / done | `check_circle` | success (`#1B5E20` light, `#A5D6A7` dark, like the web page) |
| Working | progress indicator | primary |
| Needs attention | `warning_amber` | warning (`#7A4F00` / `#FFB960`) |
| Failed | `error` | `error` |
| Info | `info_outline` | `onSurfaceVariant` |

**Typography.** M3 type scale: screen title `titleLarge`, section `titleSmall` in `primary` (as
`SectionHeader` does), body `bodyLarge` for main messages (today many key messages are `bodySmall`,
e.g. the status line and the share explanations; raise them), technical values `bodyMedium` with
`fontFeatures: [FontFeature.tabularFigures()]`. fa: Vazirmatn, line height per 4.8.

**Spacing.** 4-pt grid: 8 between related items, 16 card padding and screen gutter, 24 between
sections. Phone gutter 16 (today 12), wide gutter 24. Cards `borderRadius 12`.

**Touch targets.** >= 48x48 dp. `SelfCard`'s rename `IconButton` with an 18 px icon is fine (the
button is 48), but the dense `ListTile`s in the incoming dialog and `TextButton`s in `ShareCard` rows
should keep `MaterialTapTargetSize.padded`. Desktop: hover states and pointer cursors come with
Material.

**Empty, loading, error states.** Every list has all three: empty = icon + one sentence + one
action; loading = inline progress with what we are doing ("Looking for devices…"); error = plain
sentence + retry + "Details". No raw exception text outside Details.

**Motion.** Material defaults only: 200 ms fade/size for appearing devices
(`AnimatedSwitcher`/`AnimatedList`), progress bars animate. No looping animations except the search
indicator; respect `MediaQuery.disableAnimations`.

**Dark mode.** Already follows the system (`ThemeMode.system`). Add Settings ▸ Theme (System / Light /
Dark) next to Language. QR codes keep a white quiet zone in dark mode (already done with
`Colors.white` containers).

**Layouts.** Breakpoint 840 px (the value `home_page.dart` already uses). < 840: single column,
one FAB. >= 840: navigation stays in the app bar; two panes, left = devices + activity, right = drop
zone + self card; dialogs max width 480 (`DiagnosisDialog` already 480, incoming 420); Settings and
pages keep `maxWidth: 640`.

**Keyboard and screen readers.**
- Desktop shortcuts: `Ctrl/Cmd+O` Send files, `Ctrl/Cmd+,` Settings, `Esc` closes dialogs (default),
  `Enter` = primary dialog action (wrap dialogs in `CallbackShortcuts`).
- Focus order follows reading order; in RTL it runs right to left automatically. Use
  `FocusTraversalGroup` per card so Tab moves card by card, and `OrderedTraversalPolicy` only where
  visual order differs from tree order (the wide two-pane home: left pane first in LTR, right pane
  first in RTL — i.e. the "start" pane first).
- `Semantics`: each `PeerTile` = one node "Work Laptop, computer, send" (`MergeSemantics`); transfer
  cards announce progress with `liveRegion: true` on state changes only (not every byte); QR codes
  already have labels (`WebAccessCard`, `ShareCard`) — add one to `QrCard` and `HotspotCard`; IPs read
  digit by digit is acceptable. Persian labels come from ARB like visible text; TalkBack and VoiceOver
  read Persian when the label's locale is fa (Flutter passes the app locale).
- Contrast: check both themes with the fa font, which is thinner at the same weight; use `w500` for
  `bodyMedium` in fa if contrast reviews flag it.

## 6. Implementation plan

Rules for every step: keep every existing `Key` (move it with the widget it identifies); keep the
English copy byte-identical until a step explicitly changes copy, and update the matching
`find.text` assertions in the same PR; `flutter analyze` clean; all 212 tests green.

**Test helper** (`test/helpers/pump_localized.dart`, added in step L1):

```dart
Future<void> pumpApp(WidgetTester t, Widget app,
    {Locale locale = const Locale('en'), double width = 1000, double height = 800}) async {
  t.view.physicalSize = Size(width, height); t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(app /* LanDropApp(..., store: MemorySettingsStore({'locale': locale.languageCode})) */);
  await t.pumpAndSettle();
}
void expectRtl(WidgetTester t) => expect(
    Directionality.of(t.element(find.byType(Scaffold).first)), TextDirection.rtl);
```

Overflow is caught automatically: a `RenderFlex overflowed` is reported as a test failure via
`FlutterError.onError`. A new `test/l10n_test.dart` pumps home (with peers, empty, with transfers),
the incoming dialog, the diagnosis dialog, Settings, the share options dialog and the helper in
`fa` at 375 px and 1000 px, asserts `expectRtl`, that no English key string leaks
(`find.text('Send')` finds nothing in fa), and that `LtrText` widgets have `TextDirection.ltr`.
A unit test checks that `app_fa.arb` has every key of `app_en.arb` and the same placeholders.

| # | Step | Size | Files | Notes |
|---|---|---|---|---|
| **L1** | l10n infrastructure: deps, `l10n.yaml`, empty-ish `app_en.arb`/`app_fa.arb`, delegates in `MaterialApp`, `locale` in settings JSON + picker in Settings, test helper | S | `pubspec.yaml`, `l10n.yaml`, `lib/l10n/*`, `app.dart`, `app_controller.dart`, `settings_page.dart`, `test/helpers/` | ships a working language switch with Material strings in fa |
| **L2** | Extract strings: home, widgets, dialogs (about 85) | M | `home_page.dart`, `widgets.dart`, `dialogs.dart`, ARB | English unchanged, Persian added |
| **L3** | Extract: settings, shares, diagnosis dialog (about 90) + formatters (`format.dart`) | M | `settings_page.dart`, `shares.dart`, `diagnosis_dialog.dart`, `format.dart` | |
| **L4** | Extract: wizards and Android services (about 190) | L | `hotspot_wizard.dart`, `cable_wizard.dart`, `wifi_*`, `hotspot_service.dart` | biggest; per-OS steps |
| **L5** | Finding params + `localizeFinding`; `SendResult.errorCode` | M | `lib/core/diagnosis.dart`, `lib/core/api.dart`, core send code, `lib/ui/finding_text.dart` | English fields stay → diagnosis tests unchanged |
| **L6** | Platform strings: Android `values-fa`, `supportsRtl`, `locales_config`; iOS/macOS `CFBundleLocalizations` + `fa.lproj` | S | `android/…`, `LanDropService.kt`, `ios/Runner/`, `macos/Runner/` | built in CI only (no local SDK) |
| **L7** | Browser page dictionary + `dir` | M | `lib/core/web_assets.dart`, `test/web_test.dart` (add a check that both dictionaries have the same keys) | |
| **R1** | RTL pass: `EdgeInsetsDirectional`, `LtrText`, `ltr()`/`iso()` isolates, middle ellipsis, LTR inputs, Persian-digit input normalising | M | all `lib/ui/*` | `l10n_test.dart` at 375/1000 |
| **R2** | Vazirmatn font for fa, line height, `StatusColors` extension | S | `assets/fonts/`, `pubspec.yaml`, `app.dart` | +~0.2-0.4 MB |
| **U1** | Home simplification: one Send FAB + Send sheet (Files/Folder), remove `QrCard`/`WebAccessCard`/`ConnectedBrowsersCard`/`SharesSection` from home, status line, device subtitles without IP | M | `home_page.dart`, `widgets.dart`, `ui_test.dart` | keep `sendFab`; `sendFolderFab` → sheet item key `sendFolder`; update tests that tap `shareFab`/`sendFolderFab` |
| **U2** | Share page with "Send a link" / "Use from a browser" (keeps `sharesAction`, `shareFiles`, `shareFolder`, `webAccessCard`, `connectedBrowsersCard`, `confirmShare`…) | M | `shares.dart` | |
| **U3** | Settings regroup + `AdvancedSettingsPage` (all existing keys move with their rows) | S | `settings_page.dart`, tests that scroll Settings | |
| **U4** | Connection helper page: automatic check, Q1/Q2, reuse `FindDevicePanel`, `HotspotCard`, `CableWizardPage` steps, `WifiJoinPage`, `WifiDirectPage`; `whyNoDevices` opens it | L | new `connect_helper.dart`, `widgets.dart`, `home_page.dart` | old wizards stay as pages for Advanced and tests |
| **U5** | Plain diagnosis presentation: one finding at a time, Details collapsed, report English | S | `diagnosis_dialog.dart` | keep `finding-*`, `copyReport`, `runAgain` |
| **U6** | Transfer cards: speed, time left, cancel (core `cancelSession`), open / show in folder, declined vs failed | M | `widgets.dart`, `app_controller.dart`, `api.dart`, core, `fake_core.dart` | new dependency decision for "open" on Android |
| **U7** | Receive dialog: sender kind, first-time/trusted, save folder, "Always accept"; Trusted devices in Settings | M | `dialogs.dart`, `app_controller.dart`, `settings_page.dart` | security review: auto-accept by fingerprint only |
| **U8** | Onboarding (3 screens) + just-in-time permission pre-prompts; stop calling `ensureStorageAccess()` from `init()` | M | new `onboarding.dart`, `app_controller.dart`, `storage_access.dart` | tests start with `onboarded: true` in `MemorySettingsStore` |
| **U9** | Desktop drag and drop; recent devices | M | `home_page.dart`, `app_controller.dart`, `pubspec.yaml` | |
| **U10** | Android share-target intent (later: iOS share extension) | L | `AndroidManifest.xml`, `MainActivity.kt`, `app.dart` | native, CI-only build |

Order: L1 → L2 → L3 → L5 → L4 → L6 → L7 → R1 → R2 → U1 → U3 → U2 → U5 → U4 → U6 → U7 → U8 → U9 →
U10. L4 is after L5 because the wizards show `FindingTile`. Each step is a separate PR and can ship.
Rough total: 6-8 developer-weeks including translation review.

**Risks.**
- *Test churn*: 94 `find.text` assertions are English; changing copy in U-steps breaks them. Mitigate
  by tests pumping `en` explicitly and, for new tests, finding by `Key` instead of text.
- *Translation quality*: machine-like Persian is worse than English. Budget a native review of the
  whole `app_fa.arb` (flagged terms in 4.12) before release.
- *Bidi bugs* show only with real mixed data: seed `fake_core.dart` with a Persian alias
  («لپ‌تاپ سارا»), a mixed file name and an IP for the fa tests.
- *Android native strings and manifest* are compiled only in CI (DESIGN.md notes no local SDK):
  keep L6 small and separate.
- *Hiding expert info*: power users lose the IP on home; Advanced and the device Details sheet keep
  it one tap away.
- *Trusted auto-accept* widens the attack surface (anyone who obtains a trusted device's key). Off by
  default per device; show a snackbar with Stop on every auto-accepted transfer.

## 7. Quick wins

Each under an hour, no new dependency, existing tests stay green or need a one-line update.

1. **Status line bigger and plain**: in `SelfCard`, show "Visible to nearby devices" in `bodyMedium`
   and move `IP · port` below it in `bodySmall` muted (keep `selfAddress` key).
2. **Remove the fingerprint from the incoming dialog**: replace the
   `ip · fingerprint …` line with the device kind ("Phone", "Computer"); keep IP for browsers only.
   Add "Saves to {folder}" next to the total.
3. **Shorten `EmptyPeersHelp`**: two sentences instead of five bullets (keep "AP isolation" text in
   the diagnosis only; update the `textContaining('AP isolation')` test), and make
   "Why can't I see my device?" the only filled button.
4. **Separate declined from failed** in `_sendFlow`: use `SendResult.error` already returned by
   `c.send` via the session (`s.error`) to show "{name} declined" when it says 403/declined.
5. **Hide the "Your network" finding** in `DiagnosisDialog` (still in "Copy report"), and render
   `technical` inside a collapsed `ExpansionTile` "Details".
6. **Explain the Android save folder**: in Settings' folder row, when the path is the app-private
   folder, show "Only visible inside LanDrop. [Use Downloads]" which calls `ensureStorageAccess()`.
7. **Label the two QR codes**: `QrCard` title "For another LanDrop app" and `WebAccessCard`
   "For any phone camera or browser", so users scan the right one.
8. **Add "Send folder" to a menu**: drop `sendFolderFab`; add a "Folder" item in a small sheet
   opened by `sendFab`'s long-press and in the peer picker; fewer FABs means no two-row wrap at
   375 px (keep the `sendFolderFab` key on the sheet item to keep the test).
9. **Plain Settings subtitle**: "Restart service" subtitle shows "Running" / "Stopped" instead of
   `c.status.name`, and the plain-HTTP title becomes "Allow browsers without a warning (not
   encrypted)".

## 8. Open questions for the product owner

1. **Trusted devices with auto-accept**: acceptable from a security point of view, and should it be
   per device, time-limited, or not offered at all?
2. **Android storage**: keep "All files access" (with the new pre-prompt) or move received files to
   the Storage Access Framework / MediaStore, which avoids the restricted permission and allows a
   Google Play release (DESIGN.md 8 asks the same)?
3. **New dependencies**: OK to add `desktop_drop` (drag and drop), a file-opening package for
   "Open" on Android, and the Vazirmatn font (+~0.3 MB)?
4. **Default language for Persian systems**: follow the system locale automatically (recommended),
   or always start in English and let users switch?
5. **Jalali dates**: not needed now (no absolute dates shown); if transfer history is added later,
   should fa show Solar Hijri dates by default?
6. **Terminology**: who does the native review, and which words for VPN («فیلترشکن» or "VPN") and
   hotspot («هات‌اسپات» or «نقطهٔ اتصال»)?
