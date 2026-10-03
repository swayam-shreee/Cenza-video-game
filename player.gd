extends CharacterBody2D
class_name Player
## Stage 4 player. Everything about a fighter now comes from a character config
## (see characters.gd): stats, six directional attacks, two powers, a shield type
## and an optional movement special. This script only runs that data.
## The body is drawn and animated by a StickFigure child (stick_figure.gd).

signal stock_lost(player: Player)
signal eliminated(player: Player)

const SHIELD_STANDARD := "standard"
const SHIELD_PARRY_ONLY := "parry_only"
const SHIELD_FREEZE := "freeze"
const SHIELD_ABSORB := "absorb"

@export_group("Match")
@export var max_stocks: int = 3
@export var respawn_delay: float = 1.0
@export var respawn_invuln: float = 1.5

@export_group("Physics")
@export var ground_accel: float = 2600.0
@export var air_accel: float = 1500.0
@export var ground_friction: float = 2400.0
@export var gravity: float = 1700.0
@export var max_fall_speed: float = 700.0
@export var fast_fall_speed: float = 1100.0
@export var coyote_time: float = 0.08

@export_group("Shield")
@export var shield_max: float = 100.0
@export var shield_drain: float = 26.0
@export var shield_regen: float = 18.0
@export var shield_regen_delay: float = 0.5
@export var shield_hit_cost: float = 18.0
@export var shield_damage_through: float = 0.25
@export var shield_break_stun: float = 1.6
@export var parry_window: float = 0.14
@export var parry_stagger: float = 0.45
@export var parry_cooldown: float = 0.35
@export var freeze_on_block_time: float = 0.8
@export var dodge_time: float = 0.22
@export var dodge_speed: float = 620.0

@export_group("Feel")
@export var parry_hitstop: float = 0.12

# --- character data (filled by set_character) ---
var character: Dictionary = {}
var char_index: int = 0
var char_name: String = "Timmy"
var body_color: Color = Color(0.95, 0.75, 0.2)
var move_speed: float = 320.0
var jump_velocity: float = -640.0
var air_jump_velocity: float = -580.0
var max_air_jumps: int = 1
var weight: float = 1.0
var shield_type: String = SHIELD_STANDARD

# --- match state ---
var player_id: int = 1
var spawn_point: Vector2 = Vector2.ZERO
var blast_zone: Rect2 = Rect2(-1000, -1000, 3000, 3000)
var damage_percent: float = 0.0
var stocks: int = 3
var is_eliminated: bool = false

# --- movement state ---
var facing: int = 1
var air_jumps_left: int = 0
var coyote_left: float = 0.0
var drop_through_left: float = 0.0
var fast_falling: bool = false

# --- combat state ---
var hitstun_left: float = 0.0
var invuln_left: float = 0.0
var respawn_left: float = 0.0
var frozen_left: float = 0.0
var rooted_left: float = 0.0
var dodge_left: float = 0.0
var web_boost_left: float = 0.0
var web_line_left: float = 0.0
var web_target: Vector2 = Vector2.ZERO
var last_hitter: Player = null

# --- move state machine ---
var move_state: String = "idle"  # idle, startup, active, recovery
var move_timer: float = 0.0
var current_move: Dictionary = {}
var current_slot: String = ""
var current_move_key: String = ""  # e.g. "heavy_up" or "power1", used to pick the animation
var move_hit_targets: Array = []
var cooldowns: Dictionary = {"power1": 0.0, "power2": 0.0, "special": 0.0}

# --- shield state ---
var shield_amount: float = 100.0
var is_blocking: bool = false
var block_held_time: float = 0.0
var shield_broken_left: float = 0.0
var regen_delay_left: float = 0.0
var parry_cooldown_left: float = 0.0
var parry_flash_left: float = 0.0
var stored_power: Dictionary = {}

var _size := Vector2(40, 80)
var hitstop_left: float = 0.0  # brief freeze on big impacts
var figure: StickFigure

# --- bot control ---
var is_bot: bool = false
var bot_level: int = 1  # 0 easy, 1 normal, 2 hard
var bot_memory: Dictionary = {}
var participating: bool = true
var stage_bounds: Rect2 = Rect2(290, 500, 700, 40)
var _bot_state: Dictionary = {}
var input_grace_left: float = 0.0  # ignore new presses briefly after a menu closes
var _bot_prev: Dictionary = {}


func _ready() -> void:
	# Players sit on layer 2 and collide only with platforms (layer 1), not each other.
	collision_layer = 2
	collision_mask = 1
	add_to_group("players")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _size
	shape.shape = rect
	add_child(shape)
	figure = StickFigure.new()
	figure.player = self
	figure.show_behind_parent = true  # shield bubble etc. draw on top of the body
	add_child(figure)
	if character.is_empty():
		set_character(0)
	air_jumps_left = max_air_jumps
	stocks = max_stocks
	shield_amount = shield_max


func set_character(index: int) -> void:
	char_index = index
	character = Characters.get_by_index(index)
	char_name = character.get("name", "Fighter")
	body_color = character.get("color", Color.WHITE)
	move_speed = character.get("move_speed", 320.0)
	jump_velocity = character.get("jump_velocity", -640.0)
	air_jump_velocity = character.get("air_jump_velocity", -580.0)
	max_air_jumps = character.get("max_air_jumps", 1)
	weight = character.get("weight", 1.0)
	shield_type = character.get("shield", SHIELD_STANDARD)
	# Reset anything the old character left behind.
	move_state = "idle"
	current_move = {}
	current_slot = ""
	cooldowns = {"power1": 0.0, "power2": 0.0, "special": 0.0}
	stored_power = {}
	is_blocking = false
	shield_amount = shield_max
	frozen_left = 0.0
	rooted_left = 0.0
	dodge_left = 0.0
	air_jumps_left = max_air_jumps
	if figure != null:
		figure.reset()
	queue_redraw()


func _p(action: String) -> String:
	return "p%d_%s" % [player_id, action]


# --- input: humans read the keyboard/gamepad, bots read what the brain decided ---
func _pressed(action: String) -> bool:
	if is_bot:
		return _bot_state.get(action, false)
	return Input.is_action_pressed(_p(action))


func _just_pressed(action: String) -> bool:
	if input_grace_left > 0.0:
		return false
	if is_bot:
		return _bot_state.get(action, false) and not _bot_prev.get(action, false)
	return Input.is_action_just_pressed(_p(action))


func _move_axis() -> float:
	if is_bot:
		var r := 1.0 if _bot_state.get("right", false) else 0.0
		var l := 1.0 if _bot_state.get("left", false) else 0.0
		return r - l
	return Input.get_axis(_p("left"), _p("right"))


func get_body_rect() -> Rect2:
	return Rect2(global_position - _size / 2.0, _size)


func can_be_hit() -> bool:
	return participating and not is_eliminated and respawn_left <= 0.0 and invuln_left <= 0.0 \
			and dodge_left <= 0.0


func is_attacking() -> bool:
	return move_state != "idle"


func is_action_locked() -> bool:
	## Cannot act at all.
	return hitstun_left > 0.0 or frozen_left > 0.0 or shield_broken_left > 0.0 or dodge_left > 0.0


func _in_parry_window() -> bool:
	return is_blocking and block_held_time <= parry_window


func cooldown_text(slot: String) -> String:
	var cd: float = cooldowns.get(slot, 0.0)
	return "ready" if cd <= 0.0 else "%.1fs" % cd


# ===========================================================================
# MAIN LOOP
# ===========================================================================
func _physics_process(delta: float) -> void:
	if is_eliminated or not participating:
		return

	if hitstop_left > 0.0:
		hitstop_left -= delta
		return

	if is_bot:
		_bot_prev = _bot_state.duplicate()
		_bot_state = Bot.think(self, delta)

	if respawn_left > 0.0:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_finish_respawn()
		return

	_tick_timers(delta)

	var locked := is_action_locked()
	var on_floor := is_on_floor()

	_update_shield(delta, locked)

	# Dodge / invisible dash takes over movement entirely.
	if dodge_left > 0.0:
		dodge_left -= delta
		velocity.x = facing * dodge_speed
		velocity.y = 0.0
		move_and_slide()
		queue_redraw()
		if not blast_zone.has_point(global_position):
			_lose_stock()
		return

	_process_move(delta)

	var busy := locked or is_blocking or is_attacking()
	var can_move := not busy and rooted_left <= 0.0

	# --- horizontal movement ---
	if can_move:
		var dir := _move_axis()
		if dir != 0.0:
			facing = 1 if dir > 0.0 else -1
			queue_redraw()
		var accel := ground_accel if on_floor else air_accel
		if dir != 0.0:
			velocity.x = move_toward(velocity.x, dir * move_speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta if on_floor else air_accel * 0.4 * delta)
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * 1.3 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 250.0 * delta)

	# --- floor bookkeeping ---
	if on_floor:
		air_jumps_left = max_air_jumps
		coyote_left = coyote_time
		fast_falling = false
	else:
		coyote_left = max(coyote_left - delta, 0.0)

	# --- drop through one-way platforms ---
	if drop_through_left > 0.0:
		drop_through_left -= delta
		if drop_through_left <= 0.0:
			set_collision_mask_value(1, true)
	if can_move and on_floor and _just_pressed("down") and _standing_on_one_way():
		set_collision_mask_value(1, false)
		drop_through_left = 0.2

	# --- jump ---
	if can_move and _just_pressed("jump"):
		if on_floor or coyote_left > 0.0:
			velocity.y = jump_velocity
			coyote_left = 0.0
		elif air_jumps_left > 0:
			velocity.y = air_jump_velocity
			air_jumps_left -= 1
			fast_falling = false

	# --- gravity ---
	if not on_floor and web_boost_left <= 0.0:
		velocity.y += gravity * delta
		if can_move and _just_pressed("down") and velocity.y > 0.0:
			fast_falling = true
		var cap := fast_fall_speed if fast_falling else max_fall_speed
		if not locked:
			velocity.y = min(velocity.y, cap)

	# --- attacks, powers, movement special ---
	if not locked and not is_blocking:
		_handle_action_input()

	move_and_slide()

	if not blast_zone.has_point(global_position):
		_lose_stock()
	queue_redraw()


func _tick_timers(delta: float) -> void:
	if invuln_left > 0.0:
		invuln_left -= delta
		modulate.a = 0.45 if int(invuln_left * 12.0) % 2 == 0 else 1.0
		if invuln_left <= 0.0:
			modulate.a = 1.0
	input_grace_left = max(input_grace_left - delta, 0.0)
	parry_cooldown_left = max(parry_cooldown_left - delta, 0.0)
	parry_flash_left = max(parry_flash_left - delta, 0.0)
	regen_delay_left = max(regen_delay_left - delta, 0.0)
	web_boost_left = max(web_boost_left - delta, 0.0)
	web_line_left = max(web_line_left - delta, 0.0)
	if hitstun_left > 0.0:
		hitstun_left -= delta
	if rooted_left > 0.0:
		rooted_left -= delta
		if rooted_left <= 0.0:
			queue_redraw()
	if frozen_left > 0.0:
		frozen_left -= delta
		if frozen_left <= 0.0:
			queue_redraw()
	if shield_broken_left > 0.0:
		shield_broken_left -= delta
		queue_redraw()
		if shield_broken_left <= 0.0:
			shield_amount = shield_max * 0.5
	for slot in cooldowns:
		if cooldowns[slot] > 0.0:
			cooldowns[slot] = max(cooldowns[slot] - delta, 0.0)


# ===========================================================================
# ACTIONS
# ===========================================================================
func _attack_direction() -> String:
	if _pressed("down"):
		return "down"
	if _pressed("jump"):
		return "up"
	return "side"


func _handle_action_input() -> void:
	if is_attacking():
		return
	if _just_pressed("light"):
		var key := "light_" + _attack_direction()
		_start_move(character.get(key, {}), "", true, key)
	elif _just_pressed("heavy"):
		var key := "heavy_" + _attack_direction()
		_start_move(character.get(key, {}), "", true, key)
	elif _just_pressed("power1"):
		_try_power("power1")
	elif _just_pressed("power2"):
		_try_power("power2")
	elif _just_pressed("special"):
		_try_movement_special()


func _try_power(slot: String) -> void:
	if cooldowns.get(slot, 0.0) > 0.0:
		return
	var m: Dictionary = character.get(slot, {})
	if m.is_empty():
		return
	_start_move(m, slot)


func _start_move(m: Dictionary, slot: String, apply_cooldown: bool = true, key: String = "") -> void:
	if m.is_empty():
		return
	current_move = m
	current_slot = slot
	if key != "" or slot != "":
		current_move_key = key if key != "" else slot
	move_state = "startup"
	move_timer = m.get("startup", 0.07)
	move_hit_targets.clear()
	if apply_cooldown and slot != "" and m.get("cooldown", 0.0) > 0.0:
		cooldowns[slot] = m.get("cooldown", 0.0)
	queue_redraw()


func _process_move(delta: float) -> void:
	if move_state == "idle":
		return
	move_timer -= delta
	match move_state:
		"startup":
			if move_timer <= 0.0:
				move_state = "active"
				move_timer = current_move.get("active", 0.08)
				if _activate_move():
					return
				if current_move.get("type", "melee") == "melee":
					_check_melee_hits()
		"active":
			if current_move.get("type", "melee") == "melee":
				_check_melee_hits()
			if move_timer <= 0.0:
				move_state = "recovery"
				move_timer = current_move.get("recovery", 0.16)
		"recovery":
			if move_timer <= 0.0:
				move_state = "idle"
				current_move = {}
				current_slot = ""
	queue_redraw()


func _activate_move() -> bool:
	## Runs the instant a move becomes active. Returns true if it replaced the
	## current move (Wham's copy, Jwong's release), so the caller stops processing.
	var kind = current_move.get("type", "melee")
	if kind == "projectile":
		_spawn_projectile(current_move)
	elif kind == "special":
		match current_move.get("action", ""):
			"teleport_swap":
				_do_teleport_swap()
			"copy_last":
				var copied := _get_copy_move()
				if not copied.is_empty():
					_start_move(copied, "", false)
					return true
			"absorb_release":
				if not stored_power.is_empty():
					var released: Dictionary = stored_power.duplicate(true)
					stored_power = {}
					_start_move(released, "", false)
					return true
	return false


func _spawn_projectile(m: Dictionary) -> void:
	var proj := Projectile.new()
	proj.setup(self, m, facing)
	get_parent().add_child(proj)
	# Leave from the throwing hand, but never from behind the body.
	var spawn := global_position + Vector2(facing * 46.0, -6.0)
	if figure != null:
		var hand := figure.hand_global()
		spawn = Vector2(global_position.x + facing * maxf((hand.x - global_position.x) * facing, 24.0), hand.y)
	proj.global_position = spawn


func _get_copy_move() -> Dictionary:
	## Wham's Mimic: use whoever last hit him, falling back to the nearest opponent.
	var source: Player = last_hitter
	if source == null or not is_instance_valid(source) or source == self:
		source = _nearest_opponent()
	if source == null:
		return {}
	var m: Dictionary = source.character.get("power1", {})
	if m.is_empty():
		return {}
	var copy: Dictionary = m.duplicate(true)
	copy["name"] = "Mimic: " + str(m.get("name", "power"))
	copy["cooldown"] = 0.0
	return copy


func _do_teleport_swap() -> void:
	var other := _nearest_opponent()
	if other == null:
		return
	var mine := global_position
	global_position = other.global_position
	other.global_position = mine
	velocity = Vector2.ZERO
	other.velocity = Vector2.ZERO
	facing = -1 if other.global_position.x > global_position.x else 1
	queue_redraw()


func _nearest_opponent() -> Player:
	var best: Player = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("players"):
		var other := node as Player
		if other == null or other == self or other.is_eliminated or not other.participating:
			continue
		var d := global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best


func _try_movement_special() -> void:
	if cooldowns.get("special", 0.0) > 0.0:
		return
	match character.get("special_move", ""):
		"web_swing":
			_do_web_swing()
		"invisible_dash":
			_do_invisible_dash()


func _do_web_swing() -> void:
	var best: Node2D = null
	var best_d := 420.0
	for node in get_tree().get_nodes_in_group("anchors"):
		var a := node as Node2D
		if a == null:
			continue
		if a.global_position.y >= global_position.y - 24.0:
			continue
		var d := global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best == null:
		return
	web_target = best.global_position
	web_line_left = 0.25
	web_boost_left = 0.22
	velocity = (web_target - global_position).normalized() * 980.0
	fast_falling = false
	cooldowns["special"] = character.get("special_cooldown", 1.2)
	queue_redraw()


func _do_invisible_dash() -> void:
	dodge_left = 0.24
	velocity.x = facing * 900.0
	velocity.y = 0.0
	cooldowns["special"] = character.get("special_cooldown", 1.6)
	queue_redraw()


func _check_melee_hits() -> void:
	var offset: Vector2 = current_move.get("offset", Vector2(52, 0))
	var size: Vector2 = current_move.get("size", Vector2(60, 44))
	var center := global_position + Vector2(offset.x * facing, offset.y)
	var box := Rect2(center - size / 2.0, size)
	var angle: Vector2 = current_move.get("angle", Vector2(1.0, -0.5))
	for node in get_tree().get_nodes_in_group("players"):
		var other := node as Player
		if other == null or other == self or other in move_hit_targets:
			continue
		if not other.can_be_hit():
			continue
		if not box.intersects(other.get_body_rect()):
			continue
		move_hit_targets.append(other)
		other.take_hit(self, {
			"damage": current_move.get("damage", 8.0),
			"kb_base": current_move.get("kb_base", 300.0),
			"kb_growth": current_move.get("kb_growth", 7.0),
			"direction": Vector2(angle.x * facing, angle.y).normalized(),
			"status": current_move.get("status", ""),
			"status_time": current_move.get("status_time", 0.0),
			"is_power": current_slot.begins_with("power"),
			"move": current_move,
		})


# ===========================================================================
# SHIELD
# ===========================================================================
func _update_shield(delta: float, locked: bool) -> void:
	if shield_type == SHIELD_PARRY_ONLY:
		if not locked and shield_broken_left <= 0.0 and not is_attacking() \
				and parry_cooldown_left <= 0.0 and _just_pressed("block"):
			is_blocking = true
			block_held_time = 0.0
			parry_cooldown_left = parry_cooldown
		if is_blocking:
			block_held_time += delta
			if block_held_time > parry_window:
				is_blocking = false
			queue_redraw()
		return

	var want_block := _pressed("block") and not locked \
			and shield_broken_left <= 0.0 and not is_attacking()

	if want_block and shield_amount > 0.0:
		if not is_blocking:
			is_blocking = true
			block_held_time = 0.0
		else:
			block_held_time += delta
		shield_amount -= shield_drain * delta
		if shield_amount <= 0.0:
			_break_shield()
		queue_redraw()
	else:
		if is_blocking:
			is_blocking = false
			regen_delay_left = shield_regen_delay
			queue_redraw()
		if regen_delay_left <= 0.0 and shield_broken_left <= 0.0 and shield_amount < shield_max:
			shield_amount = min(shield_amount + shield_regen * delta, shield_max)


func _break_shield() -> void:
	shield_amount = 0.0
	is_blocking = false
	shield_broken_left = shield_break_stun
	velocity.x = 0.0
	queue_redraw()


# ===========================================================================
# TAKING HITS
# ===========================================================================
func take_hit(attacker: Player, hit: Dictionary) -> void:
	if attacker != null and attacker != self:
		last_hitter = attacker

	var direction: Vector2 = hit.get("direction", Vector2(1, -0.5))
	if is_blocking:
		var from_front: bool = signf(direction.x) == float(-facing) or is_zero_approx(direction.x)
		if from_front:
			if _in_parry_window():
				_on_parry(attacker)
				return
			if shield_type != SHIELD_PARRY_ONLY:
				_on_blocked_hit(attacker, hit)
				return

	_apply_hit(hit)

	# Impact: sparks at the contact point and a short freeze that sells the hit.
	var dmg := float(hit.get("damage", 8.0))
	var contact := global_position + Vector2(-signf(direction.x) * 14.0, -8.0)
	var col: Color = attacker.body_color if attacker != null else Color.WHITE
	Effects.hit_burst(get_parent(), contact, direction, col, (dmg - 4.0) / 14.0)
	var stop := 0.03 + dmg * 0.003
	hitstop_left = stop
	if attacker != null and attacker != self and not hit.get("is_power", false):
		attacker.hitstop_left = maxf(attacker.hitstop_left, stop)


func _on_parry(attacker: Player) -> void:
	parry_flash_left = 0.2
	# Sparks fly from the clash point back toward the attacker; both fighters freeze.
	var away := Vector2(-facing, -0.6)
	var clash := global_position + Vector2(facing * 22.0, -14.0)
	if attacker != null:
		away = (attacker.global_position - global_position).normalized() + Vector2(0, -0.6)
		clash = global_position.lerp(attacker.global_position, 0.35) + Vector2(0, -14.0)
		attacker.hitstop_left = maxf(attacker.hitstop_left, parry_hitstop)
	hitstop_left = parry_hitstop
	var tint := Color(1.0, 0.85, 0.35)
	if shield_type == SHIELD_FREEZE:
		tint = Color(0.55, 0.9, 1.0)
	elif shield_type == SHIELD_ABSORB:
		tint = Color(0.6, 1.0, 0.7)
	elif shield_type == SHIELD_PARRY_ONLY:
		tint = body_color.lightened(0.3)
	Effects.parry_burst(get_parent(), clash, away, tint)
	if shield_type == SHIELD_PARRY_ONLY:
		# Sway: the parry becomes a short invisible dash away from the attacker.
		dodge_left = dodge_time
		if attacker != null:
			facing = -1 if attacker.global_position.x > global_position.x else 1
		is_blocking = false
	else:
		shield_amount = min(shield_amount + 15.0, shield_max)
	if attacker != null:
		attacker.apply_stagger(parry_stagger)
	queue_redraw()


func _on_blocked_hit(attacker: Player, hit: Dictionary) -> void:
	# Jwong: absorb an incoming power and keep it for later.
	if shield_type == SHIELD_ABSORB and hit.get("is_power", false) and stored_power.is_empty():
		var m = hit.get("move", {})
		if m is Dictionary and not m.is_empty():
			stored_power = m.duplicate(true)
			stored_power["cooldown"] = 0.0
			Effects.absorb_swirl(get_parent(), global_position + Vector2(facing * 14.0, -10.0),
					stored_power.get("color", Color(0.6, 1.0, 0.7)))
			queue_redraw()
			return

	shield_amount -= shield_hit_cost
	damage_percent += float(hit.get("damage", 8.0)) * shield_damage_through
	var spark_col := Color(0.55, 0.9, 1.0) if shield_type == SHIELD_FREEZE else Color(0.5, 0.8, 1.0)
	Effects.block_burst(get_parent(), global_position + Vector2(facing * 26.0, -8.0),
			Vector2(facing, -0.4), spark_col)
	velocity.x = 0.0
	if shield_type == SHIELD_FREEZE and attacker != null:
		attacker.apply_freeze(freeze_on_block_time)
	if shield_amount <= 0.0:
		_break_shield()
	queue_redraw()


func _apply_hit(hit: Dictionary) -> void:
	damage_percent += float(hit.get("damage", 8.0))
	var kb: float = (float(hit.get("kb_base", 300.0)) + damage_percent * float(hit.get("kb_growth", 7.0))) * weight
	var direction: Vector2 = hit.get("direction", Vector2(1, -0.5))
	velocity = direction * kb
	hitstun_left = clamp(kb / 2200.0, 0.12, 0.6)
	if figure != null:
		figure.on_hit(velocity)
	fast_falling = false
	is_blocking = false
	web_boost_left = 0.0
	move_state = "idle"
	current_move = {}
	current_slot = ""
	set_collision_mask_value(1, true)
	drop_through_left = 0.0

	var status: String = str(hit.get("status", ""))
	var status_time: float = float(hit.get("status_time", 0.0))
	if status == "freeze":
		apply_freeze(status_time)
	elif status == "root":
		rooted_left = max(rooted_left, status_time)
	queue_redraw()


func apply_stagger(duration: float) -> void:
	hitstun_left = max(hitstun_left, duration)
	move_state = "idle"
	current_move = {}
	current_slot = ""
	velocity.x = 0.0
	queue_redraw()


func apply_freeze(duration: float) -> void:
	frozen_left = max(frozen_left, duration)
	move_state = "idle"
	current_move = {}
	current_slot = ""
	is_blocking = false
	velocity.x = 0.0
	queue_redraw()


# ===========================================================================
# STOCKS
# ===========================================================================
func _standing_on_one_way() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var collider := c.get_collider()
		if collider and collider.has_meta("one_way") and collider.get_meta("one_way"):
			return true
	return false


func _lose_stock() -> void:
	stocks -= 1
	damage_percent = 0.0
	velocity = Vector2.ZERO
	hitstun_left = 0.0
	frozen_left = 0.0
	rooted_left = 0.0
	shield_broken_left = 0.0
	dodge_left = 0.0
	web_boost_left = 0.0
	hitstop_left = 0.0
	move_state = "idle"
	current_move = {}
	current_slot = ""
	is_blocking = false
	shield_amount = shield_max
	global_position = spawn_point
	visible = false
	collision_layer = 0
	set_collision_mask_value(1, true)
	drop_through_left = 0.0
	stock_lost.emit(self)
	if stocks <= 0:
		is_eliminated = true
		eliminated.emit(self)
	else:
		respawn_left = respawn_delay


func _finish_respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	visible = true
	collision_layer = 2
	air_jumps_left = max_air_jumps
	fast_falling = false
	invuln_left = respawn_invuln
	queue_redraw()


# ===========================================================================
# DRAWING
# ===========================================================================
func _draw() -> void:
	## The body itself is the StickFigure child; this only draws overlays on top.
	var half := _size / 2.0

	# Shield bubble.
	if is_blocking and shield_amount > 0.0:
		var frac := shield_amount / shield_max
		var radius := 34.0 + 20.0 * frac
		var bubble := Color(0.4, 0.8, 1.0, 0.3)
		if _in_parry_window():
			bubble = Color(1.0, 0.95, 0.5, 0.55)
		elif shield_type == SHIELD_FREEZE:
			bubble = Color(0.5, 0.9, 1.0, 0.35)
		elif shield_type == SHIELD_ABSORB:
			bubble = Color(0.6, 1.0, 0.75, 0.35)
		draw_circle(Vector2.ZERO, radius, bubble)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(bubble, 0.8), 2.0, true)

	# Stored power marker (Jwong).
	if not stored_power.is_empty():
		var bob := sin(Time.get_ticks_msec() * 0.006) * 3.0
		var c := Vector2(0, -half.y - 30 + bob)
		var sc: Color = stored_power.get("color", Color.WHITE)
		draw_circle(c, 12.0, Color(sc, 0.25))
		draw_circle(c, 7.0, sc)

	# Shield-break stars.
	if shield_broken_left > 0.0:
		for i in 3:
			var a := float(i) / 3.0 * TAU + shield_broken_left * 6.0
			draw_circle(Vector2(cos(a), sin(a)) * 26.0 + Vector2(0, -half.y - 14.0), 5.0, Color(1, 0.9, 0.3))
