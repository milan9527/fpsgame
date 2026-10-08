extends SceneTree

func _initialize() -> void:
	var profile = load("res://scripts/mobile_performance.gd")
	var root := Node3D.new()
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/road_surface_mobile.gdshader")
	var box := BoxMesh.new()
	box.material = ground
	var first := MeshInstance3D.new()
	first.mesh = box
	root.add_child(first)
	var outside := MeshInstance3D.new()
	outside.mesh = box
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.mesh = box
	root.add_child(batch)
	var mixed := MeshInstance3D.new()
	var surfaces := ArrayMesh.new()
	surfaces.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	surfaces.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	surfaces.surface_set_material(0, ground)
	surfaces.surface_set_material(1, StandardMaterial3D.new())
	mixed.mesh = surfaces
	root.add_child(mixed)
	var prop := MeshInstance3D.new()
	prop.mesh = box
	var prop_material := StandardMaterial3D.new()
	prop.material_override = prop_material
	root.add_child(prop)
	var body := StaticBody3D.new()
	root.add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	var original_layers := first.layers
	var report: Dictionary = profile.profile_ground_materials(root)
	assert(report.replaced == 2 and report.skipped_mixed == 1)
	assert(report.diagnostic_only)
	assert(first.material_override is StandardMaterial3D)
	assert(first.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	assert(batch.material_override == first.material_override)
	assert(first.mesh == box and box.material == ground)
	assert(outside.material_override == null)
	assert(mixed.material_override == null and surfaces.surface_get_material(0) == ground)
	assert(prop.material_override == prop_material)
	assert(first.visible and first.layers == original_layers)
	assert(not collision.disabled and collision.get_parent() == body)
	outside.free()
	root.free()
	print("MOBILE_GAMEPLAY_GROUND_PASS geometry collision shared resources mixed surfaces")
	quit()
