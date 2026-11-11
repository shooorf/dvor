param(
    [switch]$Editor,
    [ValidateSet("1k", "2k", "4k")]
    [string]$Quality = "4k"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

$GodotTag = "4.7.2-stable"
$GodotExe = Join-Path $RootDir ".engine\Godot_v$GodotTag`_win64.exe"
$ManifestPath = Join-Path $RootDir "assets\downloaded\manifest.json"
$ExpectedPackVersion = 5

$NeedSetup = (-not (Test-Path $GodotExe)) -or (-not (Test-Path $ManifestPath))
if (-not $NeedSetup) {
    try {
        $ManifestObj = Get-Content $ManifestPath -Raw | ConvertFrom-Json
        if (($ManifestObj.pack_version -ne $ExpectedPackVersion) -or ($ManifestObj.quality -ne $Quality)) {
            Write-Host "Updating asset pack to v$ExpectedPackVersion ($Quality)..." -ForegroundColor Yellow
            $NeedSetup = $true
        }
    } catch {
        $NeedSetup = $true
    }
}

if ($NeedSetup) {
    Write-Host "Running setup.ps1 to download and import $Quality assets..." -ForegroundColor Yellow
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RootDir "setup.ps1") -Quality $Quality
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    $GodotConsole = Join-Path $RootDir ".engine\Godot_v$GodotTag`_win64_console.exe"
    $PatchedImports = 0
    Get-ChildItem -Path (Join-Path $RootDir "assets\downloaded") -Recurse -Include "*.jpg.import", "*.png.import" -ErrorAction SilentlyContinue | ForEach-Object {
        $raw = Get-Content $_.FullName -Raw
        $updated = $raw -replace "mipmaps/generate=false", "mipmaps/generate=true"
        if ($_.Name -match "nor_gl") { $updated = $updated -replace "compress/normal_map=0", "compress/normal_map=1" }
        if ($updated -ne $raw) {
            Set-Content -Path $_.FullName -Value $updated -NoNewline -Encoding UTF8
            $PatchedImports++
        }
    }
    if (($PatchedImports -gt 0) -and (Test-Path $GodotConsole)) {
        Write-Host "Upgrading $PatchedImports textures with 3D mipmaps & normal maps..." -ForegroundColor Cyan
        & $GodotConsole --headless --path $RootDir --import
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}

if ($Editor) {
    Write-Host "Opening Godot 4 Editor..." -ForegroundColor Cyan
    Start-Process -FilePath $GodotExe -ArgumentList "--editor", "--path", "`"$RootDir`""
} else {
    Write-Host "Launching Dvor Sandbox (Forward+)..." -ForegroundColor Green
    & $GodotExe --path $RootDir
}
