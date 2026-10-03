extends Node2D
class_name StickFigure
## Draws a fighter as a bendy stick figure and animates it procedurally.
## Purely visual: it reads the Player's state every frame and never changes gameplay.
##
## HOW IT MOVES
##   Every frame we build a target pose: where the hip, chest, head, hands and feet
##   want to be for what the fighter is doing. Each joint then chases its target on
##   a spring, and is shoved by the body's own acceleration (inertia).
##   In neutral (standing, running, jumping) the springs are stiff and well damped,
##   so the fighter stays upright and follows input instantly. Actions and hits
##   loosen them: big wind-ups, wobbly follow-throughs, and a floppy ragdoll
##   tumble when launched. That is where the comedy is.
##   Elbows and knees come from two-bone IK. The spine only curves when the body
##   is actually leaning, i.e. during actions and hits.
##
## Attacks aim the hand (and weapon) at the move's real hitbox, so what you see
## swing is what actually hits.
##
## All pose math is in "facing space": +x is the way the fighter faces. It is only
## mirrored when drawing.

const FOOT_Y := 40.0  # bottom of the 40x80 collision box
const UPPER_ARM := 17.0
const FOREARM := 17.0
const THIGH := 21.0
const SHIN := 21.0
const TORSO := 26.0
const NECK := 11.0
const HEAD_R := 8.0
const ARM_REACH := UPPER_ARM + FOREARM - 0.5
const LEG_REACH := THIGH + SHIN - 0.5

const JOINTS := ["hip", "chest", "head", "hand_a", "hand_b", "foot_a", "foot_b"]
# hand_a / foot_a are the front limbs (the weapon hand); _b are the back ones.
const STIFF := {"hip": 1.4, "chest": 1.2, "head": 1.0, "hand_a": 0.9, "hand_b": 0.9,
		"foot_a": 1.6, "foot_b": 1.6}
const INERTIA := {"hip": 0.03, "chest": 0.06, "head": 0.1, "hand_a": 0.14, "hand_b": 0.14,
		"foot_a": 0.05, "foot_b": 0.05}
const BASE_K := 1100.0
const NEUTRAL_ZETA := 0.85  # well damped: upright and snappy
const ACTION_ZETA := 0.4    # bouncy: wind-ups and follow-throughs overshoot
const HIT_ZETA := 0.2       # floppy ragdoll
const WOBBLE_TIME := 0.4    # springy recovery after being knocked around
const MAX_K := 3000.0
const LEASH := 18.0
const AIR_SPIN_TIME := 0.38
const TWO_HANDED := ["staff", "scythe", "hammer"]
const OUTLINE := Color(0.05, 0.05, 0.07, 0.55)

var player = null  # untyped: Player owns this node, so avoid a type cycle

var pos := {}
var vel := {}
var tilt := 0.0  # whole-body rotation, facing space (+ = lean forward)
var tilt_vel := 0.0
var weapon_ang := -1.3
var weapon_vel := 0.0

var t := 0.0
var run_phase := 0.0
var squash := 0.0
var spin_left := 0.0
var takeoff_left := 0.0
var wobble_left := 0.0
var tumble_spin := 0.0
var was_on_floor := true
var prev_body_vel := Vector2.ZERO
var was_visible := true

var trail: Array = []   # weapon tip history: {"p": Vector2 facing space, "age": float}
var ghosts: Array = []  # dash afterimages: {"g": Vector2 global, "lines": Array, "head": Vector2, "age": float}
var ghost_timer := 0.0
var chain_tip := Vector2.ZERO
var chain_amt := 0.0
var cast_glow := 0.0
var cast_color := Color.WHITE

# per-frame outputs of the pose builder
var _kmul := {}
var _zeta := NEUTRAL_ZETA
var _tilt_target := 0.0
var _tilt_free := false
var _wang_target := -1.3
var _wang_k := 1.0


func _ready() -> void:
	reset()


func reset() -> void:
	var rest := _rest()
	for j in JOINTS:
		pos[j] = rest[j]
		vel[j] = Vector2.ZERO
	tilt = 0.0
	tilt_vel = 0.0
	weapon_ang = _weapon_rest_angle()
	weapon_vel = 0.0
	squash = 0.0
	spin_left = 0.0
	takeoff_left = 0.0
	wobble_left = 0.0
	tumble_spin = 0.0
	trail.clear()
	ghosts.clear()
	chain_amt = 0.0
	cast_glow = 0.0
	prev_body_vel = Vector2.ZERO
	queue_redraw()


func weapon() -> String:
	return str(player.character.get("weapon", "")) if player != null else ""


# ===========================================================================
# PUBLIC HOOKS (called by Player)
# ===========================================================================
func on_hit(knockback: Vector2) -> void:
	## Called the instant the fighter is launched. Limbs get flung; strong hits
	## send them cartwheeling.
	var kb := Vector2(knockback.x * player.facing, knockback.y)
	for j in JOINTS:
		vel[j] += kb * (0.5 if j in ["head", "hand_a", "hand_b"] else 0.2)
	if kb.length() > 600.0:
		var s := signf(kb.x) if absf(kb.x) > 1.0 else -1.0
		tumble_spin = s * clampf(kb.length() / 1300.0, 0.5, 1.2) * 14.0
	else:
		tumble_spin = 0.0


func hand_global() -> Vector2:
	## World position of the weapon hand, for spawning projectiles.
	return player.global_position + _L(pos["hand_a"])


# ===========================================================================
# SIMULATION
# ===========================================================================
func _physics_process(delta: float) -> void:
	if player == null:
		return
	t += delta
	if not player.visible:
		was_visible = false
		return
	if not was_visible:
		was_visible = true
		reset()
	_age_effects(delta)
	# Frozen fighters hold their pose like a statue; hitstop freezes everything.
	if player.frozen_left > 0.0 or player.hitstop_left > 0.0:
		queue_redraw()
		return

	var on_floor: bool = player.is_on_floor()
	var bv := Vector2(player.velocity.x * player.facing, player.velocity.y)
	_detect_events(on_floor, bv)

	var tp := _target_pose(delta, on_floor, bv)
	_simulate(tp, delta, on_floor, bv)
	_record_effects(delta)

	prev_body_vel = bv
	was_on_floor = on_floor
	queue_redraw()


func _detect_events(on_floor: bool, bv: Vector2) -> void:
	var feet: Vector2 = player.global_position + Vector2(0, FOOT_Y)
	if on_floor and not was_on_floor:
		# Landing: a quick knee bend that snaps back upright.
		squash = clampf(prev_body_vel.y / 900.0, 0.2, 0.8)
		spin_left = 0.0
		if prev_body_vel.y > 350.0:
			Effects.dust(player.get_parent(), feet, prev_body_vel.y / 700.0)
	elif was_on_floor and not on_floor and bv.y < -300.0:
		takeoff_left = 0.12
		Effects.dust(player.get_parent(), feet, 0.6)
	elif not on_floor and bv.y < -400.0 and bv.y - prev_body_vel.y < -250.0 and player.hitstun_left <= 0.0 \
			and player.web_boost_left <= 0.0 and player.dodge_left <= 0.0:
		# Air jump: tuck and flip.
		spin_left = AIR_SPIN_TIME
		Effects.dust(player.get_parent(), feet, 0.4)


func _simulate(tp: Dictionary, delta: float, on_floor: bool, bv: Vector2) -> void:
	var dv := (bv - prev_body_vel).limit_length(2200.0)
	for j in JOINTS:
		var k: float = minf(BASE_K * STIFF[j] * _kmul.get(j, 1.0), MAX_K)
		var c := 2.0 * sqrt(k) * _zeta
		var v: Vector2 = vel[j]
		v -= dv * INERTIA[j]
		v += ((tp[j] - pos[j]) * k - v * c) * delta
		var p: Vector2 = pos[j] + v * delta
		var off: Vector2 = p - tp[j]
		if off.length() > LEASH:
			p = tp[j] + off.limit_length(LEASH)
		pos[j] = p
		vel[j] = v

	# Bones keep their length; hands and feet can't out-reach their limbs.
	pos["chest"] = pos["hip"] + _dir(pos["chest"] - pos["hip"], Vector2.UP) * TORSO
	pos["head"] = pos["chest"] + _dir(pos["head"] - pos["chest"], Vector2.UP) * NECK
	for h in ["hand_a", "hand_b"]:
		pos[h] = pos["chest"] + (pos[h] - pos["chest"]).limit_length(ARM_REACH)
	for f in ["foot_a", "foot_b"]:
		pos[f] = pos["hip"] + (pos[f] - pos["hip"]).limit_length(LEG_REACH)
		if on_floor and player.hitstun_left <= 0.0 and pos[f].y > FOOT_Y:
			pos[f].y = FOOT_Y

	# Whole-body rotation.
	if spin_left > 0.0:
		spin_left = maxf(spin_left - delta, 0.0)
		tilt = (1.0 - spin_left / AIR_SPIN_TIME) * TAU
		if spin_left <= 0.0:
			tilt = 0.0
		tilt_vel = 0.0
	elif _tilt_free:
		tilt += tumble_spin * delta
		tilt_vel = tumble_spin
	else:
		var tk := 260.0
		tilt_vel += (angle_difference(tilt, _tilt_target) * tk - tilt_vel * 2.0 * sqrt(tk) * 0.6) * delta
		tilt = wrapf(tilt + tilt_vel * delta, -PI, PI)

	# Weapon angle chases its own target.
	var wk := 900.0 * _wang_k
	weapon_vel += (angle_difference(weapon_ang, _wang_target) * wk
			- weapon_vel * 2.0 * sqrt(wk) * 0.6) * delta
	weapon_ang = wrapf(weapon_ang + weapon_vel * delta, -PI, PI)


# ===========================================================================
# POSES
# ===========================================================================
func _rest() -> Dictionary:
	## Standing tall: straight legs, straight back, arms hanging at the sides.
	var hip_y := FOOT_Y - (THIGH + SHIN) + 0.8
	return {
		"hip": Vector2(0, hip_y), "chest": Vector2(0, hip_y - TORSO), "head": Vector2(0, hip_y - TORSO - NECK),
		"hand_a": Vector2(4, hip_y - TORSO + UPPER_ARM + FOREARM - 1.5),
		"hand_b": Vector2(-3, hip_y - TORSO + UPPER_ARM + FOREARM - 1.5),
		"foot_a": Vector2(4, FOOT_Y), "foot_b": Vector2(-4, FOOT_Y),
	}


func _weapon_rest_angle() -> float:
	match weapon():
		"staff", "scythe":
			return -PI * 0.5  # upright beside the body
		"hammer":
			return 1.39  # hanging, head resting on the ground
		"blades":
			return 1.45  # pointing down along the legs
	return 0.0


func _target_pose(delta: float, on_floor: bool, bv: Vector2) -> Dictionary:
	_kmul = {}
	_zeta = NEUTRAL_ZETA
	_tilt_target = 0.0
	_tilt_free = false
	_wang_target = _weapon_rest_angle()
	_wang_k = 1.0
	squash = move_toward(squash, 0.0, delta * 7.0)
	takeoff_left = maxf(takeoff_left - delta, 0.0)
	wobble_left = maxf(wobble_left - delta, 0.0)

	var tp := _locomotion(delta, on_floor, bv)

	if player.hitstun_left > 0.0:
		_ragdoll(tp, bv)
		wobble_left = WOBBLE_TIME
		return tp
	tumble_spin = 0.0

	var acting := true
	if player.shield_broken_left > 0.0:
		_dizzy(tp)
	elif player.dodge_left > 0.0:
		_dash(tp)
	elif player.web_line_left > 0.0 or player.web_boost_left > 0.0:
		_web_swing(tp)
	elif player.move_state != "idle" and not player.current_move.is_empty():
		_attack(tp, on_floor)
	elif player.is_blocking:
		_block(tp)
	else:
		acting = false

	if player.parry_flash_left > 0.0:
		_deflect(tp)
		acting = true

	if acting:
		_zeta = ACTION_ZETA
	if wobble_left > 0.0:
		# Just recovered from a hit: spring back upright with a comic wobble.
		_zeta = minf(_zeta, 0.25)

	# Two-handed weapons: the back hand grips further down the shaft while acting.
	if acting and weapon() in TWO_HANDED and player.dodge_left <= 0.0 and player.shield_broken_left <= 0.0:
		tp["hand_b"] = tp["hand_a"] - Vector2.from_angle(weapon_ang) * 13.0
		_kmul["hand_b"] = _kmul.get("hand_a", 1.0) * 1.5
	return tp


func _locomotion(delta: float, on_floor: bool, bv: Vector2) -> Dictionary:
	## Standing, running and jumping. The body stays upright throughout; only the
	## legs move, plus a short knee bend on takeoff and landing.
	var tp := _rest()
	if on_floor:
		var speed_frac := clampf(absf(bv.x) / maxf(player.move_speed, 1.0), 0.0, 1.3)
		# Phase advances with distance travelled, so planted feet never slide.
		run_phase = fmod(run_phase + absf(bv.x) * delta / 13.0, TAU)
		var blend := clampf(speed_frac * 3.0, 0.0, 1.0)
		var s := sin(run_phase)
		var c := cos(run_phase)
		var drop := 2.5 * blend  # hips sit a touch lower so the stride can reach
		for j in ["hip", "chest", "head"]:
			tp[j].y += drop
		tp["foot_a"] = tp["foot_a"].lerp(Vector2(13.0 * s, FOOT_Y - maxf(0.0, c) * 9.0), blend)
		tp["foot_b"] = tp["foot_b"].lerp(Vector2(-13.0 * s, FOOT_Y - maxf(0.0, -c) * 9.0), blend)
		tp["hand_a"].x += -7.0 * s * blend
		tp["hand_b"].x += 7.0 * s * blend
		# The faintest breath when standing still.
		var breath := sin(t * 2.0) * 0.4 * (1.0 - blend)
		tp["chest"].y += breath
		tp["head"].y += breath
		# Landing: hips drop and the knees take it, then straight back up.
		var land := 7.0 * squash
		for j in ["hip", "chest", "head", "hand_a", "hand_b"]:
			tp[j].y += land
		return tp

	# --- airborne: upright, legs straight and slightly apart ---
	tp["foot_a"] = Vector2(6, FOOT_Y - 0.5)
	tp["foot_b"] = Vector2(-5, FOOT_Y - 0.5)
	tp["hand_a"] += Vector2(3, -2)
	tp["hand_b"] += Vector2(-3, -2)
	if takeoff_left > 0.0:
		# Spring off the ground: knees snap up and straighten again.
		var k := sin(PI * (1.0 - takeoff_left / 0.12))
		tp["foot_a"] += Vector2(3, -14) * k
		tp["foot_b"] += Vector2(1, -12) * k
	if spin_left > 0.0:
		# Tucked ball for the air-jump flip.
		tp["hip"] = Vector2(0, -2)
		tp["chest"] = Vector2(5, -27)
		tp["head"] = Vector2(9, -37)
		tp["foot_a"] = Vector2(8, 18)
		tp["foot_b"] = Vector2(-1, 21)
		tp["hand_a"] = Vector2(13, -6)
		tp["hand_b"] = Vector2(5, -3)
	return tp


func _ragdoll(tp: Dictionary, bv: Vector2) -> void:
	## Hitstun: soft springs, limbs trail behind the flight path with the arms
	## flailing, and big hits cartwheel the whole body.
	for j in JOINTS:
		_kmul[j] = 0.15
	_kmul["head"] = 0.1  # the head lolls around the most
	_zeta = HIT_ZETA
	_wang_k = 0.3
	var speed := bv.length()
	if speed > 180.0:
		var u := bv / speed
		var perp := u.orthogonal()
		var flail := Vector2.from_angle(t * 19.0) * 9.0
		tp["hand_a"] = tp["chest"] - u * 22.0 + perp * 13.0 + flail
		tp["hand_b"] = tp["chest"] - u * 22.0 - perp * 13.0 - flail
		tp["foot_a"] = tp["hip"] - u * 26.0 + perp * 11.0 + flail * 0.5
		tp["foot_b"] = tp["hip"] - u * 26.0 - perp * 11.0 - flail * 0.5
		tp["head"] = tp["chest"] + Vector2(-5, -10)
		if absf(tumble_spin) > 0.0:
			_tilt_free = true
		else:
			_tilt_target = clampf(bv.x * 0.0011, -0.8, 0.8)
	else:
		# Stagger (e.g. after being parried): stumble back, arms windmilling.
		tp["chest"] += Vector2(-10, 2)
		tp["head"] += Vector2(-15, 4)
		tp["hand_a"] = tp["chest"] + Vector2.from_angle(t * 16.0) * 26.0
		tp["hand_b"] = tp["chest"] + Vector2.from_angle(t * 16.0 + PI) * 24.0
		tp["foot_a"] += Vector2(4, -6.0 * maxf(sin(t * 16.0), 0.0))
		tp["foot_b"] += Vector2(-9, 0)
		_tilt_target = -0.28


func _dizzy(tp: Dictionary) -> void:
	_kmul = {"hand_a": 0.5, "hand_b": 0.5, "head": 0.6}
	var w := sin(t * 5.0)
	tp["hip"] += Vector2(0, 6)
	tp["chest"] = tp["hip"] + Vector2(w * 7.0, -TORSO)
	tp["head"] = tp["chest"] + Vector2(sin(t * 5.0 + 0.6) * 5.0, -NECK)
	tp["hand_a"] = tp["chest"] + Vector2(6, 26)
	tp["hand_b"] = tp["chest"] + Vector2(-5, 27)
	_wang_target = 1.4


func _dash(tp: Dictionary) -> void:
	tp["hip"] = Vector2(-2, 7)
	tp["chest"] = Vector2(13, -17)
	tp["head"] = Vector2(20, -26)
	tp["hand_a"] = Vector2(-12, -10)
	tp["hand_b"] = Vector2(-22, -14)
	tp["foot_a"] = Vector2(15, 37)
	tp["foot_b"] = Vector2(-17, 38)
	_wang_target = PI - 0.3


func _web_swing(tp: Dictionary) -> void:
	var anchor: Vector2 = player.to_local(player.web_target)
	var a := Vector2(anchor.x * player.facing, anchor.y)
	tp["hand_a"] = tp["chest"] + (a - tp["chest"]).limit_length(ARM_REACH)
	_kmul["hand_a"] = 3.0
	tp["hand_b"] = tp["chest"] + Vector2(-16, 6)
	tp["foot_a"] = tp["hip"] + Vector2(-6, 36)
	tp["foot_b"] = tp["hip"] + Vector2(-14, 32)
	_tilt_target = 0.25


func _block(tp: Dictionary) -> void:
	tp["hip"] += Vector2(0, 5)
	tp["chest"] += Vector2(-2, 4)
	tp["head"] += Vector2(-1, 5)
	tp["foot_a"] = Vector2(11, FOOT_Y)
	tp["foot_b"] = Vector2(-12, FOOT_Y)
	match weapon():
		"shield":
			tp["hand_a"] = Vector2(15, -16)
			tp["hand_b"] = Vector2(4, -10)
		"blades":
			tp["hand_a"] = Vector2(14, -22)
			tp["hand_b"] = Vector2(12, -14)
			_wang_target = -1.2
		_:
			tp["hand_a"] = Vector2(14, -17)
			tp["hand_b"] = Vector2(10, -10)
			_wang_target = -1.45
	_kmul["hand_a"] = 2.5


func _deflect(tp: Dictionary) -> void:
	## Just parried: a sharp flick of the weapon arm up and out.
	var f: float = player.parry_flash_left / 0.2
	tp["hand_a"] = tp["chest"] + Vector2(24, -16 - 10.0 * f).limit_length(ARM_REACH)
	tp["chest"] += Vector2(-4, 0)
	tp["head"] += Vector2(-6, 0)
	_kmul["hand_a"] = 4.0
	_wang_target = -0.9
	_wang_k = 3.0


# ---------------------------------------------------------------------------
# ATTACKS
# ---------------------------------------------------------------------------
func _phase_progress() -> float:
	var m: Dictionary = player.current_move
	var dur: float = float(m.get(player.move_state, 0.1))
	return 1.0 - clampf(player.move_timer / maxf(dur, 0.001), 0.0, 1.0)


func _attack(tp: Dictionary, on_floor: bool) -> void:
	var m: Dictionary = player.current_move
	match str(m.get("type", "melee")):
		"projectile":
			_cast(tp, m, on_floor)
		"special":
			_special(tp, m)
		_:
			_melee(tp, m, on_floor)


func _melee(tp: Dictionary, m: Dictionary, on_floor: bool) -> void:
	var key: String = player.current_move_key
	var heavy := key.begins_with("heavy") or key.begins_with("power")
	var dir := "side"
	if key.ends_with("_up"):
		dir = "up"
	elif key.ends_with("_down"):
		dir = "down"
	var offset: Vector2 = m.get("offset", Vector2(52, 0))
	var size: Vector2 = m.get("size", Vector2(60, 44))
	var S: Vector2 = tp["chest"]
	var hit := offset
	var chain := offset.x > 90.0

	# Wind-up position and which way round the swing travels (+1 = over the top).
	var wind := Vector2(-10, -20)
	var turn := 1.0
	match dir:
		"side":
			wind = Vector2(-24, -32) if heavy else Vector2(-10, -22)
		"up":
			wind = Vector2(-8, 16) if heavy else Vector2(-6, 12)
			turn = -1.0
		"down":
			if heavy:
				wind = Vector2(-6, -52)
			else:
				wind = Vector2(-20, 14)
				turn = -1.0
	if chain:
		wind = Vector2(-14, -10)

	var ang_hit := (hit - S).angle()
	var follow := S + Vector2.from_angle(ang_hit + turn * 0.9) * 30.0
	var p := _phase_progress()
	var lean := 2.0 if heavy else 1.0
	match player.move_state:
		"startup":
			var e := _ease_out(p)
			tp["hand_a"] = tp["hand_a"].lerp(wind, e)
			tp["chest"] += Vector2(-5.0 * lean, 1.0) * e
			tp["head"] += Vector2(-6.0 * lean, 1.0) * e
			tp["hand_b"] = tp["hand_b"].lerp(Vector2(14, -14), e)
			_kmul["hand_a"] = 2.0
			_wang_target = (wind - S).angle() - turn * 0.5
			_wang_k = 2.0
		"active":
			var e := _ease_out(clampf(p * 1.5, 0.0, 1.0))
			tp["hand_a"] = _arc(S, wind, hit, e, turn)
			tp["chest"] += Vector2(7.0 * lean, 1.0)
			tp["head"] += Vector2(9.0 * lean, 2.0)
			tp["hand_b"] = Vector2(-14, -12)
			_kmul["hand_a"] = 4.0
			_wang_target = (tp["hand_a"] - S).angle() + turn * 0.35
			_wang_k = 4.0
			_step_in(tp, on_floor, heavy, dir, chain)
		"recovery":
			var swing := _arc(S, hit, follow, minf(p * 2.5, 1.0), turn)
			var settle := clampf((p - 0.4) / 0.6, 0.0, 1.0)
			tp["hand_a"] = swing.lerp(tp["hand_a"], settle)
			tp["chest"] += Vector2(5.0 * lean, 1.0) * (1.0 - settle)
			tp["head"] += Vector2(6.0 * lean, 2.0) * (1.0 - settle)
			_kmul["hand_a"] = 2.0
			if settle < 0.5:
				_wang_target = (swing - S).angle() + turn * 0.35
				_wang_k = 2.0
			_step_in(tp, on_floor, heavy, dir, chain, 1.0 - settle)

	# Sway's Chained Sword: a chain shoots from the hand to the far end of the hitbox.
	if chain:
		chain_tip = Vector2(offset.x + size.x * 0.5 - 8.0, offset.y)
		match player.move_state:
			"startup":
				chain_amt = 0.0
			"active":
				chain_amt = _ease_out(clampf(p * 2.0, 0.0, 1.0))
			"recovery":
				chain_amt = 1.0 - _ease_out(p)
	else:
		chain_amt = 0.0


func _step_in(tp: Dictionary, on_floor: bool, heavy: bool, dir: String, chain: bool, amt: float = 1.0) -> void:
	if not on_floor:
		return
	if dir == "down":
		# Crouch into low attacks; slam harder on heavies.
		var drop := (11.0 if heavy else 7.0) * amt
		tp["hip"].y += drop
		tp["chest"].y += drop * 0.9
		tp["head"].y += drop * 0.9
		tp["foot_a"].x += 4.0 * amt
		tp["foot_b"].x -= 4.0 * amt
	elif dir == "up" and heavy:
		tp["hip"].y -= 4.0 * amt
		tp["chest"].y -= 4.0 * amt
		tp["head"].y -= 4.0 * amt
	if heavy or chain:
		var step := (16.0 if chain else 11.0) * amt
		tp["foot_a"].x += step
		tp["hip"].x += step * 0.4
		tp["chest"].x += step * 0.4
		tp["head"].x += step * 0.4


func _cast(tp: Dictionary, m: Dictionary, on_floor: bool) -> void:
	var look := str(m.get("look", ""))
	var p := _phase_progress()
	cast_color = m.get("color", Color.WHITE)
	var throw := look in ["knife", "disc"]
	match player.move_state:
		"startup":
			var e := _ease_out(p)
			if throw:
				tp["hand_a"] = tp["hand_a"].lerp(Vector2(-16, -36), e)
				tp["hand_b"] = tp["hand_b"].lerp(Vector2(16, -18), e)
				tp["chest"] += Vector2(-6, 1) * e
				tp["head"] += Vector2(-7, 1) * e
				_wang_target = -2.4
			else:
				# Gather energy between the hands.
				tp["hand_a"] = tp["hand_a"].lerp(Vector2(-3, -16), e)
				tp["hand_b"] = tp["hand_b"].lerp(Vector2(-6, -11), e)
				tp["chest"] += Vector2(-4, 2) * e
				tp["head"] += Vector2(-4, 2) * e
				cast_glow = e
				_wang_target = 2.0
			_kmul["hand_a"] = 2.5
			_kmul["hand_b"] = 2.5
		_:
			var settle := clampf((p - 0.5) / 0.5, 0.0, 1.0) if player.move_state == "recovery" else 0.0
			var push_a := Vector2(31, -12)
			var push_b := Vector2(-14, -8) if throw else Vector2(27, -6)
			tp["hand_a"] = push_a.lerp(tp["hand_a"], settle)
			tp["hand_b"] = push_b.lerp(tp["hand_b"], settle)
			tp["chest"] += Vector2(6, 1) * (1.0 - settle)
			tp["head"] += Vector2(8, 1) * (1.0 - settle)
			_kmul["hand_a"] = 4.0
			_kmul["hand_b"] = 3.0
			_wang_target = 0.2 if throw else 1.9
			cast_glow = 0.0
			if on_floor:
				tp["foot_a"].x += 9.0 * (1.0 - settle)


func _special(tp: Dictionary, m: Dictionary) -> void:
	var p := _phase_progress()
	var startup: bool = player.move_state == "startup"
	match str(m.get("action", "")):
		"teleport_swap":
			if startup:
				tp["hand_a"] = Vector2(3, -53)
				tp["hand_b"] = Vector2(-2, -52)
				tp["chest"] += Vector2(0, -2)
				cast_glow = p
				cast_color = Color(1.0, 0.55, 0.55)
			else:
				tp["hand_a"] = Vector2(28, -22)
				tp["hand_b"] = Vector2(-26, -22)
				cast_glow = 0.0
		"absorb_release":
			if startup:
				tp["hand_a"] = Vector2(-4, -14)
				tp["chest"] += Vector2(-4, 1)
			else:
				tp["hand_a"] = Vector2(32, -12)
				tp["chest"] += Vector2(5, 1)
		_:
			# Mimic and anything else: palms forward, shimmering.
			tp["hand_a"] = Vector2(20, -20)
			tp["hand_b"] = Vector2(16, -12)
			cast_glow = 0.6 + 0.4 * sin(t * 30.0)
			cast_color = player.body_color
	_kmul["hand_a"] = 2.5
	_kmul["hand_b"] = 2.5


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func _arc(center: Vector2, from: Vector2, to: Vector2, f: float, turn: float) -> Vector2:
	## Point along a swing from `from` to `to` around `center`, travelling the
	## `turn` way round (+1 clockwise on screen when facing right).
	var a0 := (from - center).angle()
	var d := angle_difference(a0, (to - center).angle())
	if signf(d) != signf(turn) and not is_zero_approx(d):
		d += turn * TAU
	var r := lerpf((from - center).length(), minf((to - center).length(), ARM_REACH), f)
	return center + Vector2.from_angle(a0 + d * f) * r


static func _dir(v: Vector2, fallback: Vector2) -> Vector2:
	return v.normalized() if v.length() > 0.001 else fallback


# ===========================================================================
# EFFECT BOOKKEEPING
# ===========================================================================
func _age_effects(delta: float) -> void:
	for tr in trail:
		tr["age"] += delta
	trail = trail.filter(func(e): return e["age"] < 0.14)
	for g in ghosts:
		g["age"] += delta
	ghosts = ghosts.filter(func(e): return e["age"] < 0.28)
	if player.move_state == "idle":
		cast_glow = move_toward(cast_glow, 0.0, delta * 6.0)
		chain_amt = 0.0


func _record_effects(delta: float) -> void:
	# Swoosh: weapon tip trail while a melee move swings.
	var m: Dictionary = player.current_move
	var swinging: bool = str(m.get("type", "")) == "melee" and (player.move_state == "active"
			or (player.move_state == "recovery" and _phase_progress() < 0.35))
	if swinging:
		trail.append({"p": _weapon_tip(), "age": 0.0})
	# Afterimages while dashing.
	if player.dodge_left > 0.0:
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.035
			ghosts.append({"g": player.global_position, "lines": _skeleton_lines(),
					"head": _L(pos["head"]), "age": 0.0})


# ===========================================================================
# DRAWING
# ===========================================================================
func _L(p: Vector2) -> Vector2:
	## Facing space -> this node's local space.
	var f: float = player.facing
	return Vector2(p.x * f, p.y).rotated(tilt * f)


static func _ik(root: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var to := target - root
	var d := clampf(to.length(), 0.001, l1 + l2 - 0.001)
	var dir := _dir(to, Vector2.DOWN)
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	return root + dir * x + dir.orthogonal() * h * bend


func _curve(a: Vector2, m: Vector2, b: Vector2, n: int = 10) -> PackedVector2Array:
	## Smooth bend through the middle joint (quadratic Bezier that passes through m).
	var c := 2.0 * m - (a + b) * 0.5
	var pts := PackedVector2Array()
	for i in n + 1:
		var s := float(i) / n
		pts.append(_L(a.lerp(c, s).lerp(c.lerp(b, s), s)))
	return pts


func _skeleton_lines() -> Array:
	## Local-space polylines, back to front: back arm, back leg, front leg, spine, neck, front arm.
	## Limbs are two straight bones; the spine only curves when the body leans.
	var hip: Vector2 = pos["hip"]
	var chest: Vector2 = pos["chest"]
	var head: Vector2 = pos["head"]
	var elbow_a := _ik(chest, pos["hand_a"], UPPER_ARM, FOREARM, -1.0)
	var elbow_b := _ik(chest, pos["hand_b"], UPPER_ARM, FOREARM, -1.0)
	var knee_a := _ik(hip, pos["foot_a"], THIGH, SHIN, 1.0)
	var knee_b := _ik(hip, pos["foot_b"], THIGH, SHIN, 1.0)
	var spine_dir := _dir(chest - hip, Vector2.UP)
	var bend := clampf((chest.x - hip.x) * 0.25, -5.0, 5.0)
	var spine_mid := (hip + chest) * 0.5 + spine_dir.orthogonal() * bend
	var neck_end := chest + _dir(head - chest, Vector2.UP) * (NECK - HEAD_R * 0.7)
	return [
		_bones(chest, elbow_b, pos["hand_b"]),
		_bones(hip, knee_b, pos["foot_b"]),
		_bones(hip, knee_a, pos["foot_a"]),
		_curve(hip, spine_mid, chest, 6),
		PackedVector2Array([_L(chest), _L(neck_end)]),
		_bones(chest, elbow_a, pos["hand_a"]),
	]


func _bones(a: Vector2, m: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([_L(a), _L(m), _L(b)])


func _line_width() -> float:
	return clampf(4.0 + (1.0 - float(player.weight)) * 5.0, 3.5, 5.2)


func _weapon_tip() -> Vector2:
	var d := Vector2.from_angle(weapon_ang)
	var h: Vector2 = pos["hand_a"]
	match weapon():
		"staff":
			return h + d * 46.0
		"scythe":
			return h + d * 50.0
		"hammer":
			return h + d * 36.0
		"blades":
			return h + d * 22.0
	return h + d * 10.0


func _draw() -> void:
	if player == null:
		return
	var col: Color = player.body_color
	if player.frozen_left > 0.0:
		col = col.lerp(Color(0.6, 0.88, 1.0), 0.6)
	elif player.shield_broken_left > 0.0:
		col = col.lerp(Color(0.6, 0.6, 0.6), 0.5)
	var alpha := 0.3 if player.dodge_left > 0.0 else 1.0
	col.a = alpha
	var back := col.darkened(0.35)
	var rim := Color(OUTLINE, OUTLINE.a * alpha)
	var w := _line_width()

	# Afterimages.
	for g in ghosts:
		var off: Vector2 = g["g"] - player.global_position
		var ga: float = 0.3 * (1.0 - g["age"] / 0.28)
		var gc := Color(player.body_color, ga)
		for line in g["lines"]:
			var moved := PackedVector2Array()
			for pt in line:
				moved.append(pt + off)
			draw_polyline(moved, gc, w, true)
		draw_circle(g["head"] + off, HEAD_R, gc)

	# Web line from the hand.
	if player.web_line_left > 0.0:
		draw_line(_L(pos["hand_a"]), to_local(player.web_target), Color(1, 1, 1, 0.75), 1.5, true)

	var lines := _skeleton_lines()
	var limb_cols := [back, back, col, col, col, col]
	for i in lines.size():
		if i == 5:
			_draw_back_weapon(w)  # Sway's off-hand blade sits behind the front arm
		var line: PackedVector2Array = lines[i]
		draw_polyline(line, rim, w + 1.5, true)
		draw_polyline(line, limb_cols[i], w, true)
		# Rounded joints and ends.
		for pt in line:
			draw_circle(pt, w * 0.5, limb_cols[i])
		if i == 4:
			_draw_head(col, rim)

	_draw_weapon(w, alpha)
	_draw_trail()
	_draw_chain()
	_draw_cast_glow()
	_draw_status(col)
	_draw_tag()


func _draw_head(col: Color, rim: Color) -> void:
	var c := _L(pos["head"])
	draw_circle(c, HEAD_R + 0.75, rim)
	draw_circle(c, HEAD_R, col)


func _draw_weapon(_w: float, alpha: float) -> void:
	var h: Vector2 = pos["hand_a"]
	var d := Vector2.from_angle(weapon_ang)
	var n := d.orthogonal()
	var dark := Color(0.05, 0.05, 0.07, 0.6 * alpha)
	var steel := Color(0.74, 0.77, 0.81, alpha)
	match weapon():
		"staff":
			_stick(h - d * 24.0, h + d * 46.0, Color(0.42, 0.31, 0.21, alpha), 3.0, dark)
			_stick(h + d * 42.0, h + d * 46.0, Color(0.55, 0.55, 0.58, alpha), 3.4, dark)
			_stick(h - d * 24.0, h - d * 20.0, Color(0.55, 0.55, 0.58, alpha), 3.4, dark)
		"scythe":
			_stick(h - d * 18.0, h + d * 50.0, Color(0.20, 0.18, 0.20, alpha), 2.6, dark)
			var tip := h + d * 50.0
			var blade := PackedVector2Array()
			for i in 9:
				var s := float(i) / 8.0
				blade.append(_L(tip - n * (32.0 * s) - d * (14.0 * s * s) + d * (5.0 * sin(s * PI))))
			draw_polyline(blade, dark, 4.5, true)
			draw_polyline(blade, steel, 2.8, true)
		"hammer":
			_stick(h - d * 8.0, h + d * 36.0, Color(0.36, 0.25, 0.17, alpha), 3.0, dark)
			var c := h + d * 36.0
			var head := PackedVector2Array([
				_L(c + n * 12.0 + d * 7.0), _L(c - n * 12.0 + d * 7.0),
				_L(c - n * 12.0 - d * 7.0), _L(c + n * 12.0 - d * 7.0),
			])
			draw_colored_polygon(head, Color(0.33, 0.34, 0.38, alpha))
			head.append(head[0])
			draw_polyline(head, dark, 1.2, true)
		"blades":
			_blade(h, d, alpha, dark)
		"shield":
			var c := _L(h + d * 3.0)
			draw_circle(c, 14.8, dark)
			draw_circle(c, 14.0, Color(0.40, 0.47, 0.44, alpha))
			draw_arc(c, 13.0, 0.0, TAU, 28, Color(0.62, 0.66, 0.64, alpha), 1.6, true)
			draw_circle(c, 3.0, Color(0.62, 0.66, 0.64, alpha))


func _draw_back_weapon(_w: float) -> void:
	if weapon() != "blades":
		return
	var alpha := 0.3 if player.dodge_left > 0.0 else 1.0
	var h: Vector2 = pos["hand_b"]
	var d := _dir(pos["hand_b"] - pos["chest"], Vector2.RIGHT).rotated(-0.6)
	_blade(h, d, alpha, Color(0.05, 0.05, 0.07, 0.6 * alpha))


func _blade(h: Vector2, d: Vector2, alpha: float, dark: Color) -> void:
	_stick(h - d * 5.0, h, Color(0.18, 0.16, 0.20, alpha), 3.0, dark)
	_stick(h, h + d * 22.0, Color(0.80, 0.83, 0.88, alpha), 2.0, dark)


func _stick(a: Vector2, b: Vector2, col: Color, width: float, dark: Color) -> void:
	draw_line(_L(a), _L(b), dark, width + 1.2, true)
	draw_line(_L(a), _L(b), col, width, true)


func _draw_trail() -> void:
	## A thin, faint motion streak behind the weapon tip.
	if trail.size() < 2:
		return
	for i in range(1, trail.size()):
		var a: Dictionary = trail[i - 1]
		var b: Dictionary = trail[i]
		var life: float = 1.0 - b["age"] / 0.14
		draw_line(_L(a["p"]), _L(b["p"]), Color(player.body_color, 0.12 * life), 5.0 * life + 1.0, true)
		draw_line(_L(a["p"]), _L(b["p"]), Color(1, 1, 1, 0.35 * life), 1.5 * life + 0.5, true)


func _draw_chain() -> void:
	if chain_amt <= 0.01:
		return
	var h: Vector2 = pos["hand_a"]
	var tip := h.lerp(chain_tip, chain_amt)
	var links := int(h.distance_to(tip) / 9.0)
	for i in links + 1:
		var p := h.lerp(tip, float(i) / maxf(links, 1))
		draw_arc(_L(p), 3.2, 0.0, TAU, 8, Color(0.75, 0.78, 0.85), 1.6, true)
	_blade(tip - Vector2(4, 0), Vector2.RIGHT, 1.0, Color(0.05, 0.05, 0.07, 0.6))


func _draw_cast_glow() -> void:
	if cast_glow <= 0.01:
		return
	var c := _L((pos["hand_a"] + pos["hand_b"]) * 0.5)
	var r := 4.0 + 10.0 * cast_glow
	draw_circle(c, r * 1.8, Color(cast_color, 0.2 * cast_glow))
	draw_circle(c, r, Color(cast_color, 0.75 * cast_glow))
	draw_circle(c, r * 0.45, Color(1, 1, 1, 0.9 * cast_glow))


func _draw_status(_col: Color) -> void:
	if player.rooted_left > 0.0:
		for f in ["foot_a", "foot_b"]:
			var p := _L(pos[f])
			draw_arc(p, 8.0, 0.0, TAU, 16, Color(0.7, 0.5, 1.0, 0.9), 3.0, true)
			draw_arc(p + Vector2(0, -4), 6.0, 0.0, TAU, 16, Color(0.85, 0.7, 1.0, 0.6), 2.0, true)
	if player.frozen_left > 0.0:
		var r := Rect2(-25, -50, 50, 94)
		draw_rect(r, Color(0.65, 0.9, 1.0, 0.32))
		draw_rect(r, Color(0.9, 0.97, 1.0, 0.7), false, 2.0)
		draw_line(Vector2(-18, -40), Vector2(-8, -22), Color(1, 1, 1, 0.7), 2.0)
		draw_line(Vector2(10, 18), Vector2(18, 32), Color(1, 1, 1, 0.5), 2.0)


func _draw_tag() -> void:
	var head := _L(pos["head"])
	var text := "P%d" % player.player_id
	if player.is_bot:
		text += " CPU"
	var font := ThemeDB.fallback_font
	var at := Vector2(head.x - 40.0, head.y - HEAD_R - 8.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 10, 3, Color(0.03, 0.03, 0.05, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 10, player.body_color.lightened(0.25))


