# Packs a Windows VST3 as a plain ZIP (the free, unsigned route: no installer .exe, so no installer for SmartScreen to judge):
#   <Product>-<Version>-Windows-x64.zip
#     <Product>.vst3\        the VST3 bundle folder
#     Install - read me.txt  three plain steps plus the Unblock note
#     (optional) License.txt, Third-Party Notices.txt
# plus <zip>.sha256 next to it. Prints the name and the SHA-256, sets step outputs and appends to the GitHub step summary.
#
#   make_zip.ps1 -Product GainExample -Version 0.1.0 -Vst3 <path to Product.vst3 folder> -OutDir <dir> [-Licence <file>] [-Notices <file>]
param(
    [Parameter(Mandatory)] [string] $Product,
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $Vst3,
    [Parameter(Mandatory)] [string] $OutDir,
    [string] $Licence = '',
    [string] $Notices = ''
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path "$Vst3\Contents\x86_64-win\$Product.vst3")) { throw "not a built Windows VST3 bundle: $Vst3" }
if (Get-ChildItem $Vst3 -Recurse -Include *.exe, *.lib, *.exp, *.pdb) { throw "the bundle holds build leftovers or an .exe; nothing but the plug-in goes in the ZIP" }

$name  = "$Product-$Version-Windows-x64"
$stage = Join-Path $OutDir "stage\$name"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item $Vst3 (Join-Path $stage "$Product.vst3") -Recurse
if ($Licence) { Copy-Item $Licence (Join-Path $stage 'License.txt') }
if ($Notices) { Copy-Item $Notices (Join-Path $stage 'Third-Party Notices.txt') }

$readme = @"
$Product FOR WINDOWS - INSTALL

1. Unzip.
2. Copy the $Product.vst3 folder into C:\Program Files\Common Files\VST3\
3. Rescan plug-ins in your DAW.

If Windows marks the files as downloaded, right-click the ZIP > Properties > tick Unblock before unzipping.

Requires 64-bit Windows 10 or 11 and a DAW that loads VST3 plug-ins.
To remove $Product later, delete C:\Program Files\Common Files\VST3\$Product.vst3
"@
[IO.File]::WriteAllText((Join-Path $stage 'Install - read me.txt'), ($readme -replace "`r?`n", "`r`n"), [Text.Encoding]::ASCII)

$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$stage\*" -DestinationPath $zip -CompressionLevel Optimal
Remove-Item (Join-Path $OutDir 'stage') -Recurse -Force

$sha = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText("$zip.sha256", "$sha  $name.zip`n", [Text.Encoding]::ASCII)
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 2)
"$name.zip  ($mb MB)"
"$sha  $name.zip"
if ($env:GITHUB_OUTPUT)       { "name=$name" >> $env:GITHUB_OUTPUT; "sha256=$sha" >> $env:GITHUB_OUTPUT; "zip=$zip" >> $env:GITHUB_OUTPUT }
if ($env:GITHUB_STEP_SUMMARY) { "## $Product Windows ZIP`n- **$name.zip** ($mb MB, unsigned, VST3 only)`n- SHA-256: ``$sha``" >> $env:GITHUB_STEP_SUMMARY }
