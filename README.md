# Brawl Fighter (stage 4)

Godot 4.3+ project. Open Godot, click **Import**, select `project.godot`, then press **F5**.

All five characters are in. Everything about a fighter now comes from `characters.gd`.

## Controls
| | Player 1 | Player 2 |
|---|---|---|
| Move | A / D | Left / Right |
| Jump (again in air = double jump) | W or Space | Up |
| Fast fall / drop through platform | S | Down |
| Light attack | F | / |
| Heavy attack | G | . |
| Block / parry | C | , |
| Power 1 | Q | ; |
| Power 2 | E | ' |
| Movement special | V | L |

Hold **up** (W / Up) or **down** (S / Down) while attacking for the up or down version.
**1-5** picks Player 1's character, **6-0** picks Player 2's. **R** restarts.

Character order: 1 Timmy, 2 Sway, 3 Wham, 4 Ando, 5 Jwong.

## The roster

| | Speed | Weight | Light / Heavy | Power 1 | Power 2 | Shield | Special |
|---|---|---|---|---|---|---|---|
| **Timmy** (staff) | 320 | 1.00 | 6 / 13 | Fireball (4s) | Lightning Net, roots 1.3s (9s) | standard | Web swing |
| **Sway** (hidden blade) | 365 | 1.15 | 4.5 / 11 | Throwing Knife (2.5s) | Chained Sword, huge reach (7s) | parry only | Invisible dash |
| **Wham** (scythe) | 335 | 1.00 | 7 / 15 | Ice Freeze, 1s freeze (8s) | Mimic, copies last attacker's Power 1 (6s) | ice | — |
| **Ando** (hammer) | 345 | 0.95 | 8 / 18 | Shield Throw, returns (5s) | Teleport Swap (10s) | standard | — |
| **Jwong** (shield) | 275 | 0.78 | 7.5 / 14 | Glowing Orb (5s) | Release stored power (1s) | absorb | — |

**Weight** is the knockback multiplier. Jwong at 0.78 gets launched far less than anyone
(that's how "high health" is modeled in a damage % game). Sway at 1.15 flies the furthest.
Fast characters hit softer, slow ones hit much harder: Ando's heavy does 4x Sway's light.

## How each special works
- **Timmy's web swing** (V): fires a web at the nearest platform above him within 420px and
  yanks him to it, gravity off for a moment. 1.2s cooldown. Good for recovering off-stage.
- **Timmy's lightning net**: roots the target for 1.3s. They can't move or jump but can still
  attack and block. Purple shackles show it.
- **Sway's invisible dash** (V): 900px/s dash, untargetable the whole time, 1.6s cooldown.
  His shield is parry-only, so tapping block opens a 0.14s window and nothing else. A
  successful parry becomes an automatic dash away from the attacker.
- **Wham's mimic**: copies the Power 1 of whoever last hit him and fires it himself. If nobody
  has hit him yet, it falls back to the nearest opponent's Power 1.
- **Wham's ice shield**: anyone whose attack lands on his shield gets frozen for 0.8s.
- **Ando's shield throw**: flies out 430px, then homes back to him. It can hit on the way out
  and on the way back.
- **Ando's teleport swap**: he and the nearest opponent trade places. Throw someone off-stage,
  then swap with them while they're out there.
- **Jwong's absorb shield**: hold block and the first power that hits it is absorbed instead of
  blocked, with no shield cost. A dot appears over his head. Press Power 2 to fire it back as
  his own.

## Try this
1. Press `5` so P1 is Jwong and `3` so P2 is Wham. Have Wham fire Ice Freeze (`;`) at Jwong
   while Jwong holds block (`C`) — Jwong absorbs it. Press `E` to fire it back.
2. Press `1` for Timmy, jump off the side of the stage, then press `V` to web back up.
3. Press `2` for Sway and tap `C` the instant an attack lands — he vanishes into a dash.
4. Press `4` for Ando, knock someone off the edge, then press `E` to swap places with them.
5. Hit Wham once, then have him press `E` — he throws your own Power 1 back at you.

## Tuning
Open `characters.gd`. Every number lives there: speed, weight, jump height, and for each move
the damage, knockback, launch angle, startup/active/recovery timing, hitbox size and cooldown.
The comment block at the top of the file explains each field. Nothing else needs editing.

Shield and match rules (shield drain, parry window, stocks, respawn) are `@export` vars in
`player.gd`.

## Files
- `characters.gd` — all five fighters' data. This is the file to edit.
- `player.gd` — runs a fighter: movement, the move state machine, shields, damage.
- `projectile.gd` — flying hitboxes for fireball, knife, orb, ice, shield throw.
- `main.gd` — stage, inputs, character select, HUD.

## Known rough edges
- Projectiles pass through platforms.
- Characters are still colored rectangles; the move system is the real work here.
- Up attacks use the jump key held down, which takes a moment to get used to.

## Next stages
5. 3-4 players and CPU bots
6. Menus, character select screen, more stages, sound
