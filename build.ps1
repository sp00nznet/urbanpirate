# build.ps1 - recompile your copy of Urban Pirate and build the native exe.
#
#   .\build.ps1                      # find the game, recompile, build
#   .\build.ps1 -GameDir "D:\Games\Urban Pirate"
#   .\build.ps1 -Run                 # ...then launch it
#
# Needs: Python 3, Visual Studio 2022 (C++ workload), vcpkg with sdl2,
# sdl2-image, sdl2-mixer and imgui (x64-windows), and the gmrecomp toolkit
# ($env:GMRECOMP, default ..\gmrecomp). Setup.cmd checks all of that for you.
# Generated C lands in generated\ and is never committed (it is derived from
# the game).
param([string]$GameDir = "", [switch]$Run, [string]$VcpkgRoot = "C:\vcpkg")
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
Set-Location $root

$toolkit = if ($env:GMRECOMP) { $env:GMRECOMP } else { Join-Path (Split-Path $root -Parent) "gmrecomp" }
if (-not (Test-Path (Join-Path $toolkit "tools\gmrecomp.py"))) { throw "gmrecomp toolkit not found at $toolkit (set GMRECOMP)" }

function Find-Game {
    $cands = @((Join-Path $root "game"), (Join-Path $root "Urban Pirate"))
    try {
        $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath
        $cands += Join-Path $steam "steamapps\common\Urban Pirate"
        $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $cands += Join-Path ($m.Groups[1].Value -replace '\\\\', '\') "steamapps\common\Urban Pirate"
            }
        }
    } catch { }
    foreach ($c in $cands) { if (Test-Path (Join-Path $c "data.win")) { return (Resolve-Path $c).Path } }
    return $null
}
if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir "data.win"))) {
    throw "Urban Pirate not found. Install it from Steam or pass -GameDir <folder with data.win>."
}
Write-Host "game:    $GameDir"
Write-Host "toolkit: $toolkit"

Write-Host "[1/2] Recompiling data.win -> generated\ ..."
$py = if (Get-Command py -ErrorAction SilentlyContinue) { "py" } else { "python" }
& $py (Join-Path $toolkit "tools\gmrecomp.py") (Join-Path $GameDir "data.win") -o generated
if ($LASTEXITCODE -ne 0) { throw "recompiler failed" }

Write-Host "[2/2] Building build\UrbanPirate.exe ..."
& (Join-Path $toolkit "tools\build.ps1") -Gen generated -Out build\UrbanPirate.exe -Extra profile -VcpkgRoot $VcpkgRoot

# launcher: remembers where the game data is
$launcher = Join-Path $root "Play Urban Pirate.cmd"
Set-Content -Encoding ascii $launcher "@echo off`r`nstart `"`" `"%~dp0build\UrbanPirate.exe`" --game `"$GameDir`"`r`n"
Write-Host "done. Run 'Play Urban Pirate.cmd'."
if ($Run) { & $launcher }
