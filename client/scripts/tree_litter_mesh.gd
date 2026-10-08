extends RefCounted
## Trim only guaranteed transparent corners of tree_litter_mobile.gdshader.
static var cached: ArrayMesh

static func get_mesh() -> ArrayMesh:
	if cached != null:
		return cached
	# alpha is zero when length(p) >= 0.95 + 0.10. Each diagonal
	# lies outside that circle: 1.49 / sqrt(2) > 1.05.
	var outline := PackedVector2Array([
		Vector2(-0.49, -1), Vector2(0.49, -1),
		Vector2(1, -0.49), Vector2(1, 0.49),
		Vector2(0.49, 1), Vector2(-0.49, 1),
		Vector2(-1, 0.49), Vector2(-1, -0.49),
	])
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for point in outline:
		vertices.append(Vector3(point.x * 3.6, 0, point.y * 3.6))
		normals.append(Vector3.UP)
		uvs.append(point * 0.5 + Vector2(0.5, 0.5))
	for index in range(1, outline.size() - 1):
		indices.append_array(PackedInt32Array([0, index, index + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	cached = ArrayMesh.new()
	cached.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return cached
