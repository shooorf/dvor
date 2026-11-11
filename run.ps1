param(
    [switch]$Editor
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

$GodotTag = "4.7.2-stable"
$GodotExe = Join-Path $RootDir ".engine\Godot_v$GodotTag`_win64.exe"
$ManifestPath = Join-Path $RootDir "assets\downloaded\manifest.json"
$ExpectedPackVersion = 3

$NeedSetup = (-not (Test-Path $GodotExe)) -or (-not (Test-Path $ManifestPath))
if (-not $NeedSetup) {
    try {
        $ManifestObj = Get-Content $ManifestPath -Raw | ConvertFrom-Json
        if ($ManifestObj.pack_version -ne $ExpectedPackVersion) {
            Write-Host "New asset pack v$ExpectedPackVersion detected - updating 4K assets..." -ForegroundColor Yellow
            $NeedSetup = $true
        }
    } catch {
        $NeedSetup = $true
    }
}

if ($NeedSetup) {
    Write-Host "Running setup.ps1 to download and import assets..." -ForegroundColor Yellow
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RootDir "setup.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($Editor) {
    Write-Host "Opening Godot 4 Editor..." -ForegroundColor Cyan
    Start-Process -FilePath $GodotExe -ArgumentList "--editor", "--path", "`"$RootDir`""
} else {
    Write-Host "Launching Dvor Sandbox (Forward+)..." -ForegroundColor Green
    & $GodotExe --path $RootDir
}
