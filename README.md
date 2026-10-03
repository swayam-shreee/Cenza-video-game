# Brawl Fighter (stage 6)

Godot 4.3+ project. Open Godot, click **Import**, select `project.godot`, then press **F5**.

The game now opens on a title screen with full menus. Every control is rebindable and
your bindings are saved to disk.

## Screens
Title → Choose your fighters → Pick a stage → Match → Results.
**Escape** pauses during a match and backs out of any menu.

## Controls menu
Title → Controls, or pause mid-match → Controls.

- Pick which player you're editing with the **P1 P2 P3 P4** buttons at the top.
- **Set** replaces a binding, **Add** gives the action a second binding (so one action can
  have both a key and a gamepad button), **Clear** unbinds it.
- Press the key, button, stick direction or trigger you want. **Escape** cancels.
- If the input is already used elsewhere it still binds, and tells you what else uses it.
- **Reset to defaults** per player or for everything.

Bindings save immediately to `user://settings.cfg`. On Linux that's
`~/.local/share/godot/app_userdata/Brawl Fighter/settings.cfg`.

### Controllers
Any controller Godot recognizes works — Xbox, PlayStation, or a generic pad. The controls
screen lists what's plugged in, and names buttons the way **your** controller labels them:
an Xbox pad shows `A B X Y LB RB`, a PlayStation pad shows `Cross Circle Square Triangle L1 R1`.
Plug a pad in and it appears in the menu right away.

Each player defaults to the matching pad: P1 uses pad 1, P2 pad 2, and so on. Bindings are
per-device, so two identical controllers don't conflict.

**Default gamepad layout:** left stick/D-pad move, A jump, X light, B heavy,
right trigger block, Y Power 1, RB Power 2, LB special.

**Default keyboard:**
| | Player 1 | Player 2 |
|---|---|---|
| Move | A / D | Left / Right |
| Jump | W or Space | Up |
| Down / fast fall | S | Down |
| Light | F | / |
| Heavy | G | . |
| Block | C | , |
| Power 1 | Q | ; |
| Power 2 | E | ' |
| Special | V | L |

## Stages
Four maps, pickable before each match:

- **Battlefield** — big center platform with three float platforms. The all-rounder.
- **Flat Zone** — one long platform, nowhere to hide. Favors heavy hitters like Ando.
- **Twin Towers** — two raised towers over a gap. Miss the ledge and you have to climb out.
- **Skyline** — scattered small platforms, almost no safe ground. Recovery tools matter,
  so Timmy and Sway shine here.

Adding a map is one entry in `stages.gd`: platforms, spawn points, blast zone, and the
rectangle the CPU treats as safe ground. Nothing else needs changing.

## Files
| File | What it is |
|---|---|
| `game.gd` | screen flow: title, menus, pause, results |
| `settings.gd` | control bindings, save/load, controller naming (autoloaded as `Settings`) |
| `arena.gd` | runs one match from a stage + player setup |
| `stages.gd` | **the map data — edit this to add stages** |
| `characters.gd` | **the fighter data — edit this to rebalance** |
| `player.gd` | runs a fighter: movement, moves, shields, damage |
| `bot.gd` | the CPU brain |
| `projectile.gd` | flying hitboxes |

## Known rough edges
- Fighters are still colored rectangles. Art needs the animation system first (see below).
- Projectiles pass through platforms.
- No sound yet.
- Up attacks still use the jump button held down.

## Next up
7. Animation system, then artwork
8. Sound
9. Balance pass and exported builds
