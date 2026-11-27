# agent-town in the Microsoft Store

The Windows app can also be published in the Microsoft Store, as an MSIX package. The Store signs the package, so Windows shows no SmartScreen warning and Smart App Control lets it run. The installer on GitHub Releases ([releasing.md](releasing.md)) stays as it is; both are built from the same source and the same version number.

## The product in Partner Center

The Partner Center account is an individual developer account. The product "Agent-Town for Claude Code" (an MSIX app) has this identity, which the package manifest must use exactly:

- Package/Identity/Name: `SamsonChen.Agent-TownforClaudeCode`
- Package/Identity/Publisher: `CN=4A4000D9-1902-48E3-A565-40AF7CF26EC2`
- Publisher display name: `Samson Chen`
- Package family name: `SamsonChen.Agent-TownforClaudeCode_z4f7aag6y3hy2`
- Store ID: `9N0G35LW0LNK`
- Store page: https://apps.microsoft.com/detail/9N0G35LW0LNK (live since 2026-11-15, version 1.0.6; 1.0.8 live 2026-11-15; 1.0.9 passed certification 2026-11-16; 1.0.10 passed certification 2026-11-16; 1.0.11 to be submitted; the 1.0.13 package built 2026-11-26, not submitted; the 1.0.14 package built 2026-11-26, not submitted; the 1.0.15 package built 2026-11-26, not submitted; the 1.0.16 package built 2026-11-26, not submitted; the 1.0.17 package built 2026-11-27, to be submitted)
- winget: `winget install "Agent-Town for Claude Code"` (the full name; shorter ones found nothing on 2026-11-15) or `winget install 9N0G35LW0LNK` installs the Store version from the `msstore` source (`winget show --id 9N0G35LW0LNK --source msstore` lists it). No separate winget package is needed.

These are public (they are in every installed package); they are not secrets.

## How a Store copy differs

A Store copy is exported with the preset "Windows x64 Store", which adds the custom feature `store` (`Distribution.is_store()` in `app/windows/shell/distribution.gd`):

- **Updates:** the Store updates the app, so it does not check GitHub for a newer app; the Updates window says "The Microsoft Store keeps agent-town up to date." It still checks town-link's version and tells the user about sessions that run an older one. Settings → Updates keeps Check for updates automatically and Check now for that, with a note saying so.
- **Open at login:** the package declares a startup task (off until the user turns it on). Settings shows "Open at login…", which opens Windows Settings → Apps → Startup. A Store copy never touches the `Run` key: the Store puts each version in a new folder, and `LoginItem.repair()` would otherwise point the installer copy's entry at the package.
- **The data folder:** Windows normally keeps a packaged app's writes under `%APPDATA%` inside the package, where town-link would not find `endpoint.json`. The manifest excludes `%APPDATA%\agent-town-claude-code` from that (`virtualization:ExcludedDirectories`), so the Store copy uses the same folder, endpoint file and settings as the installer copy. Checked 2026-11-13 with no restricted capability (only `runFullTrust`), on a profile with and without the folder, and with a real Claude Code session.

Writes to the registry are not kept inside the package: a test copy's `repair()` rewrote the real `Run` value. Keep it that way: a Store copy must not write the `Run` key.

## Building the package

Needs the Windows SDK (`makeappx.exe`; `$env:MAKEAPPX`, else the newest under `Windows Kits\10\bin`), besides Godot.

```powershell
.\app\windows\scripts\release.ps1 -Store
```

It runs the tests, exports `app\windows\build\store\package\` with the Store preset, makes the icons from `shared\icons\app-icon-1024.png`, fills the manifest template `app\windows\installer\msix\AppxManifest.xml` with the version, and packs `app\windows\build\store\agent-town-<version>.msix`. The package is unsigned: Partner Center signs it.

To try it first, turn on Developer Mode (Settings → System → For developers), quit the installed agent-town, and register the package folder:

```powershell
Add-AppxPackage -Register app\windows\build\store\package\AppxManifest.xml
```

Start it from the Start menu (Agent-Town for Claude Code). Remove it afterwards with `Get-AppxPackage SamsonChen.Agent-TownforClaudeCode | Remove-AppxPackage`; a test copy and the installer copy should not run at the same time, as they share the endpoint file.

## Submitting

In Partner Center, Apps and games → Agent-Town for Claude Code → Start submission (the user does this):

1. **Pricing and availability:** free; markets as wanted.
2. **Properties:** category Developer tools; privacy policy URL `https://samsonchen.github.io/agent-town-claude-code/privacy.html`; website `https://samsonchen.github.io/agent-town-claude-code/`.
3. **Age ratings:** the questionnaire (no user-generated content, no purchases).
4. **Packages:** upload `agent-town-<version>.msix`.
5. **Store listings** (English, and Traditional Chinese if wanted): the description, screenshots (at least one, 1366×768 or larger), and a note that it needs Claude Code with the town-link plugin.
6. **Submission options, notes for certification:** that the app shows Claude Code sessions and needs Claude Code with town-link to show anything beyond an empty office; that `runFullTrust` is needed because it is a desktop app with a tray icon and a local loopback server for the plugin.

## Submitting an update

Each Windows release can go to the Store too. The Store package and the installer are built from the same commit and carry the same version.

1. Make the Windows release as [releasing.md](releasing.md) says (the version raised, `release.ps1 -Publish`).
2. Build the Store package from that commit:
   ```powershell
   git pull
   .\app\windows\scripts\release.ps1 -Store
   ```
   It prints the package's path: `app\windows\build\store\agent-town-<version>.msix`.

   Steps 3 to 6 can be done by a script instead: [Submitting with the script](#submitting-with-the-script).
3. In Partner Center, Apps and games → Agent-Town for Claude Code → **Start update**. This copies the last submission.
4. **Packages:** remove the old `.msix` (the trash icon on its row) and upload the new one. Partner Center checks it; the version must be higher than the published one.
5. **Store listings** (optional): "What's new in this version" can take the version's entry from `CHANGELOG/CHANGELOG_WINDOWS.md`. Change the description or screenshots only if the app looks different.
6. **Submit to the Store.** Pricing, properties, age rating and the certification notes carry over. Store users get the new version automatically once it passes, but not at once: the Store checks for updates in the background, which can take from a few hours to a day after publishing. To get it right away: Microsoft Store → Library (Downloads) → Get updates. The app itself does not say a newer version exists (it never checks GitHub for a newer app).

A product has one submission at a time. When a new version is ready while the last one is still in certification, either let that one finish and then submit the newest package (the usual way), or cancel it in Partner Center and submit the newest package instead, which starts certification over. Versions in between need not go to the Store: submit the newest one.

## Submitting with the script

`app\windows\scripts\store-submit.ps1` does steps 3 to 6 of "Submitting an update" with the Microsoft Store Developer CLI (`msstore`). It takes the package `release.ps1 -Store` built for the version in `project.godot`.

```powershell
.\app\windows\scripts\store-submit.ps1 -Status          # the current submission's status
.\app\windows\scripts\store-submit.ps1 -Draft           # upload, keep the submission as a draft
.\app\windows\scripts\store-submit.ps1                  # upload and submit to certification
.\app\windows\scripts\store-submit.ps1 -DeletePending   # delete the pending submission first, then submit
```

`msstore publish` deletes a pending draft and makes a new submission from the last published one, so the listing, pricing, properties, age rating and certification notes carry over; only the package changes. "What's new in this version" is not set by the script: change it in Partner Center (a `-Draft` submission is the moment) if wanted. When a submission is in certification, publish may refuse; `-DeletePending` deletes it first (msstore asks to confirm), which starts certification over.

**Credentials stay out of the repo.** The script holds none and never asks for them. `msstore` keeps its own, set once by the user in their own terminal (not in a script, a commit or a chat). `.gitignore` also ignores `.env`, `*.pfx`, `*.p12`, `*.local.ps1`, `*credentials*.json` and `msstore*.json`, in case one lands in the checkout.

One-time setup (the user does this):

1. Install the CLI: `winget install --id 9P53PC5S0PHJ --source msstore` (installed 2026-11-27, version 0.4.4.3), then open a new terminal.
2. Partner Center → gear → Account settings → **Tenants**. With no organization or tenant to associate, select **Create Microsoft Entra ID** (free) and follow the wizard: it makes a new directory (`<name>.onmicrosoft.com`) and its global admin account. Adding an Entra application needs a Partner Center Manager who is also that tenant's global admin, so do step 3 signed in to Partner Center as the new admin account, if your usual sign-in is refused.
3. Account settings → User management → **Microsoft Entra applications** → Add Microsoft Entra application → Create Microsoft Entra application (any display name; any unique reply URL, such as `https://localhost/agent-town`, which msstore does not use), with the **Manager** role, and add a key (client secret; it is shown once). Note the tenant ID and client ID. The Seller ID is in Account settings → Legal info → Developer.
4. In your own terminal:
   ```powershell
   msstore reconfigure --tenantId <tenant> --sellerId <seller> --clientId <client> --clientSecret <secret>
   ```
5. Check: `msstore info` prints the configuration, and `.\app\windows\scripts\store-submit.ps1 -Status` the submission's status.

Not yet known: whether Partner Center offers Microsoft Entra applications to an individual developer account (this one is). If it does not, submit in Partner Center as above.

A stuck submission (2026-11-27): Submission 10 (`1152921505702517492`) is unfinished and Partner Center's website cannot open it (Microsoft ticket 2611270060000470). Try `store-submit.ps1 -Status`, then `-DeletePending` to clear it, so the 1.0.17 package can go in a new submission.
