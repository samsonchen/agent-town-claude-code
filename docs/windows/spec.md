# Windows app spec

The Windows app runs on Windows 11 on x64 (the installer also allows Windows 10, untested), with ARM64 as a nice-to-have (an x64 build also runs on ARM through emulation). It draws the same office from the same protocol and follows the main [spec](../spec.md), except where this document says otherwise.

It has its own version number, separate from the macOS app and from town-link. The protocol version alone decides whether a plugin and an app work together.

## First version

Included: the office and its blocks, the CEO's and the Chief of Staff's calls, staff and the resource bench, desk workers, operators, approvals, the context bar, the sounds, and the tray menu. That is about scenes 1 to 12 of the main spec.

Since W2 ([roadmap.md](roadmap.md)) the Windows app has every scene of the main spec: the Dispatcher's board (13 and 14), the Inspector (15), messages (16) and compaction (17), and walking the CEO, with the tips, Hide the window when no session is open, Hide idle project blocks (with the hidden blocks' context bars), the office growing with the window, small windows, auto-scroll and the update notices. Each is to be confirmed by hand before the release. The installer and signing come last, once every feature is confirmed.

## Differences from the macOS app

| Topic | macOS | Windows |
|---|---|---|
| Where the app lives | Menu bar icon, no Dock icon | Tray icon (notification area), no taskbar button. Closing the office window hides it; the app keeps running. |
| Menu | The menu bar menu | The same items in the tray icon's menu (Show tips is in Settings → Office, as on the Mac). A left click on the icon shows a hidden window, and opens the menu while the window is showing (since 1.0.12, as on the Mac); a right click always opens the menu. Windows 11 first puts a new tray icon among the hidden icons (the ^ arrow); it can be dragged out to stay in view. |
| Sounds | macOS system sounds (Glass, Ping, Pop) | Windows system sounds from `C:\Windows\Media`, played from there and never bundled: completion `Windows Notify.wav`, approval `Windows Exclamation.wav`, dispatch `Speech Disambiguation.wav` (the user's picks, 2026-11-13). A missing file plays nothing. |
| Sound choices (spec: sound settings) | The sounds in `/System/Library/Sounds` | Every WAV file in `C:\Windows\Media` (70 on Windows 11), listed by name without `.wav`, sorted, with the default first. Defaults: completion `Windows Notify`, approval `Windows Exclamation`, dispatch `Speech Disambiguation`. Own files: WAV, MP3 or Ogg Vorbis (what Godot loads at run time); the path is kept, the file is not copied. |
| Waking the audio output (spec: sound settings) | macOS only: after a long idle, a USB speaker dropped the first sound, so 0.7 s of silence plays first (macOS app 1.0.16) | **Not built, and Windows may not need it.** Windows may not have the problem; nobody has checked yet. Check by hand on a Windows machine with a USB or other external output (`todo.md` section 6) before building anything. If the first sound after a long idle is lost there too, do the same as the Mac (`SoundPlayer.preview` in `app/macos/Sources/AgentTown/Sounds.swift`) |
| Window sizes | Points; the smallest window is 320 × 240 | Pixels; the smallest window is 320 × 240. One saved window size, in the `window_compact` section of `settings.cfg` (since 1.0.12, when Large view was removed; a size saved in large view's `window` section is not carried over). A window larger than the office draws it larger, up to 3× (165 pixels per meter), with its text; in a wide window the project blocks sit side by side in columns (since 1.0.12, as the macOS app 1.0.21; `docs/spec.md` → A window larger than the office). A new installation (no size saved) opens compact at the smallest width, 320, in the top-right corner of the primary screen's usable area (since 1.0.9): the frame 12 pixels below the top, the window's right edge 12 pixels in. Its height fits the office and follows it as blocks come and go (since 1.0.10; 1.0.9 kept it at 240), as the user did not choose the size; the office auto-scrolls only when it is taller than the screen or the user made the window smaller. The tip at the bottom wraps in a window too narrow for it on one line |
| Update notices | A dot on the menu bar icon; Homebrew's command or the `.dmg` | A red dot on the tray icon; the Download button opens the installer from the newest `windows-v` release. Until the first Windows release, a check finds none and says agent-town is up to date. Dev flags: `--fake-update`, `--check-now`, `--open updates` |
| Open at login | A login item macOS manages | An entry in the user's startup apps (Settings → Apps → Startup) |
| Language | Follows the macOS language list | Follows the Windows display language: `zh_TW`, `zh_HK`, `zh_MO` and any `zh_Hant` locale get Traditional Chinese; every other locale, including Simplified Chinese, gets English |
| Font | System font for now; Cubic 11 planned | Cubic 11 (俐方體11號) from the first version, because Traditional Chinese must show and the engine's default font has no Chinese characters |
| Install | Homebrew cask or a signed `.dmg` | The Microsoft Store (also through winget, `winget install 9N0G35LW0LNK`), or an installer `.exe` on GitHub Releases. Not code-signed: Windows shows "Windows protected your PC", and the user clicks More info → Run anyway. The signed version is the Microsoft Store package ([store.md](store.md)). |
| Update notices (spec: Updates) | Newest `v*` release; a red dot on the menu bar icon; the Updates window shows the brew command or the `.dmg` Download button | Newest `windows-v*` release (by tag: GitHub's "Latest" stays on the macOS release); a red dot on the tray icon; the Updates window shows a Download button for the installer, which replaces the installed app when run. Until the first Windows release there is no `windows-v*` tag: show no app update, and say "Not checked yet" only before any check has answered. town-link's part is the same on both. No system notifications on either. |

## Where it works

Claude Code run natively on Windows: the terminal (PowerShell, Command Prompt, Git Bash), the Code tab of the Claude Desktop app, and the VS Code extension.

Not supported: sessions inside WSL or WSL2 (they cannot see the Windows endpoint file), plus everything the main spec lists as unsupported.
