extends PanelContainer
signal closed
signal changed
var bindings
var pending := ""
var rows := {}
var status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := StyleBoxFlat.new()
	background.bg_color = Color("101e27")
	add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var title := Label.new()
	title.text = "KEYBOARD CONTROLS"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	status = Label.new()
	status.text = "Select an action, then press a key. Escape cancels capture. Mouse buttons remain fixed."
	box.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for action in bindings.DEFAULTS:
		var label := Label.new()
		label.text = action.replace("_", " ").to_upper()
		label.custom_minimum_size.x = 230
		grid.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(230, 42)
		button.disabled = action == "pause"
		button.pressed.connect(func(): pending = action; status.text = "Press a key for " + action + ". Escape cancels.")
		grid.add_child(button)
		rows[action] = button
	var reset := Button.new()
	reset.text = "RESTORE DEFAULT KEYS"
	reset.pressed.connect(func(): pending = ""; bindings.reset_defaults(); refresh(); changed.emit())
	box.add_child(reset)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(close)
	box.add_child(back)
	refresh()
	hide()

func refresh() -> void:
	for action in rows:
		rows[action].text = OS.get_keycode_string(bindings.keys[action]).to_upper()
	if bindings.message != "":
		status.text = bindings.message

func open() -> void:
	pending = ""
	refresh()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	pending = ""
	hide()
	for action in InputMap.get_actions():
		Input.action_release(action)
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		if pending != "":
			pending = ""
			status.text = "Key capture cancelled."
		else:
			close()
		get_viewport().set_input_as_handled()
	elif pending != "":
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if bindings.bind(pending, code):
			pending = ""
			changed.emit()
		refresh()
		get_viewport().set_input_as_handled()
