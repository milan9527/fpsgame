extends CanvasLayer

signal leaderboard_requested(endpoint: String)
signal solo_requested
signal online_requested(username: String, password: String, register: bool, endpoint: String)
signal leave_requested
signal quit_requested
signal quit_without_save_requested
signal local_history_requested
signal volume_changed(value: float)
signal sensitivity_changed(value: float)
signal pause_changed(enabled: bool)
signal checkpoint_save_requested
signal checkpoint_resume_requested
var checkpoint_save_button: Button
var checkpoint_resume_button: Button
signal connection_cancel_requested
var connection_cancel: Button
signal inventory_changed(enabled: bool)
signal map_changed(enabled: bool)
var inventory
var tactical_map
var waypoint_label: Label
var pause_description: Label
var feedback_pause_time := -1
var menu: Control
var hud: Control
var pause_panel: Control
var status: Label
var headline: Label
var stats: Label
var weapon: Label
var prompt: Label
var feed: Label
var result_label: Label
var username: LineEdit
var password: LineEdit
var endpoint: LineEdit
var health_bar: ProgressBar
var loadout_label: Label
var armor_bar: ProgressBar
var radar: Control
var local_position := Vector3.ZERO
var local_yaw := 0.0
var radius := 110.0
var zone_info: Dictionary = {}
const Bindings = preload("res://scripts/control_bindings.gd")
var bindings
var controls
var controls_hint: Label
var sensitivity := 0.0022
var volume := 0.65
var settings := ConfigFile.new()
var busy := false
var grenade_warning_distance := INF
var hit_until := 0
var damage_until := 0
var hit_color := Color.WHITE
var damage_source := Vector3.ZERO
var hit_text: Label
var leaderboard_panel: Control
var leaderboard_label: Label
var scoreboard_panel: Control
var scoreboard_label: Label
var local_history_panel: PanelContainer
var local_history_backdrop: ColorRect
var local_summary_label: Label
var local_warning_label: Label
var local_history_grid: GridContainer
var local_exit_button: Button
var spectating := false
var sight_aiming := false
var weapon_blocked := false
var supply_prompt := ""
var spectator_label: Label
const INK := Color("0c1721")
const ACCENT := Color("e2b875")

func _ready() -> void:
	settings.load("user://settings.cfg")
	sensitivity = settings.get_value("controls", "sensitivity", 0.0022)
	volume = settings.get_value("audio", "volume", 0.65)
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("e0e9e8"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("29404a") if state == "hover" else Color("192c38")
		box.border_color = ACCENT if state == "focus" else Color("49616a")
		box.set_border_width_all(1)
		box.set_content_margin_all(12)
		theme.set_stylebox(state, "Button", box)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.theme = theme
	add_child(menu)
	var background := ColorRect.new()
	background.color = Color(0.025, 0.055, 0.078, 0.88)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	menu.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 70)
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	row.add_child(left)
	label(left, "M E R I D I A N   /   F I E L D   O P E R A T I O N S", 16, ACCENT)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	left.add_child(spacer)
	label(left, "IRON\nMERIDIAN", 64, Color("eef3ea"))
	label(left, "THE LAST SIGNAL", 25, ACCENT)
	label(left, "Enter the exclusion zone.\nScavenge. Adapt. Be the last operator standing.", 20)
	label(left, "01  /  ASH VALLEY\n16 operators · shrinking combat zone\nOriginal tactical survival FPS", 16, Color("8ca6ad"))
	var history_buttons := HBoxContainer.new()
	left.add_child(history_buttons)
	button(history_buttons, "SERVICE LEADERBOARD", func(): leaderboard_requested.emit(endpoint.text.trim_suffix("/")))
	button(history_buttons, "LOCAL OPERATIONS", func(): local_history_requested.emit())
	checkpoint_resume_button = Button.new()
	checkpoint_resume_button.text = "CONTINUE SAVED OPERATION"
	checkpoint_resume_button.pressed.connect(func(): checkpoint_resume_requested.emit())
	left.add_child(checkpoint_resume_button)
	button(left, "KEYBOARD CONTROLS", func(): controls.open())
	var bottom := Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(bottom)
	controls_hint = label(left, "WASD  Move    •    SHIFT  Sprint    •    SPACE  Jump\nR  Reload    •    E  Loot    •    H  Heal\n1/2/3  Weapons    •    RMB  Aim    •    ESC  Menu\nB  Inventory    •    M  Map    •    G  Frag    •    Z/C  Lean\nV  Smoke grenade", 16, Color("b7c6c8"))
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 390
	right.add_theme_constant_override("separation", 13)
	row.add_child(right)
	label(right, "DEPLOYMENT", 26, ACCENT)
	button(right, "SOLO  /  OFFLINE OPERATION", func(): solo_requested.emit())
	label(right, "ONLINE ACCOUNT", 16, Color("9aafb4"))
	username = field(right, "Username (3–24 letters / digits)", "")
	password = field(right, "Password (at least 10 characters)", "")
	password.secret = true
	endpoint = field(right, "API URL", settings.get_value("network", "endpoint", "http://127.0.0.1:8000"))
	var connection_row := HBoxContainer.new()
	right.add_child(connection_row)
	button(connection_row, "SIGN IN & DEPLOY", func(): online(false))
	connection_cancel = Button.new()
	connection_cancel.text = "CANCEL"
	connection_cancel.disabled = true
	connection_cancel.pressed.connect(func(): connection_cancel_requested.emit())
	connection_row.add_child(connection_cancel)
	button(right, "CREATE ACCOUNT & DEPLOY", func(): online(true))
	status = label(right, "Offline operations need no account or connection.", 15, Color("9aafb4"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 65
	label(right, "FIELD SETTINGS", 16, ACCENT)
	label(right, "Mouse sensitivity", 14)
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.006
	sens.step = 0.0001
	sens.value = sensitivity
	right.add_child(sens)
	sens.value_changed.connect(func(v): sensitivity = v; sensitivity_changed.emit(v); save_settings())
	label(right, "Master volume", 14)
	var vol := HSlider.new()
	vol.min_value = 0
	vol.max_value = 1
	vol.step = 0.01
	vol.value = volume
	right.add_child(vol)
	vol.value_changed.connect(func(v): volume = v; volume_changed.emit(v); save_settings())
	button(right, "EXIT TO DESKTOP", func(): quit_requested.emit())
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = theme
	add_child(hud)
	hud.draw.connect(draw_hud)
	headline = placed_label(hud, Vector2(40, 28), 23, ACCENT)
	stats = placed_label(hud, Vector2(40, 66), 17)
	weapon = placed_label(hud, Vector2(40, 750), 23)
	loadout_label = placed_label(hud, Vector2(40, 779), 14)
	waypoint_label = placed_label(hud, Vector2(540, 80), 16, Color("f6a77a"))
	health_bar = bar(Vector2(40, 800), Color("77c9b0"))
	armor_bar = bar(Vector2(40, 829), Color("7ebce4"))
	prompt = placed_label(hud, Vector2(480, 735), 18, ACCENT)
	feed = placed_label(hud, Vector2(40, 118), 16)
	hit_text = placed_label(hud, Vector2(610, 505), 16, ACCENT)
	result_label = placed_label(hud, Vector2(430, 290), 38, ACCENT)
	spectator_label = placed_label(hud, Vector2(430, 140), 22, ACCENT)
	hud.visible = false
	inventory = preload("res://scripts/inventory_panel.gd").new()
	inventory.theme = theme
	add_child(inventory)
	inventory.close_requested.connect(func(): set_inventory(false))
	tactical_map = preload("res://scripts/tactical_map.gd").new()
	tactical_map.theme = theme
	add_child(tactical_map)
	tactical_map.close_requested.connect(func(): set_map(false))
	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2(480, 290)
	pause_panel.size = Vector2(460, 250)
	pause_panel.theme = theme
	add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_panel.add_child(pause_box)
	label(pause_box, "FIELD MENU", 28, ACCENT)
	pause_description = label(pause_box, "Operation paused.", 16)
	pause_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(pause_box, "KEYBOARD CONTROLS", func(): controls.open())
	button(pause_box, "RESUME", func(): set_pause(false))
	checkpoint_save_button = Button.new()
	checkpoint_save_button.text = "SAVE OPERATION & RETURN"
	checkpoint_save_button.pressed.connect(func(): checkpoint_save_requested.emit())
	pause_box.add_child(checkpoint_save_button)
	checkpoint_save_button.hide()
	button(pause_box, "ABANDON / RETURN TO DEPLOYMENT", func(): leave_requested.emit())
	pause_panel.visible = false
	leaderboard_panel = PanelContainer.new()
	leaderboard_panel.position = Vector2(320, 100)
	leaderboard_panel.size = Vector2(800, 680)
	leaderboard_panel.theme = theme
	add_child(leaderboard_panel)
	var leader_box := VBoxContainer.new()
	leader_box.add_theme_constant_override("separation", 18)
	leaderboard_panel.add_child(leader_box)
	label(leader_box, "SERVICE LEADERBOARD", 30, ACCENT)
	leaderboard_label = label(leader_box, "", 21)
	leaderboard_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button(leader_box, "BACK", func(): leaderboard_panel.visible = false)
	leaderboard_panel.visible = false
	scoreboard_panel = PanelContainer.new()
	scoreboard_panel.position = Vector2(390, 120)
	scoreboard_panel.size = Vector2(660, 660)
	scoreboard_panel.theme = theme
	add_child(scoreboard_panel)
	scoreboard_label = label(scoreboard_panel, "", 21)
	scoreboard_panel.visible = false
	local_history_backdrop = ColorRect.new()
	local_history_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	local_history_backdrop.color = Color(0, 0, 0, 0.6)
	add_child(local_history_backdrop)
	local_history_backdrop.visible = false
	local_history_panel = PanelContainer.new()
	local_history_panel.position = Vector2(300, 90)
	local_history_panel.size = Vector2(840, 710)
	local_history_panel.theme = theme
	var local_style := StyleBoxFlat.new()
	local_style.bg_color = Color("0c1721")
	local_style.border_color = Color("49616a")
	local_style.set_border_width_all(1)
	local_style.set_content_margin_all(20)
	local_history_panel.add_theme_stylebox_override("panel", local_style)
	add_child(local_history_panel)
	var local_box := VBoxContainer.new()
	local_box.add_theme_constant_override("separation", 14)
	local_history_panel.add_child(local_box)
	label(local_box, "LOCAL OPERATIONS", 30, ACCENT)
	label(local_box, "Results on this device. Separate from the online leaderboard.", 16)
	label(local_box, "Latest 100 operations. Totals include all readable local results.", 14)
	local_summary_label = label(local_box, "", 20)
	local_warning_label = label(local_box, "", 16, Color("efad75"))
	local_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	local_box.add_child(scroll)
	local_history_grid = GridContainer.new()
	local_history_grid.columns = 4
	local_history_grid.add_theme_constant_override("h_separation", 30)
	local_history_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(local_history_grid)
	button(local_box, "REFRESH / RETRY SAVE", func(): local_history_requested.emit())
	local_exit_button = Button.new()
	local_exit_button.text = "EXIT WITHOUT SAVING PENDING RESULTS"
	local_exit_button.pressed.connect(func(): quit_without_save_requested.emit())
	local_box.add_child(local_exit_button)
	local_exit_button.visible = false
	button(local_box, "BACK", hide_local_history)
	local_history_panel.visible = false
	if bindings == null:
		bindings = Bindings.new()
	controls = preload("res://scripts/controls_panel.gd").new()
	controls.bindings = bindings
	controls.theme = theme
	add_child(controls)
	controls.changed.connect(update_controls_hint)
	controls.closed.connect(update_controls_hint)
	update_controls_hint()

func update_controls_hint() -> void:
	controls_hint.text = "%s/%s/%s/%s  Move   •   %s  Sprint   •   %s  Jump\n%s  Reload   •   %s  Loot   •   %s  Heal\n%s/%s/%s  Weapons   •   RMB  Aim   •   ESC  Menu\n%s  Inventory   •   %s  Map   •   %s  Frag\n%s/%s  Lean   •   %s  Smoke" % [Bindings.key_label("forward"), Bindings.key_label("back"), Bindings.key_label("left"), Bindings.key_label("right"), Bindings.key_label("sprint"), Bindings.key_label("jump"), Bindings.key_label("reload"), Bindings.key_label("loot"), Bindings.key_label("heal"), Bindings.key_label("weapon1"), Bindings.key_label("weapon2"), Bindings.key_label("weapon3"), Bindings.key_label("inventory"), Bindings.key_label("map"), Bindings.key_label("throw"), Bindings.key_label("lean_left"), Bindings.key_label("lean_right"), Bindings.key_label("smoke_throw")]

func label(parent: Node, text: String, font_size: int, color := Color("e0e9e8")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func placed_label(parent: Node, at: Vector2, font_size: int, color := Color("e0e9e8")) -> Label:
	var l := label(parent, "", font_size, color)
	l.position = at
	return l

func button(parent: Node, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 48
	b.pressed.connect(action)
	parent.add_child(b)

func field(parent: Node, placeholder: String, value: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = value
	edit.custom_minimum_size.y = 44
	parent.add_child(edit)
	return edit

func bar(at: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = at
	b.size = Vector2(320, 20)
	b.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = color
	b.add_theme_stylebox_override("fill", style)
	hud.add_child(b)
	return b

func online(register: bool) -> void:
	if busy:
		return
	busy = true
	connection_cancel.disabled = false
	status.text = "Connecting to operations service…"
	save_settings()
	online_requested.emit(username.text, password.text, register, endpoint.text.trim_suffix("/"))

func save_settings() -> void:
	settings.set_value("controls", "sensitivity", sensitivity)
	settings.set_value("audio", "volume", volume)
	if endpoint:
		settings.set_value("network", "endpoint", endpoint.text)
	settings.save("user://settings.cfg")

func show_menu(message := "") -> void:
	controls.close()
	set_map(false)
	tactical_map.waypoint = null
	set_inventory(false)
	menu.visible = true
	leaderboard_panel.visible = false
	hide_local_history()
	scoreboard_panel.visible = false
	hud.visible = false
	pause_panel.visible = false
	busy = false
	connection_cancel.disabled = true
	password.text = ""
	if not message.is_empty():
		status.text = message
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_game() -> void:
	controls.close()
	set_map(false)
	tactical_map.waypoint = null
	set_inventory(false)
	feedback_pause_time = -1
	pause_panel.visible = false
	hit_until = 0
	damage_until = 0
	hit_text.text = ""
	menu.visible = false
	hide_local_history()
	hud.visible = true
	busy = false
	connection_cancel.disabled = true
	password.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_pause(enabled: bool) -> void:
	if enabled:
		set_map(false)
		set_inventory(false)
	pause_panel.visible = enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED
	pause_changed.emit(enabled)

func set_inventory(enabled: bool) -> void:
	if enabled:
		set_map(false)
	inventory.visible = enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED
	inventory_changed.emit(enabled)

func set_map(enabled: bool) -> void:
	if enabled:
		set_inventory(false)
	tactical_map.visible = enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED
	map_changed.emit(enabled)

func pause_feedback(enabled: bool) -> void:
	var now := Time.get_ticks_msec()
	if enabled and feedback_pause_time < 0:
		feedback_pause_time = now
	elif not enabled and feedback_pause_time >= 0:
		if hit_until > feedback_pause_time:
			hit_until += now - feedback_pause_time
		if damage_until > feedback_pause_time:
			damage_until += now - feedback_pause_time
		feedback_pause_time = -1

func draw_hud() -> void:
	var center := hud.size / 2
	var white := Color(0.9, 0.95, 0.92, 0.85)
	if not spectating and weapon_blocked:
		hud.draw_arc(center, 12, 0, TAU, 24, ACCENT, 2)
		hud.draw_line(center + Vector2(-8, 8), center + Vector2(8, -8), ACCENT, 2)
	elif not spectating and not sight_aiming:
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			hud.draw_line(center + direction * 5, center + direction * 12, white, 2)
	var now := feedback_pause_time if feedback_pause_time >= 0 else Time.get_ticks_msec()
	if now < hit_until:
		for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			hud.draw_line(center + direction * 10, center + direction * 17, hit_color, 2)
	else:
		hit_text.text = ""
	if now < damage_until:
		var opacity := float(damage_until - now) / 600.0
		hud.draw_rect(Rect2(Vector2.ZERO, hud.size), Color(0.85, 0.1, 0.05, opacity * 0.5), false, 12)
		var direction := damage_source - local_position
		if direction.length() > 0.5:
			var angle := -PI / 2 - (atan2(-direction.x, -direction.z) - local_yaw)
			hud.draw_arc(center, 62, angle - 0.25, angle + 0.25, 12, Color(1, 0.2, 0.1, opacity), 5)
	var radar_center := Vector2(hud.size.x - 120, 120)
	hud.draw_circle(radar_center, 88, Color(0.03, 0.08, 0.11, 0.85))
	hud.draw_arc(radar_center + zone_info.get("center", Vector2.ZERO) * 0.72, radius * 0.72, 0, TAU, 64, Color("72bbd9"), 2)
	if not zone_info.is_empty():
		hud.draw_arc(radar_center + zone_info.next_center * 0.72, zone_info.next_radius * 0.72, 0, TAU, 64, Color.WHITE, 1)
	hud.draw_line(radar_center + Vector2(-80, 0), radar_center + Vector2(80, 0), Color("49606a"), 7)
	hud.draw_line(radar_center + Vector2(0, -80), radar_center + Vector2(0, 80), Color("49606a"), 7)
	var p := radar_center + Vector2(local_position.x, local_position.z) * 0.72
	hud.draw_circle(p, 4, ACCENT)
	hud.draw_line(p, p + Vector2(-sin(local_yaw), -cos(local_yaw)) * 13, ACCENT, 2)
	if tactical_map.waypoint is Vector2 and not spectating:
		var target: Vector2 = radar_center + (tactical_map.waypoint * 0.72).limit_length(80)
		hud.draw_circle(target, 5, tactical_map.MARKER, false, 2)

func update_hud(actor, alive_count: int, phase: String, time_left: float, zone: float, events: Array, message: String, circle: Dictionary = {}) -> void:
	weapon_blocked = actor.weapon_blocked
	headline.text = "ASH VALLEY   /   " + phase.to_upper()
	stats.text = "%02d ALIVE    •    %02d ELIMINATIONS    •    ZONE %dm    •    %02d:%02d" % [alive_count, actor.kills, zone, int(time_left) / 60, int(time_left) % 60]
	if not circle.is_empty() and phase == "live":
		headline.text += "   /   ZONE %d · %s %ds" % [circle.stage, "SHRINKING" if circle.moving else "CLOSES IN", ceili(circle.remaining)]
	weapon.text = "%s    %02d / %03d" % [actor.NAMES[actor.weapon], actor.ammo, actor.reserve]
	loadout_label.text = "%s  AR %02d   |   %s  SG %02d   |   %s  SR %02d" % [Bindings.key_label("weapon1"), actor.magazines[0], Bindings.key_label("weapon2"), actor.magazines[1], Bindings.key_label("weapon3"), actor.magazines[2]]
	if actor.crouched:
		weapon.text += "  [CROUCHED]"
	if absf(actor.lean) > 0.05:
		weapon.text += "  [LEAN L]" if actor.lean < 0 else "  [LEAN R]"
	health_bar.value = actor.health
	armor_bar.value = actor.armor
	prompt.text = ("%s  Medkit ×%d   |   %s  Frag ×%d   |   %s  Smoke ×%d" % [Bindings.key_label("heal"), actor.medkits, Bindings.key_label("throw"), actor.grenades, Bindings.key_label("smoke_throw"), actor.smokes]) if supply_prompt == "" else supply_prompt
	if actor.throw_left > 0:
		prompt.text = "THROWING GRENADE"
	elif actor.reload_left > 0:
		prompt.text = "RELOADING   %.1fs" % actor.reload_left
	elif actor.heal_left > 0:
		prompt.text = "APPLYING MEDKIT   %.1fs" % actor.heal_left
	elif Vector2(actor.position.x, actor.position.z).distance_to(circle.get("center", Vector2.ZERO)) > zone:
		prompt.text = "WARNING  /  RETURN TO THE SAFE ZONE"
	elif actor.weapon_blocked and not spectating:
		prompt.text = "MUZZLE BLOCKED / STEP BACK OR REPOSITION"
	elif actor.ammo == 0 and not spectating:
		prompt.text = Bindings.key_label("reload") + "  RELOAD / EMPTY MAGAZINE" if actor.reserve > 0 else "NO RESERVE AMMUNITION / FIND SUPPLIES"
	if grenade_warning_distance < 9:
		prompt.text = "FRAG NEARBY / %dm — MOVE TO COVER" % ceili(grenade_warning_distance)
	feed.text = "\n".join(events)
	result_label.text = message
	local_position = actor.position
	local_yaw = actor.yaw
	radius = zone
	zone_info = circle
	tactical_map.refresh(actor.position, actor.yaw, zone, time_left, circle)
	waypoint_label.visible = tactical_map.waypoint is Vector2 and not spectating
	if waypoint_label.visible:
		var distance: float = Vector2(actor.position.x, actor.position.z).distance_to(tactical_map.waypoint)
		waypoint_label.text = "WAYPOINT  %dm  /  %s MAP" % [roundi(distance), Bindings.key_label("map")]
	hud.queue_redraw()

func set_spectator(enabled: bool, nickname: String, placement: int) -> void:
	spectating = enabled
	spectator_label.visible = enabled
	if enabled:
		spectator_label.text = "SPECTATING  /  " + (nickname if nickname != "" else "AWAITING RESULT")
		spectator_label.text += "\nYOUR PLACEMENT  #%d" % placement
		prompt.text = "%s / %s  Switch operator   |   Mouse  Orbit   |   Wheel  Zoom   |   ESC  Menu" % [Bindings.key_label("spectate_previous"), Bindings.key_label("spectate_next")]
		hit_until = 0
		damage_until = 0
		hit_text.text = ""

func show_leaderboard(rows: Array, profile: Dictionary = {}) -> void:
	leaderboard_panel.visible = true
	var lines := PackedStringArray()
	if not profile.is_empty():
		lines.append("YOU / %s  ·  %d wins  ·  %d eliminations" % [profile.username, profile.wins, profile.kills])
	lines.append("RANK       OPERATOR                     WINS / KILLS")
	for i in range(mini(15, rows.size())):
		var row: Dictionary = rows[i]
		lines.append("%02d          %-24s  %d / %d" % [i + 1, row.username, row.wins, row.kills])
	if rows.is_empty():
		lines.append("No recorded operations yet.")
	leaderboard_label.text = "\n".join(lines)

func update_scoreboard(roster: Array, enabled: bool) -> void:
	scoreboard_panel.visible = enabled
	if not enabled:
		return
	roster.sort_custom(func(a, b): return a.kills > b.kills)
	var lines := PackedStringArray(["FIELD ROSTER  /  HOLD " + Bindings.key_label("scoreboard"), "", "OPERATOR                         KILLS     STATUS"])
	for actor in roster:
		lines.append("%-24s      %02d        %s" % [actor.display_name, actor.kills, "LIVE" if actor.alive else "OUT"])
	scoreboard_label.text = "\n".join(lines)

func show_local_history(summary: Dictionary) -> void:
	local_history_panel.visible = true
	local_history_backdrop.visible = true
	local_summary_label.text = "%d COMPLETED   /   %d ABANDONED   /   %d WINS\n%d ELIMINATIONS   /   %d MINUTES PLAYED" % [summary.completed, summary.abandoned, summary.wins, summary.kills, int(summary.seconds) / 60]
	var warnings := PackedStringArray()
	if summary.get("read_error", "") != "":
		warnings.append(summary.read_error)
	if summary.get("pending", 0) > 0:
		warnings.append("%d result(s) not saved. %s Use Retry Save before exiting." % [summary.pending, summary.get("save_error", "")])
	if summary.recovered > 0:
		warnings.append("%d result(s) recovered from a backup copy." % summary.recovered)
	if summary.unreadable > 0:
		warnings.append("%d unreadable result(s) preserved on disk; totals exclude them." % summary.unreadable)
	if summary.newer > 0:
		warnings.append("%d result(s) require a newer game version; totals exclude them." % summary.newer)
	local_warning_label.text = "\n".join(warnings)
	if summary.get("pending", 0) == 0:
		local_exit_button.visible = false
	for child in local_history_grid.get_children():
		local_history_grid.remove_child(child)
		child.queue_free()
	for heading in ["DATE (UTC)", "PLACEMENT", "ELIMINATIONS", "DURATION"]:
		label(local_history_grid, heading, 16, ACCENT)
	for record in summary.records.slice(0, 100):
		label(local_history_grid, Time.get_datetime_string_from_unix_time(int(record.finished_at), true).left(16), 16)
		label(local_history_grid, "#%d" % record.rank if record.status == "completed" else "ABANDONED", 16)
		label(local_history_grid, str(int(record.kills)), 16)
		label(local_history_grid, "%02d:%02d" % [int(record.seconds) / 60, int(record.seconds) % 60], 16)
	if summary.records.is_empty():
		label(local_history_grid, "No local operations recorded yet.", 16)

func hide_local_history() -> void:
	local_history_panel.visible = false
	local_history_backdrop.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if local_history_panel.visible and event.is_action_pressed("pause"):
		hide_local_history()
		get_viewport().set_input_as_handled()

func combat_feedback(kind: int, amount: float, headshot: bool, killed: bool, origin: Vector3) -> void:
	if kind == 0:
		hit_until = Time.get_ticks_msec() + (650 if killed else 300)
		hit_color = Color("ef7959") if killed else (ACCENT if headshot else Color.WHITE)
		hit_text.text = "ELIMINATED" if killed else ("HEADSHOT" if headshot else "HIT %d" % roundi(amount))
	else:
		damage_until = Time.get_ticks_msec() + 600
		damage_source = origin
	hud.queue_redraw()
