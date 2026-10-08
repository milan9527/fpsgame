extends SceneTree

func _initialize() -> void:
	var profile = load("res://scripts/mobile_performance.gd")
	for name in ["meadow_ground", "meadow_ground_mobile", "terrain_slopes",
			"terrain_slopes_mobile", "road_surface", "road_surface_mobile", "service_ground"]:
		var ground := ShaderMaterial.new()
		ground.shader = load("res://shaders/%s.gdshader" % name)
		var family: String = {"meadow": "meadow", "terrain": "terrain",
			"road": "road", "service": "service"}[name.get_slice("_", 0)]
		assert(profile.baseline_material_kind(ground) == "ground", name)
		assert(profile.baseline_ground_family(ground) == family, name)
		# Use an unrelated resource path for relative includes, as an embedded
		# shader still needs a base directory. Keep exact code to test matching.
		var embedded := Shader.new()
		if '#include "terrain_slopes_mobile.gdshaderinc"' in ground.shader.code:
			embedded.resource_path = "res://shaders/test_embedded.tres::Shader_ground"
		embedded.code = ground.shader.code
		ground.shader = embedded
		assert(profile.baseline_material_kind(ground) == "ground", "embedded " + name)
		assert(profile.baseline_ground_family(ground) == family, "embedded " + name)
	var standard := StandardMaterial3D.new()
	var custom := ShaderMaterial.new()
	custom.shader = load("res://shaders/grass.gdshader")
	assert(profile.baseline_material_kind(custom) == "custom")
	assert(profile.baseline_ground_family(custom) == "")
	assert(profile.baseline_ground_family(null) == "")
	assert(profile.baseline_material_kind(standard) == "standard")
	assert(profile.baseline_material_kind(null) == "standard")
	assert(profile.baseline_material_kind(ShaderMaterial.new()) == "standard")
	var node := MeshInstance3D.new()
	node.mesh = BoxMesh.new()
	node.mesh.material = custom
	assert(profile.baseline_materials(node, node.mesh) == [custom])
	node.set_surface_override_material(0, standard)
	assert(profile.baseline_materials(node, node.mesh) == [standard])
	node.material_override = custom
	assert(profile.baseline_materials(node, node.mesh) == [custom])
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.mesh = node.mesh
	assert(profile.baseline_materials(batch, node.mesh) == [custom])
	batch.material_override = standard
	assert(profile.baseline_materials(batch, node.mesh) == [standard])
	node.free()
	batch.free()
	print("MOBILE_BASELINE_MATERIAL_PASS embedded mobile terrain and effective material precedence")
	quit()
