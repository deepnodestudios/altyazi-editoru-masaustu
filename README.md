# altyazi_editoru

A new Flutter project.

## Cloud (Dropbox / Yandex Disk) OAuth Setup

This app uses OAuth for Dropbox, and a Yandex-friendly OAuth flow for Yandex Disk.

### 1) Redirect URI

The app is currently configured to use this redirect URI:

- `com.deepnode.altyaziceviri://oauth2redirect`

This must be registered in:

- The provider console (Microsoft/Dropbox/Yandex)
- Android intent-filters / iOS URL schemes (already present for the default package)

If you change the app id/package name, update `CloudOAuthConfig.redirectScheme` accordingly.

Note: Yandex requires an HTTPS Redirect URI for “Web services”. For mobile apps we use Yandex’s
built-in `https://oauth.yandex.com/verification_code` page (it shows a confirmation code to the user).

### 2) Provide OAuth credentials at runtime

Credentials are read from `--dart-define` (so you don’t hardcode secrets in git).

Examples:

- Dropbox:
	- `--dart-define=DROPBOX_CLIENT_ID=...`
- Google (desktop sign-in):
	- `--dart-define=GOOGLE_OAUTH_CLIENT_ID=...`
- Yandex Disk:
	- `--dart-define=YANDEX_CLIENT_ID=...`
	- `--dart-define=YANDEX_CLIENT_SECRET=...`

Run example:

- `flutter run --dart-define=GOOGLE_OAUTH_CLIENT_ID=XXX --dart-define=DROPBOX_CLIENT_ID=YYY --dart-define=YANDEX_CLIENT_ID=ZZZ --dart-define=YANDEX_CLIENT_SECRET=WWW`

### 3) Provider console notes

Dropbox:

- Create an app in Dropbox Developer Console
- Add Redirect URI: `com.deepnode.altyaziceviri://oauth2redirect`
- Use the app key as `DROPBOX_CLIENT_ID`

Yandex Disk:

- Create an app at https://oauth.yandex.com/client/new/
- Under Platforms, enable **Web services** and set Redirect URI to: `https://oauth.yandex.com/verification_code`
- Keep **Android app** enabled too (package name + SHA256) for their mobile app validation fields.
- Use ClientID as `YANDEX_CLIENT_ID` and Client secret as `YANDEX_CLIENT_SECRET`

### 4) VS Code launch config (optional)

You can add the `--dart-define` flags to your VS Code launch configuration so you don’t need to type them every time.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Windows Release (Optimized)

For a smaller and faster Windows desktop release:

- C++ release/profile optimizations are enabled in `windows/runner/CMakeLists.txt`.
- Dart release build can use obfuscation + split debug symbols.

Build with the helper script:

- `pwsh ./tool/build_windows_release.ps1`

Optional flags:

- `pwsh ./tool/build_windows_release.ps1 -Clean` (runs `flutter clean` first)
- `pwsh ./tool/build_windows_release.ps1 -NoObfuscate` (skip obfuscation)

Optional code-signing args (recommended for SmartScreen/antivirus reputation):

- `-CodeSignCertThumbprint ...` (certificate in Windows cert store)
- or `-CodeSignPfxPath ... -CodeSignPfxPassword ...` (PFX file)
- `-CodeSignTimestampUrl http://timestamp.digicert.com`

Optional OAuth args for release build:

- `-GoogleOauthClientId ...`
- `-DropboxClientId ...`
- `-YandexClientId ...`
- `-YandexClientSecret ...`

Example:

- `pwsh ./tool/build_windows_release.ps1 -GoogleOauthClientId XXX -DropboxClientId YYY -YandexClientId ZZZ -YandexClientSecret WWW`

Output folder:

- `build/windows/x64/runner/Release`

Installer build (with optional signing):

- `pwsh ./tool/build_windows_installer.ps1`
- `pwsh ./tool/build_windows_installer.ps1 -CodeSignPfxPath C:\certs\codesign.pfx -CodeSignPfxPassword "***"`

Notes:

- Unsigned EXE/installer files are frequently blocked on other PCs.
- For best compatibility, sign both app EXE and installer EXE with an EV/OV code-signing certificate.

## Unsigned Installer End-User Guide (Windows)

If you distribute an unsigned installer, users may see SmartScreen/antivirus warnings. Share these steps:

1) Download

- Download the installer from your official link only.
- File name example: `AI_Subtitle_Translator_Editor_Desktop_vX.Y.Z.exe`

2) SmartScreen warning (`Windows protected your PC`)

- Click `More info`.
- Click `Run anyway`.

3) If antivirus quarantines or blocks the file

- Open Windows Security (or your AV quarantine list).
- Restore the installer/app if quarantined.
- Add an allow/exclusion rule only for this installer/app path.

4) Install

- Right-click installer → `Run as administrator` (recommended).
- Finish setup and launch from desktop/start menu shortcut.

5) First launch

- If firewall asks, allow network access so cloud/AI features can work.

6) Troubleshooting

- If app does not start, reinstall after temporarily closing conflicting AV real-time scan.
- If still blocked, redownload from official source and retry.

Note for distributors:

- Unsigned builds are expected to trigger warnings on some systems.
- To remove most warnings, use OV/EV code signing for both app EXE and installer EXE.

## Android Signing (Secure)

Do not store real signing credentials in git.

- Use environment variables for release signing:
	- `ANDROID_KEY_ALIAS`
	- `ANDROID_KEY_PASSWORD`
	- `ANDROID_STORE_FILE`
	- `ANDROID_STORE_PASSWORD`
- Or create a local (untracked) `android/key.properties` file from `android/key.properties.example`.

## Desktop Selection Behavior (Dev Note)

Desktop multi-selection in cloud pickers, selected-files list, and history list follows these rules:

- `Click`: single selection (replaces current selection)
- `Ctrl/Cmd + Click`: toggle one item (discontiguous selection)
- `Shift + Click`: range selection from last anchor
- `Ctrl/Cmd + Shift + Click`: add range to existing selection
- `Ctrl/Cmd + Drag (marquee)`: add rectangle hit items to existing selection
- `Drag (marquee)` without modifier: replace selection with rectangle hit items
- `Ctrl/Cmd + A`: select all visible selectable items

Anchor policy:

- Anchor is updated on successful item selection actions.
- Anchor is reset when selection becomes empty or selection mode exits.

## Translation Credit/Stop Regression Checklist

Use this checklist after translation/billing changes:

- Scenario A (first chunk arrives):
	- Start single-file translation.
	- Wait until first successful chunk.
	- Verify credit decreases by `1`.
	- Press `Stop`, then start same file again.
	- Verify credit does **not** decrease again for the same run resume.

- Scenario B (stop before first chunk):
	- Start a different file.
	- Press `Stop` before first chunk success.
	- Verify credit does **not** decrease.
	- Verify file remains in selected files list.
	- Verify log contains `log_translation_stopped_kept_in_list`.

- Scenario C (stop after first chunk):
	- Start translation and wait for first chunk success.
	- Press `Stop`.
	- Verify partial state is in History.
	- Verify file is removed from selected files list.
	- Verify log contains `log_translation_saved_removed_list`.

Optional backend verification:

- Check recent function logs:
	- `firebase functions:log --only consumeCredit -n 50`
- Confirm no duplicate charge for a single translation run (`chargeKey` idempotency).
