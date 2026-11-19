# Uninstalling agent-town

agent-town has two parts, and each is removed on its own: the **app** (macOS or Windows) and the **town-link plugin** in Claude Code. You can remove either one. Without the app, town-link has nowhere to send events and does nothing; without the plugin, the app stays empty.

Quit the app first (menu bar or tray icon → Quit).

## 1. The town-link plugin (macOS and Windows)

In a Claude Code session:

```
/plugin uninstall town-link@agent-town-claude-code
```

```
/plugin marketplace remove agent-town-claude-code
```

Or from a terminal:

```bash
claude plugin uninstall town-link@agent-town-claude-code
```

```bash
claude plugin marketplace remove agent-town-claude-code
```

Then restart Claude Code (sessions already running keep the plugin they started with). The marketplace step is optional: it only removes the list of plugins from this repository.

If you turned town-link off with `/town off`, nothing else is left behind.

## 2. The app on macOS

### Installed with Homebrew

```bash
brew uninstall --cask agent-town
```

To also delete the app's settings and its data folder (the `zap` step):

```bash
brew uninstall --zap --cask agent-town
```

To forget the tap as well:

```bash
brew untap samsonchen/agent-town-claude-code
```

### Installed from the `.dmg`

Quit AgentTown, then drag `AgentTown.app` from Applications to the Trash.

### Leftovers (optional)

Homebrew's `--zap` removes these; with the `.dmg` copy, delete them yourself:

```bash
rm -rf ~/Library/Application\ Support/agent-town-claude-code
```

```bash
rm -f ~/Library/Preferences/ai.careactive.agenttown-claude-code.plist
```

If you turned on Settings → Open at login, the entry disappears from System Settings → General → Login Items once the app is gone. If it stays listed, select it there and click the minus button.

## 3. The app on Windows

Quit agent-town from its tray icon first. If the icon isn't visible, click the **^** arrow in the notification area.

### Installed from the Microsoft Store

Right-click **Agent-Town for Claude Code** in the Start menu and choose **Uninstall**, or open Settings → Apps → Installed apps, find it, and choose Uninstall. From a terminal:

```powershell
winget uninstall "Agent-Town for Claude Code"
```

or by its Store ID:

```powershell
winget uninstall 9N0G35LW0LNK
```

### Installed with `agent-town-setup-<version>.exe`

Open Settings → Apps → Installed apps, find **agent-town**, and choose Uninstall. The uninstaller stops a running copy, removes the app, its Start menu shortcut and its Open at login entry, and deletes the logs and the endpoint file.

### Leftovers (optional)

Both ways keep your settings (`settings.cfg`, with the window's position and size) in `%APPDATA%\agent-town-claude-code`, so a later reinstall looks as you left it. To delete them too, in PowerShell:

```powershell
Remove-Item -Recurse -Force "$env:APPDATA\agent-town-claude-code"
```

If agent-town is still listed in Settings → Apps → Startup after uninstalling, turn it off there.

## 4. Check that it is gone

- In Claude Code, `/town` no longer reports town-link, and `claude plugin list` doesn't list `town-link`.
- The menu bar or tray no longer shows the building icon.
- `endpoint.json` is gone from the data folder (`~/Library/Application Support/agent-town-claude-code` on macOS, `%APPDATA%\agent-town-claude-code` on Windows).

agent-town keeps no account and sends nothing off your computer other than what [privacy.md](privacy.md) lists, so there is nothing to cancel or delete elsewhere.
