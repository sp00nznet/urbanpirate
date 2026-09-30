# setup.ps1 - the Quick start behind Setup.cmd.
#
# Checks every prerequisite and asks before installing anything. Then it runs
# exactly what README "Step by step" documents (build.ps1) and leaves
# "Play Urban Pirate.cmd" in this folder. Safe to rerun: finished steps are
# skipped. Details go to setup.log.
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$log = Join-Path $root "setup.log"
Start-Transcript -Path $log -Force | Out-Null

function Ask($q) { $a = Read-Host "$q [y/N]"; return $a -match '^(y|yes)$' }
function Fail($msg) {
    Write-Host ""
    Write-Host $msg -ForegroundColor Red
    Write-Host "Details are in $log"
    Stop-Transcript | Out-Null
    Read-Host "Press Enter to close"
    exit 1
}
function Have($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Write-Host "Urban Pirate recompiled - setup" -ForegroundColor Cyan
Write-Host "You need your own copy of Urban Pirate (Steam). Nothing from the game is downloaded."
Write-Host ""

# 1. Python
$py = $null
foreach ($c in "py", "python") {
    if (Have $c) {
        $v = & $c -c "import sys; print(sys.version_info[:2] >= (3, 10))" 2>$null
        if ($v -eq "True") { $py = $c; break }
    }
}
if (-not $py) {
    if (-not (Ask "Python 3.10+ is missing (it runs the recompiler). Install Python 3.12 with winget (~30 MB)?")) { Fail "Install Python 3.12 from python.org, then run Setup.cmd again." }
    winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
    Fail "Python installed. Close this window and run Setup.cmd again so the new PATH is picked up."
}
Write-Host "ok  Python ($py)"

# 2. Visual Studio C++ tools
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
$vs = if (Test-Path $vswhere) { & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath } else { "" }
if (-not $vs) {
    if (-not (Ask "The Visual Studio C++ compiler is missing. Install Visual Studio 2022 Build Tools with winget (~2.5 GB)?")) { Fail "Install Visual Studio 2022 with 'Desktop development with C++', then run Setup.cmd again." }
    winget install -e --id Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { Fail "The C++ tools didn't install. Install Visual Studio 2022 with 'Desktop development with C++' by hand." }
}
Write-Host "ok  C++ compiler ($vs)"

# 3. vcpkg and libraries
$vcpkg = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { "C:\vcpkg" }
if (-not (Test-Path (Join-Path $vcpkg "vcpkg.exe"))) {
    if (-not (Have "git")) { Fail "git is needed to fetch vcpkg. Install Git for Windows, then run Setup.cmd again." }
    if (-not (Ask "vcpkg (C/C++ library manager) is missing. Download it to $vcpkg (~50 MB)?")) { Fail "Install vcpkg to C:\vcpkg (github.com/microsoft/vcpkg), then run Setup.cmd again." }
    git clone https://github.com/microsoft/vcpkg $vcpkg
    & (Join-Path $vcpkg "bootstrap-vcpkg.bat") -disableMetrics
}
$vi = Join-Path $vcpkg "installed\x64-windows"
$need = @()
if (-not (Test-Path "$vi\include\SDL2\SDL.h")) { $need += "sdl2" }
if (-not (Test-Path "$vi\include\SDL2\SDL_image.h")) { $need += "sdl2-image" }
if (-not (Test-Path "$vi\include\SDL2\SDL_mixer.h")) { $need += "sdl2-mixer" }
if (-not (Test-Path "$vi\include\imgui.h")) { $need += "imgui" }
if ($need.Count) {
    if (-not (Ask "Libraries missing: $($need -join ', '). Build them with vcpkg (about 10 minutes)?")) { Fail "Run: $vcpkg\vcpkg install $($need -join ' ') --triplet x64-windows" }
    & (Join-Path $vcpkg "vcpkg.exe") install @need --triplet x64-windows
    if ($LASTEXITCODE -ne 0) { Fail "vcpkg couldn't build the libraries." }
}
Write-Host "ok  SDL2, SDL2_image, SDL2_mixer, imgui"

# 4. gmrecomp toolkit
$toolkit = if ($env:GMRECOMP) { $env:GMRECOMP } else { Join-Path (Split-Path $root -Parent) "gmrecomp" }
if (-not (Test-Path (Join-Path $toolkit "tools\gmrecomp.py"))) {
    if (-not (Have "git")) { Fail "git is needed to fetch the gmrecomp toolkit. Install Git for Windows, then run Setup.cmd again." }
    if (-not (Ask "The gmrecomp toolkit is missing. Download it to $toolkit (~1 MB)?")) { Fail "Clone github.com/sp00nznet/gmrecomp next to this folder, then run Setup.cmd again." }
    git clone https://github.com/sp00nznet/gmrecomp $toolkit
}
$env:GMRECOMP = $toolkit
Write-Host "ok  gmrecomp ($toolkit)"

# 5. the game
$gameArgs = @()
$found = $false
foreach ($c in @((Join-Path $root "game"), (Join-Path $root "Urban Pirate"))) { if (Test-Path (Join-Path $c "data.win")) { $found = $true } }
try {
    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath
    if (Test-Path (Join-Path $steam "steamapps\common\Urban Pirate\data.win")) { $found = $true }
} catch { }
if (-not $found) {
    $g = Read-Host "Where is Urban Pirate installed? (the folder with data.win; Steam: right-click > Manage > Browse local files)"
    $g = $g.Trim('"')
    if (-not (Test-Path (Join-Path $g "data.win"))) { Fail "No data.win in '$g'." }
    $gameArgs = @("-GameDir", $g)
}

# 6. build: the same command as README "Step by step"
& (Join-Path $root "build.ps1") @gameArgs -VcpkgRoot $vcpkg
if (-not (Test-Path (Join-Path $root "build\UrbanPirate.exe"))) { Fail "The build failed." }

Write-Host ""
Write-Host "All set. Double-click 'Play Urban Pirate.cmd' to play." -ForegroundColor Green
Stop-Transcript | Out-Null
Read-Host "Press Enter to close"
