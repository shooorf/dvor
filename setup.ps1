param(
    [ValidateSet("1k", "2k", "4k")]
    [string]$Quality = "4k",
    [switch]$ForceAssets
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

$GodotTag = "4.7.2-stable"
$GodotDir = Join-Path $RootDir ".engine"
$GodotExe = Join-Path $GodotDir "Godot_v$GodotTag`_win64.exe"
$GodotConsole = Join-Path $GodotDir "Godot_v$GodotTag`_win64_console.exe"
$GodotZipUrl = "https://github.com/godotengine/godot/releases/download/$GodotTag/Godot_v$GodotTag`_win64.exe.zip"

Write-Host "=== [1/3] Checking Portable Godot $GodotTag ===" -ForegroundColor Cyan
if (-not (Test-Path $GodotConsole)) {
    New-Item -ItemType Directory -Force -Path $GodotDir | Out-Null
    $ZipPath = Join-Path $GodotDir "godot.zip"
    Write-Host "Downloading Godot $GodotTag (~70 MB)..."
    & curl.exe -L --fail -o $ZipPath $GodotZipUrl
    Expand-Archive -Path $ZipPath -DestinationPath $GodotDir -Force
    Remove-Item $ZipPath -Force
}
Write-Host "Godot ready: $GodotExe" -ForegroundColor Green

Write-Host "`n=== [2/3] Fetching Free CC0 Assets (Profile: $Quality) ===" -ForegroundColor Cyan
$PythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $PythonCmd) {
    throw "Python 3.10+ is not installed or not in PATH. Install via: winget install Python.Python.3.13"
}

$FetchArgs = @("scripts/fetch_assets.py", "--quality", $Quality)
if ($ForceAssets) {
    $FetchArgs += "--force"
}
& python @FetchArgs
if ($LASTEXITCODE -ne 0) {
    throw "Asset download failed with exit code $LASTEXITCODE"
}

Write-Host "`n=== [3/3] Importing 3D Models, 4K PBR Textures & HDRI into Godot ===" -ForegroundColor Cyan
& $GodotConsole --headless --path $RootDir --import
if ($LASTEXITCODE -ne 0) {
    throw "Godot asset import failed with exit code $LASTEXITCODE"
}

Write-Host "`nSetup complete! Run .\run.bat to play or .\build.bat to build standalone .exe for friends." -ForegroundColor Green
