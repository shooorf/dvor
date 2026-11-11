param(
    [ValidateSet("1k", "2k", "4k")]
    [string]$Quality = "4k"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

$GodotTag = "4.7.2-stable"
$TemplateVerDirName = "4.7.2.stable"
$GodotConsole = Join-Path $RootDir ".engine\Godot_v$GodotTag`_win64_console.exe"
$ManifestPath = Join-Path $RootDir "assets\downloaded\manifest.json"
$ExpectedPackVersion = 4

$NeedSetup = (-not (Test-Path $GodotConsole)) -or (-not (Test-Path $ManifestPath))
if (-not $NeedSetup) {
    try {
        $ManifestObj = Get-Content $ManifestPath -Raw | ConvertFrom-Json
        if ($ManifestObj.pack_version -ne $ExpectedPackVersion) {
            $NeedSetup = $true
        }
    } catch {
        $NeedSetup = $true
    }
}

if ($NeedSetup) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RootDir "setup.ps1") -Quality $Quality
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$TemplatesDir = Join-Path $env:APPDATA "Godot\export_templates\$TemplateVerDirName"
$ReleaseTemplate = Join-Path $TemplatesDir "windows_release_x86_64.exe"

if (-not (Test-Path $ReleaseTemplate)) {
    Write-Host "=== Downloading Godot $GodotTag Windows Export Templates ===" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $TemplatesDir | Out-Null
    $TpzPath = Join-Path $RootDir ".engine\export_templates.tpz"
    $TpzUrl = "https://github.com/godotengine/godot/releases/download/$GodotTag/Godot_v$GodotTag`_export_templates.tpz"
    & curl.exe -L --fail -o $TpzPath $TpzUrl

    Write-Host "Extracting Windows x86_64 templates into $TemplatesDir ..."
    $PyExtract = @"
import zipfile, shutil
from pathlib import Path
tpz = Path(r'$TpzPath')
out_dir = Path(r'$TemplatesDir')
with zipfile.ZipFile(tpz, 'r') as zf:
    for member in zf.namelist():
        base = Path(member).name
        if base.startswith('windows_') or base == 'version.txt':
            with zf.open(member) as src, open(out_dir / base, 'wb') as dst:
                shutil.copyfileobj(src, dst)
print('Extracted Windows export templates successfully.')
"@
    $PyExtract | python -
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to extract Windows export templates."
    }
    Remove-Item $TpzPath -Force
}

$DistDir = Join-Path $RootDir "dist"
$GameSubDir = Join-Path $DistDir "ArenaSandbox"
if (Test-Path $GameSubDir) {
    Remove-Item $GameSubDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $GameSubDir | Out-Null

$OutExe = Join-Path $GameSubDir "ArenaSandbox.exe"
Write-Host "`n=== Building Standalone Windows x64 Executable ===" -ForegroundColor Cyan
& $GodotConsole --headless --path $RootDir --export-release "Windows Desktop" $OutExe
if ($LASTEXITCODE -ne 0 -or (-not (Test-Path $OutExe))) {
    throw "Export failed! Check console errors above."
}

Write-Host "`nBUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "  Output folder: $GameSubDir"
Write-Host "  Executable   : $OutExe"
