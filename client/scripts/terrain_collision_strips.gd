extends RefCounted

# Offline optimization for the authored row-major terrain grid. Only merge
# exactly horizontal rectangles with matching edges, heights and winding.
# Non-grid faces and all slopes/ruts pass through byte-for-byte. Render meshes
# are independent. Keep this experimental until traversal is reviewed.
static func build(source: ConcavePolygonShape3D, max_quads: int = 0) -> ConcavePolygonShape3D:
	var faces := source.get_faces()
	var output := PackedVector3Array()
	var cursor := 0
	while cursor < faces.size():
		if not flat_quad(faces, cursor):
			output.append_array(faces.slice(cursor, mini(cursor + 6, faces.size())))
			cursor += 6
			continue
		var a := faces[cursor]
		var b := faces[cursor + 1]
		var c := faces[cursor + 2]
		var d := faces[cursor + 5]
		cursor += 6
		var merged := 1
		while (max_quads <= 0 or merged < max_quads) and flat_quad(faces, cursor) and faces[cursor] == b and faces[cursor + 5] == c:
			b = faces[cursor + 1]
			c = faces[cursor + 2]
			cursor += 6
			merged += 1
		output.append_array(PackedVector3Array([a, b, c, a, c, d]))
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = source.backface_collision
	shape.set_faces(output)
	return shape

static func flat_quad(faces: PackedVector3Array, i: int) -> bool:
	if i + 5 >= faces.size():
		return false
	var a := faces[i]
	var b := faces[i + 1]
	var c := faces[i + 2]
	var d := faces[i + 5]
	return faces[i + 3] == a and faces[i + 4] == c \
		and a.y == b.y and a.y == c.y and a.y == d.y \
		and a.z == b.z and c.z == d.z and a.x == d.x and b.x == c.x \
		and b.x > a.x and c.z > a.z
