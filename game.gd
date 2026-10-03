extends Node
## Screen manager. Owns the whole flow: title -> character select -> stage select
## -> match -> results, plus the controls menu and the pause menu. Every screen is
## built in code into ui_root; the match lives in an Arena node beside it.

const CHAR_NAMES := ["Timmy", "Sway", "Wham", "Ando", "Jwong"]
const CHAR_BLURBS := [
	"staff, web swing", "blades, fast, fragile", "scythe, ice, long reach",
	"hammer, huge knockback", "shield, slow, heavy",
]

var ui_layer: CanvasLayer
var ui_root: Control
var arena: Arena = null

var screen: String = ""

# --- match configuration, carried between screens ---
var active_count: int = 2
var slot_is_bot := [false, true, true, true]
var slot_char := [0, 3, 2, 4]
var slot_level := [1, 1, 1, 1]
var stage_index: int = Stages.AIR_TEMPLE

# --- rebinding state ---
var rebind_player: int = 0      # 0 = not currently rebinding
var rebind_action: String = ""
var rebind_add: bool = false    # true = add a second binding instead of replacing
var controls_player: int = 1    # which player the controls screen is editing
var controls_message: String = ""
var came_from_pause: bool = false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.07, 0.08, 0.12))
	# This node keeps running while the tree is paused, so Escape can unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)
	show_title()


# ===========================================================================
# INPUT
# ===========================================================================
func _input(event: InputEvent) -> void:
	if rebind_player > 0:
		_capture_rebind(event)
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		match screen:
			"match":
				set_paused(true)
			"pause":
				resume()
			"controls":
				back_from_controls()
			"char_select":
				show_title()
			"results":
				show_title()


func _capture_rebind(event: InputEvent) -> void:
	# Stick and trigger events never report is_pressed(), so they need their own check.
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.6:
			return
	elif not event.is_pressed():
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		rebind_player = 0
		rebind_action = ""
		controls_message = "Rebinding cancelled."
		get_viewport().set_input_as_handled()
		show_controls()
		return
	if not (event is InputEventKey or event is InputEventJoypadButton
			or event is InputEventJoypadMotion):
		return
	var conflict := Settings.find_conflict(rebind_player, rebind_action, event)
	var ok: bool
	if rebind_add:
		ok = Settings.add_binding(rebind_player, rebind_action, event)
	else:
		ok = Settings.set_binding(rebind_player, rebind_action, event)
	if not ok:
		return  # stick drift or an unusable event; keep waiting
	if conflict != "":
		controls_message = "Saved. Note: also used by %s" % conflict
	else:
		controls_message = "Saved."
	rebind_player = 0
	rebind_action = ""
	get_viewport().set_input_as_handled()
	show_controls()


# ===========================================================================
# UI HELPERS
# ===========================================================================
func _clear_ui() -> void:
	for c in ui_root.get_children():
		ui_root.remove_child(c)
		c.queue_free()


func _panel(title_text: String, subtitle: String = "") -> VBoxContainer:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.06, 0.1, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	center.add_child(box)

	var heading := Label.new()
	heading.text = title_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	heading.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	box.add_child(heading)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 14)
		sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.88))
		box.add_child(sub)

	box.add_child(_spacer(8))
	return box


func _spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


func _button(text: String, callback: Callable, width: int = 340, font_size: int = 19) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 36)
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(callback)
	return b


func _label(text: String, font_size: int = 15, color: Color = Color(0.85, 0.88, 0.95)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	return h


func _focus_first(node: Node) -> void:
	for c in node.get_children():
		if c is Button:
			c.grab_focus()
			return
		if c is Container:
			for cc in c.get_children():
				if cc is Button:
					cc.grab_focus()
					return


# ===========================================================================
# TITLE
# ===========================================================================
func show_title() -> void:
	screen = "title"
	came_from_pause = false
	_unpause()
	_free_arena()
	_clear_ui()
	var box := _panel("BRAWL FIGHTER", "A platform fighter with five custom characters")
	box.add_child(_button("Start", show_char_select))
	box.add_child(_button("Controls", open_controls_from_title))
	box.add_child(_button("Quit", do_quit))
	box.add_child(_spacer(12))
	box.add_child(_label("Arrow keys or mouse to navigate, Enter to pick", 13,
			Color(0.55, 0.6, 0.75)))
	_focus_first(box)


func do_quit() -> void:
	get_tree().quit()


func open_controls_from_title() -> void:
	came_from_pause = false
	show_controls()


# ===========================================================================
# CHARACTER SELECT
# ===========================================================================
func show_char_select() -> void:
	screen = "char_select"
	_clear_ui()
	var box := _panel("Choose your fighters",
			"Players 3 and 4 are gamepad only, so leave them on CPU if you have no pads")

	for i in Settings.PLAYERS:
		box.add_child(_slot_row(i))

	box.add_child(_spacer(8))
	var count_row := _row()
	count_row.add_child(_label("Fighters in the match:", 16))
	count_row.add_child(_button("-", change_count.bind(-1), 42, 17))
	count_row.add_child(_label("  %d  " % active_count, 20, Color(0.95, 0.85, 0.5)))
	count_row.add_child(_button("+", change_count.bind(1), 42, 17))
	box.add_child(count_row)

	box.add_child(_spacer(6))
	var stage := Stages.get_by_index(stage_index)
	var map_row := _row()
	map_row.add_child(_label("Map:", 16))
	map_row.add_child(_button("<", cycle_stage.bind(-1), 34, 15))
	var map_name := _label(str(stage.get("name", "Stage")), 18, Color(0.95, 0.85, 0.5))
	map_name.custom_minimum_size = Vector2(150, 0)
	map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_row.add_child(map_name)
	map_row.add_child(_button(">", cycle_stage.bind(1), 34, 15))
	box.add_child(map_row)
	box.add_child(_label(str(stage.get("blurb", "")), 12, Color(0.6, 0.65, 0.78)))

	box.add_child(_spacer(10))
	box.add_child(_button("FIGHT", start_match, 340, 24))
	box.add_child(_button("Back", show_title))
	_focus_first(box)


func _slot_row(i: int) -> HBoxContainer:
	var row := _row()
	var active := i < active_count

	var tag := _label("P%d" % (i + 1), 18,
			Color(0.95, 0.85, 0.5) if active else Color(0.4, 0.43, 0.52))
	tag.custom_minimum_size = Vector2(34, 0)
	row.add_child(tag)

	if not active:
		var off := _label("not in this match", 15, Color(0.4, 0.43, 0.52))
		off.custom_minimum_size = Vector2(460, 32)
		row.add_child(off)
		return row

	row.add_child(_button("<", cycle_char.bind(i, -1), 34, 15))
	var name_label := _label(CHAR_NAMES[slot_char[i]], 18,
			Characters.get_by_index(slot_char[i]).get("color", Color.WHITE))
	name_label.custom_minimum_size = Vector2(86, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	row.add_child(_button(">", cycle_char.bind(i, 1), 34, 15))

	row.add_child(_button("CPU" if slot_is_bot[i] else "Human", toggle_bot.bind(i), 86, 15))

	if slot_is_bot[i]:
		row.add_child(_button(Bot.LEVEL_NAMES[slot_level[i]], cycle_level.bind(i), 86, 15))
	else:
		var pad := _label("", 15)
		pad.custom_minimum_size = Vector2(86, 0)
		row.add_child(pad)

	var blurb := _label(CHAR_BLURBS[slot_char[i]], 12, Color(0.6, 0.65, 0.78))
	blurb.custom_minimum_size = Vector2(160, 0)
	row.add_child(blurb)
	return row


func cycle_char(slot: int, direction: int) -> void:
	slot_char[slot] = posmod(slot_char[slot] + direction, CHAR_NAMES.size())
	show_char_select()


func toggle_bot(slot: int) -> void:
	slot_is_bot[slot] = not slot_is_bot[slot]
	show_char_select()


func cycle_level(slot: int) -> void:
	slot_level[slot] = posmod(slot_level[slot] + 1, 3)
	show_char_select()


func change_count(delta: int) -> void:
	active_count = clampi(active_count + delta, 2, Settings.PLAYERS)
	show_char_select()


func cycle_stage(direction: int) -> void:
	stage_index = posmod(stage_index + direction, Stages.count())
	show_char_select()


# ===========================================================================
# MATCH
# ===========================================================================
func start_match() -> void:
	_clear_ui()
	_free_arena()
	arena = Arena.new()
	arena.stage_index = stage_index
	arena.active_count = active_count
	arena.slot_is_bot = slot_is_bot.duplicate()
	arena.slot_char = slot_char.duplicate()
	arena.slot_level = slot_level.duplicate()
	arena.match_over.connect(show_results)
	# This node always runs (so Escape can unpause), but the match itself must pause.
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	_unpause()
	screen = "match"


func _free_arena() -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
	arena = null


func _unpause() -> void:
	get_tree().paused = false


func set_paused(value: bool) -> void:
	get_tree().paused = value
	if value:
		show_pause()


func resume() -> void:
	_unpause()
	_clear_ui()
	screen = "match"


func show_pause() -> void:
	screen = "pause"
	_clear_ui()
	var box := _panel("Paused")
	box.add_child(_button("Resume", resume))
	box.add_child(_button("Controls", open_controls_from_pause))
	box.add_child(_button("Restart match", restart_match))
	box.add_child(_button("Change fighters or map", leave_match_to_select))
	box.add_child(_button("Quit to title", show_title))
	_focus_first(box)


func open_controls_from_pause() -> void:
	came_from_pause = true
	_unpause()
	show_controls()


func restart_match() -> void:
	_unpause()
	_clear_ui()
	if arena != null and is_instance_valid(arena):
		arena.restart()
	screen = "match"


func leave_match_to_select() -> void:
	_unpause()
	_free_arena()
	show_char_select()


# ===========================================================================
# RESULTS
# ===========================================================================
func show_results(result_text: String) -> void:
	screen = "results"
	_clear_ui()
	var box := _panel(result_text, str(Stages.get_by_index(stage_index).get("name", "")))
	box.add_child(_button("Rematch", restart_match))
	box.add_child(_button("Change fighters or map", leave_match_to_select))
	box.add_child(_button("Quit to title", show_title))
	_focus_first(box)


# ===========================================================================
# CONTROLS
# ===========================================================================
func show_controls() -> void:
	screen = "controls"
	_clear_ui()
	var box := _panel("Controls", _connected_pads_text())

	var picker := _row()
	picker.add_child(_label("Editing:", 16))
	for i in Settings.PLAYERS:
		var pn := i + 1
		var text := "[P%d]" % pn if controls_player == pn else " P%d " % pn
		picker.add_child(_button(text, choose_controls_player.bind(pn), 58, 15))
	box.add_child(picker)

	if controls_message != "":
		box.add_child(_label(controls_message, 13, Color(0.6, 0.95, 0.7)))
	box.add_child(_spacer(4))

	for action in Settings.ACTIONS:
		box.add_child(_control_row(action))

	box.add_child(_spacer(10))
	box.add_child(_button("Reset P%d to defaults" % controls_player,
			reset_player_controls, 460, 16))
	box.add_child(_button("Reset everything to defaults", reset_all_controls, 460, 16))
	box.add_child(_button("Back", back_from_controls, 460))
	_focus_first(box)


func _control_row(action: String) -> HBoxContainer:
	var row := _row()
	var label := _label(str(Settings.ACTION_LABELS.get(action, action)), 15)
	label.custom_minimum_size = Vector2(146, 0)
	row.add_child(label)

	var has_binding := Settings.get_events(controls_player, action).size() > 0
	var bound := _label(Settings.binding_text(controls_player, action), 13,
			Color(0.95, 0.85, 0.5) if has_binding else Color(0.85, 0.45, 0.45))
	bound.custom_minimum_size = Vector2(300, 0)
	bound.clip_text = true
	row.add_child(bound)

	row.add_child(_button("Set", begin_rebind.bind(action, false), 60, 13))
	row.add_child(_button("Add", begin_rebind.bind(action, true), 60, 13))
	row.add_child(_button("Clear", clear_control.bind(action), 60, 13))
	return row


func choose_controls_player(pn: int) -> void:
	controls_player = pn
	controls_message = ""
	show_controls()


func clear_control(action: String) -> void:
	Settings.clear_binding(controls_player, action)
	controls_message = "Cleared."
	show_controls()


func reset_player_controls() -> void:
	Settings.reset_player(controls_player)
	controls_message = "Reset to defaults."
	show_controls()


func reset_all_controls() -> void:
	Settings.reset_all()
	controls_message = "All controls reset."
	show_controls()


func back_from_controls() -> void:
	controls_message = ""
	if came_from_pause:
		came_from_pause = false
		set_paused(true)
	else:
		show_title()


func begin_rebind(action: String, add_mode: bool) -> void:
	rebind_player = controls_player
	rebind_action = action
	rebind_add = add_mode
	_clear_ui()
	var box := _panel("Press a key or button",
			"for P%d  %s" % [controls_player, str(Settings.ACTION_LABELS.get(action, action))])
	if add_mode:
		box.add_child(_label("This adds a second binding instead of replacing it.", 14,
				Color(0.7, 0.75, 0.88)))
	box.add_child(_label("Press Escape to cancel.", 14, Color(0.7, 0.75, 0.88)))


func _connected_pads_text() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "No gamepads detected. Plug one in and it shows up here."
	var names := []
	for dev in pads:
		names.append(Settings.pad_label(dev))
	return "Connected: " + ", ".join(names)
