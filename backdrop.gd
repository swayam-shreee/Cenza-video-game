extends Node2D
class_name ParallaxBackdrop
## Base for themed stage backdrops (air_temple.gd, neon_district.gd).
##
## Art is authored as if seen by an unzoomed camera centered on CENTER, then drawn
## in layers. Call layer(d) before drawing each one: d = 0 is infinitely far away
## (fixed to the screen, e.g. the sky), d = 1 is the stage itself (moves fully with
## the camera). Layers in between drift and zoom less than the stage, which gives
## the parallax depth as the camera follows the fighters.

const VIEW := Vector2(1280, 720)
const CENTER := Vector2(640, 360)

var stage: Dictionary = {}
var t: float = 0.0
var cam_pos: Vector2 = CENTER
var cam_zoom: float = 1.0


func _ready() -> void:
	z_index = -50


func _process(delta: float) -> void:
	t += delta
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam_pos = cam.get_screen_center_position()
		cam_zoom = cam.zoom.x
	queue_redraw()


func layer(d: float) -> void:
	## Everything drawn after this call sits at depth d.
	var s := 1.0 + (1.0 / cam_zoom - 1.0) * (1.0 - d)
	var origin := CENTER - CENTER * s + (cam_pos - CENTER) * (1.0 - d)
	draw_set_transform(origin, 0.0, Vector2(s, s))


func gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))


static func ridge(seed_value: int, x0: float, x1: float, base_y: float, amp: float, steps: int = 7) -> PackedVector2Array:
	## A natural-looking ridgeline by midpoint displacement. Same seed, same ridge.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ys: Array = [base_y + rng.randf_range(-amp, amp) * 0.5, base_y + rng.randf_range(-amp, amp) * 0.5]
	var spread := amp
	for i in steps:
		var next: Array = []
		for k in ys.size() - 1:
			next.append(ys[k])
			next.append((ys[k] + ys[k + 1]) * 0.5 + rng.randf_range(-spread, spread))
		next.append(ys[ys.size() - 1])
		ys = next
		spread *= 0.55
	var pts := PackedVector2Array()
	for k in ys.size():
		pts.append(Vector2(lerpf(x0, x1, float(k) / (ys.size() - 1)), ys[k]))
	return pts


static func filled_below(line: PackedVector2Array, bottom: float) -> PackedVector2Array:
	var poly := line.duplicate()
	poly.append(Vector2(line[line.size() - 1].x, bottom))
	poly.append(Vector2(line[0].x, bottom))
	return poly


static func ellipse(c: Vector2, r: Vector2, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := float(i) / n * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
