extends Control
## Touch-only presentation; commands still use the game's authoritative input path.

var game
var gyro := preload("res://scripts/gyro_aim.gd").new()
var gyro_panel: Control
var gyro_status: Label
var gyro_readings_seen := false
var app_focused := true
var fingers := {}
var toggles := {}
var buttons := {}
var stick := Vector2.ZERO
var stick_center := Vector2.ZERO
var menu_panel: Control
var pause_panel: Control
var username: LineEdit
var password: LineEdit
var endpoint: LineEdit
var mode: OptionButton
var status: Label
var login_buttons: Array[Button] = []
var last_size := Vector2.ZERO
var last_playing := false
var menu_was_visible := false
var save_button: Button
var previous_mouse_emulation := true
var last_alive := true
var voice_requested := false
var microphone_permission_granted := false
const MICROPHONE_PERMISSION := "android.permission.RECORD_AUDIO"
const TOGGLES := ["aim", "crouch", "sprint", "lean_left", "lean_right"]
const SPECIAL := ["pause", "inventory", "map", "spectate_next", "spectate_previous"]

func bind(target) -> void:
	game = target
	refresh_microphone_permission()
	get_tree().on_request_permissions_result.connect(microphone_permission_result)
	previous_mouse_emulation = Input.emulate_mouse_from_touch
	name = "MobileControls"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_gyro_settings()
	build_menu()
	build_pause()
	build_gyro_settings()
	game.ui.pause_changed.connect(func(_value): release_all())
	game.ui.inventory_changed.connect(func(_value): release_all())
	game.ui.map_changed.connect(func(_value): release_all())
	get_tree().quit_on_go_back = false
	for action in ["left", "right", "forward", "back"]:
		InputMap.action_set_deadzone(action, 0.12)
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func panel() -> PanelContainer:
	var result := PanelContainer.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101f29")
	style.set_content_margin_all(36)
	result.add_theme_stylebox_override("panel", style)
	var theme := Theme.new()
	theme.default_font_size = 26
	result.theme = theme
	add_child(result)
	return result

func button(parent: Node, text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 88
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func label(parent: Node, text: String, font_size := 26) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	return result

func field(parent: Node, placeholder: String) -> LineEdit:
	var result := LineEdit.new()
	result.placeholder_text = placeholder
	result.custom_minimum_size = Vector2(0, 80)
	parent.add_child(result)
	return result

func build_menu() -> void:
	menu_panel = panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	menu_panel.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.add_theme_constant_override("separation", 18)
	row.add_child(left)
	label(left, "IRON MERIDIAN", 44)
	label(left, "ANDROID  /  ASH VALLEY", 24)
	label(left, "Offline play needs no account.", 24)
	button(left, "SOLO  /  OFFLINE", func(): game.start_solo("solo"))
	button(left, "DUO  /  OFFLINE", func(): game.start_solo("duo"))
	button(left, "BASIC TRAINING", func(): game.start_training())
	button(left, "CONTINUE SAVED GAME", func(): game.resume_solo())
	button(left, "GYROSCOPE", func(): show_gyro_settings(true))
	label(left, "Left thumb: move\nRight side: look\nDrag FIRE to aim while shooting", 24)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.2
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	label(right, "ONLINE ACCOUNT", 32)
	username = field(right, "Username")
	username.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	password = field(right, "Password (10+ characters)")
	password.secret = true
	password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	endpoint = field(right, "HTTPS server address")
	endpoint.text = game.ui.endpoint.text
	endpoint.text_changed.connect(func(_value): restore_login())
	restore_login()
	endpoint.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	mode = OptionButton.new()
	mode.custom_minimum_size.y = 72
	for text in ["SOLO", "DUO", "TEAM LOBBY"]:
		mode.add_item(text)
	right.add_child(mode)
	var actions := HBoxContainer.new()
	right.add_child(actions)
	login_buttons.append(button(actions, "SIGN IN", func(): sign_in(false)))
	login_buttons.append(button(actions, "REGISTER", func(): sign_in(true)))
	var account_tools := HBoxContainer.new()
	right.add_child(account_tools)
	button(account_tools, "CANCEL", func(): game.leave("Connection cancelled."))
	button(account_tools, "FORGET LOGIN", func():
		game.ui.endpoint.text = endpoint.text
		game.ui.forget_login()
		restore_login())
	status = label(right, "", 22)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 100

func restore_login() -> void:
	var saved := preload("res://scripts/remembered_login.gd").read(endpoint.text)
	username.text = saved.username
	password.text = saved.password

func sign_in(register: bool) -> void:
	if game.ui.busy:
		return
	game.ui.username.text = username.text
	game.ui.password.text = password.text
	game.ui.endpoint.text = endpoint.text
	game.ui.save_settings()
	if mode.selected == 2:
		game.sign_in(username.text, password.text, register, endpoint.text, "party")
	else:
		game.sign_in(username.text, password.text, register, endpoint.text, "duo" if mode.selected == 1 else "solo")

func build_pause() -> void:
	pause_panel = panel()
	var center := CenterContainer.new()
	pause_panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 650
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	label(box, "FIELD MENU", 38)
	button(box, "RESUME", func(): game.ui.set_pause(false))
	save_button = button(box, "SAVE GAME & RETURN", func(): game.suspend_solo())
	button(box, "RETURN TO MAIN MENU", func(): game.leave())
	button(box, "GYROSCOPE", func(): show_gyro_settings(true))
	var voice := CheckButton.new()
	voice.text = "Team voice: listen and enable microphone"
	voice.custom_minimum_size.y = 88
	voice.toggled.connect(func(enabled):
		voice_requested = enabled
		game.ui.voice_listen = enabled
		if enabled and OS.has_feature("android"):
			OS.request_permission(MICROPHONE_PERMISSION)
		refresh_microphone_permission()
		game.ui.save_settings())
	box.add_child(voice)
	label(box, "Hold TALK in a duo match to speak.\nOnline matches continue while this menu is open.", 24)

func modal() -> bool:
	return (gyro_panel != null and gyro_panel.visible) or game.ui.pause_panel.visible or game.ui.inventory.visible or game.ui.tactical_map.visible or game.ui.controls.visible

func playing() -> bool:
	return game != null and game.running and not game.ui.menu.visible and not modal()

func refresh_microphone_permission() -> void:
	# Query the platform only at permission/lifecycle boundaries, not each frame.
	microphone_permission_granted = not OS.has_feature("android") or MICROPHONE_PERMISSION in OS.get_granted_permissions()

func microphone_permission_result(permission: String, granted: bool) -> void:
	if permission == MICROPHONE_PERMISSION:
		microphone_permission_granted = granted

func _process(delta: float) -> void:
	if game == null:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.ui.voice_microphone = voice_requested and microphone_permission_granted
	var show_menu: bool = game.ui.menu.visible and not game.ui.party_lobby.visible
	if menu_panel.visible != show_menu:
		menu_panel.visible = show_menu
	if menu_panel.visible and not menu_was_visible:
		restore_login()
	if not menu_panel.visible and not password.text.is_empty():
		password.text = ""
	menu_was_visible = menu_panel.visible
	if pause_panel.visible != game.ui.pause_panel.visible:
		pause_panel.visible = game.ui.pause_panel.visible
	# Refresh hidden menu content when it becomes visible. In duo matches the
	# save eligibility check scans living teams; gameplay never uses that button.
	if menu_panel.visible:
		if status.text != game.ui.status.text:
			status.text = game.ui.status.text
		for item in login_buttons:
			if item.disabled != game.ui.busy:
				item.disabled = game.ui.busy
	if pause_panel.visible:
		var show_save: bool = game.can_suspend_operation()
		if save_button.visible != show_save:
			save_button.visible = show_save
	var active := playing()
	var alive: bool = not game.actors.has(game.local_id) or game.actors[game.local_id].alive
	# GUI widgets need mouse emulation, but gameplay does not: an emulated left
	# mouse button would otherwise fire the weapon when touching the movement stick.
	if Input.emulate_mouse_from_touch != not active:
		Input.emulate_mouse_from_touch = not active
	if not active and last_playing:
		release_all()
	# State changes affect drawing and hit eligibility, not button geometry.
	# Avoid theme invalidation and rebuilding the button dictionary on pause,
	# resume or death when the viewport dimensions have not changed.
	var layout_changed := last_size != size or buttons.is_empty()
	if layout_changed:
		layout_buttons()
	if layout_changed or last_playing != active or last_alive != alive:
		queue_redraw()
	last_size = size
	last_playing = active
	last_alive = alive
	if OS.has_feature("android"):
		apply_gyro(Input.get_gyroscope(), delta)

func layout_buttons() -> void:
	var w := size.x
	var h := size.y
	game.ui.weapon.position = Vector2(32, h - 150)
	game.ui.weapon.add_theme_font_size_override("font_size", 18)
	game.ui.loadout_label.position = Vector2(32, h - 122)
	game.ui.loadout_label.add_theme_font_size_override("font_size", 12)
	game.ui.health_bar.position = Vector2(32, h - 88)
	game.ui.armor_bar.position = Vector2(32, h - 54)
	game.ui.health_bar.size.x = 240
	game.ui.armor_bar.size.x = 240
	game.ui.prompt.position = Vector2(w / 2 - 170, h - 275)
	game.ui.prompt.size.x = 340
	game.ui.prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stick_center = Vector2(180, h - 250)
	buttons = {
		"pause": [Rect2(w / 2 - 60, 20, 120, 76), "MENU"],
		"inventory": [Rect2(24, 155, 116, 80), "BAG"],
		"map": [Rect2(154, 155, 116, 80), "MAP"],
		"scoreboard": [Rect2(284, 155, 116, 80), "SCORE"],
		"sprint": [Rect2(80, h - 450, 120, 90), "RUN"],
		"crouch": [Rect2(315, h - 175, 110, 96), "CROUCH"],
		"lean_left": [Rect2(440, h - 175, 96, 96), "LEAN L"],
		"lean_right": [Rect2(550, h - 175, 96, 96), "LEAN R"],
		"weapon1": [Rect2(w / 2 - 170, h - 70, 100, 60), "AR"],
		"weapon2": [Rect2(w / 2 - 50, h - 70, 100, 60), "SG"],
		"weapon3": [Rect2(w / 2 + 70, h - 70, 100, 60), "SR"],
		"fire": [Rect2(w - 190, h - 340, 150, 150), "FIRE"],
		"aim": [Rect2(w - 345, h - 315, 116, 104), "AIM"],
		"jump": [Rect2(w - 185, h - 170, 132, 96), "JUMP"],
		"reload": [Rect2(w - 335, h - 170, 132, 96), "RELOAD"],
		"loot": [Rect2(w - 495, h - 310, 128, 104), "USE"],
		"heal": [Rect2(w - 495, h - 180, 128, 96), "HEAL"],
		"throw": [Rect2(w - 185, h - 470, 132, 96), "FRAG"],
		"smoke_throw": [Rect2(w - 335, h - 470, 132, 96), "SMOKE"],
		"push_to_talk": [Rect2(315, h - 310, 110, 96), "TALK"],
		"spectate_next": [Rect2(w / 2 + 150, 20, 160, 76), "NEXT VIEW"],
	}

func _input(event: InputEvent) -> void:
	if game == null or not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if event is InputEventScreenTouch and not event.pressed:
		if fingers.has(event.index):
			release_finger(event.index)
			get_viewport().set_input_as_handled()
		return
	# Existing inventory/map widgets retain normal touch-to-mouse UI interaction.
	if not playing():
		if game.running and not game.ui.menu.visible and not game.ui.pause_panel.visible:
			if event is InputEventScreenTouch and event.pressed and Rect2(size.x / 2 - 60, 20, 120, 76).has_point(event.position):
				special("pause")
				get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var action := ""
		for key in buttons:
			if key == "spectate_next" and last_alive:
				continue
			if buttons[key][0].has_point(event.position):
				action = key
				break
		if action.is_empty():
			action = "stick" if event.position.distance_to(stick_center) < 140 else "look"
		if action == "stick" and "stick" in fingers.values():
			action = "look"
		fingers[event.index] = action
		if action == "stick":
			move_stick(event.position)
		elif action in SPECIAL:
			special(action)
		elif action in TOGGLES:
			toggles[action] = not toggles.get(action, false)
			if toggles[action]:
				Input.action_press(action)
			else:
				Input.action_release(action)
		elif action != "look":
			Input.action_press(action)
		if action != "look":
			queue_redraw()
	else:
		if not fingers.has(event.index):
			return
		var action: String = fingers[event.index]
		if action == "stick":
			var previous_stick := stick
			move_stick(event.position)
			if stick != previous_stick:
				queue_redraw()
		elif action in ["look", "fire"]:
			look(event.relative)
		# Looking changes the camera, not the touch overlay. Keep its retained
		# draw commands until a button or the stick actually changes.
	get_viewport().set_input_as_handled()

func special(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)

func move_stick(point: Vector2) -> void:
	var next_stick := ((point - stick_center) / 105.0).limit_length()
	if next_stick == stick:
		return
	stick = next_stick
	if stick.length() < 0.12:
		for action in ["left", "right", "forward", "back"]:
			Input.action_release(action)
		return
	update_stick_action("left", maxf(0, -stick.x))
	update_stick_action("right", maxf(0, stick.x))
	update_stick_action("forward", maxf(0, -stick.y))
	update_stick_action("back", maxf(0, stick.y))

func update_stick_action(action: StringName, strength: float) -> void:
	# Zero-strength action_press still marks an action pressed. Release inactive
	# directions, and leave unchanged strengths alone to avoid redundant writes.
	if strength == 0.0:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	elif Input.get_action_strength(action) != strength:
		Input.action_press(action, strength)

func look(relative: Vector2) -> void:
	if not game.actors.has(game.local_id):
		return
	var actor = game.actors[game.local_id]
	if not actor.alive:
		game.spectator.orbit(relative, game.ui.sensitivity)
	elif actor.is_seated():
		actor.vehicle_camera.begin(actor.vehicle_ref.get_ref())
		actor.vehicle_camera.orbit(relative, game.ui.sensitivity)
	else:
		var sensitivity: float = game.ui.sensitivity * (0.55 if Input.is_action_pressed("aim") else 1.0)
		actor.yaw = wrapf(actor.yaw - relative.x * sensitivity, -PI, PI)
		actor.pitch = clampf(actor.pitch - relative.y * sensitivity, -1.45, 1.45)

func release_finger(index: int) -> void:
	var action: String = fingers[index]
	fingers.erase(index)
	if action == "stick":
		stick = Vector2.ZERO
		for key in ["left", "right", "forward", "back"]:
			Input.action_release(key)
	elif action not in TOGGLES and action not in SPECIAL and action != "look" and action not in fingers.values():
		Input.action_release(action)
	if action != "look":
		queue_redraw()

func release_all() -> void:
	for index in fingers.keys():
		release_finger(index)
	for action in toggles:
		Input.action_release(action)
	toggles.clear()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		app_focused = false
		gyro.reset()
		release_all()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		app_focused = true
		gyro.reset()
		refresh_microphone_permission()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and game != null:
		if gyro_panel != null and gyro_panel.visible:
			show_gyro_settings(false)
		elif game.running:
			special("pause")
		else:
			game.request_quit()

func _exit_tree() -> void:
	release_all()
	Input.emulate_mouse_from_touch = previous_mouse_emulation

func _draw() -> void:
	if game == null or game.ui.menu.visible or game.ui.pause_panel.visible:
		return
	var font := ThemeDB.fallback_font
	# Modal visibility is constant throughout this synchronous draw.
	var modal_visible := modal()
	for action in buttons:
		if action == "spectate_next" and game.actors.has(game.local_id) and game.actors[game.local_id].alive:
			continue
		if modal_visible and action != "pause":
			continue
		var box: Rect2 = buttons[action][0]
		var active := Input.is_action_pressed(action)
		draw_rect(box, Color(0.15, 0.25, 0.3, 0.85) if active else Color(0.05, 0.1, 0.14, 0.65))
		draw_rect(box, Color("d2c59c") if active else Color(0.75, 0.85, 0.86, 0.65), false, 2)
		draw_string(font, box.position + Vector2(8, box.size.y / 2 + 8), buttons[action][1], HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 16, 22, Color.WHITE)
	if not modal_visible:
		draw_circle(stick_center, 115, Color(0.04, 0.08, 0.12, 0.55))
		draw_arc(stick_center, 115, 0, TAU, 48, Color(0.8, 0.9, 0.9, 0.7), 3)
		draw_circle(stick_center + stick * 72, 44, Color(0.7, 0.8, 0.8, 0.7))

func load_gyro_settings() -> void:
	gyro.mode = clampi(int(game.ui.settings.get_value("gyro", "mode", 0)), 0, 2)
	var gain := float(game.ui.settings.get_value("gyro", "sensitivity", 1.0))
	gyro.sensitivity = clampf(gain, 0.1, 4.0) if is_finite(gain) else 1.0
	gyro.invert_x = game.ui.settings.get_value("gyro", "invert_x", false) == true
	gyro.invert_y = game.ui.settings.get_value("gyro", "invert_y", false) == true

func save_gyro_settings() -> void:
	game.ui.settings.set_value("gyro", "mode", gyro.mode)
	game.ui.settings.set_value("gyro", "sensitivity", gyro.sensitivity)
	game.ui.settings.set_value("gyro", "invert_x", gyro.invert_x)
	game.ui.settings.set_value("gyro", "invert_y", gyro.invert_y)
	game.ui.save_settings()
	gyro.reset()

func show_gyro_settings(value: bool) -> void:
	gyro_panel.visible = value
	release_all()
	gyro.reset()

func build_gyro_settings() -> void:
	gyro_panel = panel()
	var center := CenterContainer.new()
	gyro_panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 720
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	label(box, "GYROSCOPE AIM", 38)
	var selection := OptionButton.new()
	selection.custom_minimum_size.y = 80
	for text in ["OFF", "ADS ONLY", "ALWAYS"]:
		selection.add_item(text)
	selection.select(gyro.mode)
	selection.item_selected.connect(func(value): gyro.mode = value; save_gyro_settings())
	box.add_child(selection)
	var gain_label := label(box, "Sensitivity: %.1fx" % gyro.sensitivity)
	var slider := HSlider.new()
	slider.min_value = 0.1
	slider.max_value = 4.0
	slider.step = 0.1
	slider.value = gyro.sensitivity
	slider.custom_minimum_size.y = 60
	slider.value_changed.connect(func(value):
		gyro.sensitivity = value
		gain_label.text = "Sensitivity: %.1fx" % value
		save_gyro_settings())
	box.add_child(slider)
	for axis in ["Horizontal", "Vertical"]:
		var inverse := CheckButton.new()
		inverse.text = "Invert " + axis
		inverse.custom_minimum_size.y = 72
		inverse.button_pressed = gyro.invert_x if axis == "Horizontal" else gyro.invert_y
		inverse.toggled.connect(func(value):
			if axis == "Horizontal": gyro.invert_x = value
			else: gyro.invert_y = value
			save_gyro_settings())
		box.add_child(inverse)
	gyro_status = label(box, "", 22)
	update_gyro_status()
	gyro_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gyro_status.custom_minimum_size = Vector2(720, 100)
	button(box, "BACK", func(): show_gyro_settings(false))
	gyro_panel.hide()

func update_gyro_status() -> void:
	gyro_status.text = "Sensor readings received. Tilt the phone to aim.
Touch aiming remains available." if gyro_readings_seen else "Move the phone to check sensor readings.
A hardware gyroscope is required; touch aiming remains available."

func apply_gyro(rate: Vector3, delta: float) -> void:
	# Sensor availability only changes once; avoid dispatching a Label setter
	# every rendered frame, including while the settings panel is hidden.
	if not gyro_readings_seen and rate.is_finite() and rate.length_squared() > 0.000001:
		gyro_readings_seen = true
		update_gyro_status()
	var aiming := Input.is_action_pressed("aim")
	# Keep sensor detection above, but skip actor/UI eligibility queries when
	# this mode cannot move the camera. Clear smoothing before reactivation.
	if gyro.mode == gyro.Mode.OFF or (gyro.mode == gyro.Mode.ADS and not aiming):
		gyro.reset()
		return
	var actor = game.actors.get(game.local_id)
	var active: bool = app_focused and playing() and actor != null and actor.alive and not actor.downed and not actor.is_seated()
	var angle := gyro.step(rate, delta, active, aiming)
	if active:
		actor.yaw = wrapf(actor.yaw + angle.x, -PI, PI)
		actor.pitch = clampf(actor.pitch + angle.y, -1.45, 1.45)
