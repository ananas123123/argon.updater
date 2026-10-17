# Argon installer test plan

Run this plan against a disposable Windows 10/11 x64 account or a clean virtual machine. Never test destructive uninstall options against irreplaceable personal data.

## 1. Build and payload validation
- [ ] Run Argon build/deployment and confirm Argon.exe starts from the staged App folder before packaging.
- [ ] Run Prepare-Installer.ps1. It must reject missing Argon.exe, required Qt DLLs, qwindows.dll, QML deployment files or MinGW runtime DLLs.
- [ ] Confirm the payload contains only App, Updater and Bootstrap; it must not contain UserData, Updates, Logs or development build folders.
- [ ] Confirm payload-manifest.json lists every staged file and includes a SHA-256 hash and byte size.
- [ ] Confirm the installer does not include fake updater/bootstrap executables.
- [ ] Compile with Inno Setup 6 and retain its full compiler output.

## 2. Interactive installation
- [ ] Run as a standard user with no elevation prompt.
- [ ] Confirm Windows 10/11 x64 is accepted and unsupported architectures are rejected.
- [ ] Check the default folder is %LOCALAPPDATA%\Argon and the custom folder selector works.
- [ ] Check available disk space and permission failures produce understandable messages.
- [ ] Confirm required runtime folders are created without populating Search QR with the repository's sample PDFs.
- [ ] Confirm the Start Menu shortcut works. Test the optional desktop shortcut and startup entry separately.
- [ ] Confirm the launch option starts Argon and that the app runs without the developer's Qt/MinGW paths on PATH.
- [ ] Confirm Setup's log can be located and contains actionable diagnostics.

## 3. Integrity and error handling
- [ ] Run Test-Installed-Argon.ps1 after installing and check every hash.
- [ ] On a disposable copy only, corrupt a staged DLL before compiling; the generated manifest should reflect the changed file, so also test a deliberately altered installed file against the manifest and confirm the verification script reports it.
- [ ] Confirm the install-time post-copy hash check rejects a missing or modified installed file.
- [ ] Simulate insufficient space and access denied on a disposable VM. Record the exact message and ensure existing user data remains intact.
- [ ] Cancel installation at each wizard page and confirm no unrelated folders or personal files are removed.
- [ ] Test upgrade over an existing test install and record how the prior application payload is handled.

## 4. Uninstallation and data retention
- [ ] Uninstall and answer Yes to keep data. Confirm UserData, Updates and Logs are retained.
- [ ] Reinstall and choose No to remove data. Confirm the managed user-data, update, log and runtime subdirectories under %LOCALAPPDATA%\Argon are removed; the parent folder may remain empty during final cleanup.
- [ ] Select Cancel at the data prompt. Uninstall should stop without removing application files.
- [ ] Test silent uninstall with default options; data must be preserved.
- [ ] Test silent complete removal using /REMOVEUSERDATA=1 only on a disposable account.
- [ ] Confirm the Start Menu, desktop and startup shortcuts are removed.
- [ ] Reinstall immediately after uninstall to check stale files do not interfere.

## 5. Separate-user acceptance
- [ ] Copy only the installer EXE to a second standard Windows account.
- [ ] Verify no developer repository, source code, build tools, Qt install or MinGW install is required on that account.
- [ ] Launch Argon and exercise representative search, open-file preview and document workflows.
- [ ] Verify logs can be used to diagnose a failed launch.
- [ ] Record OS build, installer version, selected paths, outcome, and any error text before reporting a bug.

## Scope and known gaps

The current updater and bootstrap executables are placeholders-by-absence, not implemented components. Automatic updates, rollback of application versions, repair/modify mode, release signature verification and Authenticode signing are not complete. SHA-256 checks protect against accidental corruption when paired with the installer-embedded hash table, but without a signed release manifest they do not authenticate a publisher.
