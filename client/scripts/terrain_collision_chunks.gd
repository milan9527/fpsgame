extends RefCounted

# Experimental offline broad-phase partition. Preserve each triangle, winding
# and coordinates exactly; triangles crossing a cell boundary remain whole.
# Do not enable in production until character traversal and Android are tested.
static func build(source: ConcavePolygonShape3D, cell_size: float = 16.0, single_tree: bool = false) -> Array[ConcavePolygonShape3D]:
	assert(cell_size > 0.0)
	var buckets := {}
	var faces := source.get_faces()
	for i in range(0, faces.size(), 3):
		var center := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		var key := Vector2i(floori(center.x / cell_size), floori(center.z / cell_size))
		if not buckets.has(key):
			buckets[key] = []
		# Packed arrays copy on write when shared with the dictionary. Accumulate
		# in a reference array to avoid copying a growing cell for every face.
		var vertices: Array = buckets[key]
		vertices.append(faces[i])
		vertices.append(faces[i + 1])
		vertices.append(faces[i + 2])
	var shapes: Array[ConcavePolygonShape3D] = []
	if single_tree:
		# Compare spatial face ordering in one BVH against many broad-phase
		# shapes. Geometry remains exact, but contact tie order still needs
		# differential verification. This is not a runtime integration.
		var ordered := PackedVector3Array()
		for key in buckets:
			ordered.append_array(PackedVector3Array(buckets[key]))
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = source.backface_collision
		shape.set_faces(ordered)
		shapes.append(shape)
		return shapes
	for key in buckets:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = source.backface_collision
		shape.set_faces(PackedVector3Array(buckets[key]))
		shapes.append(shape)
	return shapes
