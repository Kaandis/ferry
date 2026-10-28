# Changelog

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
