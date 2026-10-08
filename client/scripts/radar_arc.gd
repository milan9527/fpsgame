extends RefCounted

# Match CanvasItem.draw_arc's 64-point full circle, retaining the packed
# geometry between HUD redraws while the zone and viewport stay unchanged.
var _center := Vector2(INF, INF)
var _radius := INF
var _points := PackedVector2Array()
var _directions := PackedVector2Array()

func points(center: Vector2, radius: float) -> PackedVector2Array:
	if _directions.is_empty():
		_directions.resize(64)
		for i in range(64):
			var angle := float(i) / 63.0 * TAU
			_directions[i] = Vector2(cos(angle), sin(angle))
	if center != _center or radius != _radius:
		_center = center
		_radius = radius
		_points.resize(64)
		for i in range(64):
			_points[i] = center + _directions[i] * radius
	return _points
