extends SceneTree
const Bindings = preload("res://scripts/control_bindings.gd")
const ACTIONS = ["weapon1", "weapon2", "weapon3", "heal", "throw", "smoke_throw", "loot"]

func original_label(action: String) -> String:
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				return OS.get_keycode_string(event.physical_keycode).to_upper()
	return "?"

func _initialize() -> void:
	var path := "user://qa-labels-%d.cfg" % Time.get_ticks_usec()
	var profile = Bindings.new(path)
	assert(Bindings.key_label("missing_action") == "?")
	profile.apply()
	for action in Bindings.DEFAULTS:
		assert(Bindings.key_label(action) == original_label(action))
	assert(profile.bind("reload", KEY_F))
	assert(Bindings.key_label("reload") == "F")
	var failed = Bindings.new("user://nonexistent-bindings-folder/labels.cfg")
	assert(not failed.bind("reload", KEY_Y))
	assert(Bindings.key_label("reload") == "F")
	var fresh = Bindings.new(path)
	fresh.load_profile()
	fresh.apply()
	assert(Bindings.key_label("reload") == "F")
	assert(fresh.reset_defaults())
	assert(Bindings.key_label("reload") == "R")
	assert(Bindings.key_label("fire") == "?")
	var results := []
	for trial in range(6):
		var times := {}
		for cached in ([false, true] if trial % 2 == 0 else [true, false]):
			var start := Time.get_ticks_usec()
			for frame in range(20000):
				for action in ACTIONS:
					var label: String = Bindings.key_label(action) if cached else original_label(action)
					assert(not label.is_empty())
			times["cached_us" if cached else "original_us"] = Time.get_ticks_usec() - start
		results.append(times)
	DirAccess.remove_absolute(path)
	print("BINDING_LABEL_PASS " + JSON.stringify({"iterations": 20000, "labels_per_iteration": ACTIONS.size(), "trials": results}))
	quit()
