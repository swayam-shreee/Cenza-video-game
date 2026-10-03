# Brawl Fighter (stage 7)

Godot 4.3+ project. Open Godot, click **Import**, select `project.godot`, then press **F5**.

The game now opens on a title screen with full menus. Every control is rebindable and
your bindings are saved to disk.

## Screens
Title → Choose your fighters and map → Match → Results.
**Escape** pauses during a match and backs out of any menu.

## Look and feel
Fighters are stick figures animated in code (`stick_figure.gd`):
- They stand upright: straight back, straight legs, arms at the sides, and they stay
  that way running and jumping. The body only bends when it's doing something.
- Every joint chases its pose on a spring. In neutral the springs are stiff, so fighters
  follow your input instantly. Actions loosen them: heavy attacks have big wind-ups and
  wobbly follow-throughs, and the air jump is a tucked flip.
- Each attack swings through the move's real hitbox with the fighter's weapon: Timmy's
  staff, Sway's twin blades, Wham's scythe, Ando's hammer and Jwong's shield. Powers are
  thrown or cast from the hands.
- Getting launched goes floppy: limbs flail, big hits send you cartwheeling, and you
  spring back upright with a wobble.
- Parrying freezes both fighters for a beat, then a flash and shockwave go off and sparks
  fly back at the attacker, with a little screen shake. Normal hits, blocks and Jwong's
  absorb each get their own smaller effects (`effects.gd`).

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
Six maps. Pick one with the **Map** row on the setup screen. Stages are wider than the
window: the camera follows the fighters, zooming out as they spread apart and back in
when they close the gap.

- **Air Temple** (default): a mountain courtyard at dusk, with a temple on the far peak.
  Three timber balconies, two ledges and a lookout. Art in `air_temple.gd`.
- **Neon District**: a rain-soaked rooftop in a cyberpunk megacity, with catwalks and
  billboard ledges stepping up unevenly. Art in `neon_district.gd`.
- **Battlefield** — big center platform with three float platforms. The all-rounder.
- **Flat Zone** — one long platform, nowhere to hide. Favors heavy hitters like Ando.
- **Twin Towers** — two raised towers over a gap. Miss the ledge and you have to climb out.
- **Skyline** — scattered small platforms, almost no safe ground. Recovery tools matter,
  so Timmy and Sway shine here.

Adding a map is one entry in `stages.gd`: platforms, spawn points, blast zone, and the
rectangle the CPU treats as safe ground. Nothing else needs changing. Give it a `theme`
to use custom art; without one it draws as plain blocks. `camera_limits` optionally
bounds what the camera can show (default: the blast zone, shrunk a little).

## Files
| File | What it is |
|---|---|
| `game.gd` | screen flow: title, menus, pause, results |
| `settings.gd` | control bindings, save/load, controller naming (autoloaded as `Settings`) |
| `arena.gd` | runs one match from a stage + player setup, and the camera |
| `stages.gd` | **the map data — edit this to add stages** |
| `characters.gd` | **the fighter data — edit this to rebalance** |
| `player.gd` | runs a fighter: movement, moves, shields, damage |
| `stick_figure.gd` | draws and animates a fighter's body and weapon |
| `effects.gd` | sparks, impact rings, dust, absorb swirls |
| `backdrop.gd` | parallax layer helpers shared by the themed backdrops |
| `air_temple.gd` | Air Temple backdrop and platform art |
| `neon_district.gd` | Neon District backdrop and platform art |
| `bot.gd` | the CPU brain |
| `projectile.gd` | flying hitboxes |

## Known rough edges
- Projectiles pass through platforms.
- No sound yet.
- Up attacks still use the jump button held down.

## Next up
8. Sound
9. Balance pass and exported builds
