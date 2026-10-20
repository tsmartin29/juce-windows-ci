# Downloads the official ONNX Runtime CPU package for Windows x64, checks its SHA-256 against the value you pin, expands it,
# and prints the folder (it holds include/ and lib/ and onnxruntime.dll). The workflow passes that folder to CMake as -DORT_ROOT.
# Source: https://github.com/microsoft/onnxruntime/releases  (MIT licence; ship its licence file if you ship the DLL)
#
#   fetch_onnxruntime.ps1 -Version 1.30.0 -Sha256 <hash of onnxruntime-win-x64-<version>.zip> -OutDir ort
# Take the hash from the release page (GitHub shows a digest next to each asset) the first time, then keep it pinned.
param(
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $Sha256,
    [string] $OutDir = 'ort'
)
$ErrorActionPreference = 'Stop'
$zip = "onnxruntime-win-x64-$Version.zip"
Invoke-WebRequest "https://github.com/microsoft/onnxruntime/releases/download/v$Version/$zip" -OutFile $zip
$h = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($h -ne $Sha256.ToLower()) { Write-Error "$zip hash is $h, expected $Sha256"; exit 1 }
Expand-Archive $zip -DestinationPath $OutDir -Force
Remove-Item $zip
$root = (Resolve-Path (Join-Path $OutDir "onnxruntime-win-x64-$Version")).Path
$root
if ($env:GITHUB_ENV) { "ORT_ROOT=$($root -replace '\\','/')" >> $env:GITHUB_ENV }
