extends Node2D
class_name Effects
## Short-lived visual effects: parry sparks, hit bursts, dust puffs, absorb swirls.
## Each helper spawns one Effects node into the arena; it frees itself once its
## particles are gone. Purely visual, nothing here touches gameplay.

const SPARK_GRAVITY := 1100.0

var parts: Array = []


static func _spawn(parent: Node) -> Effects:
	var fx := Effects.new()
	fx.z_index = 20
	parent.add_child(fx)
	return fx


static func shake(parent: Node, amount: float) -> void:
	if parent != null and parent.has_method("shake"):
		parent.shake(amount)


# ===========================================================================
# PRESETS
# ===========================================================================
static func parry_burst(parent: Node, at: Vector2, away: Vector2, tint: Color) -> void:
	## The big one: white flash, double shockwave ring and a fountain of sparks
	## spraying back toward the attacker.
	if parent == null:
		return
	var fx := _spawn(parent)
	var p: Vector2 = parent.to_local(at)
	var dir := away.normalized() if away.length() > 0.01 else Vector2.UP
	fx._flash(p, 40.0, Color(1, 1, 1, 0.95), 0.12)
	fx._ring(p, 10.0, 100.0, Color(1, 1, 1, 0.95), 0.3, 7.0)
	fx._ring(p, 6.0, 64.0, tint, 0.24, 4.0)
	for i in 30:
		var a := dir.angle() + randf_range(-1.1, 1.1)
		fx._spark(p, Vector2.from_angle(a) * randf_range(380.0, 950.0), tint,
				randf_range(0.35, 0.65), randf_range(2.2, 3.4))
	for i in 12:
		fx._spark(p, Vector2.from_angle(randf() * TAU) * randf_range(180.0, 480.0), tint,
				randf_range(0.25, 0.45), 1.8)
	shake(parent, 9.0)


static func hit_burst(parent: Node, at: Vector2, dir: Vector2, color: Color, strength: float) -> void:
	## Smaller impact for normal hits, scaled by damage (strength 0..1).
	if parent == null:
		return
	var fx := _spawn(parent)
	var p: Vector2 = parent.to_local(at)
	var s := clampf(strength, 0.0, 1.0)
	fx._ring(p, 6.0, 28.0 + 30.0 * s, Color(1, 1, 1, 0.85), 0.18, 3.0 + 3.0 * s)
	for i in int(6 + 8 * s):
		var a := dir.angle() + randf_range(-0.8, 0.8)
		fx._spark(p, Vector2.from_angle(a) * randf_range(260.0, 520.0 + 300.0 * s),
				color.lightened(0.3), randf_range(0.18, 0.35), 2.0)
	if s > 0.6:
		shake(parent, 3.0 + 4.0 * s)


static func block_burst(parent: Node, at: Vector2, dir: Vector2, color: Color) -> void:
	## A hit landing on a shield: a few cool sparks and a ripple.
	if parent == null:
		return
	var fx := _spawn(parent)
	var p: Vector2 = parent.to_local(at)
	fx._ring(p, 10.0, 38.0, Color(color, 0.8), 0.18, 3.0)
	for i in 7:
		var a := dir.angle() + randf_range(-1.0, 1.0)
		fx._spark(p, Vector2.from_angle(a) * randf_range(200.0, 420.0), color, 0.25, 1.8)


static func absorb_swirl(parent: Node, at: Vector2, color: Color) -> void:
	## Jwong soaking up a power: motes spiral inward.
	if parent == null:
		return
	var fx := _spawn(parent)
	var p: Vector2 = parent.to_local(at)
	fx._ring(p, 70.0, 14.0, Color(color, 0.8), 0.3, 3.0)
	for i in 18:
		fx.parts.append({"kind": "orbit", "c": p, "a": randf() * TAU, "r0": randf_range(40.0, 70.0),
				"spin": randf_range(8.0, 12.0), "life": 0.0, "max": randf_range(0.3, 0.45),
				"color": color, "size": randf_range(2.0, 3.5)})
	shake(parent, 4.0)


static func dust(parent: Node, at: Vector2, amount: float) -> void:
	## Puffs kicked up from the ground on jumps and landings.
	if parent == null:
		return
	var fx := _spawn(parent)
	fx.z_index = 4
	var p: Vector2 = parent.to_local(at)
	var n := int(clampf(3.0 + amount * 4.0, 3.0, 8.0))
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		fx.parts.append({"kind": "dust", "p": p + Vector2(side * randf_range(2.0, 10.0), -2.0),
				"v": Vector2(side * randf_range(50.0, 140.0) * (0.6 + amount), randf_range(-40.0, -10.0)),
				"life": 0.0, "max": randf_range(0.3, 0.5), "color": Color(0.95, 0.93, 0.9),
				"size": randf_range(4.0, 7.0) * (0.7 + amount * 0.5)})


# ===========================================================================
# PARTICLE BUILDERS
# ===========================================================================
func _spark(p: Vector2, v: Vector2, tint: Color, life: float, size: float) -> void:
	parts.append({"kind": "spark", "p": p, "v": v, "life": 0.0, "max": life, "color": tint, "size": size})


func _ring(p: Vector2, r0: float, r1: float, color: Color, life: float, width: float) -> void:
	parts.append({"kind": "ring", "p": p, "r0": r0, "r1": r1, "life": 0.0, "max": life,
			"color": color, "size": width})


func _flash(p: Vector2, r: float, color: Color, life: float) -> void:
	parts.append({"kind": "flash", "p": p, "r0": r, "life": 0.0, "max": life, "color": color})


# ===========================================================================
# UPDATE / DRAW
# ===========================================================================
func _process(delta: float) -> void:
	for e in parts:
		e["life"] += delta
		match e["kind"]:
			"spark":
				e["v"].y += SPARK_GRAVITY * delta
				e["v"] *= 1.0 - 1.8 * delta
				e["p"] += e["v"] * delta
			"dust":
				e["v"] *= 1.0 - 3.0 * delta
				e["p"] += e["v"] * delta
			"orbit":
				e["a"] += e["spin"] * delta
	parts = parts.filter(func(e): return e["life"] < e["max"])
	if parts.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for e in parts:
		var f: float = e["life"] / e["max"]
		var col: Color = e["color"]
		match e["kind"]:
			"spark":
				# White-hot, cooling to the tint, then to ember orange.
				var c := Color.WHITE.lerp(col, clampf(f * 2.0, 0.0, 1.0)).lerp(
						Color(1.0, 0.35, 0.1), clampf(f * 2.0 - 1.0, 0.0, 1.0))
				c.a = 1.0 - f * f
				var v: Vector2 = e["v"]
				var tail: Vector2 = e["p"] - v.normalized() * maxf(v.length() * 0.035, 4.0)
				var w: float = e["size"] * (1.0 - f) + 0.8
				draw_line(e["p"], tail, Color(c, c.a * 0.25), w * 2.6, true)
				draw_line(e["p"], tail, c, w, true)
			"ring":
				var r := lerpf(e["r0"], e["r1"], 1.0 - pow(1.0 - f, 3.0))
				draw_arc(e["p"], r, 0.0, TAU, 40, Color(col, col.a * (1.0 - f)),
						e["size"] * (1.0 - f) + 1.0, true)
			"flash":
				draw_circle(e["p"], e["r0"] * (1.0 + f * 0.6), Color(col, col.a * (1.0 - f)))
			"dust":
				draw_circle(e["p"], e["size"] * (0.6 + f), Color(col, 0.5 * (1.0 - f)))
			"orbit":
				var r: float = e["r0"] * (1.0 - f)
				var p: Vector2 = e["c"] + Vector2.from_angle(e["a"]) * r
				draw_circle(p, e["size"], Color(col, 1.0 - f * 0.5))
