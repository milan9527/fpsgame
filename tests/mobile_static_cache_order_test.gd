extends "res://tests/mobile_facade_cache_test.gd"

func _run() -> void:
	var meshes: Array[PrimitiveMesh] = []
	var sphere := SphereMesh.new()
	sphere.radial_segments = 32
	sphere.rings = 16
	meshes.append(sphere)
	var cylinder := CylinderMesh.new()
	cylinder.radial_segments = 32
	meshes.append(cylinder)
	var capsule := CapsuleMesh.new()
	capsule.radial_segments = 32
	capsule.rings = 8
	meshes.append(capsule)
	var report := {}
	for source in meshes:
		var previous := SurfaceTool.new()
		previous.create_from(source, 0)
		previous.optimize_indices_for_cache()
		var before := previous.commit_to_arrays()
		Profile.strip_collapsed_static_triangles(before)
		var reference := ArrayMesh.new()
		reference.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, before)
		before = reference.surface_get_arrays(0)
		var optimized := Profile.optimize_static_surface(source)
		var after := optimized.surface_get_arrays(0)
		assert(_triangles(before) == _triangles(after), "Triangle attributes/winding changed")
		assert(optimized.custom_aabb == source.get_aabb(), "Culling bounds changed")
		var locality := {}
		for capacity in [16, 24, 32]:
			assert(_misses(after[Mesh.ARRAY_INDEX], capacity) <=
				_misses(before[Mesh.ARRAY_INDEX], capacity), "Cache locality regressed")
			locality[str(capacity)] = {
				"before": _misses(before[Mesh.ARRAY_INDEX], capacity),
				"after": _misses(after[Mesh.ARRAY_INDEX], capacity)}
		report[source.get_class()] = locality
	print("MOBILE_STATIC_CACHE_ORDER_PASS ", JSON.stringify(report))
	quit()
