# How TermPaste works

## The rule

A plain **⌘V** key-down becomes **Ctrl+V** when all of these hold at that moment:

1. Image paste is not paused, Accessibility is allowed and Secure Input is off.
2. The app receiving the key is on the list, enabled, and frontmost.
3. The general pasteboard holds exactly **one** item, and that item advertises a type conforming
   to `public.image` (PNG, TIFF, JPEG, HEIC…). The same item may also carry a file URL, as items
   from Paste do.
4. For an app set to **Terminal input only**, the focused control is a text field or text area
   whose description or title is the configured label (Orca's xterm uses `Terminal input`).

Its matching key-up is converted too, so the receiving app never sees a half-converted pair. A
held ⌘V stops repeating if any condition stops holding. Everything else — text on the clipboard,
file-URL-only items, several items, ⌘⇧V, ⌥⌘V, Ctrl+V itself, unlisted apps — passes through
untouched.

## The pieces

| Component | Role |
| --- | --- |
| `EventRouter` | Keeps one `CGEvent.tapCreateForPid` tap per running listed app, re-evaluated every two seconds and on app launch, quit and activation. Rewrites the flags of the original event in place and marks it so it is never processed twice. |
| `KeyRouter` | Pure state machine for key-down, key-up and repeat pairing. |
| `ClipboardProbe` | Reads only `NSPasteboard` item types; never reads data. |
| `TerminalFocus` / `FocusPolicy` | For *Terminal input only*: one bounded (35 ms) Accessibility query of the focused element's role, description and title. Never its value, selected text or window contents. |
| `AppListFile` | `apps.json`: written with the defaults when missing, re-read when it changes, never overwritten because it could not be read. |
| `SecureInputProbe` / `SecureInputReport` | Explains a Secure Input pause (see below). |
| `AppState` | The observable model shared by the menu and the SwiftUI Settings window. |

The app writes a status snapshot to `~/Library/Application Support/TermPaste/status.json`
(mode 600): permission and Secure Input state, connected apps, counters, and the bundle ID, time
and source PID of the latest decision. It holds no image data, text, file paths or history.

## Why rewrite the key instead of the clipboard

There are three ways to get a screenshot into a terminal CLI:

| | TermPaste | [CopyCat](https://github.com/andyhtran/CopyCat) | [clipaste](https://github.com/hqhq1025/clipaste) |
| --- | --- | --- | --- |
| Intercepts | ⌘V, per app, via event taps | ⌘V, as a hot key registered only while a target app is frontmost | Nothing; watches the clipboard |
| Delivers | Ctrl+V; the CLI reads the image itself | The image saved as JPEG, its path typed into the terminal | A file path added to the clipboard item |
| In the CLI | Native attachment (`[Image #1]`) | A path the agent reads as a file | A path |
| Writes files | No | Yes, a cache of recent images | Yes |
| Over SSH | No: the remote CLI cannot read this Mac's clipboard | Yes, copies the image to the host | Yes |

Rewriting the key keeps each CLI's own image handling — its preview, resizing and format
support — and leaves the clipboard exactly as the user put it. The cost is that it only helps a
CLI running on this Mac.

CopyCat's hot key is also a sound design: it stays out of the key stream until a target app is
in front. A registered hot key swallows the chord before any app sees it, so when the clipboard
turns out not to hold an image the chord has to be re-posted. Event taps instead see every ⌘V
of a listed app and pass most of them through unchanged, which also covers the ⌘V that Paste
posts for its *paste + Enter* action.

## Secure Input

While any process has Secure Input on (a focused password field, a password manager, a
terminal's *Secure Keyboard Entry*), macOS hides keystrokes from event taps, so image paste
pauses everywhere and resumes when it ends.

macOS offers no public API that names the holder. The app reads the undocumented
`kCGSSessionSecureInputPID` key of the console session, as CopyCat does, and words the result as
*the app macOS names*, not the app that holds it: in three tests on macOS 27, a background
process turned Secure Input on and the key named whichever app was in front (Chrome, Synara,
Orca). The advice line follows the case. When the named app is the one in front, it mentions
both that app's Secure Keyboard Entry (for a listed terminal) or a focused password field, and
password apps in the background; `loginwindow`, a process that has quit, or no name suggest
locking and unlocking the Mac.

## Signing and the Accessibility permission

macOS stores the Accessibility grant against the app's designated requirement. With a Developer
ID signature that requirement is the bundle ID plus the team ID, so rebuilt and moved copies keep
the grant; with an ad-hoc signature it is the code hash, which changes with every build. This was
measured: a rebuilt copy with a new code hash, and later the move from `~/Applications` to
`/Applications`, both kept the permission without asking again.

## Launch at Login

The app writes `~/Library/LaunchAgents/com.suatkocar.termpaste.plist`, which runs its
own executable at login (so System Settings → Login Items names the app) with no `KeepAlive`, so
quitting keeps it quit until the next login. Each launch of an installed copy points the agent at
itself; a build inside the repository never touches it. Turning the item off removes the file.

## Testing

`swift test` covers the key state machine, native event mapping (on events that are created in
memory and never posted), clipboard classification on private pasteboards, the focus policy, the
app list and its file handling, the paste tally, the Secure Input wording and the login agent.

Unit tests cannot prove that a terminal received the converted key. That was checked by hand with
physical key presses: image ⌘V and Paste's *paste + Enter* in Ghostty, Orca and super.engineering,
with normal text ⌘V still pasting text. Warp, Terminal and iTerm have not been checked end to end.
To check an app yourself, copy a screenshot, press ⌘V in an unsent prompt, and compare the
attachment with **Last ⌘V** in Settings → Diagnostics; then paste some text.
