# Cheats: what each one changes

Everything in the **Cheats** menu lives in `profile/profile_up.cpp`. The rules
were read from the game's own logic using the toolkit's pseudo-GML view
(`python ..\gmrecomp\tools\gmdis.py --gml data.win <name>`, output to a
gitignored folder).

## Stats

| Stat | Global | Game's own limits |
|---|---|---|
| Money | `money` | clamped at 0; a new game starts at 65 |
| Food | `food` | 0-3 (0-4 from level 3 on) |
| Energy | `energy` | reset each day: 5, or 3 when insane or starving |
| Sanity | `sanity` | 0-10; 0 sends you to the insane ending (`room_insane`) |
| Hunger | `hunger` | 0-4; 4 is starving, and 5 starving days is `room_starved` |
| Smoke, Street cred, XP | `smoke`, `points`, `XP_points` | no cap |

A **lock** freezes the value: it is written back before every step, so the
game can spend it and it comes straight back. The limits come from
`controller_lvl_N_Step_0`, which clamps them every step, so the editors
clamp to the same ranges.

## Controls: why they feel bad

Stock movement (`p1_KeyPress_37..40`, `p1_KeyRelease_*`, `p1_Collision_*`):

- A key **press** sets `hspeed`/`vspeed` to ±3 once. Nothing reads held keys.
- A **release** zeroes that axis, even if the opposite key is still held
  (the left/right handlers check, up/down don't).
- Touching the coastline (`sheep_island_mask`, `shark_city_mask`, which are
  solid precise masks) or `final_cops` sets both speeds to 0. You stop dead and
  have to let go and press again, and a diagonal into the coast stops both axes.

**Smooth movement** (on by default) sets the speed from the held arrows every
step, through the toolkit's `gm_premove_hook`, which runs after the game's
Step and before anything moves. Each axis is tested against the walls
separately, so you slide along the coast instead of sticking to it. It only
steers when the game would let you move (`controls_on == 0`, `pause == 0`),
and it sets the game's own `move` flag, so walking animations still play.
Turn it off in Cheats > Controls for the original feel.

## Luck

Every outcome below is a `choose()` whose result selects which result object
is created. The recompiler labels each option with that object, and the
presets pick by name:

| Preset | Code | Forces | Result object does |
|---|---|---|---|
| Dumpster diving | `action_dumpster_Alarm_0` | `result_5`, else `result_1` / `_2` / `_3` | 5: +$50; 1: +3 food; 2: +2; 3: +1. Stock odds: 6 of 10 rolls find nothing (`result_4`) |
| Shoplifting | `action_shoplift_Alarm_0` | `result_1`, else `result_4` | 1: +2-3 food; 4: caught, fined, -1 sanity; 5 (avoided): police chase |
| Socializing | `action_socialize*` | `result_2`, then 5, 4, 1 | 2: +3 sanity; 5: +1 sanity and -1 hunger; 4: +1 and +2 smoke; 3 (avoided): +2 but -$5 |
| Hitchhiking | `action_hitchhike_Alarm_0` | `result_1`, else `result_4` | 1: the ride; 2 (avoided): police |
| Train painting | `action_paint_train_Other_7` | value 1 (result_1) | +2 sanity; value 11 gets you caught |
| Fights | `controller_fight*` | `friend_t` | your friend turns up |
| Skate contests | `controller_skate_competition*` | your `round_N_points` highest, `_mia/_nicky/_snake` lowest | the judges' scores within your trick band |
| Plants | `action_plant*` | fewest days, biggest harvest | |
| Loaded dice | `p1_gamble_roll_1/2_Other_7` | first roll 3+4, later rolls = your point | craps: 7 or 11 wins on the first roll; later you need your point (`win_point`) |

Anything else random is in the **Luck** window, where any site can be forced
by hand.
