extends Node2D
## Stage 4: stage, inputs, character select, HUD with power cooldowns, win screen.

const BLAST_ZONE := Rect2(-200, -250, 1680, 1170)

var players: Array[Player] = []
var name_labels: Dictionary = {}
var power_labels: Dictionary = {}
var shield_bars: Dictionary = {}
var win_label: Label
var game_over: bool = false


func _ready() -> void:
	_setup_inputs()
	_build_stage()
	_spawn_player(1, Vector2(480, 300), 0)  # Timmy
	_spawn_player(2, Vector2(800, 300), 3)  # Ando
	_build_hud()


func _process(_delta: float) -> void:
	for p in players:
		var name_label: Label = name_labels[p.player_id]
		name_label.text = "P%d  %s   %d%%   stocks: %d" % [
			p.player_id, p.char_name, int(p.damage_percent), p.stocks
		]
		name_label.add_theme_color_override("font_color", p.body_color)

		var power_label: Label = power_labels[p.player_id]
		power_label.text = _power_text(p)

		var bar: ProgressBar = shield_bars[p.player_id]
		bar.value = p.shield_amount
		if p.shield_broken_left > 0.0:
			bar.modulate = Color(1.0, 0.4, 0.4)
		elif p.shield_type == Player.SHIELD_PARRY_ONLY:
			bar.modulate = Color(0.6, 0.6, 0.7)
		else:
			bar.modulate = Color.WHITE


func _power_text(p: Player) -> String:
	var k := _keys_for(p.player_id)
	var p1: Dictionary = p.character.get("power1", {})
	var p2: Dictionary = p.character.get("power2", {})
	var line := "%s %s %s    %s %s %s" % [
		k["power1"], p1.get("name", "-"), p.cooldown_text("power1"),
		k["power2"], p2.get("name", "-"), p.cooldown_text("power2"),
	]
	var special: String = p.character.get("special_move", "")
	if special != "":
		line += "    %s %s %s" % [k["special"], special.replace("_", " "), p.cooldown_text("special")]
	if not p.stored_power.is_empty():
		line += "    [holding %s]" % p.stored_power.get("name", "power")
	return line


func _keys_for(id: int) -> Dictionary:
	if id == 1:
		return {"power1": "Q", "power2": "E", "special": "V"}
	return {"power1": ";", "power2": "'", "special": "L"}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	# Character select: 1-5 for P1, 6-9 and 0 for P2.
	for i in 5:
		if event.is_action_pressed("p1_char%d" % (i + 1)):
			players[0].set_character(i)
		if event.is_action_pressed("p2_char%d" % (i + 1)):
			players[1].set_character(i)


func _draw() -> void:
	draw_rect(BLAST_ZONE, Color(1, 0.3, 0.3, 0.35), false, 3.0)


func _spawn_player(id: int, spawn: Vector2, char_index: int) -> void:
	var p := Player.new()
	p.player_id = id
	p.spawn_point = spawn
	p.blast_zone = BLAST_ZONE
	p.set_character(char_index)
	p.eliminated.connect(_on_eliminated)
	add_child(p)
	p.global_position = spawn
	players.append(p)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	for p in players:
		var x := 30.0 + float(p.player_id - 1) * 640.0

		var name_label := Label.new()
		name_label.position = Vector2(x, 16)
		name_label.add_theme_font_size_override("font_size", 24)
		layer.add_child(name_label)
		name_labels[p.player_id] = name_label

		var bar := ProgressBar.new()
		bar.position = Vector2(x, 48)
		bar.size = Vector2(260, 12)
		bar.min_value = 0.0
		bar.max_value = p.shield_max
		bar.value = p.shield_max
		bar.show_percentage = false
		layer.add_child(bar)
		shield_bars[p.player_id] = bar

		var power_label := Label.new()
		power_label.position = Vector2(x, 66)
		power_label.add_theme_font_size_override("font_size", 14)
		power_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.92))
		layer.add_child(power_label)
		power_labels[p.player_id] = power_label

	win_label = Label.new()
	win_label.position = Vector2(0, 270)
	win_label.size = Vector2(1280, 120)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.add_theme_font_size_override("font_size", 56)
	win_label.visible = false
	layer.add_child(win_label)

	var hint := Label.new()
	hint.position = Vector2(0, 648)
	hint.size = Vector2(1280, 60)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.85))
	hint.text = "P1  WASD move, F light, G heavy, C block, Q/E powers, V special\n" \
		+ "P2  arrows move, / light, . heavy, , block, ;/' powers, L special\n" \
		+ "Characters: 1-5 picks P1, 6-0 picks P2  (Timmy, Sway, Wham, Ando, Jwong)     R restarts"
	layer.add_child(hint)


func _on_eliminated(_player: Player) -> void:
	if game_over:
		return
	var alive := players.filter(func(pl): return not pl.is_eliminated)
	if alive.size() <= 1:
		game_over = true
		if alive.size() == 1:
			win_label.text = "%s WINS!\nPress R to restart" % alive[0].char_name
		else:
			win_label.text = "DRAW\nPress R to restart"
		win_label.visible = true


func _build_stage() -> void:
	_add_platform(Vector2(640, 520), Vector2(700, 40), false, Color(0.35, 0.4, 0.55))
	_add_platform(Vector2(440, 380), Vector2(200, 16), true, Color(0.5, 0.6, 0.75))
	_add_platform(Vector2(840, 380), Vector2(200, 16), true, Color(0.5, 0.6, 0.75))
	_add_platform(Vector2(640, 250), Vector2(160, 16), true, Color(0.5, 0.6, 0.75))


func _add_platform(pos: Vector2, size: Vector2, one_way: bool, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.set_meta("one_way", one_way)
	# Timmy's web swing attaches to these.
	body.add_to_group("anchors")
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


func _setup_inputs() -> void:
	# Player 1 (left hand).
	_add_key_action("p1_left", KEY_A)
	_add_key_action("p1_right", KEY_D)
	_add_key_action("p1_jump", KEY_W)
	_add_key_action("p1_jump", KEY_SPACE)
	_add_key_action("p1_down", KEY_S)
	_add_key_action("p1_light", KEY_F)
	_add_key_action("p1_heavy", KEY_G)
	_add_key_action("p1_block", KEY_C)
	_add_key_action("p1_power1", KEY_Q)
	_add_key_action("p1_power2", KEY_E)
	_add_key_action("p1_special", KEY_V)
	# Player 2 (right hand).
	_add_key_action("p2_left", KEY_LEFT)
	_add_key_action("p2_right", KEY_RIGHT)
	_add_key_action("p2_jump", KEY_UP)
	_add_key_action("p2_down", KEY_DOWN)
	_add_key_action("p2_light", KEY_SLASH)
	_add_key_action("p2_heavy", KEY_PERIOD)
	_add_key_action("p2_block", KEY_COMMA)
	_add_key_action("p2_power1", KEY_SEMICOLON)
	_add_key_action("p2_power2", KEY_APOSTROPHE)
	_add_key_action("p2_special", KEY_L)
	# Character select.
	var p1_keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
	var p2_keys := [KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
	for i in 5:
		_add_key_action("p1_char%d" % (i + 1), p1_keys[i])
		_add_key_action("p2_char%d" % (i + 1), p2_keys[i])
	# Match controls.
	_add_key_action("restart", KEY_R)


func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	# Avoid duplicate events when the scene reloads.
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
