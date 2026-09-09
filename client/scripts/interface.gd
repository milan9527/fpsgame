extends CanvasLayer

signal leaderboard_requested(endpoint: String)
signal solo_requested
signal online_requested(username: String, password: String, register: bool, endpoint: String)
signal leave_requested
signal volume_changed(value: float)
signal sensitivity_changed(value: float)
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
var armor_bar: ProgressBar
var radar: Control
var local_position := Vector3.ZERO
var local_yaw := 0.0
var radius := 110.0
var sensitivity := 0.0022
var volume := 0.65
var settings := ConfigFile.new()
var busy := false
var leaderboard_panel: Control
var leaderboard_label: Label
var scoreboard_panel: Control
var scoreboard_label: Label
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
	left.add_theme_constant_override("separation", 20)
	row.add_child(left)
	label(left, "M E R I D I A N   /   F I E L D   O P E R A T I O N S", 16, ACCENT)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 80
	left.add_child(spacer)
	label(left, "IRON\nMERIDIAN", 76, Color("eef3ea"))
	label(left, "THE LAST SIGNAL", 25, ACCENT)
	label(left, "Enter the exclusion zone.\nScavenge. Adapt. Be the last operator standing.", 20)
	label(left, "01  /  ASH VALLEY\n16 operators · shrinking combat zone\nOriginal tactical survival FPS", 16, Color("8ca6ad"))
	button(left, "SERVICE LEADERBOARD", func(): leaderboard_requested.emit(endpoint.text.trim_suffix("/")))
	var bottom := Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(bottom)
	label(left, "WASD  Move    •    SHIFT  Sprint    •    SPACE  Jump\nR  Reload    •    E  Loot    •    H  Heal\n1/2/3  Weapons    •    RMB  Aim    •    ESC  Menu", 16, Color("b7c6c8"))
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
	button(right, "SIGN IN & DEPLOY", func(): online(false))
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
	button(right, "EXIT TO DESKTOP", func(): get_tree().quit())
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = theme
	add_child(hud)
	hud.draw.connect(draw_hud)
	headline = placed_label(hud, Vector2(40, 28), 23, ACCENT)
	stats = placed_label(hud, Vector2(40, 66), 17)
	weapon = placed_label(hud, Vector2(40, 750), 23)
	health_bar = bar(Vector2(40, 800), Color("77c9b0"))
	armor_bar = bar(Vector2(40, 829), Color("7ebce4"))
	prompt = placed_label(hud, Vector2(480, 735), 18, ACCENT)
	feed = placed_label(hud, Vector2(40, 118), 16)
	result_label = placed_label(hud, Vector2(430, 290), 38, ACCENT)
	hud.visible = false
	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2(480, 290)
	pause_panel.size = Vector2(460, 250)
	pause_panel.theme = theme
	add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_panel.add_child(pause_box)
	label(pause_box, "FIELD MENU", 28, ACCENT)
	label(pause_box, "The operation continues while this menu is open.", 16)
	button(pause_box, "RESUME", func(): set_pause(false))
	button(pause_box, "RETURN TO DEPLOYMENT", func(): leave_requested.emit())
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
	menu.visible = true
	leaderboard_panel.visible = false
	scoreboard_panel.visible = false
	hud.visible = false
	pause_panel.visible = false
	busy = false
	password.text = ""
	if not message.is_empty():
		status.text = message
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_game() -> void:
	menu.visible = false
	hud.visible = true
	busy = false
	password.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_pause(enabled: bool) -> void:
	pause_panel.visible = enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED

func draw_hud() -> void:
	var center := hud.size / 2
	var white := Color(0.9, 0.95, 0.92, 0.85)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		hud.draw_line(center + direction * 5, center + direction * 12, white, 2)
	var radar_center := Vector2(hud.size.x - 120, 120)
	hud.draw_circle(radar_center, 88, Color(0.03, 0.08, 0.11, 0.85))
	hud.draw_arc(radar_center, radius * 0.72, 0, TAU, 64, Color("72bbd9"), 2)
	hud.draw_line(radar_center + Vector2(-80, 0), radar_center + Vector2(80, 0), Color("49606a"), 7)
	hud.draw_line(radar_center + Vector2(0, -80), radar_center + Vector2(0, 80), Color("49606a"), 7)
	var p := radar_center + Vector2(local_position.x, local_position.z) * 0.72
	hud.draw_circle(p, 4, ACCENT)
	hud.draw_line(p, p + Vector2(-sin(local_yaw), -cos(local_yaw)) * 13, ACCENT, 2)

func update_hud(actor, alive_count: int, phase: String, time_left: float, zone: float, events: Array, message: String) -> void:
	headline.text = "ASH VALLEY   /   " + phase.to_upper()
	stats.text = "%02d ALIVE    •    %02d ELIMINATIONS    •    ZONE %dm    •    %02d:%02d" % [alive_count, actor.kills, zone, int(time_left) / 60, int(time_left) % 60]
	weapon.text = "%s    %02d / %03d" % [actor.NAMES[actor.weapon], actor.ammo, actor.reserve]
	health_bar.value = actor.health
	armor_bar.value = actor.armor
	prompt.text = "E  Pick up nearby supplies   |   H  Medkit ×%d" % actor.medkits
	if actor.reload_left > 0:
		prompt.text = "RELOADING   %.1fs" % actor.reload_left
	elif actor.heal_left > 0:
		prompt.text = "APPLYING MEDKIT   %.1fs" % actor.heal_left
	elif Vector2(actor.position.x, actor.position.z).length() > zone:
		prompt.text = "WARNING  /  RETURN TO THE SAFE ZONE"
	feed.text = "\n".join(events)
	result_label.text = message
	local_position = actor.position
	local_yaw = actor.yaw
	radius = zone
	hud.queue_redraw()

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
	var lines := PackedStringArray(["FIELD ROSTER  /  HOLD TAB", "", "OPERATOR                         KILLS     STATUS"])
	for actor in roster:
		lines.append("%-24s      %02d        %s" % [actor.display_name, actor.kills, "LIVE" if actor.alive else "OUT"])
	scoreboard_label.text = "\n".join(lines)
