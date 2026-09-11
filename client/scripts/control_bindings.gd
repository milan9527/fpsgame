extends RefCounted
const DEFAULTS := {"push_to_talk": KEY_T, "forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "lean_left": KEY_Z, "lean_right": KEY_C, "crouch": KEY_CTRL, "jump": KEY_SPACE, "reload": KEY_R, "loot": KEY_E, "heal": KEY_H, "throw": KEY_G, "smoke_throw": KEY_V, "weapon1": KEY_1, "weapon2": KEY_2, "weapon3": KEY_3, "pause": KEY_ESCAPE, "inventory": KEY_B, "map": KEY_M, "scoreboard": KEY_TAB, "spectate_previous": KEY_Q, "spectate_next": KEY_E}
var keys: Dictionary = DEFAULTS.duplicate()
var path := "user://bindings.cfg"
var message := ""

func _init(profile_path := "user://bindings.cfg") -> void:
	path = profile_path

static func valid_key(code: int) -> bool:
	return (code >= KEY_SPACE and code <= KEY_ASCIITILDE) or (code >= KEY_F1 and code <= KEY_F24) or code in [KEY_TAB, KEY_BACKSPACE, KEY_ENTER, KEY_INSERT, KEY_DELETE, KEY_HOME, KEY_END, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]

static func same_context(a: String, b: String) -> bool:
	return a == "push_to_talk" or b == "push_to_talk" or a.begins_with("spectate_") == b.begins_with("spectate_")

func conflict(action: String, code: int, candidate: Dictionary) -> String:
	for other in candidate:
		if other != action and same_context(action, other) and candidate[other] == code:
			return other
	return ""

func load_profile() -> void:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		message = "Using defaults; bindings file could not be read." if error != ERR_FILE_NOT_FOUND else ""
		return
	var candidate := DEFAULTS.duplicate()
	for action in DEFAULTS:
		var code = config.get_value("keyboard", action, DEFAULTS[action])
		if not code is int or (action == "pause" and code != KEY_ESCAPE) or (action != "pause" and not valid_key(code)):
			message = "Invalid bindings file; using defaults."
			return
		candidate[action] = code
	for action in candidate:
		if conflict(action, candidate[action], candidate) != "":
			message = "Conflicting bindings file; using defaults."
			return
	keys = candidate

func apply() -> void:
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	for action in ["fire", "aim"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, event)

func commit(candidate: Dictionary) -> bool:
	var config := ConfigFile.new()
	for action in candidate:
		config.set_value("keyboard", action, candidate[action])
	var error := config.save(path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		message = "Could not save bindings; previous keys remain active."
		return false
	keys = candidate
	apply()
	message = "Bindings saved."
	return true

func bind(action: String, code: int) -> bool:
	if not DEFAULTS.has(action) or action == "pause" or not valid_key(code):
		message = "Choose a keyboard key. Escape is reserved for closing menus."
		return false
	var other := conflict(action, code, keys)
	if other != "":
		message = "Already assigned to " + other.replace("_", " ") + ". Choose another key."
		return false
	var candidate := keys.duplicate()
	candidate[action] = code
	return commit(candidate)

func reset_defaults() -> bool:
	return commit(DEFAULTS.duplicate())

static func key_label(action: String) -> String:
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				return OS.get_keycode_string(event.physical_keycode).to_upper()
	return "?"
