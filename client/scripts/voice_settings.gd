extends PanelContainer

signal changed
var device := "Default"
var gain := 1.0
var testing := false
var devices: OptionButton
var meter: ProgressBar
var status: Label
var hold: Button
var backdrop: ColorRect

func _ready() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.45)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().add_child.call_deferred(backdrop)
	call_deferred("place_backdrop")
	visibility_changed.connect(func():
		backdrop.visible = is_visible_in_tree()
		set_process_input(is_visible_in_tree())
	)
	position = Vector2(450, 200)
	custom_minimum_size = Vector2(540, 380)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e27")
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = "MICROPHONE SETUP"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	devices = OptionButton.new()
	box.add_child(devices)
	devices.item_selected.connect(func(index): device = devices.get_item_text(index); testing = false; changed.emit())
	var refresh := Button.new()
	refresh.text = "REFRESH INPUT DEVICES"
	refresh.pressed.connect(refresh_devices)
	box.add_child(refresh)
	var gain_label := Label.new()
	gain_label.text = "Input gain (0.25–4×)"
	box.add_child(gain_label)
	var slider := HSlider.new()
	slider.min_value = 0.25
	slider.max_value = 4
	slider.step = 0.05
	slider.value = gain
	slider.value_changed.connect(func(value): gain = value; changed.emit())
	box.add_child(slider)
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 24
	meter.show_percentage = false
	box.add_child(meter)
	status = Label.new()
	status.text = "Hold below to check input. No audio is sent."
	box.add_child(status)
	hold = Button.new()
	hold.text = "HOLD TO TEST MICROPHONE"
	hold.button_down.connect(func(): testing = true)
	hold.button_up.connect(func(): testing = false)
	box.add_child(hold)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(close)
	box.add_child(back)
	refresh_devices()
	hide()
	set_process_input(false)

func place_backdrop() -> void:
	get_parent().move_child(backdrop, get_index())
	backdrop.visible = visible

func _exit_tree() -> void:
	if is_instance_valid(backdrop):
		backdrop.queue_free()

func refresh_devices() -> void:
	testing = false
	devices.clear()
	var available := AudioServer.get_input_device_list()
	if available.is_empty():
		available.append("Default")
	if not device in available:
		device = "Default" if "Default" in available else available[0]
	for value in available:
		devices.add_item(value)
		if value == device:
			devices.select(devices.item_count - 1)
	changed.emit()

func open() -> void:
	refresh_devices()
	update_level(0, false, false, 0)
	show()

func close() -> void:
	testing = false
	hide()

func update_level(peak: float, clipped: bool, active: bool, signal_at: int) -> void:
	meter.value = peak * 100 if active else 0
	if not active:
		status.text = "Hold below to check input. No audio is sent."
	elif clipped:
		status.text = "Input clipping — reduce gain."
	elif signal_at > 0 and Time.get_ticks_msec() - signal_at < 1000:
		status.text = "Input detected. Test audio stays on this device."
	else:
		status.text = "No input detected — check device and permissions."

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
