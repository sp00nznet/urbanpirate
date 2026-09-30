# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Mouse support (needs gmrecomp#1): click the game's buttons and icons, ◄ ► selectors by their
  ends, Enter/Esc elsewhere; click the map to walk there.
- Quick actions: a tap of 1/2/3 or a click on the icon does the game's "hold the key, press
  Enter" for you.
- Smoke route "mouse clicks reach level 1" (3/3).

### Added
- Urban Pirate recompiled with gmrecomp: 1691/1691 code entries, boots through the intro and
  title menu into level 1, with the game's own save and Continue working.
- Cheats menu (`profile/profile_up.cpp`): stat editors with locks, refill, +$500.
- Luck presets for dumpster diving, shoplifting, socializing, hitchhiking, train painting,
  fights, skate contests, plants, and loaded dice that follow the craps point.
- Smooth movement, on by default: held-key steering with wall sliding, through the toolkit's
  premove hook.
- `build.ps1` (finds the game through Steam libraries), `Setup.cmd` Quick start, and
  `tools/smoke.ps1` headless routes (2/2).
- `docs/cheats.md`: what each cheat changes and why the stock controls feel bad.
