extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Use xvfb-run with gl_compatibility")
		quit(2)
		return
	var path := OS.get_environment("MOBILE_PERFORMANCE_SCRIPT")
	var mobile: GDScript = load(path if not path.is_empty() else "res://scripts/mobile_performance.gd")
	var fixtures: Array[Mesh] = []
	for segments in [5, 6, 7]:
		for rings in [1, 2, 3]:
			var source := SphereMesh.new()
			source.radius = 1.0
			source.height = 2.0
			source.radial_segments = segments
			source.rings = rings
			source.material = StandardMaterial3D.new()
			fixtures.append(source)
	# Run the actual production mesh builder up to its first MultiMesh,
	# retaining deformation, deindexing, flat normals and material assignment.
	var production := FileAccess.get_file_as_string("res://scripts/world_visuals.gd")
	var builder := production.split("static func repair_apron_drainage(world) -> void:")[1].split("\n\tvar stones := MultiMesh.new()")[0]
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nstatic func build() -> ArrayMesh:" + builder + "\n\treturn stone_mesh\n"
	assert(script.reload() == OK)
	fixtures.append(script.build())
	for source in fixtures:
		var result: ArrayMesh = mobile.compact_gravel_mesh(source)
		var before := source.surface_get_arrays(0)
		var after := result.surface_get_arrays(0)
		assert(result.surface_get_material(0) == source.surface_get_material(0))
		assert(result.get_aabb().is_equal_approx(source.get_aabb()))
		var vertices: PackedVector3Array = before[Mesh.ARRAY_VERTEX]
		var old_indices := PackedInt32Array()
		if before[Mesh.ARRAY_INDEX] != null:
			old_indices = before[Mesh.ARRAY_INDEX]
		if old_indices.is_empty():
			for i in range(vertices.size()):
				old_indices.append(i)
		var new_indices: PackedInt32Array = after[Mesh.ARRAY_INDEX]
		assert(after[Mesh.ARRAY_VERTEX].size() < vertices.size())
		if not source is SphereMesh:
			# The production deindexed stone has 126 surviving corners.
			# Exact attribute sharing must reduce them without merging seams.
			assert(after[Mesh.ARRAY_VERTEX].size() == 38)
		assert(new_indices.size() == old_indices.size() - (source.radial_segments if source is SphereMesh else 7) * 6)
		var cursor := 0
		var referenced := {}
		# Index cache optimization may reorder triangles, but must retain each
		# oriented triangle and all of its corner attributes exactly once.
		var triangles := {}
		for i in range(0, new_indices.size(), 3):
			var corners := []
			for corner in range(3):
				corners.append(after[Mesh.ARRAY_VERTEX][new_indices[i + corner]])
			var key := var_to_str(corners)
			assert(not triangles.has(key), "Duplicate gravel triangle")
			triangles[key] = i
		for i in range(0, old_indices.size(), 3):
			var area := (vertices[old_indices[i+1]] - vertices[old_indices[i]]).cross(vertices[old_indices[i+2]] - vertices[old_indices[i]]).length()
			if area > 0.000001:
				var key := var_to_str([vertices[old_indices[i]], vertices[old_indices[i + 1]], vertices[old_indices[i + 2]]])
				assert(triangles.has(key), "Triangle missing or winding changed")
				var triangle_start: int = triangles[key]
				triangles.erase(key)
				for corner in range(3):
					var old_vertex := old_indices[i + corner]
					var new_vertex := new_indices[triangle_start + corner]
					referenced[new_vertex] = true
					for attribute in range(Mesh.ARRAY_MAX):
						if attribute == Mesh.ARRAY_INDEX:
							continue
						if before[attribute] == null:
							assert(after[attribute] == null)
							continue
						var stride := 4 if attribute == Mesh.ARRAY_TANGENT else 1
						assert(after[attribute].size() == after[Mesh.ARRAY_VERTEX].size() * stride)
						for component in range(stride):
							var a = before[attribute][old_vertex * stride + component]
							var b = after[attribute][new_vertex * stride + component]
							# GPU normal/tangent encoding is lossy on a second upload.
							var delta: float = absf(a - b) if a is float else a.distance_to(b)
							var tolerance := 0.0002 if attribute in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT] else 0.000001
							assert(delta <= tolerance, "attribute=%d delta=%f" % [attribute, delta])
				cursor += 3
		assert(cursor == new_indices.size())
		assert(triangles.is_empty())
		assert(referenced.size() == after[Mesh.ARRAY_VERTEX].size())
		print("GRAVEL_MESH_PASS fixture=", fixtures.find(source),
			" triangles=", old_indices.size()/3, "->", new_indices.size()/3,
			" vertices=", vertices.size(), "->", after[Mesh.ARRAY_VERTEX].size(),
			" attributes/material/bounds/winding preserved")
	quit()
