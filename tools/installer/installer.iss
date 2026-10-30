; Inno Setup Script for HammeRR Map Editor
#define MyAppName "HammeRR"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "HammeRR Team"
#define MyAppURL "https://github.com/HammeRR"
#define MyAppExeName "hammerr.exe"

[Setup]
AppId={{D37F2A38-8B91-4C5C-9A52-25D8F7F70F01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\..\dist
OutputBaseFilename=HammeRR-Setup-v{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\..\assets\icon.ico
ChangesAssociations=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "associatevmf"; Description: "Associate .vmf (Valve Map Format) files with HammeRR"; GroupDescription: "File associations:"; Flags: checkedonce

[Files]
Source: "..\..\target\release\editor.exe"; DestDir: "{app}"; DestName: "hammerr.exe"; Flags: ignoreversion
Source: "..\..\target\release\editor.exe"; DestDir: "{app}"; DestName: "editor.exe"; Flags: ignoreversion
Source: "..\..\target\release\hammerr-compile.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\target\release\hammerr-physics.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\target\release\hammerr-headless.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\target\release\hammerr-native-runtime.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "Software\Classes\.vmf"; ValueType: string; ValueName: ""; ValueData: "HammeRR.Vmf"; Flags: uninsdeletevalue; Tasks: associatevmf
Root: HKA; Subkey: "Software\Classes\HammeRR.Vmf"; ValueType: string; ValueName: ""; ValueData: "Valve Map Format (.vmf)"; Flags: uninsdeletekey; Tasks: associatevmf
Root: HKA; Subkey: "Software\Classes\HammeRR.Vmf\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatevmf
Root: HKA; Subkey: "Software\Classes\HammeRR.Vmf\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatevmf

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

