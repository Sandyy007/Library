; Inno Setup script template for Library Management System
; Build Output: a single Setup.exe
;
; Assumes you create a staging folder with this structure:
;   dist\
;     app\                (Flutter Windows Release output copied here)
;     backend\             (backend source + node_modules copied here)
;     database\schema_v2.sql
;     runtime\node\node.exe (optional portable Node)
;     deploy\windows\start_all.bat
;     deploy\windows\start_backend.bat
;
; NOTE: MySQL Server installation is NOT bundled here by default.
; You can either require MySQL to be pre-installed, or add a MySQL installer
; to the [Files]/[Run] sections (advanced).

[Setup]
AppName=Library Management System
AppVersion=1.0.0
DefaultDirName={pf}\LibraryManagementSystem
DefaultGroupName=Library Management System
OutputBaseFilename=LibraryManagementSetup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64

[Files]
; Frontend
Source: "dist\app\*"; DestDir: "{app}\app"; Flags: recursesubdirs ignoreversion

; Backend
Source: "dist\backend\*"; DestDir: "{app}\backend"; Flags: recursesubdirs ignoreversion

; Database schema
Source: "dist\database\schema_v2.sql"; DestDir: "{app}\database"; Flags: ignoreversion

; Optional portable Node runtime
Source: "dist\runtime\node\*"; DestDir: "{app}\runtime\node"; Flags: recursesubdirs ignoreversion skipifsourcedoesntexist

; Start scripts
Source: "dist\deploy\windows\start_all.bat"; DestDir: "{app}\deploy\windows"; Flags: ignoreversion
Source: "dist\deploy\windows\start_backend.bat"; DestDir: "{app}\deploy\windows"; Flags: ignoreversion

[Icons]
Name: "{group}\Library Management System"; Filename: "{app}\deploy\windows\start_all.bat"; WorkingDir: "{app}";
Name: "{group}\Uninstall"; Filename: "{uninstallexe}"

[Run]
; Start the app after install
Filename: "{app}\deploy\windows\start_all.bat"; Description: "Start Library Management System"; Flags: nowait postinstall skipifsilent

; OPTIONAL (advanced): import schema automatically.
; Requires mysql client (mysql.exe) available on PATH OR bundled with installer.
; You would also need to handle credentials (root password) safely.
; Example (interactive password prompt will appear):
; Filename: "cmd.exe"; Parameters: "/c mysql -u root -p < \"{app}\database\schema_v2.sql\""; Flags: postinstall
