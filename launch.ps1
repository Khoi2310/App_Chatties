<#
    launch.ps1 — one command to build and run Chatties (server + client).

    Usage (from the repo root, in PowerShell):
        ./launch.ps1
        ./launch.ps1 -QtDir "C:\Qt\6.11.1\msvc2022_64"
        ./launch.ps1 -Clean          # wipe build dirs first (forces QML cache refresh)
        ./launch.ps1 -NoRun          # build + deploy only, don't launch

    Prerequisites (installed once on the machine):
      * CMake 3.16+ and Visual Studio 2022 (MSVC, "Desktop development with C++")
      * vcpkg, with the VCPKG_ROOT environment variable set to its folder
      * Qt 6.11 for MSVC 2022 64-bit (auto-detected under C:\Qt, or pass -QtDir)

    The first server build compiles vcpkg dependencies (Boost, OpenSSL, SQLite,
    libsodium, cpp-httplib) and can take 10-30+ minutes. Later runs are incremental.
#>
param(
    [string]$QtDir  = $env:QT_DIR,
    [string]$Config = "Debug",
    [switch]$Clean,
    [switch]$NoRun
)

$ErrorActionPreference = "Stop"
$root       = $PSScriptRoot
$code       = Join-Path $root "Code"
$client     = Join-Path $code "Chatties"
$serverBld  = Join-Path $code   "build"
$clientBld  = Join-Path $client "build"

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# ── 1. Prerequisites ────────────────────────────────────────────────
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    Fail "CMake not found on PATH. Install CMake 3.16+ (and Visual Studio 2022)."
}
if (-not $env:VCPKG_ROOT) {
    Fail "VCPKG_ROOT is not set. Install vcpkg and set VCPKG_ROOT to its folder (e.g. C:\vcpkg)."
}

# Auto-detect Qt if not supplied.
if (-not $QtDir) {
    $QtDir = Get-ChildItem "C:\Qt" -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -match '^6\.' } |
             ForEach-Object { Join-Path $_.FullName "msvc2022_64" } |
             Where-Object { Test-Path $_ } |
             Sort-Object -Descending | Select-Object -First 1
}
if (-not $QtDir -or -not (Test-Path $QtDir)) {
    Fail "Qt not found. Pass -QtDir 'C:\Qt\6.x.x\msvc2022_64' or set the QT_DIR env var."
}
$windeployqt = Join-Path $QtDir "bin\windeployqt.exe"
if (-not (Test-Path $windeployqt)) { Fail "windeployqt.exe not found in $QtDir\bin." }
Write-Host "Qt:     $QtDir"
Write-Host "vcpkg:  $env:VCPKG_ROOT"

# ── 2. server_config.json (created from the template if missing) ─────
$cfg     = Join-Path $code "server_config.json"
$example = Join-Path $code "server_config.example.json"
if (-not (Test-Path $cfg)) {
    Copy-Item $example $cfg
    Write-Host "Created Code/server_config.json — add your Giphy API key to enable the GIF picker." -ForegroundColor Yellow
}

# ── 3. Optional clean ───────────────────────────────────────────────
if ($Clean) {
    Write-Host "`nCleaning build directories..."
    if (Test-Path $serverBld) { Remove-Item -Recurse -Force $serverBld }
    if (Test-Path $clientBld) { Remove-Item -Recurse -Force $clientBld }
}

# ── 4. Build the server (vcpkg preset) ──────────────────────────────
Write-Host "`n=== Building server (this compiles vcpkg deps on first run) ===" -ForegroundColor Cyan
Push-Location $code
try {
    cmake --preset default
    if ($LASTEXITCODE -ne 0) { Fail "Server configure failed." }
    cmake --build --preset debug
    if ($LASTEXITCODE -ne 0) { Fail "Server build failed." }
} finally { Pop-Location }

# ── 5. Build the client (Qt) ────────────────────────────────────────
Write-Host "`n=== Building client ===" -ForegroundColor Cyan
cmake -S $client -B $clientBld -G "Visual Studio 17 2022" -DCMAKE_PREFIX_PATH="$QtDir"
if ($LASTEXITCODE -ne 0) { Fail "Client configure failed." }
cmake --build $clientBld --config $Config
if ($LASTEXITCODE -ne 0) { Fail "Client build failed." }

# ── 6. Deploy the Qt runtime next to the client exe ─────────────────
$clientExe = Join-Path $clientBld "$Config\Chatties.exe"
$serverExe = Join-Path $serverBld "$Config\ServerApp.exe"
if (-not (Test-Path $clientExe)) { Fail "Client exe not found at $clientExe." }
if (-not (Test-Path $serverExe)) { Fail "Server exe not found at $serverExe." }

Write-Host "`n=== Deploying Qt runtime (windeployqt) ===" -ForegroundColor Cyan
& $windeployqt --qmldir $client $clientExe
if ($LASTEXITCODE -ne 0) { Fail "windeployqt failed." }

# ── 7. Launch server, then client ───────────────────────────────────
if ($NoRun) {
    Write-Host "`nBuild complete. Skipping launch (-NoRun)." -ForegroundColor Green
    Write-Host "Run manually:  $serverExe   then   $clientExe"
    exit 0
}

Write-Host "`n=== Launching Chatties ===" -ForegroundColor Green
Start-Process -FilePath $serverExe -WorkingDirectory (Split-Path $serverExe)
Start-Sleep -Seconds 1
Start-Process -FilePath $clientExe -WorkingDirectory (Split-Path $clientExe)
Write-Host "Server and client started. Register an account in the client to begin."
