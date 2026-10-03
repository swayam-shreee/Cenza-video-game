extends Node2D
class_name Projectile
## A flying hitbox spawned by a projectile move. Hits route through the target's
## take_hit, so blocking, parrying, freezing and absorbing all still apply.
## Projectiles pass through platforms for now.
## How one looks comes from the move's "look" field (fireball, net, knife, ice,
## disc, orb); anything else draws as a plain box.
##
## The shooter and targets are deliberately untyped so this script does not
## reference Player while Player references Projectile (a cycle Godot dislikes).

var shooter = null
var data: Dictionary = {}
var velocity: Vector2 = Vector2.ZERO
var life_left: float = 1.5
var box_size: Vector2 = Vector2(24, 24)
var color: Color = Color.WHITE
var facing: int = 1

var returning: bool = false
var travelled: float = 0.0
var max_travel: float = 400.0
var is_coming_back: bool = false

var look: String = ""
var spin: float = 0.0
var age: float = 0.0
var trail: Array = []  # recent global positions, newest last


func setup(p_shooter, p_data: Dictionary, p_facing: int) -> void:
	shooter = p_shooter
	data = p_data
	facing = p_facing
	box_size = p_data.get("proj_size", Vector2(24, 24))
	color = p_data.get("color", Color.WHITE)
	life_left = p_data.get("life", 1.5)
	returning = p_data.get("returns", false)
	max_travel = p_data.get("max_travel", 400.0)
	velocity = Vector2(float(p_data.get("speed", 500.0)) * p_facing, 0.0)
	look = str(p_data.get("look", ""))


func get_rect() -> Rect2:
	return Rect2(global_position - box_size / 2.0, box_size)


func _draw() -> void:
	var r := minf(box_size.x, box_size.y) * 0.5
	var heading := velocity.angle() if velocity.length() > 1.0 else (0.0 if facing > 0 else PI)
	match look:
		"fireball":
			_draw_trail(r * 0.9, Color(1.0, 0.45, 0.1))
			var flick := 1.0 + sin(age * 40.0) * 0.08
			draw_circle(Vector2.ZERO, r * 1.5 * flick, Color(1.0, 0.5, 0.1, 0.25))
			draw_circle(Vector2.ZERO, r * flick, color)
			draw_circle(Vector2(2, -1), r * 0.62, Color(1.0, 0.85, 0.3))
			draw_circle(Vector2(3, -2), r * 0.3, Color(1, 1, 0.9))
		"net":
			var R := r * 1.05
			draw_circle(Vector2.ZERO, R, Color(color, 0.18))
			for k in 3:
				var a := spin + k * PI / 3.0
				var d := Vector2.from_angle(a) * R
				draw_line(-d, d, Color(color, 0.85), 2.0, true)
			draw_arc(Vector2.ZERO, R, 0.0, TAU, 24, Color(0.9, 0.8, 1.0), 2.0, true)
			draw_arc(Vector2.ZERO, R * 0.55, 0.0, TAU, 16, Color(color, 0.8), 1.5, true)
			# Crackle: a jagged bolt that changes every frame.
			var pts := PackedVector2Array()
			for k in 6:
				var a := float(k) / 5.0 * TAU
				pts.append(Vector2.from_angle(a) * R * randf_range(0.7, 1.25))
			draw_polyline(pts, Color(1, 1, 1, 0.8), 1.4, true)
		"knife":
			_draw_trail(2.5, Color(0.85, 0.9, 1.0))
			var d := Vector2.from_angle(heading)
			var n := d.orthogonal()
			var blade := PackedVector2Array([d * 14.0, n * 3.5, -d * 4.0, -n * 3.5])
			draw_colored_polygon(blade, color)
			draw_line(-d * 4.0, -d * 12.0, Color(0.3, 0.22, 0.32), 3.0, true)
		"ice":
			_draw_trail(r * 0.5, Color(0.7, 0.95, 1.0))
			var shard := PackedVector2Array()
			for k in 6:
				var a := spin + float(k) / 6.0 * TAU
				shard.append(Vector2.from_angle(a) * r * (1.15 if k % 2 == 0 else 0.6))
			draw_colored_polygon(shard, Color(color, 0.85))
			shard.append(shard[0])
			draw_polyline(shard, Color(1, 1, 1, 0.9), 1.6, true)
		"disc":
			_draw_trail(r * 0.7, color)
			draw_circle(Vector2.ZERO, r + 1.5, Color(0.1, 0.08, 0.1))
			draw_circle(Vector2.ZERO, r, color)
			draw_arc(Vector2.ZERO, r * 0.65, 0.0, TAU, 20, Color(1, 0.85, 0.6), 2.0, true)
			for k in 4:
				var d := Vector2.from_angle(spin + k * PI * 0.5) * r * 0.9
				draw_line(Vector2.ZERO, d, Color(0.55, 0.15, 0.15), 2.0, true)
			draw_circle(Vector2.ZERO, r * 0.22, Color(0.95, 0.85, 0.5))
		"orb":
			_draw_trail(r * 0.6, color)
			var pulse := 1.0 + sin(age * 9.0) * 0.12
			draw_circle(Vector2.ZERO, r * 1.6 * pulse, Color(color, 0.15))
			draw_circle(Vector2.ZERO, r * 1.15 * pulse, Color(color, 0.35))
			draw_circle(Vector2.ZERO, r * 0.8, color)
			draw_circle(Vector2(-r * 0.2, -r * 0.2), r * 0.35, Color(1, 1, 1, 0.85))
		_:
			draw_rect(Rect2(-box_size / 2.0, box_size), color)
			draw_rect(Rect2(-box_size / 2.0, box_size), Color(1, 1, 1, 0.5), false, 2.0)


func _draw_trail(radius: float, col: Color) -> void:
	var n := trail.size()
	for k in n:
		var f := float(k + 1) / float(n + 1)
		draw_circle(to_local(trail[k]), radius * f, Color(col, 0.45 * f))


func _physics_process(delta: float) -> void:
	var g: float = data.get("proj_gravity", 0.0)
	if g != 0.0:
		velocity.y += g * delta

	var step := velocity * delta
	global_position += step
	travelled += step.length()

	# Returning projectiles (Ando's shield throw) fly out, then home back.
	if returning:
		if not is_coming_back and travelled >= max_travel:
			is_coming_back = true
		if is_coming_back:
			if shooter == null or not is_instance_valid(shooter):
				queue_free()
				return
			var to_owner: Vector2 = shooter.global_position - global_position
			if to_owner.length() < 40.0:
				queue_free()
				return
			velocity = to_owner.normalized() * float(data.get("speed", 500.0))

	age += delta
	spin += delta * (16.0 if look == "disc" else 5.0)
	trail.append(global_position)
	if trail.size() > 7:
		trail.pop_front()

	life_left -= delta
	if life_left <= 0.0:
		queue_free()
		return

	if _check_hits():
		return
	queue_redraw()


func _check_hits() -> bool:
	var box := get_rect()
	for other in get_tree().get_nodes_in_group("players"):
		if other == shooter or not is_instance_valid(other):
			continue
		if not other.can_be_hit():
			continue
		if not box.intersects(other.get_body_rect()):
			continue
		var dir_x := 1.0 if velocity.x >= 0.0 else -1.0
		var angle: Vector2 = data.get("angle", Vector2(1.0, -0.45))
		other.take_hit(shooter, {
			"damage": data.get("damage", 8.0),
			"kb_base": data.get("kb_base", 300.0),
			"kb_growth": data.get("kb_growth", 7.0),
			"direction": Vector2(angle.x * dir_x, angle.y).normalized(),
			"status": data.get("status", ""),
			"status_time": data.get("status_time", 0.0),
			"is_power": true,
			"move": data,
		})
		queue_free()
		return true
	return false
