# Changelog

## 0.3.0 — 2026-10-11

- Renamed from Terminal Image Paste to TermPaste; the bundle identifier is now
  `com.suatkocar.termpaste`.
- The app list is no longer compiled in. Add apps from the menu (**Add “…”** for the app you used
  last) or from Settings (**Add App…**), switch them on and off, remove them, or edit
  `apps.json` by hand; changes apply within two seconds.
- Each app can route in the **Whole app** or only in its **Terminal input**; Orca's terminal rule
  is now an ordinary setting, and super.engineering's separate menu switch is gone.
- New menu: a status header with what is connected and the latest paste, one submenu per app,
  Pause, Settings, Launch at Login.
- New Settings window with General, Apps and Diagnostics tabs.
- Secure Input pauses now say which app macOS names and what usually ends the pause; the menu bar
  icon shows a dot while image paste cannot work.
- App icon and menu bar icon.
- Installs to `/Applications`; an earlier copy in `~/Applications` is kept as a backup.
- Quits cleanly on SIGTERM.
- Requires macOS 14.

## 0.2.0 — 2026-10-11

- Launch at Login through a LaunchAgent that runs the app itself.
- Signed with Developer ID, so rebuilds keep the Accessibility permission.

## 0.1.0 — 2026-10-09

- First version: image-bearing ⌘V becomes Ctrl+V in Ghostty, iTerm, Warp, Terminal, Orca
  (terminal input only) and super.engineering.
