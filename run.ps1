param(
    [switch]$Editor
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

$GodotTag = "4.7.2-stable"
$GodotExe = Join-Path $RootDir ".engine\Godot_v$GodotTag`_win64.exe"
$ManifestPath = Join-Path $RootDir "assets\downloaded\manifest.json"

if ((-not (Test-Path $GodotExe)) -or (-not (Test-Path $ManifestPath))) {
    Write-Host "First launch detected - running setup.ps1 first..." -ForegroundColor Yellow
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RootDir "setup.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($Editor) {
    Write-Host "Opening Godot 4 Editor..." -ForegroundColor Cyan
    Start-Process -FilePath $GodotExe -ArgumentList "--editor", "--path", "`"$RootDir`""
} else {
    Write-Host "Launching Arena Sandbox (Forward+)..." -ForegroundColor Green
    & $GodotExe --path $RootDir
}
