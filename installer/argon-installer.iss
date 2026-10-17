#ifndef AppVersion
  #define AppVersion "0.1.0-dev"
#endif
#ifndef AppFileVersion
  #define AppFileVersion "0.1.0.0"
#endif

#define ProductName "Argon"
#define PayloadDir "..\dist\payload"
#define PayloadManifest "..\dist\payload-manifest.json"

[Setup]
AppId={{1B7DD9B0-86E9-4D4C-9C5B-3D8C8BA9B6E2}
AppName={#ProductName}
AppVersion={#AppVersion}
AppVerName={#ProductName} {#AppVersion}
AppPublisher=Argon
AppPublisherURL=https://github.com/ananas123123/argon.app
AppSupportURL=https://github.com/ananas123123/argon.updater
AppUpdatesURL=https://github.com/ananas123123/argon.app/releases
DefaultDirName={localappdata}\Argon
DefaultGroupName=Argon
DisableProgramGroupPage=yes
DisableWelcomePage=no
AllowNoIcons=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0
WizardStyle=modern
SetupLogging=yes
CloseApplications=yes
RestartApplications=no
UninstallDisplayName=Argon
UninstallDisplayIcon={app}\App\Argon.exe
OutputDir=..\dist\output
OutputBaseFilename=ArgonInstaller-{#AppVersion}-x64
Compression=lzma2/ultra64
SolidCompression=yes
VersionInfoCompany=Argon
VersionInfoDescription=Argon Windows Installer
VersionInfoProductName=Argon
VersionInfoProductVersion={#AppFileVersion}
VersionInfoVersion={#AppFileVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional options:"; Flags: unchecked
Name: "startwithwindows"; Description: "Start Argon automatically when I sign in"; GroupDescription: "Additional options:"; Flags: unchecked
Name: "launchargon"; Description: "Launch Argon when setup finishes"; GroupDescription: "Additional options:"

[Dirs]
; AppPaths currently resolves writable runtime data under %LOCALAPPDATA%\Argon.
; These folders remain on normal uninstall; the user chooses whether to remove data.
Name: "{localappdata}\Argon\App"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\Updater"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\Bootstrap"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\UserData\Settings"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\UserData\Cache"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\UserData\Search QR"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\UserData\Documents"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\UserData\Accounts"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\UserData\Analytics\Daily"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\Updates\Downloads"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\Updates\Staging"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\Updates\Backups"; Flags: uninsneveruninstall
Name: "{localappdata}\Argon\Logs"; Flags: uninsneveruninstall

[Files]
Source: "{#PayloadDir}\App\*"; DestDir: "{app}\App"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PayloadDir}\Updater\*"; DestDir: "{app}\Updater"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PayloadDir}\Bootstrap\*"; DestDir: "{app}\Bootstrap"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PayloadManifest}"; DestDir: "{app}"; DestName: "payload-manifest.json"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Argon\Argon"; Filename: "{app}\App\Argon.exe"; WorkingDir: "{app}\App"
Name: "{autodesktop}\Argon"; Filename: "{app}\App\Argon.exe"; WorkingDir: "{app}\App"; Tasks: desktopicon
Name: "{userstartup}\Argon"; Filename: "{app}\App\Argon.exe"; WorkingDir: "{app}\App"; Tasks: startwithwindows

[Run]
Filename: "{app}\App\Argon.exe"; Description: "Launch Argon"; WorkingDir: "{app}\App"; Flags: postinstall nowait skipifsilent; Check: WizardIsTaskSelected('launchargon')

[UninstallDelete]
; Only installer-owned program payload is removed by default. Runtime data is handled below.
Type: filesandordirs; Name: "{app}\App"
Type: filesandordirs; Name: "{app}\Updater"
Type: filesandordirs; Name: "{app}\Bootstrap"
Type: files; Name: "{app}\payload-manifest.json"

[Code]
var
  RemoveArgonUserData: Boolean;

#include "..\dist\payload-verification.iss"

procedure VerifyInstalledPayload;
var
  I: Integer;
  RelativePath: String;
  InstalledPath: String;
  ExpectedHash: String;
  ActualHash: String;
begin
  for I := 0 to GetPayloadFileCount - 1 do
  begin
    RelativePath := GetPayloadFilePath(I);
    ExpectedHash := GetPayloadFileHash(I);
    StringChangeEx(RelativePath, '/', '\', True);
    InstalledPath := AddBackslash(ExpandConstant('{app}')) + RelativePath;

    if not FileExists(InstalledPath) then
      RaiseException('Integrity check failed: installed file is missing: ' + RelativePath);

    ActualHash := GetSHA256OfFile(InstalledPath);
    if CompareText(ActualHash, ExpectedHash) <> 0 then
      RaiseException('Integrity check failed: SHA-256 mismatch for: ' + RelativePath);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    Log('Verifying installed Argon payload files using SHA-256.');
    VerifyInstalledPayload;
    Log('Argon payload integrity check passed.');
  end;
end;

function InitializeUninstall: Boolean;
var
  Answer: Integer;
begin
  Result := True;
  RemoveArgonUserData := False;

  if UninstallSilent then
  begin
    RemoveArgonUserData :=
      CompareText(ExpandConstant('{param:REMOVEUSERDATA|0}'), '1') = 0;
    Exit;
  end;

  if DirExists(ExpandConstant('{localappdata}\Argon\UserData')) or
     DirExists(ExpandConstant('{localappdata}\Argon\Updates')) or
     DirExists(ExpandConstant('{localappdata}\Argon\Logs')) then
  begin
    Answer := MsgBox(
      'Keep your Argon settings, documents, search files, updates and logs?' +
      #13#10#13#10 +
      'Choose Yes to preserve your data. Choose No to remove all data under ' +
      '%LOCALAPPDATA%\Argon. Choose Cancel to stop uninstalling.',
      mbConfirmation, MB_YESNOCANCEL);

    if Answer = IDYES then
      RemoveArgonUserData := False
    else if Answer = IDNO then
      RemoveArgonUserData := True
    else
      Result := False;
  end;
end;

procedure RemoveDataSubdirectory(const DataRoot, RelativePath: String);
var
  FullPath: String;
begin
  FullPath := AddBackslash(DataRoot) + RelativePath;
  if DirExists(FullPath) then
  begin
    Log('Removing user-requested Argon data directory: ' + FullPath);
    if not DelTree(FullPath, True, True, True) then
      MsgBox(
        'Argon was uninstalled, but some data could not be removed:' +
        #13#10 + FullPath + #13#10#13#10 +
        'Close applications that may be using those files and remove them manually if desired.',
        mbError, MB_OK);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataRoot: String;
begin
  if (CurUninstallStep = usPostUninstall) and RemoveArgonUserData then
  begin
    DataRoot := ExpandConstant('{localappdata}\Argon');
    Log('User explicitly requested removal of Argon runtime data under: ' + DataRoot);

    { Do not delete the root directory itself: on a default install it also
      contains the running uninstaller until its final cleanup has completed. }
    RemoveDataSubdirectory(DataRoot, 'UserData');
    RemoveDataSubdirectory(DataRoot, 'Updates');
    RemoveDataSubdirectory(DataRoot, 'Logs');
    RemoveDataSubdirectory(DataRoot, 'App');
    RemoveDataSubdirectory(DataRoot, 'Updater');
    RemoveDataSubdirectory(DataRoot, 'Bootstrap');
  end;
end;
