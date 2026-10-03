extends Node
## Autoloaded as "Settings". Holds every control binding, writes them to disk,
## and pushes them into Godot's InputMap. Also names gamepad buttons correctly
## for whichever controller is plugged in (Xbox vs PlayStation).
##
## Saved to user://settings.cfg, which on Linux is
## ~/.local/share/godot/app_userdata/Brawl Fighter/settings.cfg

const PATH := "user://settings.cfg"
const PLAYERS := 4

## The ten things a fighter can do, in the order the rebinding menu lists them.
const ACTIONS := [
	"left", "right", "jump", "down", "light",
	"heavy", "block", "power1", "power2", "special",
]

const ACTION_LABELS := {
	"left": "Move left", "right": "Move right", "jump": "Jump",
	"down": "Down / fast fall", "light": "Light attack", "heavy": "Heavy attack",
	"block": "Block / parry", "power1": "Power 1", "power2": "Power 2",
	"special": "Movement special",
}

# bindings["p1"]["light"] == [ {"t":"key","code":70}, {"t":"btn","dev":0,"idx":2} ]
var bindings: Dictionary = {}


func _ready() -> void:
	load_settings()


# ===========================================================================
# DEFAULTS
# ===========================================================================
func default_bindings() -> Dictionary:
	var d := {}
	for i in PLAYERS:
		d["p%d" % (i + 1)] = {}
		for a in ACTIONS:
			d["p%d" % (i + 1)][a] = []

	# Player 1: left-hand keyboard.
	_bind(d, 1, "left", [_key(KEY_A)])
	_bind(d, 1, "right", [_key(KEY_D)])
	_bind(d, 1, "jump", [_key(KEY_W), _key(KEY_SPACE)])
	_bind(d, 1, "down", [_key(KEY_S)])
	_bind(d, 1, "light", [_key(KEY_F)])
	_bind(d, 1, "heavy", [_key(KEY_G)])
	_bind(d, 1, "block", [_key(KEY_C)])
	_bind(d, 1, "power1", [_key(KEY_Q)])
	_bind(d, 1, "power2", [_key(KEY_E)])
	_bind(d, 1, "special", [_key(KEY_V)])

	# Player 2: right-hand keyboard.
	_bind(d, 2, "left", [_key(KEY_LEFT)])
	_bind(d, 2, "right", [_key(KEY_RIGHT)])
	_bind(d, 2, "jump", [_key(KEY_UP)])
	_bind(d, 2, "down", [_key(KEY_DOWN)])
	_bind(d, 2, "light", [_key(KEY_SLASH)])
	_bind(d, 2, "heavy", [_key(KEY_PERIOD)])
	_bind(d, 2, "block", [_key(KEY_COMMA)])
	_bind(d, 2, "power1", [_key(KEY_SEMICOLON)])
	_bind(d, 2, "power2", [_key(KEY_APOSTROPHE)])
	_bind(d, 2, "special", [_key(KEY_L)])

	# Every player also gets the matching gamepad: P1 pad 1, P2 pad 2, and so on.
	for i in PLAYERS:
		var pn := i + 1
		var dev := i
		_append(d, pn, "left", _axis(dev, JOY_AXIS_LEFT_X, -1.0))
		_append(d, pn, "left", _btn(dev, JOY_BUTTON_DPAD_LEFT))
		_append(d, pn, "right", _axis(dev, JOY_AXIS_LEFT_X, 1.0))
		_append(d, pn, "right", _btn(dev, JOY_BUTTON_DPAD_RIGHT))
		_append(d, pn, "down", _axis(dev, JOY_AXIS_LEFT_Y, 1.0))
		_append(d, pn, "down", _btn(dev, JOY_BUTTON_DPAD_DOWN))
		_append(d, pn, "jump", _btn(dev, JOY_BUTTON_A))
		_append(d, pn, "light", _btn(dev, JOY_BUTTON_X))
		_append(d, pn, "heavy", _btn(dev, JOY_BUTTON_B))
		_append(d, pn, "power1", _btn(dev, JOY_BUTTON_Y))
		_append(d, pn, "power2", _btn(dev, JOY_BUTTON_RIGHT_SHOULDER))
		_append(d, pn, "special", _btn(dev, JOY_BUTTON_LEFT_SHOULDER))
		_append(d, pn, "block", _axis(dev, JOY_AXIS_TRIGGER_RIGHT, 1.0))
	return d


func _bind(d: Dictionary, player_num: int, action: String, events: Array) -> void:
	d["p%d" % player_num][action] = events


func _append(d: Dictionary, player_num: int, action: String, event: Dictionary) -> void:
	d["p%d" % player_num][action].append(event)


func _key(code: int) -> Dictionary:
	return {"t": "key", "code": code}


func _btn(device: int, index: int) -> Dictionary:
	return {"t": "btn", "dev": device, "idx": index}


func _axis(device: int, axis: int, value: float) -> Dictionary:
	return {"t": "axis", "dev": device, "axis": axis, "val": signf(value)}


func reset_player(player_num: int) -> void:
	var defaults := default_bindings()
	bindings["p%d" % player_num] = defaults["p%d" % player_num]
	apply_to_input_map()
	save_settings()


func reset_all() -> void:
	bindings = default_bindings()
	apply_to_input_map()
	save_settings()


# ===========================================================================
# BINDING EDITS
# ===========================================================================
func get_events(player_num: int, action: String) -> Array:
	var key := "p%d" % player_num
	if not bindings.has(key) or not bindings[key].has(action):
		return []
	return bindings[key][action]


func set_binding(player_num: int, action: String, event: InputEvent) -> bool:
	## Replaces every binding for this action with the one event given.
	## Returns false if the event isn't something we can bind.
	var d := event_to_dict(event)
	if d.is_empty():
		return false
	bindings["p%d" % player_num][action] = [d]
	apply_to_input_map()
	save_settings()
	return true


func add_binding(player_num: int, action: String, event: InputEvent) -> bool:
	var d := event_to_dict(event)
	if d.is_empty():
		return false
	var list: Array = bindings["p%d" % player_num][action]
	for existing in list:
		if existing == d:
			return false
	list.append(d)
	apply_to_input_map()
	save_settings()
	return true


func clear_binding(player_num: int, action: String) -> void:
	bindings["p%d" % player_num][action] = []
	apply_to_input_map()
	save_settings()


func find_conflict(player_num: int, action: String, event: InputEvent) -> String:
	## Returns "P2 Heavy attack" if this event is already used elsewhere, else "".
	var d := event_to_dict(event)
	if d.is_empty():
		return ""
	for i in PLAYERS:
		var pn := i + 1
		for a in ACTIONS:
			if pn == player_num and a == action:
				continue
			for existing in get_events(pn, a):
				if existing == d:
					return "P%d %s" % [pn, ACTION_LABELS.get(a, a)]
	return ""


# ===========================================================================
# EVENT <-> DICTIONARY
# ===========================================================================
func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: int = event.physical_keycode
		if code == 0:
			code = event.keycode
		if code == 0:
			return {}
		return {"t": "key", "code": code}
	if event is InputEventJoypadButton:
		return {"t": "btn", "dev": event.device, "idx": int(event.button_index)}
	if event is InputEventJoypadMotion:
		# Ignore tiny stick drift when capturing a binding.
		if absf(event.axis_value) < 0.6:
			return {}
		return {"t": "axis", "dev": event.device, "axis": int(event.axis),
				"val": signf(event.axis_value)}
	return {}


func dict_to_event(d: Dictionary) -> InputEvent:
	match d.get("t", ""):
		"key":
			var ev := InputEventKey.new()
			ev.physical_keycode = int(d.get("code", 0))
			return ev
		"btn":
			var ev := InputEventJoypadButton.new()
			ev.device = int(d.get("dev", 0))
			ev.button_index = int(d.get("idx", 0))
			return ev
		"axis":
			var ev := InputEventJoypadMotion.new()
			ev.device = int(d.get("dev", 0))
			ev.axis = int(d.get("axis", 0))
			ev.axis_value = float(d.get("val", 1.0))
			return ev
	return null


# ===========================================================================
# DISPLAY NAMES
# ===========================================================================
const XBOX_BUTTONS := {
	0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 5: "Guide", 6: "Start",
	7: "L-Stick", 8: "R-Stick", 9: "LB", 10: "RB",
	11: "D-Pad Up", 12: "D-Pad Down", 13: "D-Pad Left", 14: "D-Pad Right",
}

const PS_BUTTONS := {
	0: "Cross", 1: "Circle", 2: "Square", 3: "Triangle", 4: "Share", 5: "PS", 6: "Options",
	7: "L3", 8: "R3", 9: "L1", 10: "R1",
	11: "D-Pad Up", 12: "D-Pad Down", 13: "D-Pad Left", 14: "D-Pad Right",
}


func is_playstation_pad(device: int) -> bool:
	var n := Input.get_joy_name(device).to_lower()
	for marker in ["playstation", "dualshock", "dualsense", "sony", "ps3", "ps4", "ps5"]:
		if n.contains(marker):
			return true
	return false


func pad_label(device: int) -> String:
	var n := Input.get_joy_name(device)
	if n == "":
		return "Pad %d (not connected)" % (device + 1)
	return "Pad %d: %s" % [device + 1, n]


func event_name(d: Dictionary) -> String:
	match d.get("t", ""):
		"key":
			return OS.get_keycode_string(int(d.get("code", 0)))
		"btn":
			var dev := int(d.get("dev", 0))
			var idx := int(d.get("idx", 0))
			var table := PS_BUTTONS if is_playstation_pad(dev) else XBOX_BUTTONS
			return "P%d %s" % [dev + 1, table.get(idx, "Button %d" % idx)]
		"axis":
			var dev2 := int(d.get("dev", 0))
			var axis := int(d.get("axis", 0))
			var val := float(d.get("val", 1.0))
			var ps := is_playstation_pad(dev2)
			var name := "Axis %d" % axis
			match axis:
				JOY_AXIS_LEFT_X:
					name = "L-Stick " + ("Right" if val > 0.0 else "Left")
				JOY_AXIS_LEFT_Y:
					name = "L-Stick " + ("Down" if val > 0.0 else "Up")
				JOY_AXIS_RIGHT_X:
					name = "R-Stick " + ("Right" if val > 0.0 else "Left")
				JOY_AXIS_RIGHT_Y:
					name = "R-Stick " + ("Down" if val > 0.0 else "Up")
				JOY_AXIS_TRIGGER_LEFT:
					name = "L2" if ps else "LT"
				JOY_AXIS_TRIGGER_RIGHT:
					name = "R2" if ps else "RT"
			return "P%d %s" % [dev2 + 1, name]
	return "-"


func binding_text(player_num: int, action: String) -> String:
	var events := get_events(player_num, action)
	if events.is_empty():
		return "unbound"
	var parts := []
	for d in events:
		parts.append(event_name(d))
	return ", ".join(parts)


# ===========================================================================
# INPUT MAP
# ===========================================================================
func action_name(player_num: int, action: String) -> String:
	return "p%d_%s" % [player_num, action]


func apply_to_input_map() -> void:
	for i in PLAYERS:
		var pn := i + 1
		for a in ACTIONS:
			var name := action_name(pn, a)
			if InputMap.has_action(name):
				InputMap.action_erase_events(name)
			else:
				InputMap.add_action(name, 0.3)
			for d in get_events(pn, a):
				var ev := dict_to_event(d)
				if ev != null:
					InputMap.action_add_event(name, ev)


# ===========================================================================
# DISK
# ===========================================================================
func save_settings() -> void:
	var cfg := ConfigFile.new()
	for i in PLAYERS:
		var pn := "p%d" % (i + 1)
		for a in ACTIONS:
			cfg.set_value(pn, a, bindings[pn][a])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Could not save settings: %s" % err)


func load_settings() -> void:
	bindings = default_bindings()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		# No settings file yet; defaults are already in place.
		apply_to_input_map()
		return
	for i in PLAYERS:
		var pn := "p%d" % (i + 1)
		if not cfg.has_section(pn):
			continue
		for a in ACTIONS:
			if cfg.has_section_key(pn, a):
				var value = cfg.get_value(pn, a, [])
				if value is Array:
					bindings[pn][a] = value
	apply_to_input_map()
