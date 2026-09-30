# smoke.ps1 - headless play-through checks for the recompiled Urban Pirate.
#
#   tools\smoke.ps1 [-GameDir <folder with data.win>]
#
# Runs scripted routes with no window (works over RDP) against a throwaway
# save folder, so your own saves are never touched, and checks which room each
# route ends in. Prints "N/M routes passed" and exits 1 on any failure.
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $root "build\UrbanPirate.exe"
if (-not (Test-Path $exe)) { throw "build first: .\build.ps1" }
if (-not $GameDir) {
    $l = Get-Content (Join-Path $root "Play Urban Pirate.cmd") -Raw -ErrorAction SilentlyContinue
    if ($l -match '--game "([^"]+)"') { $GameDir = $Matches[1] }
}
if (-not (Test-Path (Join-Path $GameDir "data.win"))) { throw "pass -GameDir <folder with data.win>" }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("up-smoke-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force $tmp | Out-Null
$oldLocal = $env:LOCALAPPDATA
$env:LOCALAPPDATA = $tmp          # gm_save_dir() lives under LOCALAPPDATA

# With no save the title menu starts on "Exit Game": Left = New Game.
$enter = (1..10 | ForEach-Object { "$(1060 + $_ * 45):13" }) -join ','
$routes = @(
    @{ name = "new game reaches level 1";  keys = "1000:37,1030:13,$enter"; frames = 1600; room = "room_lvl_1" },
    @{ name = "continue loads the save";   keys = "1000:39,1030:13";         frames = 1150; room = "room_level_menu" }
)
$pass = 0
Push-Location $tmp
try {
    foreach ($r in $routes) {
        # the exe logs to stderr; PowerShell 5.1 turns that into errors under "Stop"
        $ErrorActionPreference = "Continue"
        $out = & $exe --game $GameDir --headless --seed 1 --frames $r.frames --keys $r.keys 2>&1 | Out-String
        $ErrorActionPreference = "Stop"
        $ok = $out -match "exit after \d+ frames in room (\S+)"
        $room = if ($ok) { $Matches[1] } else { "?" }
        $good = $ok -and $room -eq $r.room
        if ($good) { $pass++ }
        Write-Host ("{0}  {1}  (ended in {2})" -f ($(if ($good) { "PASS" } else { "FAIL" })), $r.name, $room)
    }
} finally {
    Pop-Location
    $env:LOCALAPPDATA = $oldLocal
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
Write-Host "$pass/$($routes.Count) routes passed"
if ($pass -ne $routes.Count) { exit 1 }
