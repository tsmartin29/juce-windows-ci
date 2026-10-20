; Inno Setup 6 script for the example plug-in. Inno Setup 6 is preinstalled on the windows-latest runner (check the runner
; image list); the workflow calls ISCC with /DVersion /DBuildDir /DOutDir. Edit the names, the AppId and the publisher.
;
; What it does: installs the VST3 bundle folder to C:\Program Files\Common Files\VST3\ (needs admin), registers an uninstaller
; in "Apps & features", and DELETES the previous copy of the bundle first, so an update never leaves old files behind.
#ifndef Version
  #define Version "0.1.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\build"
#endif
#ifndef OutDir
  #define OutDir "..\installer-out"
#endif
#define Product "GainExample"

[Setup]
; AppId must be unique per product and NEVER change between versions (it is how updates find the old install). Make your own GUID.
AppId={{6F1D3C52-8A47-4E0B-9B2D-5C7E1A90F3B4}
AppName=Gain Example
AppVersion={#Version}
AppPublisher=Example Audio
DefaultDirName={commoncf64}\VST3\{#Product}.vst3
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
OutputDir={#OutDir}
OutputBaseFilename={#Product}-{#Version}-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=Gain Example {#Version}

[InstallDelete]
; remove the previous version's bundle (all files) before copying the new one
Type: filesandordirs; Name: "{commoncf64}\VST3\{#Product}.vst3"

[Files]
Source: "{#BuildDir}\{#Product}_artefacts\Release\VST3\{#Product}.vst3\*"; DestDir: "{commoncf64}\VST3\{#Product}.vst3"; Flags: recursesubdirs createallsubdirs ignoreversion

[UninstallDelete]
Type: filesandordirs; Name: "{commoncf64}\VST3\{#Product}.vst3"
