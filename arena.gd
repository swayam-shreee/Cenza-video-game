extends Node2D
class_name Arena
## Runs one match. Built entirely from a stage entry (stages.gd) and a list of
## player slots, so it knows nothing about menus. game.gd creates it, fills in
## stage_index and the slot arrays, then adds it to the tree.

signal match_over(result_text: String)

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


func _ready() -> void:
	stage = Stages.get_by_index(stage_index)
	RenderingServer.set_default_clear_color(stage.get("bg", Color(0.09, 0.10, 0.16)))
	_build_stage()
	for i in Settings.PLAYERS:
		_spawn_player(i)
	_build_hud()


func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(Color(0.07, 0.08, 0.12))


func _draw() -> void:
	var bz: Rect2 = stage.get("blast_zone", Rect2(-200, -250, 1680, 1170))
	draw_rect(bz, Color(1, 0.3, 0.3, 0.3), false, 3.0)


func _process(_delta: float) -> void:
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
		if node is Projectile:
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
				d.get("one_way", false), d.get("color", Stages.SOLID))


func _add_platform(pos: Vector2, size: Vector2, one_way: bool, color: Color) -> void:
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
		power_label.add_theme_color_override("font_color", Color(0.76, 0.8, 0.9))
		hud_layer.add_child(power_label)
		power_labels[i] = power_label

	var stage_label := Label.new()
	stage_label.position = Vector2(0, 690)
	stage_label.size = Vector2(1280, 24)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size", 12)
	stage_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.68))
	stage_label.text = "%s     Esc to pause" % stage.get("name", "Stage")
	hud_layer.add_child(stage_label)
