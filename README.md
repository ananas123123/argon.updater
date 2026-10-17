# Argon Installer

Windows per-user installer for Argon. This repository owns the installer and its packaging scripts; the Argon application remains in **ananas123123/argon.app** (https://github.com/ananas123123/argon.app).

## Current status

- Inno Setup EXE installer source is provided in installer/argon-installer.iss.
- The installer defaults to %LOCALAPPDATA%\Argon, lets the user choose another application directory, creates the Argon runtime data folders, installs shortcuts, supports silent installation, verifies installed payload files with SHA-256, and preserves user data on uninstall unless removal is explicitly selected.
- The updater and bootstrap executables are **not implemented yet**. The preparation script creates clearly marked placeholder README files instead of inventing fake executables. Argon installs and launches without an updater, but updating is not available yet.
- The Argon app repository currently has no published GitHub release. Therefore a release-based installer build cannot succeed until a release is published with the package described below.
- Code signing is intentionally not configured yet. Do not describe an unsigned installer as digitally signed.

## Release package contract

Publish a release asset named exactly **Argon-Windows-x64.zip** in **ananas123123/argon.app**. The ZIP should contain this layout at its root:

~~~text
App/
  Argon.exe
  Qt6*.dll
  platforms/qwindows.dll
  ...all other files deployed by windeployqt...
Updater/          # optional until updater is implemented
Bootstrap/        # optional until bootstrap is implemented
~~~

Include the complete deployed application directory, not just Argon.exe. The MinGW runtime, Qt DLLs, Qt platform plugin and QML dependencies must be present. Do not put a user's UserData, Updates, Logs, documents, credentials or development build directory into a release ZIP. The package preparation step deliberately copies only App, Updater and Bootstrap.

The manifest written during packaging records every payload file's relative path, byte size and SHA-256. Those hashes are compiled into the installer and checked against the installed files after copying. This detects accidental corruption; it does not establish publisher authenticity. Release signing and public-key verification remain a later step.

## Build the installer from an Argon release

Prerequisites: Windows 10/11 x64, PowerShell 5.1 or newer, and Inno Setup 6.

Double-click `build-installer.bat`, or run the PowerShell builder directly:

~~~powershell
.\tools\Build-Installer.ps1
~~~

The script downloads Argon-Windows-x64.zip from the latest Argon app GitHub release, validates and stages its payload, then invokes Inno Setup. The result is placed under dist\output\. A specific release tag can be selected:

~~~powershell
.\tools\Build-Installer.ps1 -ReleaseTag v0.1.0
~~~

Use -ReleaseAssetName if a future release adopts a different asset filename. If the release or asset is missing, the script stops and explains what is missing.

## Smoke-test before publishing the first release

The current app repository has build.bat, which deploys a runnable copy to the Windows Desktop Argon-sim folder. After running it successfully, prepare and compile the installer from that directory:

~~~bat
build-installer.bat -PayloadDirectory "%USERPROFILE%\Desktop\Argon-sim" -AppVersion "0.1.0-test.1"
~~~

Or run the PowerShell script directly:

~~~powershell
.\tools\Build-Installer.ps1 -PayloadDirectory "$env:USERPROFILE\Desktop\Argon-sim" -AppVersion "0.1.0-test.1"
~~~

If Windows redirects Desktop to OneDrive or another path, use the actual path to Argon-sim. For example, you may first run only the packaging checks:

~~~powershell
.\tools\Prepare-Installer.ps1 -PayloadDirectory "C:\path\to\Argon-sim" -AppVersion "0.1.0-test.1" -Force
~~~

The build requires the installed app payload to include Argon.exe, the Qt 6 runtime DLLs, platforms\qwindows.dll, QML deployment files and the MinGW runtime DLLs. It intentionally fails if required runtime files are missing.

Find ISCC.exe by installing Inno Setup 6 or supply its path:

~~~powershell
.\tools\Build-Installer.ps1 -PayloadDirectory "C:\path\to\Argon-sim" -AppVersion "0.1.0-test.1" -ISCCPath "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
~~~

## Test on a separate Windows account

1. Build the installer from a complete, working Argon-sim\App payload.
2. Copy the generated installer to a separate standard Windows account. Do not copy your development repository or a populated UserData folder.
3. Run the installer without administrator privileges. Leave the default path selected for the first test.
4. Confirm Argon launches, search and preview work, the Start Menu shortcut works, and %LOCALAPPDATA%\Argon\Logs\argon-runtime.log is created if runtime logging writes there.
5. Open Settings → Apps → Installed apps (or the classic Programs and Features list) and confirm Argon can be uninstalled by the same user.
6. Uninstall and choose to preserve the user data. Confirm %LOCALAPPDATA%\Argon\UserData remains.
7. Reinstall, uninstall again, and explicitly choose removal of user data. Confirm that the known user-data, update, log and runtime subdirectories under %LOCALAPPDATA%\Argon are removed; the parent folder can remain empty while Windows finishes uninstall cleanup.
8. Repeat installation with a custom application directory. The current Argon code resolves its writable runtime data root to %LOCALAPPDATA%\Argon unless ARGON_DATA_ROOT is set, so custom application location and runtime-data location are intentionally separate. The updater integration must account for the selected application path when updater binaries become available.
9. Try silent install on a disposable test account or virtual machine:

~~~powershell
ArgonInstaller-<version>-x64.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-
~~~

Use /DIR="D:\Apps\Argon" to select a custom install directory. Silent uninstall preserves data by default; explicit complete removal is available with unins000.exe /VERYSILENT /SUPPRESSMSGBOXES /REMOVEUSERDATA=1.

## Debugging helpers

- tools/Prepare-Installer.ps1: inspect, validate and stage a payload; generates dist\payload-manifest.json and the Inno Pascal verification include.
- tools/Build-Installer.ps1: obtains the release package (or uses a local staged app), runs preparation, and compiles the EXE.
- tools/Test-Installed-Argon.ps1: verifies an installed payload against its manifest and checks runtime folders.
- Inno Setup build output: dist\output.
- Runtime log: %LOCALAPPDATA%\Argon\Logs\argon-runtime.log.

## Important limitations before public distribution

- No real ArgonUpdater.exe or ArgonBootstrap.exe is included until those projects produce tested release binaries.
- No Authenticode signature or cryptographic release-manifest signature is configured. SHA-256 in this build pipeline detects file changes against the hashes embedded into the same installer, but does not prove who published the installer.
- Confirm third-party license notices and distribution obligations for Qt, MinGW and bundled fonts before distributing the installer outside testing.
- Installer compilation, Windows UI behavior, installation/uninstallation and a second-user test must be run on Windows. A successful commit does not substitute for those tests.
