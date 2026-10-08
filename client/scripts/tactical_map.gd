extends Control

signal close_requested
signal waypoint_requested(point: Vector2, clear: bool)
const Bindings = preload("res://scripts/control_bindings.gd")
const BOUNDS := Rect2(-120, -120, 240, 240)
const MAP_RECT := Rect2(260, 120, 640, 640)
const MARKER := Color("f6a77a")
var features: Array[Dictionary] = []
var operator_position := Vector2.ZERO
var operator_yaw := 0.0
var zone_radius := 110.0
var zone_info: Dictionary = {}
var time_left := 300.0
var waypoint = null
var teammates: Array = []
var shared_pings: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var close := Button.new()
	close.position = Vector2(970, 690)
	close.size = Vector2(290, 48)
	close.text = "RETURN TO OPERATION"
	close.pressed.connect(func(): close_requested.emit())
	add_child(close)
	visibility_changed.connect(func():
		if is_visible_in_tree():
			queue_redraw()
	)
	hide()

func world_to_map(point: Vector2) -> Vector2:
	return MAP_RECT.position + (point - BOUNDS.position) / BOUNDS.size * MAP_RECT.size

func map_to_world(point: Vector2) -> Vector2:
	return BOUNDS.position + (point - MAP_RECT.position) / MAP_RECT.size * BOUNDS.size

func mark(point: Vector2) -> bool:
	if not point.is_finite() or absf(point.x) > 115 or absf(point.y) > 115:
		return false
	waypoint = point
	queue_redraw()
	return true

func refresh(at: Vector3, yaw: float, zone: float, remaining: float, circle: Dictionary = {}) -> void:
	operator_position = Vector2(at.x, at.z)
	operator_yaw = yaw
	zone_radius = zone
	zone_info = circle
	time_left = remaining
	# Keep navigation state current for the HUD while the full map is closed.
	# Opening the map invalidates it once through visibility_changed.
	if is_visible_in_tree():
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and MAP_RECT.has_point(event.position):
		if event.button_index == MOUSE_BUTTON_LEFT:
			var point := map_to_world(event.position)
			if mark(point):
				waypoint_requested.emit(point, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			waypoint = null
			waypoint_requested.emit(Vector2.ZERO, true)
			queue_redraw()
		accept_event()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var white := Color("dce7e5")
	var blue := Color("72bbd9")
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.07, 0.96))
	draw_string(font, Vector2(260, 70), "ASH VALLEY / TACTICAL MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, white)
	draw_rect(MAP_RECT, Color("393c34"))
	draw_circle(world_to_map(zone_info.get("center", Vector2.ZERO)), zone_radius / 240 * 640, Color("344b45"))
	for feature in features:
		var area: Rect2 = feature.rect
		var rectangle := Rect2(world_to_map(area.position), area.size / BOUNDS.size * MAP_RECT.size)
		var color := Color("65757c") if feature.kind == "road" else (Color("b7b09a") if feature.kind == "building" else Color("879989"))
		draw_rect(rectangle, color)
	for index in range(7):
		var offset := float(index) / 6 * 640
		draw_line(MAP_RECT.position + Vector2(offset, 0), MAP_RECT.position + Vector2(offset, 640), Color(0.8, 0.9, 0.9, 0.16))
		draw_line(MAP_RECT.position + Vector2(0, offset), MAP_RECT.position + Vector2(640, offset), Color(0.8, 0.9, 0.9, 0.16))
		if index < 6:
			draw_string(font, MAP_RECT.position + Vector2(offset + 47, -12), "ABCDEF"[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)
			draw_string(font, MAP_RECT.position + Vector2(-24, offset + 58), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)
	draw_arc(world_to_map(zone_info.get("center", Vector2.ZERO)), zone_radius / 240 * 640, 0, TAU, 128, blue, 3, true)
	draw_rect(MAP_RECT, white, false, 1)
	var p := world_to_map(operator_position)
	var forward := Vector2(-sin(operator_yaw), -cos(operator_yaw))
	var right := Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([p + forward * 11, p - forward * 7 + right * 6, p - forward * 7 - right * 6]), white)
	for member in teammates:
		var at := world_to_map(Vector2(member.position.x, member.position.z))
		var color := MARKER if member.downed else Color("77c9b0")
		if member.alive:
			draw_circle(at, 7, color, false, 2, true)
		else:
			draw_line(at - Vector2(5, 5), at + Vector2(5, 5), color, 2)
			draw_line(at + Vector2(-5, 5), at + Vector2(5, -5), color, 2)
		var caption := at + Vector2(12, -10)
		var width := font.get_string_size(member.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		caption.x = clampf(caption.x, MAP_RECT.position.x + 4, MAP_RECT.end.x - width - 4)
		caption.y = clampf(caption.y, MAP_RECT.position.y + 18, MAP_RECT.end.y - 4)
		draw_string(font, caption, member.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	for ping in shared_pings:
		var target := world_to_map(ping.point)
		draw_circle(target, 10, Color("83dcff"), false, 2, true)
		var caption := Vector2(clampf(target.x + 12, MAP_RECT.position.x + 4, MAP_RECT.end.x - 190), clampf(target.y - 12, MAP_RECT.position.y + 18, MAP_RECT.end.y - 4))
		draw_string(font, caption, str(ping.name) + " / PING", HORIZONTAL_ALIGNMENT_LEFT, 185, 15, Color("83dcff"))
	if waypoint is Vector2:
		var target := world_to_map(waypoint)
		draw_dashed_line(p, target, MARKER, 1.5, 7)
		draw_circle(target, 7, MARKER, false, 2, true)
		draw_line(target - Vector2(11, 0), target + Vector2(11, 0), MARKER, 2)
		draw_line(target - Vector2(0, 11), target + Vector2(0, 11), MARKER, 2)
	if not zone_info.is_empty():
		draw_arc(world_to_map(zone_info.next_center), zone_info.next_radius / 240 * 640, 0, TAU, 128, Color.WHITE, 2, true)
	var lines := ["NORTH  /  -Z", "", "%s / ESC     CLOSE MAP" % Bindings.key_label("map"), "LEFT CLICK  SET WAYPOINT", "RIGHT CLICK CLEAR WAYPOINT", "", "BLUE RING   CURRENT ZONE", "WHITE RING  NEXT ZONE", "STAGE %d / %s %ds" % [zone_info.get("stage", 1), "SHRINK" if zone_info.get("moving", false) else "HOLD", ceili(zone_info.get("remaining", 0))], "PALE BLOCKS BUILDINGS", "GRAY STRIPS ROADS", "GRID CELL   40 m", "GREEN TEAM / AMBER DOWNED" if not teammates.is_empty() else "", "ZONE RADIUS  %d m" % zone_radius, "ROUND TIME   %02d:%02d" % [int(time_left) / 60, int(time_left) % 60], "", "WORLD CONTINUES WHILE OPEN"]
	if waypoint is Vector2:
		lines.append("WAYPOINT     %d m" % roundi(operator_position.distance_to(waypoint)))
	for index in range(lines.size()):
		draw_string(font, Vector2(950, 150 + index * 29), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)
