extends Node
class_name Characters
## All character data lives here. Edit numbers in this file to rebalance the game;
## no other script needs to change.
##
## MOVE FIELDS
##   name          shown in the HUD when the move comes out
##   type          "melee", "projectile", or "special"
##   damage        damage % added on hit
##   kb_base       knockback at 0% damage
##   kb_growth     extra knockback per 1% of the victim's damage
##   angle         launch direction; x is mirrored to the attacker's facing
##   startup       wind-up seconds before the hitbox exists
##   active        seconds the hitbox can hit
##   recovery      seconds locked after the hitbox ends
##   offset/size   hitbox position (x mirrored by facing) and size in pixels
##   cooldown      seconds before the move can be used again (0 = no cooldown)
##   status        "", "freeze" (cannot act), or "root" (cannot move or jump)
##   status_time   how long the status lasts
##
## PROJECTILE EXTRAS
##   speed, life, proj_gravity, returns, max_travel, proj_size, color
##   look          how it's drawn: "fireball", "net", "knife", "ice", "disc", "orb"
##
## SPECIAL ACTIONS (type "special")
##   action        "teleport_swap", "copy_last", or "absorb_release"
##
## CHARACTER FIELDS (besides the moves)
##   weapon        what the stick figure holds: "staff", "blades", "scythe",
##                 "hammer" or "shield". Purely visual.

const SHIELD_STANDARD := "standard"
const SHIELD_PARRY_ONLY := "parry_only"
const SHIELD_FREEZE := "freeze"
const SHIELD_ABSORB := "absorb"


static func M(overrides: Dictionary) -> Dictionary:
	## Builds a move from sensible defaults plus whatever you override.
	var base := {
		"name": "Move",
		"type": "melee",
		"damage": 8.0,
		"kb_base": 300.0,
		"kb_growth": 7.0,
		"angle": Vector2(1.0, -0.5),
		"startup": 0.07,
		"active": 0.09,
		"recovery": 0.16,
		"offset": Vector2(52.0, 0.0),
		"size": Vector2(60.0, 44.0),
		"cooldown": 0.0,
		"status": "",
		"status_time": 0.0,
		# projectile-only
		"speed": 500.0,
		"life": 1.5,
		"proj_gravity": 0.0,
		"returns": false,
		"max_travel": 400.0,
		"proj_size": Vector2(24.0, 24.0),
		"color": Color(1, 1, 1),
		"look": "",
		# special-only
		"action": "",
	}
	for k in overrides:
		base[k] = overrides[k]
	return base


static func get_all() -> Array:
	return [timmy(), sway(), wham(), ando(), jwong()]


static func get_by_index(i: int) -> Dictionary:
	var all := get_all()
	return all[clampi(i, 0, all.size() - 1)]


# ---------------------------------------------------------------------------
# TIMMY - staff. Balanced all-rounder with a web swing and zoning powers.
# ---------------------------------------------------------------------------
static func timmy() -> Dictionary:
	return {
		"name": "Timmy",
		"weapon": "staff",
		"color": Color(0.95, 0.75, 0.2),
		"move_speed": 320.0,
		"jump_velocity": -640.0,
		"air_jump_velocity": -580.0,
		"max_air_jumps": 1,
		"weight": 1.0,  # knockback taken multiplier; lower = heavier
		"shield": SHIELD_STANDARD,
		"special_move": "web_swing",
		"special_cooldown": 1.2,
		"light_side": M({"name": "Staff Jab", "damage": 6.0, "kb_base": 270.0, "kb_growth": 6.5,
			"startup": 0.06, "active": 0.08, "recovery": 0.14,
			"offset": Vector2(54, 0), "size": Vector2(66, 40)}),
		"light_up": M({"name": "Staff Twirl", "damage": 6.0, "kb_base": 290.0, "kb_growth": 7.0,
			"angle": Vector2(0.2, -1.0), "startup": 0.06, "active": 0.09, "recovery": 0.15,
			"offset": Vector2(16, -42), "size": Vector2(56, 56)}),
		"light_down": M({"name": "Staff Sweep", "damage": 6.5, "kb_base": 250.0, "kb_growth": 6.0,
			"angle": Vector2(1.0, -0.25), "startup": 0.07, "active": 0.09, "recovery": 0.16,
			"offset": Vector2(48, 26), "size": Vector2(72, 32)}),
		"heavy_side": M({"name": "Staff Thrust", "damage": 13.0, "kb_base": 420.0, "kb_growth": 9.0,
			"startup": 0.16, "active": 0.10, "recovery": 0.28,
			"offset": Vector2(66, 0), "size": Vector2(86, 44)}),
		"heavy_up": M({"name": "Rising Staff", "damage": 12.0, "kb_base": 430.0, "kb_growth": 9.5,
			"angle": Vector2(0.15, -1.0), "startup": 0.15, "active": 0.10, "recovery": 0.28,
			"offset": Vector2(14, -50), "size": Vector2(62, 70)}),
		"heavy_down": M({"name": "Staff Slam", "damage": 14.0, "kb_base": 400.0, "kb_growth": 8.5,
			"angle": Vector2(0.8, -0.6), "startup": 0.18, "active": 0.10, "recovery": 0.30,
			"offset": Vector2(52, 30), "size": Vector2(84, 40)}),
		"power1": M({"name": "Fireball", "type": "projectile", "look": "fireball", "damage": 11.0,
			"kb_base": 360.0, "kb_growth": 7.0, "angle": Vector2(1.0, -0.45),
			"startup": 0.16, "active": 0.05, "recovery": 0.26, "cooldown": 4.0,
			"speed": 520.0, "life": 1.6, "proj_size": Vector2(26, 26),
			"color": Color(1.0, 0.5, 0.15)}),
		"power2": M({"name": "Lightning Net", "type": "projectile", "look": "net", "damage": 6.0,
			"kb_base": 120.0, "kb_growth": 2.0, "angle": Vector2(1.0, -0.2),
			"startup": 0.22, "active": 0.05, "recovery": 0.32, "cooldown": 9.0,
			"speed": 420.0, "life": 1.2, "proj_size": Vector2(46, 46),
			"color": Color(0.7, 0.5, 1.0), "status": "root", "status_time": 1.3}),
	}


# ---------------------------------------------------------------------------
# SWAY - hidden blade. Fastest and most fragile. Parry-only defense.
# ---------------------------------------------------------------------------
static func sway() -> Dictionary:
	return {
		"name": "Sway",
		"weapon": "blades",
		"color": Color(0.55, 0.3, 0.75),
		"move_speed": 365.0,
		"jump_velocity": -660.0,
		"air_jump_velocity": -600.0,
		"max_air_jumps": 1,
		"weight": 1.15,  # light: gets launched further
		"shield": SHIELD_PARRY_ONLY,
		"special_move": "invisible_dash",
		"special_cooldown": 1.6,
		"light_side": M({"name": "Blade Slash", "damage": 4.5, "kb_base": 230.0, "kb_growth": 5.5,
			"startup": 0.04, "active": 0.07, "recovery": 0.10,
			"offset": Vector2(42, 0), "size": Vector2(48, 40)}),
		"light_up": M({"name": "Upward Slice", "damage": 5.0, "kb_base": 250.0, "kb_growth": 6.0,
			"angle": Vector2(0.2, -1.0), "startup": 0.05, "active": 0.07, "recovery": 0.11,
			"offset": Vector2(12, -38), "size": Vector2(46, 52)}),
		"light_down": M({"name": "Low Cut", "damage": 5.0, "kb_base": 210.0, "kb_growth": 5.0,
			"angle": Vector2(1.0, -0.3), "startup": 0.05, "active": 0.07, "recovery": 0.12,
			"offset": Vector2(40, 24), "size": Vector2(54, 30)}),
		"heavy_side": M({"name": "Assassin Strike", "damage": 11.0, "kb_base": 390.0, "kb_growth": 9.5,
			"startup": 0.12, "active": 0.08, "recovery": 0.22,
			"offset": Vector2(50, 0), "size": Vector2(60, 42)}),
		"heavy_up": M({"name": "Ascend", "damage": 10.0, "kb_base": 400.0, "kb_growth": 10.0,
			"angle": Vector2(0.1, -1.0), "startup": 0.11, "active": 0.08, "recovery": 0.24,
			"offset": Vector2(10, -46), "size": Vector2(50, 64)}),
		"heavy_down": M({"name": "Falling Blade", "damage": 12.0, "kb_base": 360.0, "kb_growth": 9.0,
			"angle": Vector2(0.7, -0.5), "startup": 0.14, "active": 0.08, "recovery": 0.26,
			"offset": Vector2(44, 28), "size": Vector2(58, 38)}),
		"power1": M({"name": "Throwing Knife", "type": "projectile", "look": "knife", "damage": 7.0,
			"kb_base": 250.0, "kb_growth": 5.0, "angle": Vector2(1.0, -0.35),
			"startup": 0.10, "active": 0.05, "recovery": 0.18, "cooldown": 2.5,
			"speed": 760.0, "life": 1.4, "proj_size": Vector2(22, 10),
			"color": Color(0.85, 0.88, 0.95)}),
		"power2": M({"name": "Chained Sword", "damage": 14.0, "kb_base": 430.0, "kb_growth": 9.0,
			"startup": 0.18, "active": 0.12, "recovery": 0.30, "cooldown": 7.0,
			"offset": Vector2(110, 0), "size": Vector2(170, 34)}),
	}


# ---------------------------------------------------------------------------
# WHAM - scythe. Longest melee reach, freeze control, ice shield.
# ---------------------------------------------------------------------------
static func wham() -> Dictionary:
	return {
		"name": "Wham",
		"weapon": "scythe",
		"color": Color(0.35, 0.7, 1.0),
		"move_speed": 335.0,
		"jump_velocity": -635.0,
		"air_jump_velocity": -575.0,
		"max_air_jumps": 1,
		"weight": 1.0,
		"shield": SHIELD_FREEZE,
		"special_move": "",
		"special_cooldown": 0.0,
		"light_side": M({"name": "Scythe Swipe", "damage": 7.0, "kb_base": 280.0, "kb_growth": 6.5,
			"startup": 0.08, "active": 0.10, "recovery": 0.18,
			"offset": Vector2(62, 0), "size": Vector2(84, 46)}),
		"light_up": M({"name": "Reaping Arc", "damage": 7.0, "kb_base": 300.0, "kb_growth": 7.0,
			"angle": Vector2(0.2, -1.0), "startup": 0.08, "active": 0.10, "recovery": 0.19,
			"offset": Vector2(18, -46), "size": Vector2(66, 62)}),
		"light_down": M({"name": "Low Reap", "damage": 7.0, "kb_base": 260.0, "kb_growth": 6.0,
			"angle": Vector2(1.0, -0.3), "startup": 0.09, "active": 0.10, "recovery": 0.19,
			"offset": Vector2(56, 26), "size": Vector2(80, 34)}),
		"heavy_side": M({"name": "Death Harvest", "damage": 15.0, "kb_base": 440.0, "kb_growth": 9.5,
			"startup": 0.20, "active": 0.12, "recovery": 0.32,
			"offset": Vector2(74, 0), "size": Vector2(108, 50)}),
		"heavy_up": M({"name": "Soul Reaper", "damage": 13.0, "kb_base": 450.0, "kb_growth": 10.0,
			"angle": Vector2(0.15, -1.0), "startup": 0.18, "active": 0.12, "recovery": 0.32,
			"offset": Vector2(16, -54), "size": Vector2(70, 78)}),
		"heavy_down": M({"name": "Grave Slam", "damage": 16.0, "kb_base": 410.0, "kb_growth": 9.0,
			"angle": Vector2(0.8, -0.55), "startup": 0.22, "active": 0.12, "recovery": 0.34,
			"offset": Vector2(60, 30), "size": Vector2(100, 42)}),
		"power1": M({"name": "Ice Freeze", "type": "projectile", "look": "ice", "damage": 5.0,
			"kb_base": 100.0, "kb_growth": 2.0, "angle": Vector2(1.0, -0.2),
			"startup": 0.18, "active": 0.05, "recovery": 0.28, "cooldown": 8.0,
			"speed": 460.0, "life": 1.5, "proj_size": Vector2(30, 30),
			"color": Color(0.6, 0.9, 1.0), "status": "freeze", "status_time": 1.0}),
		"power2": M({"name": "Mimic", "type": "special", "action": "copy_last",
			"startup": 0.12, "active": 0.05, "recovery": 0.20, "cooldown": 6.0}),
	}


# ---------------------------------------------------------------------------
# ANDO - hammer. Biggest knockback, shield throw, teleport swap.
# ---------------------------------------------------------------------------
static func ando() -> Dictionary:
	return {
		"name": "Ando",
		"weapon": "hammer",
		"color": Color(0.9, 0.35, 0.35),
		"move_speed": 345.0,
		"jump_velocity": -625.0,
		"air_jump_velocity": -565.0,
		"max_air_jumps": 1,
		"weight": 0.95,
		"shield": SHIELD_STANDARD,
		"special_move": "",
		"special_cooldown": 0.0,
		"light_side": M({"name": "Hammer Swing", "damage": 8.0, "kb_base": 310.0, "kb_growth": 7.0,
			"startup": 0.10, "active": 0.10, "recovery": 0.20,
			"offset": Vector2(52, 0), "size": Vector2(64, 48)}),
		"light_up": M({"name": "Hammer Lift", "damage": 8.0, "kb_base": 330.0, "kb_growth": 7.5,
			"angle": Vector2(0.2, -1.0), "startup": 0.10, "active": 0.10, "recovery": 0.21,
			"offset": Vector2(16, -44), "size": Vector2(58, 60)}),
		"light_down": M({"name": "Ground Tap", "damage": 8.5, "kb_base": 290.0, "kb_growth": 6.5,
			"angle": Vector2(1.0, -0.3), "startup": 0.11, "active": 0.10, "recovery": 0.21,
			"offset": Vector2(48, 26), "size": Vector2(68, 34)}),
		"heavy_side": M({"name": "Thunder Smash", "damage": 18.0, "kb_base": 500.0, "kb_growth": 10.0,
			"startup": 0.24, "active": 0.12, "recovery": 0.36,
			"offset": Vector2(62, 0), "size": Vector2(80, 54)}),
		"heavy_up": M({"name": "Sky Breaker", "damage": 16.0, "kb_base": 510.0, "kb_growth": 10.5,
			"angle": Vector2(0.1, -1.0), "startup": 0.22, "active": 0.12, "recovery": 0.36,
			"offset": Vector2(14, -52), "size": Vector2(66, 76)}),
		"heavy_down": M({"name": "Quake Slam", "damage": 19.0, "kb_base": 470.0, "kb_growth": 9.5,
			"angle": Vector2(0.75, -0.5), "startup": 0.26, "active": 0.12, "recovery": 0.38,
			"offset": Vector2(54, 30), "size": Vector2(92, 44)}),
		"power1": M({"name": "Shield Throw", "type": "projectile", "look": "disc", "damage": 12.0,
			"kb_base": 330.0, "kb_growth": 6.5, "angle": Vector2(1.0, -0.4),
			"startup": 0.14, "active": 0.05, "recovery": 0.24, "cooldown": 5.0,
			"speed": 620.0, "life": 3.0, "returns": true, "max_travel": 430.0,
			"proj_size": Vector2(34, 34), "color": Color(0.95, 0.4, 0.4)}),
		"power2": M({"name": "Teleport Swap", "type": "special", "action": "teleport_swap",
			"startup": 0.14, "active": 0.05, "recovery": 0.22, "cooldown": 10.0}),
	}


# ---------------------------------------------------------------------------
# JWONG - shield. Slow tank, hardest to launch, absorbs powers.
# ---------------------------------------------------------------------------
static func jwong() -> Dictionary:
	return {
		"name": "Jwong",
		"weapon": "shield",
		"color": Color(0.4, 0.8, 0.5),
		"move_speed": 275.0,
		"jump_velocity": -600.0,
		"air_jump_velocity": -545.0,
		"max_air_jumps": 1,
		"weight": 0.78,  # heavy: takes much less knockback, the "high health" trait
		"shield": SHIELD_ABSORB,
		"special_move": "",
		"special_cooldown": 0.0,
		"light_side": M({"name": "Shield Bash", "damage": 7.5, "kb_base": 300.0, "kb_growth": 6.5,
			"startup": 0.10, "active": 0.10, "recovery": 0.20,
			"offset": Vector2(46, 0), "size": Vector2(56, 50)}),
		"light_up": M({"name": "Shield Raise", "damage": 7.5, "kb_base": 320.0, "kb_growth": 7.0,
			"angle": Vector2(0.15, -1.0), "startup": 0.10, "active": 0.10, "recovery": 0.21,
			"offset": Vector2(14, -42), "size": Vector2(54, 58)}),
		"light_down": M({"name": "Shield Drop", "damage": 8.0, "kb_base": 280.0, "kb_growth": 6.0,
			"angle": Vector2(1.0, -0.3), "startup": 0.11, "active": 0.10, "recovery": 0.21,
			"offset": Vector2(44, 26), "size": Vector2(62, 34)}),
		"heavy_side": M({"name": "Bulwark Charge", "damage": 14.0, "kb_base": 450.0, "kb_growth": 9.0,
			"startup": 0.20, "active": 0.14, "recovery": 0.30,
			"offset": Vector2(54, 0), "size": Vector2(70, 54)}),
		"heavy_up": M({"name": "Shield Launch", "damage": 13.0, "kb_base": 460.0, "kb_growth": 9.5,
			"angle": Vector2(0.1, -1.0), "startup": 0.18, "active": 0.12, "recovery": 0.30,
			"offset": Vector2(12, -48), "size": Vector2(60, 70)}),
		"heavy_down": M({"name": "Fortress Slam", "damage": 15.0, "kb_base": 420.0, "kb_growth": 8.5,
			"angle": Vector2(0.7, -0.55), "startup": 0.22, "active": 0.12, "recovery": 0.32,
			"offset": Vector2(48, 30), "size": Vector2(80, 42)}),
		"power1": M({"name": "Glowing Orb", "type": "projectile", "look": "orb", "damage": 13.0,
			"kb_base": 380.0, "kb_growth": 7.5, "angle": Vector2(1.0, -0.45),
			"startup": 0.20, "active": 0.05, "recovery": 0.30, "cooldown": 5.0,
			"speed": 380.0, "life": 2.2, "proj_size": Vector2(38, 38),
			"color": Color(0.7, 1.0, 0.85)}),
		"power2": M({"name": "Release", "type": "special", "action": "absorb_release",
			"startup": 0.10, "active": 0.05, "recovery": 0.18, "cooldown": 1.0}),
	}
