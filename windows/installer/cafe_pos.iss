; Installer for the Windows cashier app, built by .github/workflows/windows-release.yml.
; Per-user install (no admin prompt), so the app can update itself silently.
;
; Customer data is never in the install folder: offline sales, the saved menu and the cafe-slot
; link live in %APPDATA%\com.example\menu_web_v1, which this installer never touches (and the
; uninstaller leaves in place). Do not change AppId, or Windows treats it as a different app.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{6B0F3B5E-2C7A-4E61-9C1B-8E5A2D4F7C31}
AppName=Cafe POS
AppVersion={#AppVersion}
AppPublisher=Cafe POS
DefaultDirName={localappdata}\Programs\CafePOS
DefaultGroupName=Cafe POS
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\build\installer
OutputBaseFilename=CafePOS-setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=force
RestartApplications=no
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\menu_web_v1.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Cafe POS"; Filename: "{app}\menu_web_v1.exe"
Name: "{userdesktop}\Cafe POS"; Filename: "{app}\menu_web_v1.exe"

[Run]
; Starts the app again after a silent update, and after a first install.
Filename: "{app}\menu_web_v1.exe"; Flags: nowait
