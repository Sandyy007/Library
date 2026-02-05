; Library Management System - Inno Setup Script
; This installer bundles the Flutter app, Node.js backend, and MySQL database
; Complete Bundle: App + Backend + Database
; Updated: February 5, 2026

#define MyAppName "Library Management System"
#define MyAppVersion "1.3.0"
#define MyAppPublisher "Library Management"
#define MyAppURL "https://library-management.local"
#define MyAppExeName "library_management_app.exe"
#define MyAppCopyright "Copyright (C) 2026 Library Management"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppCopyright={#MyAppCopyright}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=
InfoBeforeFile=
InfoAfterFile=
OutputDir=installer_output
OutputBaseFilename=LibraryManagementSystem_Setup_v{#MyAppVersion}
SetupIconFile=flutter_app\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
VersionInfoVersion=1.3.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode
Name: "reinitdb"; Description: "Reinitialize database (WARNING: Deletes existing data!)"; GroupDescription: "Database Options:"; Flags: unchecked

[Files]
; Flutter App files (Windows build output)
Source: "flutter_app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Backend core files (exclude test files)
Source: "backend\server.js"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "backend\package.json"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "backend\package-lock.json"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "backend\hash.js"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "backend\seed.js"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "backend\.env.example"; DestDir: "{app}\backend"; Flags: ignoreversion

; Backend node_modules (required for running)
Source: "backend\node_modules\*"; DestDir: "{app}\backend\node_modules"; Flags: ignoreversion recursesubdirs createallsubdirs

; Backend uploads directory (preserve user data on upgrade)
Source: "backend\uploads\*"; DestDir: "{app}\backend\uploads"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist onlyifdoesntexist

; Database schema files
Source: "database\schema_v2.sql"; DestDir: "{app}\database"; Flags: ignoreversion
Source: "database\schema.sql"; DestDir: "{app}\database"; Flags: ignoreversion

; Documentation
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "INSTALLATION_GUIDE.md"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
Name: "{app}\backend\uploads"; Permissions: users-modify
Name: "{app}\logs"; Permissions: users-modify

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; Launch application after install
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop any running backend processes on port 3000
Filename: "{cmd}"; Parameters: "/c FOR /F ""tokens=5"" %a IN ('netstat -ano ^| findstr :3000') DO taskkill /F /PID %a 2>nul"; Flags: runhidden

[UninstallDelete]
; Clean up generated files (but not user uploads)
Type: files; Name: "{app}\backend\.env"
Type: dirifempty; Name: "{app}\logs"

[Code]
var
  MySQLPage: TInputQueryWizardPage;
  NodeJSInstalled: Boolean;
  MySQLInstalled: Boolean;

function GenerateRandomString(Len: Integer): String;
var
  I: Integer;
  CharSet: String;
  TimeStr: String;
begin
  // Use timestamp to generate semi-random characters
  TimeStr := GetDateTimeString('yyyymmddhhnnsszzz', #0, #0);
  CharSet := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  Result := '';
  for I := 1 to Len do
  begin
    Result := Result + CharSet[((Ord(TimeStr[(I mod Length(TimeStr)) + 1]) * I) mod 62) + 1];
  end;
end;

function IsNodeJSInstalled: Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('cmd', '/c node --version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function IsMySQLInstalled: Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('cmd', '/c mysql --version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

procedure InitializeWizard;
begin
  NodeJSInstalled := IsNodeJSInstalled;
  MySQLInstalled := IsMySQLInstalled;
  
  // Create MySQL configuration page
  MySQLPage := CreateInputQueryPage(wpSelectTasks,
    'Database Configuration',
    'Configure MySQL Database Connection',
    'Please enter your MySQL database credentials. The installer will configure the backend to use these settings.');
  MySQLPage.Add('MySQL Host:', False);
  MySQLPage.Add('MySQL User:', False);
  MySQLPage.Add('MySQL Password:', True);
  MySQLPage.Add('Database Name:', False);
  
  // Set default values
  MySQLPage.Values[0] := 'localhost';
  MySQLPage.Values[1] := 'root';
  MySQLPage.Values[2] := 'admin';
  MySQLPage.Values[3] := 'library_management';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Msg: String;
begin
  Result := True;
  
  if CurPageID = wpWelcome then
  begin
    Msg := '';
    
    if not NodeJSInstalled then
    begin
      Msg := 'Node.js is not detected on this system.' + #13#10 + 
             'The backend server requires Node.js 18 or later to run.' + #13#10 + 
             'Download from: https://nodejs.org' + #13#10#13#10;
    end;
    
    if not MySQLInstalled then
    begin
      Msg := Msg + 'MySQL is not detected on this system.' + #13#10 +
             'A MySQL database is required for full functionality.' + #13#10 +
             'Download from: https://dev.mysql.com/downloads/mysql/' + #13#10#13#10;
    end;
    
    if Msg <> '' then
    begin
      Msg := Msg + 'Would you like to continue anyway?' + #13#10 +
             '(You can install these prerequisites later)';
      if MsgBox(Msg, mbConfirmation, MB_YESNO) = IDNO then
        Result := False;
    end;
  end;
end;

procedure CreateEnvFile;
var
  EnvContent: String;
  EnvFile: String;
  JWTSecret: String;
begin
  EnvFile := ExpandConstant('{app}\backend\.env');
  
  // Delete existing .env file to ensure fresh credentials are used
  if FileExists(EnvFile) then
    DeleteFile(EnvFile);
  
  // Generate a secure random JWT secret
  JWTSecret := GenerateRandomString(64);
  
  EnvContent := '# Library Management System Backend Configuration' + Chr(13) + Chr(10) + '# Generated during installation on ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + Chr(13) + Chr(10) + Chr(13) + Chr(10) + '# Database Configuration' + Chr(13) + Chr(10) + 'DB_HOST=' + MySQLPage.Values[0] + Chr(13) + Chr(10) + 'DB_USER=' + MySQLPage.Values[1] + Chr(13) + Chr(10) + 'DB_PASSWORD=' + MySQLPage.Values[2] + Chr(13) + Chr(10) + 'DB_NAME=' + MySQLPage.Values[3] + Chr(13) + Chr(10) + Chr(13) + Chr(10) + '# Server Configuration' + Chr(13) + Chr(10) + 'PORT=3000' + Chr(13) + Chr(10) + 'NODE_ENV=production' + Chr(13) + Chr(10) + Chr(13) + Chr(10) + '# Security Configuration' + Chr(13) + Chr(10) + 'JWT_SECRET=' + JWTSecret + Chr(13) + Chr(10) + 'JWT_EXPIRES_IN=8h' + Chr(13) + Chr(10) + Chr(13) + Chr(10) + '# Rate Limiting (disabled for desktop use)' + Chr(13) + Chr(10) + 'RATE_LIMIT_ENABLED=false' + Chr(13) + Chr(10) + 'RATE_LIMIT_WINDOW_MS=900000' + Chr(13) + Chr(10) + 'RATE_LIMIT_MAX=500' + Chr(13) + Chr(10) + Chr(13) + Chr(10) + '# Request body size' + Chr(13) + Chr(10) + 'JSON_BODY_LIMIT=10mb' + Chr(13) + Chr(10);
  
  SaveStringToFile(EnvFile, EnvContent, False);
end;

procedure CreateDatabaseIfNeeded;
var
  ResultCode: Integer;
  DropDBCmd: String;
  CreateDBCmd: String;
  ImportCmd: String;
  SchemaFile: String;
begin
  if MySQLInstalled then
  begin
    SchemaFile := ExpandConstant('{app}\database\schema_v2.sql');
    
    // If reinitialize database is checked, drop the existing database first
    if IsTaskSelected('reinitdb') then
    begin
      DropDBCmd := '/c mysql -h ' + MySQLPage.Values[0] + 
                   ' -u ' + MySQLPage.Values[1] + 
                   ' -p' + MySQLPage.Values[2] + 
                   ' -e "DROP DATABASE IF EXISTS `' + MySQLPage.Values[3] + '`;"';
      Exec('cmd', DropDBCmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
    
    // Create database command
    CreateDBCmd := '/c mysql -h ' + MySQLPage.Values[0] + 
                   ' -u ' + MySQLPage.Values[1] + 
                   ' -p' + MySQLPage.Values[2] + 
                   ' -e "CREATE DATABASE IF NOT EXISTS `' + MySQLPage.Values[3] + '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"';
    
    Exec('cmd', CreateDBCmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    
    // Import schema if file exists and (new install or reinit selected)
    if FileExists(SchemaFile) then
    begin
      ImportCmd := '/c mysql -h ' + MySQLPage.Values[0] + 
                   ' -u ' + MySQLPage.Values[1] + 
                   ' -p' + MySQLPage.Values[2] + 
                   ' ' + MySQLPage.Values[3] + 
                   ' < "' + SchemaFile + '"';
      Exec('cmd', ImportCmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    CreateEnvFile;
    CreateDatabaseIfNeeded;
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;
