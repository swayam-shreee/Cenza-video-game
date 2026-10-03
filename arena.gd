extends Node2D
class_name Arena
## Runs one match. Built entirely from a stage entry (stages.gd) and a list of
## player slots, so it knows nothing about menus. game.gd creates it, fills in
## stage_index and the slot arrays, then adds it to the tree.

signal match_over(result_text: String)

const VIEW := Vector2(1280, 720)
# Camera framing: space kept around the fighters (left, top, right, bottom).
const CAM_MARGIN := [260.0, 220.0, 260.0, 160.0]

var stage_index: int = 0
var active_count: int = 2
var slot_is_bot := [false, true, true, true]
var slot_char := [0, 3, 2, 4]
var slot_level := [1, 1, 1, 1]

var stage: Dictionary = {}
var players: Array[Player] = []
var name_labels: Dictionary = {}
var power_labels: Dictionary = {}
var shield_bars: Dictionary = {}
var hud_layer: CanvasLayer
var finished: bool = false
var camera: Camera2D
var shake_amount: float = 0.0
var cam_limits: Rect2
var min_zoom: float = 0.6


func _ready() -> void:
	stage = Stages.get_by_index(stage_index)
	RenderingServer.set_default_clear_color(stage.get("bg", Color(0.09, 0.10, 0.16)))
	# The camera follows the fighters and zooms out to fit them, never showing
	# past the stage's camera limits.
	cam_limits = Stages.camera_limits(stage)
	min_zoom = clampf(maxf(VIEW.x / cam_limits.size.x, VIEW.y / cam_limits.size.y), 0.45, 1.0)
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.make_current()
	var backdrop := _make_backdrop(str(stage.get("theme", "")))
	if backdrop != null:
		backdrop.set("stage", stage)
		add_child(backdrop)
	_build_stage()
	for i in Settings.PLAYERS:
		_spawn_player(i)
	_build_hud()
	_update_camera(0.0, true)


func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(Color(0.07, 0.08, 0.12))


func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


func _physics_process(delta: float) -> void:
	_update_camera(delta)


func _update_camera(delta: float, snap: bool = false) -> void:
	var box := Rect2()
	var any := false
	for p in players:
		if not p.participating or p.is_eliminated or not p.visible:
			continue
		# Clamp first so a fighter flying off toward the blast zone can't drag the view out.
		var at := p.global_position.clamp(cam_limits.position, cam_limits.end)
		if any:
			box = box.expand(at)
		else:
			box = Rect2(at, Vector2.ZERO)
			any = true
	if not any:
		var mb: Rect2 = stage.get("main_bounds", Rect2(290, 500, 700, 40))
		box = Rect2(mb.get_center(), Vector2.ZERO)
	box = box.grow_individual(CAM_MARGIN[0], CAM_MARGIN[1], CAM_MARGIN[2], CAM_MARGIN[3])
	var z := clampf(minf(VIEW.x / box.size.x, VIEW.y / box.size.y), min_zoom, 1.0)
	if snap:
		camera.zoom = Vector2(z, z)
		camera.position = box.get_center()
	else:
		var zz := lerpf(camera.zoom.x, z, 1.0 - exp(-3.5 * delta))
		camera.zoom = Vector2(zz, zz)
		camera.position = camera.position.lerp(box.get_center(), 1.0 - exp(-5.0 * delta))
	# Keep the actual view inside the limits.
	var half := VIEW / camera.zoom.x * 0.5
	camera.position = Vector2(
		clampf(camera.position.x, cam_limits.position.x + half.x, maxf(cam_limits.end.x - half.x, cam_limits.position.x + half.x)),
		clampf(camera.position.y, cam_limits.position.y + half.y, maxf(cam_limits.end.y - half.y, cam_limits.position.y + half.y)))
	if snap:
		camera.reset_smoothing()


func _process(delta: float) -> void:
	if shake_amount > 0.0:
		shake_amount = move_toward(shake_amount, 0.0, delta * 45.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
	else:
		camera.offset = Vector2.ZERO
	for i in Settings.PLAYERS:
		var p := players[i]
		var name_label: Label = name_labels[i]
		var power_label: Label = power_labels[i]
		var bar: ProgressBar = shield_bars[i]

		if not p.participating:
			name_label.visible = false
			power_label.visible = false
			bar.visible = false
			continue

		name_label.visible = true
		power_label.visible = true
		bar.visible = true
		var who: String = ("CPU " + Bot.level_name(p.bot_level)) if p.is_bot else "Human"
		name_label.text = "P%d %s (%s)\n%d%%   stocks %d" % [
			i + 1, p.char_name, who, int(p.damage_percent), p.stocks,
		]
		name_label.add_theme_color_override("font_color", p.body_color)
		power_label.text = _power_text(p)
		bar.value = p.shield_amount
		if p.shield_broken_left > 0.0:
			bar.modulate = Color(1.0, 0.4, 0.4)
		elif p.shield_type == Player.SHIELD_PARRY_ONLY:
			bar.modulate = Color(0.6, 0.6, 0.7)
		else:
			bar.modulate = Color.WHITE


func _power_text(p: Player) -> String:
	var p1: Dictionary = p.character.get("power1", {})
	var p2: Dictionary = p.character.get("power2", {})
	var line := "%s %s   %s %s" % [
		p1.get("name", "-"), p.cooldown_text("power1"),
		p2.get("name", "-"), p.cooldown_text("power2"),
	]
	var special: String = p.character.get("special_move", "")
	if special != "":
		line += "   %s %s" % [special.replace("_", " "), p.cooldown_text("special")]
	if not p.stored_power.is_empty():
		line += "   [holding %s]" % p.stored_power.get("name", "power")
	return line


func _spawn_player(index: int) -> void:
	var spawns: Array = stage.get("spawns", [Vector2(430, 300), Vector2(850, 300),
			Vector2(560, 180), Vector2(720, 180)])
	var p := Player.new()
	p.player_id = index + 1
	p.spawn_point = spawns[index % spawns.size()]
	p.blast_zone = stage.get("blast_zone", Rect2(-200, -250, 1680, 1170))
	p.stage_bounds = stage.get("main_bounds", Rect2(290, 500, 700, 40))
	p.set_character(slot_char[index])
	p.is_bot = slot_is_bot[index]
	p.bot_level = slot_level[index]
	p.participating = index < active_count
	p.visible = p.participating
	p.collision_layer = 2 if p.participating else 0
	p.eliminated.connect(_on_eliminated)
	add_child(p)
	p.global_position = p.spawn_point
	players.append(p)


func restart() -> void:
	finished = false
	for node in get_children():
		if node is Projectile or node is Effects:
			node.queue_free()
	for i in Settings.PLAYERS:
		var p := players[i]
		p.participating = i < active_count
		p.is_bot = slot_is_bot[i]
		p.bot_level = slot_level[i]
		p.bot_memory = {}
		p.set_character(slot_char[i])
		p.stocks = p.max_stocks
		p.damage_percent = 0.0
		p.is_eliminated = false
		p.respawn_left = 0.0
		p.invuln_left = 0.0
		p.hitstun_left = 0.0
		p.last_hitter = null
		p.velocity = Vector2.ZERO
		p.global_position = p.spawn_point
		p.visible = p.participating
		p.collision_layer = 2 if p.participating else 0
		p.modulate.a = 1.0
		p.queue_redraw()
	_update_camera(0.0, true)


func _on_eliminated(_player: Player) -> void:
	if finished:
		return
	var alive := players.filter(func(pl): return pl.participating and not pl.is_eliminated)
	if alive.size() <= 1:
		finished = true
		if alive.size() == 1:
			var w: Player = alive[0]
			match_over.emit("P%d  %s  WINS" % [w.player_id, w.char_name])
		else:
			match_over.emit("DRAW")


# ===========================================================================
# BUILDING
# ===========================================================================
func _build_stage() -> void:
	for entry in stage.get("platforms", []):
		var d: Dictionary = entry
		_add_platform(d.get("pos", Vector2.ZERO), d.get("size", Vector2(100, 20)),
				d.get("one_way", false), d.get("color", Stages.SOLID), str(stage.get("theme", "")))


func _make_backdrop(theme: String) -> Node2D:
	match theme:
		"air_temple":
			return AirTempleBackdrop.new()
		"neon_district":
			return NeonDistrictBackdrop.new()
	return null


func _draw_themed_platform(theme: String, ci: CanvasItem, size: Vector2, one_way: bool) -> void:
	match theme:
		"air_temple":
			AirTempleBackdrop.draw_platform(ci, size, one_way)
		"neon_district":
			NeonDistrictBackdrop.draw_platform(ci, size, one_way)


func _add_platform(pos: Vector2, size: Vector2, one_way: bool, color: Color, theme: String = "") -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.set_meta("one_way", one_way)
	body.add_to_group("anchors")  # Timmy's web swing attaches to these
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.one_way_collision = one_way
	body.add_child(shape)
	if theme in ["air_temple", "neon_district"]:
		var art := Node2D.new()
		art.draw.connect(func(): _draw_themed_platform(theme, art, size, one_way))
		body.add_child(art)
		add_child(body)
		return
	var visual := Polygon2D.new()
	var h := size / 2.0
	visual.polygon = PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)
	])
	visual.color = color
	body.add_child(visual)
	add_child(body)


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	for i in Settings.PLAYERS:
		var x := 14.0 + float(i) * 317.0

		var name_label := Label.new()
		name_label.position = Vector2(x, 10)
		name_label.size = Vector2(305, 46)
		name_label.add_theme_font_size_override("font_size", 17)
		_outline(name_label, 6)
		hud_layer.add_child(name_label)
		name_labels[i] = name_label

		var bar := ProgressBar.new()
		bar.position = Vector2(x, 56)
		bar.size = Vector2(290, 9)
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = 100.0
		bar.show_percentage = false
		hud_layer.add_child(bar)
		shield_bars[i] = bar

		var power_label := Label.new()
		power_label.position = Vector2(x, 68)
		power_label.size = Vector2(300, 46)
		power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		power_label.add_theme_font_size_override("font_size", 11)
		power_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.98))
		_outline(power_label, 4)
		hud_layer.add_child(power_label)
		power_labels[i] = power_label

	var stage_label := Label.new()
	stage_label.position = Vector2(0, 690)
	stage_label.size = Vector2(1280, 24)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size", 12)
	stage_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.68))
	stage_label.text = "%s     Esc to pause" % stage.get("name", "Stage")
	_outline(stage_label, 4)
	hud_layer.add_child(stage_label)


func _outline(label: Label, size: int) -> void:
	## Dark outline so HUD text reads on bright backdrops like the Air Temple sky.
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.9))
	label.add_theme_constant_override("outline_size", size)
