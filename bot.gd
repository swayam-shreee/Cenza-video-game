extends Node
class_name Bot
## CPU brain. think() is called once per physics frame and returns the set of
## buttons the bot is "holding" that frame; Player reads it exactly like a
## human's keyboard. The player argument is untyped on purpose so this script
## does not reference Player while Player references Bot.
##
## The bot reads the character config too, so a long scythe keeps its distance
## and a hammer closes in, without any per-character AI code.

const LEVEL_NAMES := ["Easy", "Normal", "Hard"]


static func level_name(level: int) -> String:
	return LEVEL_NAMES[clampi(level, 0, 2)]


static func params(level: int) -> Dictionary:
	match level:
		0:  # Easy: slow to react, rarely blocks, wanders
			return {
				"react": 0.34, "attack": 0.45, "block": 0.10, "power": 0.20,
				"heavy": 0.25, "jitter": 70.0, "recover_skill": 0.55, "idle_drift": 0.35,
			}
		2:  # Hard: fast, punishes, uses powers and recovers well
			return {
				"react": 0.07, "attack": 0.95, "block": 0.62, "power": 0.80,
				"heavy": 0.55, "jitter": 10.0, "recover_skill": 1.0, "idle_drift": 0.0,
			}
		_:  # Normal
			return {
				"react": 0.17, "attack": 0.75, "block": 0.32, "power": 0.50,
				"heavy": 0.38, "jitter": 30.0, "recover_skill": 0.85, "idle_drift": 0.12,
			}


static func blank() -> Dictionary:
	return {
		"left": false, "right": false, "jump": false, "down": false,
		"light": false, "heavy": false, "block": false,
		"power1": false, "power2": false, "special": false,
	}


static func think(p, delta: float) -> Dictionary:
	var out := blank()
	if p.is_action_locked():
		return out

	var cfg := params(p.bot_level)
	var mem: Dictionary = p.bot_memory

	# Re-roll intent every "react" seconds so the bot isn't frame-perfect.
	mem["timer"] = float(mem.get("timer", 0.0)) - delta
	if mem["timer"] <= 0.0:
		mem["timer"] = cfg["react"]
		mem["want_attack"] = randf() < float(cfg["attack"])
		mem["want_block"] = randf() < float(cfg["block"])
		mem["want_power"] = randf() < float(cfg["power"])
		mem["want_heavy"] = randf() < float(cfg["heavy"])
		mem["aim_error"] = randf_range(-float(cfg["jitter"]), float(cfg["jitter"]))
		mem["drift"] = randf() < float(cfg["idle_drift"])

	var stage: Rect2 = p.stage_bounds
	var pos: Vector2 = p.global_position

	# --- recovery comes before everything else ---
	var off_side := pos.x < stage.position.x - 10.0 or pos.x > stage.end.x + 10.0
	var below := pos.y > stage.position.y + 30.0
	if (off_side or below) and randf() < float(cfg["recover_skill"]):
		return _recover(p, out, stage, pos)

	var target = _pick_target(p)
	if target == null:
		return out

	var tpos: Vector2 = target.global_position
	var dx: float = tpos.x - pos.x + float(mem.get("aim_error", 0.0))
	var dy: float = tpos.y - pos.y
	var dist: float = absf(dx)
	var reach := _reach(p)

	# --- face and approach ---
	if dist > reach * 0.75:
		if dx > 0.0:
			out["right"] = true
		else:
			out["left"] = true
	elif mem.get("drift", false):
		# Easy bots shuffle around instead of standing perfectly still.
		out["left"] = dx > 0.0
		out["right"] = dx <= 0.0

	# --- jump toward a target above, or off a ledge to chase ---
	if dy < -70.0 and dist < 180.0 and randf() < 0.08:
		out["jump"] = true
	elif dy > 90.0 and dist < 60.0 and randf() < 0.05:
		out["down"] = true  # drop through to follow them down

	# --- block when something is coming ---
	var incoming: bool = target.is_attacking() and dist < reach + 60.0
	if incoming and mem.get("want_block", false):
		out["block"] = true
		return out  # committing to the block this frame

	# --- attack when in range ---
	if dist < reach and absf(dy) < 70.0 and mem.get("want_attack", false) and target.can_be_hit():
		if mem.get("want_heavy", false):
			out["heavy"] = true
		else:
			out["light"] = true
		if dy < -40.0:
			out["jump"] = true   # up variant
		elif dy > 40.0:
			out["down"] = true   # down variant
		return out

	# --- powers ---
	if mem.get("want_power", false):
		if _use_power(p, out, target, dist, dy):
			return out

	# --- movement special ---
	_use_special(p, out, target, dist)
	return out


static func _recover(p, out: Dictionary, stage: Rect2, pos: Vector2) -> Dictionary:
	var center_x: float = stage.position.x + stage.size.x * 0.5
	if pos.x < center_x:
		out["right"] = true
	else:
		out["left"] = true
	# Jump back up if we're falling or below the stage lip.
	if p.velocity.y > -60.0:
		out["jump"] = true
	# Character escapes: Timmy webs back up, Sway dashes, Ando swaps with someone safe.
	var special: String = p.character.get("special_move", "")
	if special == "web_swing" and float(p.cooldowns.get("special", 0.0)) <= 0.0:
		out["special"] = true
	elif special == "invisible_dash" and float(p.cooldowns.get("special", 0.0)) <= 0.0 and absf(pos.x - center_x) < 340.0:
		out["special"] = true
	elif p.character.get("power2", {}).get("action", "") == "teleport_swap" \
			and float(p.cooldowns.get("power2", 0.0)) <= 0.0:
		out["power2"] = true
	return out


static func _pick_target(p):
	## Nearest living opponent that is actually in the match.
	var best = null
	var best_d := INF
	for other in p.get_tree().get_nodes_in_group("players"):
		if other == p or other.is_eliminated or not other.participating:
			continue
		var d: float = p.global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best


static func _reach(p) -> float:
	## How far this character's basic attack actually hits, read from its config.
	var m: Dictionary = p.character.get("light_side", {})
	if m.is_empty():
		return 80.0
	var offset: Vector2 = m.get("offset", Vector2(52, 0))
	var size: Vector2 = m.get("size", Vector2(60, 44))
	return offset.x + size.x * 0.5


static func _use_power(p, out: Dictionary, target, dist: float, dy: float) -> bool:
	var p1: Dictionary = p.character.get("power1", {})
	var p2: Dictionary = p.character.get("power2", {})

	# Power 2 first: the situational ones.
	if float(p.cooldowns.get("power2", 0.0)) <= 0.0 and not p2.is_empty():
		var action: String = p2.get("action", "")
		match action:
			"absorb_release":
				if not p.stored_power.is_empty() and dist < 620.0:
					out["power2"] = true
					return true
			"copy_last":
				if p.last_hitter != null and is_instance_valid(p.last_hitter) and dist < 620.0:
					out["power2"] = true
					return true
			"teleport_swap":
				# Best used when the opponent is off-stage: swap them back into danger.
				var stage: Rect2 = p.stage_bounds
				var their_pos: Vector2 = target.global_position
				var they_are_out := their_pos.x < stage.position.x or their_pos.x > stage.end.x
				if they_are_out or (dist > 260.0 and randf() < 0.3):
					out["power2"] = true
					return true
			_:
				# A regular projectile or melee power 2.
				var is_melee: bool = p2.get("type", "melee") == "melee"
				var want: bool = (dist < _reach(p) + 90.0) if is_melee else (dist < 600.0)
				if want and absf(dy) < 110.0:
					out["power2"] = true
					return true

	# Power 1: usually the projectile. Fire it at range.
	if float(p.cooldowns.get("power1", 0.0)) <= 0.0 and not p1.is_empty():
		var p1_melee: bool = p1.get("type", "melee") == "melee"
		var ok: bool = (dist < _reach(p) + 90.0) if p1_melee else (dist > 90.0 and dist < 620.0)
		if ok and absf(dy) < 110.0:
			out["power1"] = true
			return true
	return false


static func _use_special(p, out: Dictionary, target, dist: float) -> void:
	if float(p.cooldowns.get("special", 0.0)) > 0.0:
		return
	match p.character.get("special_move", ""):
		"invisible_dash":
			# Close a gap, or escape when hurt.
			if (dist > 230.0 and dist < 520.0 and randf() < 0.25) \
					or (p.damage_percent > 90.0 and dist < 110.0 and randf() < 0.2):
				out["special"] = true
		"web_swing":
			if not p.is_on_floor() and p.velocity.y > 120.0 and randf() < 0.3:
				out["special"] = true
