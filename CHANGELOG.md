# Changelog

## 1.2.2 — 2026-10-29

- Full-screen windows always show in the switcher, titled or not (a video playing full screen in Safari, say).
- An app that's busy and slow to answer no longer drops out of the switcher; its windows on screen stay.
- Apps that turn into regular apps after launching now show up.
- Minimized windows and hidden apps' windows are found more reliably.
- Dock previews reconnect when the Dock restarts or rebuilds its icons (after a display change or wake), and match an app by bundle identifier when its Dock path differs.
- `Ferry --list-windows` prints every window Ferry sees and why it is or isn't in the switcher.
- When Harbor uninstalls Ferry, Ferry removes its own login item first, so nothing is left in System Settings › Login Items.

## 1.2.1 — 2026-10-29

- Signed with a stable Harbor certificate, so macOS keeps Ferry’s permissions when it updates. (Updating from 1.2 or earlier asks one last time.)

## 1.2 — 2026-10-29

- Works with the new [Harbor](https://kaandis.github.io/harbor/) hub: settings changed there apply to Ferry right away, and Ferry’s menu opens its Harbor page when Harbor is installed (its own Settings window otherwise).
- Ferry tells Harbor which permissions it has, so Harbor can show them.
- Shared design code now lives in [HarborKit](https://github.com/Kaandis/harbor-kit).

## 1.1 — 2026-10-28

- Appearance: Harbor’s cream or Liquid Glass (macOS 26 and later), and a highlight colour for the selection: pebble grey by default, or sky, mint, lilac, sun, coral, graphite or the system accent. Both in Settings → General.
- W, M, Q and H work while ⌥ is held, and search types plain letters on any keyboard layout.
- Windows that apps keep around after you close them (Music, Calendar…) no longer show up as switchable windows.
- Dock previews close the moment the pointer is on neither the Dock nor the preview.
- Window pictures are more reliable: every window of the app you leave is pictured, Spaces you arrive on are pictured once they settle, and a stuck capture no longer blocks a window.
- A smaller hint bar.
- On Ferry’s own website, ⌥Tab goes to the page, so the demo works with Ferry installed.

## 1.0 — 2026-10-28

First release.

- Window switcher on ⌥Tab (or ⌘Tab / ⌃Tab): every window, most recently used first, on every Space, with minimized, hidden and full-screen windows marked.
- Live window pictures through ScreenCaptureKit, kept in memory and refreshed only when something is about to show them.
- Search (press Space), and W / M / Q / H to close, minimize, quit or hide without letting go.
- Dock previews: rest on a Dock icon to see that app’s windows; click one to switch, or close it from the preview.
- A welcome window for the two permissions; Screen Recording is optional.
- English and Turkish with an in-app language picker.
- Near-zero CPU while idle: no polling, no mouse monitoring, no timers between uses.
