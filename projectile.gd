extends Node2D
class_name Projectile
## A flying hitbox spawned by a projectile move. Hits route through the target's
## take_hit, so blocking, parrying, freezing and absorbing all still apply.
## Projectiles pass through platforms for now.
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


func get_rect() -> Rect2:
	return Rect2(global_position - box_size / 2.0, box_size)


func _draw() -> void:
	draw_rect(Rect2(-box_size / 2.0, box_size), color)
	draw_rect(Rect2(-box_size / 2.0, box_size), Color(1, 1, 1, 0.5), false, 2.0)


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
