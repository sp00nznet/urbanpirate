# Contributing

Thanks for helping. Bug reports, playthrough notes and PRs are all welcome.

## Never attach game material

Not in issues, PRs or screenshots of files: no `data.win`, music, extracted sprites or sounds,
no `generated/` C, and no disassembly or pseudo-GML listings. They are derived from the game and
can't be shared (REPO_RULES section 3). Describe the behaviour instead, and name the code entry
(`gml_Object_p1_KeyPress_39`) so it can be looked up locally. Screenshots of the game running
are fine.

## Where your code comes from

Contributions must be your own work or MIT-compatible. In particular, don't port code from
**UndertaleModTool** (GPL-3.0) or other GPL GameMaker tools, and nothing from YoYo Games' runner
sources. Reading their format notes for understanding is fine; copying code is not. If a change
is unusually polished, say where it came from.

## A note on AI-assisted contributions

They're welcome, provided a human understood and verified the change: say what you ran, and on
which part of the game.

## Before a PR

- `.\build.ps1` builds, and `tools\smoke.ps1` passes.
- Game-specific behaviour goes in `profile/`. Anything any GameMaker game could use belongs in
  [gmrecomp](https://github.com/sp00nznet/gmrecomp) as its own PR.
- New cheats default to off, unless they fix controls and have a switch.
