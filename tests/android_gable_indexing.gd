extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world_visuals.gd")
	var report := {}
	for definition in [
		["rear", "\tvar gable := SurfaceTool.new()", "\tvar end_panel := MeshInstance3D.new()", "gable"],
		["front", "\tvar front_gable := SurfaceTool.new()", "\tvar clerestory := MeshInstance3D.new()", "front_gable"],
	]:
		var start := source.find(definition[1])
		var end := source.find(definition[2], start)
		assert(start >= 0 and end > start)
		var body := source.substr(start, end - start)
		var snapshots: Array = []
		for android in [false, true]:
			var script := GDScript.new()
			script.source_code = "extends RefCounted\nstatic func mesh_arrays() -> Array:\n\tvar center := Vector3(15.5, 0, 31)\n" + body.replace('OS.has_feature("android")', str(android)) + "\treturn " + definition[3] + ".commit_to_arrays()\n"
			assert(script.reload() == OK)
			snapshots.append(script.mesh_arrays())
		var before: Array = snapshots[0]
		var after: Array = snapshots[1]
		var indices: PackedInt32Array = after[Mesh.ARRAY_INDEX]
		assert(indices.size() == before[Mesh.ARRAY_VERTEX].size())
		for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV]:
			for index in range(indices.size()):
				assert(before[slot][index] == after[slot][indices[index]], "Expanded triangle attribute changed")
		assert(after[Mesh.ARRAY_VERTEX].size() < before[Mesh.ARRAY_VERTEX].size())
		var meshes: Array[ArrayMesh] = []
		for arrays in snapshots:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			meshes.append(mesh)
		assert(meshes[0].get_faces() == meshes[1].get_faces(), "Collision triangle order changed")
		assert(meshes[0].get_aabb() == meshes[1].get_aabb())
		report[definition[0]] = {
			"before_vertices": before[Mesh.ARRAY_VERTEX].size(),
			"after_vertices": after[Mesh.ARRAY_VERTEX].size(),
			"triangles": indices.size() / 3,
			"expanded_attributes_collision_faces_aabb_exact": true,
		}
	print("ANDROID_GABLE_INDEXING_PASS ", JSON.stringify(report))
	quit()
