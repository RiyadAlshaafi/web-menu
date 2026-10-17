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

[UninstallDelete]
Type: files; Name: "{app}\features.json"

[Code]
// Feature pages: Online/Offline -> feature checkboxes. The answers are written to
// {app}\features.json, which lib/features/app_feature.dart reads. Keys must match AppFeature.key.
// Silent updates show no pages and leave features.json as it is.
const
  FeatureCount = 9;

var
  ModePage: TInputOptionWizardPage;
  FeaturePage: TWizardPage;
  FeatureList: TNewCheckListBox;
  FeatureKeys: array of String;
  RowKeys: array of String;

function FeaturesFile: String;
begin
  Result := AddBackslash(WizardDirValue) + 'features.json';
end;

function SavedFeatures: String;
var
  Text: AnsiString;
begin
  Result := '';
  if LoadStringFromFile(FeaturesFile, Text) then Result := String(Text);
end;

function FeatureLabel(Key: String): String;
begin
  case Key of
    'tables': Result := 'Tables & floor (table QR codes, floor view)';
    'qr_ordering': Result := 'QR guest ordering (live alerts, staff calls, bill requests)';
    'location_check': Result := 'Guest location check';
    'discounts': Result := 'Discounts';
    'dish_toggle': Result := 'Cashiers can turn dishes on/off';
    'expenses': Result := 'Expenses & wages';
    'reports': Result := 'Reports (dashboard, sales log, CSV/PDF export)';
    'branding': Result := 'Custom colours';
    'payment_types': Result := 'Extra payment types (card, etc.)';
  else
    Result := Key;
  end;
end;

// Must match AppFeature.worksOffline.
function WorksOffline(Key: String): Boolean;
begin
  Result := (Key = 'expenses') or (Key = 'payment_types');
end;

// Must match AppFeature.requires.
function RequiredKey(Key: String): String;
begin
  case Key of
    'qr_ordering': Result := 'tables';
    'location_check': Result := 'qr_ordering';
  else
    Result := '';
  end;
end;

function FeatureLevel(Key: String): Byte;
begin
  case Key of
    'qr_ordering': Result := 1;
    'location_check': Result := 2;
  else
    Result := 0;
  end;
end;

function OfflineChosen: Boolean;
begin
  Result := ModePage.SelectedValueIndex = 1;
end;

// Ticked when there is no saved choice yet, otherwise as saved.
function StartsTicked(Key, Saved: String): Boolean;
begin
  Result := (Saved = '') or (Pos('"' + Key + '"', Saved) > 0);
end;

procedure FillFeatureList;
var
  I, Row: Integer;
  Key, Saved: String;
  Offline, HasChildren: Boolean;
begin
  Saved := SavedFeatures;
  Offline := OfflineChosen;
  FeatureList.Items.Clear;
  SetArrayLength(RowKeys, 0);
  for I := 0 to FeatureCount - 1 do
  begin
    Key := FeatureKeys[I];
    if Offline and not WorksOffline(Key) then Continue;
    HasChildren := (Key = 'tables') or (Key = 'qr_ordering');
    Row := FeatureList.AddCheckBox(FeatureLabel(Key), '', FeatureLevel(Key),
      StartsTicked(Key, Saved), True, HasChildren, False, nil);
    SetArrayLength(RowKeys, Row + 1);
    RowKeys[Row] := Key;
  end;
end;

function RowTicked(Key: String): Boolean;
var
  Row: Integer;
begin
  Result := False;
  for Row := 0 to GetArrayLength(RowKeys) - 1 do
    if RowKeys[Row] = Key then
    begin
      Result := FeatureList.Checked[Row];
      Exit;
    end;
end;

// A feature counts only when everything it needs is ticked too.
function KeyOn(Key: String): Boolean;
begin
  Result := RowTicked(Key) and ((RequiredKey(Key) = '') or KeyOn(RequiredKey(Key)));
end;

function FeaturesJson: String;
var
  I: Integer;
  Mode, List: String;
begin
  if OfflineChosen then Mode := 'offline' else Mode := 'online';
  List := '';
  for I := 0 to FeatureCount - 1 do
    if KeyOn(FeatureKeys[I]) then
    begin
      if List <> '' then List := List + ', ';
      List := List + '"' + FeatureKeys[I] + '"';
    end;
  Result := '{"mode": "' + Mode + '", "features": [' + List + ']}';
end;

procedure InitializeWizard;
begin
  SetArrayLength(FeatureKeys, FeatureCount);
  FeatureKeys[0] := 'tables';
  FeatureKeys[1] := 'qr_ordering';
  FeatureKeys[2] := 'location_check';
  FeatureKeys[3] := 'discounts';
  FeatureKeys[4] := 'dish_toggle';
  FeatureKeys[5] := 'expenses';
  FeatureKeys[6] := 'reports';
  FeatureKeys[7] := 'branding';
  FeatureKeys[8] := 'payment_types';

  ModePage := CreateInputOptionPage(wpWelcome, 'Online or offline',
    'How will this till be used?', 'Offline shows only the features that work without internet.',
    True, False);
  ModePage.Add('Online - every feature, guests can order by QR code');
  ModePage.Add('Offline - till only (needs internet once to link the cafe and set up the menu)');
  if Pos('"offline"', SavedFeatures) > 0 then ModePage.SelectedValueIndex := 1
  else ModePage.SelectedValueIndex := 0;

  FeaturePage := CreateCustomPage(ModePage.ID, 'Features',
    'Tick the features this cafe gets. Login, menu, quick takeout, payment, receipts, shifts and settings are always included.');
  FeatureList := TNewCheckListBox.Create(FeaturePage);
  FeatureList.Parent := FeaturePage.Surface;
  FeatureList.Width := FeaturePage.SurfaceWidth;
  FeatureList.Height := FeaturePage.SurfaceHeight;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = FeaturePage.ID then FillFeatureList;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and not WizardSilent then
    if not SaveStringToFile(FeaturesFile, FeaturesJson, False) then
      MsgBox('Could not save the feature choices. Every feature will be on.', mbError, MB_OK);
end;
