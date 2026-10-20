# Proves a Windows ZIP works the way its read-me says: checks the .sha256, expands the ZIP, copies the .vst3 bundle into the
# system VST3 folder, runs pluginval on THAT copy, removes it again and checks it is gone. Exits non-zero on any failure.
#
#   test_zip.ps1 -Product GainExample -Zip <file.zip> -Pluginval <pluginval.exe> [-Strictness 5] [-TimeoutMs 600000] [-LogDir <dir>]
param(
    [Parameter(Mandatory)] [string] $Product,
    [Parameter(Mandatory)] [string] $Zip,
    [Parameter(Mandatory)] [string] $Pluginval,
    [string] $Strictness = '5',
    [string] $TimeoutMs = '600000',
    [string] $LogDir = 'pluginval-logs-zip'
)
$ErrorActionPreference = 'Stop'
function Check($what, $ok) { if ($ok) { "OK    $what" } else { Write-Error "FAIL  $what"; exit 1 } }

$sha = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToLower()
$listed = (Get-Content "$Zip.sha256").Split(' ')[0]
Check "the .sha256 file matches the ZIP ($sha)" ($sha -eq $listed)

$x = Join-Path ([IO.Path]::GetTempPath()) "zip-test-$Product"
if (Test-Path $x) { Remove-Item $x -Recurse -Force }
Expand-Archive $Zip -DestinationPath $x
$items = Get-ChildItem $x | Select-Object -ExpandProperty Name
Check "ZIP holds $Product.vst3 and Install - read me.txt" (($items -contains "$Product.vst3") -and ($items -contains 'Install - read me.txt'))
Check "no .exe anywhere in the ZIP" (-not (Get-ChildItem $x -Recurse -Filter *.exe))
Check "read me says where to copy the plug-in" ((Get-Content "$x\Install - read me.txt") -match 'Common Files\\VST3')

$dest = "C:\Program Files\Common Files\VST3\$Product.vst3"
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Copy-Item "$x\$Product.vst3" $dest -Recurse
Check "bundle copied to $dest (the read-me's step 2)" (Test-Path "$dest\Contents\x86_64-win\$Product.vst3")

New-Item -ItemType Directory -Force $LogDir | Out-Null
& $Pluginval --strictness-level $Strictness --validate-in-process --timeout-ms $TimeoutMs --output-dir $LogDir --validate $dest 2>&1 | Tee-Object "$LogDir\pluginval-zip-copy.log" | Select-Object -Last 3
Check "pluginval strictness $Strictness on the copy in the system VST3 folder" ($LASTEXITCODE -eq 0)

Remove-Item $dest -Recurse -Force
Remove-Item $x -Recurse -Force
Check "removed again from the system VST3 folder" (-not (Test-Path $dest))
