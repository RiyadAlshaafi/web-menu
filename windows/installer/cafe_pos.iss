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
; Where setup checks the password (the dev screen password, via public.check_dev_access).
; The publishable key is public; the release workflow passes the repo's values.
#ifndef SupabaseUrl
  #define SupabaseUrl "https://kzafgozkgvcflcizuemr.supabase.co"
#endif
#ifndef SupabaseKey
  #define SupabaseKey "sb_publishable_CWfwwYkp5D8nc_U0x3mjjg_YiYKg0Tj"
#endif
; Signs the offline admin reset ticket. Must match adminResetKey in lib/data/admin_reset.dart;
; the release workflow passes ADMIN_RESET_KEY from the repo secrets when it is set.
#ifndef ResetKey
  #define ResetKey "tawla-offline-admin-reset-v1"
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
Type: files; Name: "{app}\admin_reset.json"

[Code]
// Pages: password (checked online) -> Online/Offline -> cafe slot (online only) -> admin reset
// (offline only) -> feature checkboxes. The answers are written to {app}\features.json, which
// lib/features/app_feature.dart reads. Keys must match AppFeature.key. Silent updates show no pages
// and leave features.json as it is.
// The admin reset writes {app}\admin_reset.json, a one-time signed ticket that lib/data/admin_reset.dart
// checks when the app starts, so a forgotten offline admin password can be replaced without internet.
const
  FeatureCount = 9;
  SlotCount = 8;

var
  PasswordPage: TInputQueryWizardPage;
  ModePage: TInputOptionWizardPage;
  SlotPage: TInputOptionWizardPage;
  SlotNamesLoaded: Boolean;
  ResetPage: TInputOptionWizardPage;
  FeaturePage: TWizardPage;
  FeatureList: TNewCheckListBox;
  FeatureKeys: array of String;
  RowKeys: array of String;

function JsonText(Value: String): String;
begin
  StringChangeEx(Value, '\', '\\', True);
  StringChangeEx(Value, '"', '\"', True);
  Result := '"' + Value + '"';
end;

// The scheme and host of Url only, like the app's AppDatabase.supabaseUrl, so a configured
// address with a path (".../rest/v1") or a trailing slash still reaches the API.
function ServerOrigin(Url: String): String;
var
  Start, Slash: Integer;
  Rest: String;
begin
  Url := Trim(Url);
  Start := Pos('://', Url);
  if Start = 0 then
  begin
    Result := Url;
    Exit;
  end;
  Rest := Copy(Url, Start + 3, Length(Url));
  Slash := Pos('/', Rest);
  if Slash > 0 then Rest := Copy(Rest, 1, Slash - 1);
  Result := Copy(Url, 1, Start + 2) + Rest;
end;

// True only when the server says the password is the dev screen password.
// 5 wrong tries lock the check for 15 minutes (it then answers false).
function PasswordAccepted(Password: String; var Problem: String): Boolean;
var
  Http: Variant;
  Status: Integer;
  Answer: String;
begin
  Result := False;
  try
    Http := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    Http.Open('POST', ServerOrigin('{#SupabaseUrl}') + '/rest/v1/rpc/check_dev_access', False);
    Http.SetTimeouts(10000, 10000, 15000, 15000);
    Http.SetRequestHeader('apikey', '{#SupabaseKey}');
    Http.SetRequestHeader('Content-Type', 'application/json');
    Http.Send('{"p_password": ' + JsonText(Password) + '}');
  except
    Problem := 'Could not reach the server. Connect this PC to the internet for the password check, then press Next again.';
    Exit;
  end;
  Status := Http.Status;
  Answer := Http.ResponseText;
  if Status <> 200 then
  begin
    Problem := 'The server could not check the password (error ' + IntToStr(Status) + '). Try again.';
    Exit;
  end;
  Result := Trim(Answer) = 'true';
  if not Result then
    Problem := 'Wrong password. After 5 wrong tries the check is locked for 15 minutes.';
end;

// Value of the text field Name in a compact JSON answer ('' when missing).
function JsonTextField(Json, Name: String): String;
var
  At: Integer;
begin
  Result := '';
  At := Pos('"' + Name + '":"', Json);
  if At = 0 then Exit;
  Json := Copy(Json, At + Length(Name) + 4, Length(Json));
  At := Pos('"', Json);
  if At > 0 then Result := Copy(Json, 1, At - 1);
end;

// "Slot 3 - Cafe name (in use)" from public.restaurant_for_slot; just "Slot 3" when the server can't say.
function SlotLabel(Slot: Integer): String;
var
  Http: Variant;
  Answer, Name: String;
begin
  Result := 'Slot ' + IntToStr(Slot);
  try
    Http := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    Http.Open('POST', ServerOrigin('{#SupabaseUrl}') + '/rest/v1/rpc/restaurant_for_slot', False);
    Http.SetTimeouts(5000, 5000, 8000, 8000);
    Http.SetRequestHeader('apikey', '{#SupabaseKey}');
    Http.SetRequestHeader('Content-Type', 'application/json');
    Http.Send('{"p_slot": ' + IntToStr(Slot) + '}');
    if Http.Status <> 200 then Exit;
    Answer := Http.ResponseText;
  except
    Exit;
  end;
  Name := Trim(JsonTextField(Answer, 'name'));
  if Pos('"active":true', Answer) > 0 then
  begin
    if Name = '' then Name := 'unnamed cafe';
    Result := Result + ' - ' + Name + ' (in use)';
  end
  else
    Result := Result + ' - empty';
end;

procedure LoadSlotNames;
var
  I: Integer;
begin
  if SlotNamesLoaded then Exit;
  for I := 0 to SlotCount - 1 do
    SlotPage.CheckListBox.ItemCaption[I] := SlotLabel(I + 1);
  SlotNamesLoaded := True;
end;

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
    'tables': Result := 'Tables & floor (open a table, add dishes, settle the bill)';
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
  Result := (Key <> 'qr_ordering') and (Key <> 'location_check');
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

// The slot saved by an earlier setup ("slot": 3), or 0.
function SavedSlot: Integer;
var
  Saved: String;
  At: Integer;
begin
  Result := 0;
  Saved := SavedFeatures;
  At := Pos('"slot": ', Saved);
  if At > 0 then Result := StrToIntDef(Copy(Saved, At + 8, 1), 0);
  if (Result < 1) or (Result > SlotCount) then Result := 0;
end;

function ResetFile: String;
begin
  Result := AddBackslash(WizardDirValue) + 'admin_reset.json';
end;

// Must match adminResetSignature in lib/data/admin_reset.dart.
function AdminResetSignature(Nonce, Issued: String): String;
begin
  Result := Lowercase(GetSHA256OfString('{#ResetKey}' + '|' + Nonce + '|' + Issued));
end;

// Random id of one ticket; the app saves it once used, so a copied ticket works only once.
function NewNonce: String;
var
  I: Integer;
  Seed: String;
begin
  Seed := GetDateTimeString('yyyymmddhhnnsszzz', '-', ':');
  for I := 1 to 8 do
    Seed := Seed + '-' + IntToStr(Random(2147483647));
  Result := Lowercase(GetSHA256OfString(Seed));
end;

// The ticket the app checks: valid for 24 hours, in this PC's local time like the app's clock.
function ResetTicketJson: String;
var
  Nonce, Issued: String;
begin
  Nonce := NewNonce;
  Issued := GetDateTimeString('yyyy/mm/dd hh:nn:ss', '-', ':');
  Result := '{"nonce": "' + Nonce + '", "issued": "' + Issued + '", "sig": "' +
    AdminResetSignature(Nonce, Issued) + '"}';
end;

function ResetChosen: Boolean;
begin
  Result := OfflineChosen and ResetPage.Values[0];
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
  Result := '{"mode": "' + Mode + '", "features": [' + List + ']';
  if not OfflineChosen and (SlotPage.SelectedValueIndex >= 0) then
    Result := Result + ', "slot": ' + IntToStr(SlotPage.SelectedValueIndex + 1);
  Result := Result + '}';
end;

procedure InitializeWizard;
var
  I: Integer;
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

  PasswordPage := CreateInputQueryPage(wpWelcome, 'Password',
    'Only the seller can install Cafe POS.',
    'Enter the setup password. This PC needs internet for this check only.');
  PasswordPage.Add('Password:', True);

  ModePage := CreateInputOptionPage(PasswordPage.ID, 'Online or offline',
    'How will this till be used?', 'Offline shows only the features that work without internet.',
    True, False);
  ModePage.Add('Online - every feature, guests can order by QR code');
  ModePage.Add('Offline - works with no internet at all; all data stays on this PC');
  if Pos('"offline"', SavedFeatures) > 0 then ModePage.SelectedValueIndex := 1
  else ModePage.SelectedValueIndex := 0;

  SlotPage := CreateInputOptionPage(ModePage.ID, 'Cafe slot',
    'Which cafe is this till for?',
    'Pick the cafe slot this till belongs to. Its sales and menu come from that cafe.',
    True, False);
  for I := 1 to SlotCount do
    SlotPage.Add('Slot ' + IntToStr(I));
  // No default: a wrong slot would show another cafe's data.
  if SavedSlot > 0 then SlotPage.SelectedValueIndex := SavedSlot - 1;

  ResetPage := CreateInputOptionPage(SlotPage.ID, 'Admin password',
    'Forgot the offline admin password?',
    'Tick this to let the cafe set a new admin password when Cafe POS opens. No internet is needed for it. ' +
    'Sales, menu, cashiers and settings are kept. The reset can be used once, within 24 hours.',
    False, False);
  ResetPage.Add('Reset the offline admin password');

  FeaturePage := CreateCustomPage(ResetPage.ID, 'Features',
    'Tick the features this cafe gets. Login, menu, quick takeout, payment, receipts, shifts and settings are always included.');
  FeatureList := TNewCheckListBox.Create(FeaturePage);
  FeatureList.Parent := FeaturePage.Surface;
  FeatureList.Width := FeaturePage.SurfaceWidth;
  FeatureList.Height := FeaturePage.SurfaceHeight;
end;

// The slot page is for online tills; the admin reset is for offline tills (online ones reset by email).
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := ((PageID = SlotPage.ID) and OfflineChosen) or ((PageID = ResetPage.ID) and not OfflineChosen);
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = SlotPage.ID then LoadSlotNames;
  if CurPageID = FeaturePage.ID then FillFeatureList;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Problem: String;
begin
  Result := True;
  if (CurPageID = SlotPage.ID) and (SlotPage.SelectedValueIndex < 0) then
  begin
    MsgBox('Pick the cafe slot for this till.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  if CurPageID <> PasswordPage.ID then Exit;
  if Trim(PasswordPage.Values[0]) = '' then
  begin
    MsgBox('Enter the setup password.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  if not PasswordAccepted(PasswordPage.Values[0], Problem) then
  begin
    MsgBox(Problem, mbError, MB_OK);
    Result := False;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep <> ssPostInstall) or WizardSilent then Exit;
  if not SaveStringToFile(FeaturesFile, FeaturesJson, False) then
    MsgBox('Could not save the feature choices. Every feature will be on.', mbError, MB_OK);
  // A ticket left from an earlier run must not outlive a setup that did not ask for one.
  DeleteFile(ResetFile);
  if ResetChosen then
    if SaveStringToFile(ResetFile, ResetTicketJson, False) then
      MsgBox('Cafe POS will now open. Go to Admin sign-in and set the new admin password (within 24 hours).',
        mbInformation, MB_OK)
    else
      MsgBox('Could not save the admin password reset. Run the setup again.', mbError, MB_OK);
end;
