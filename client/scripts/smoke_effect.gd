extends RefCounted

static var shared_mesh: SphereMesh

static func create() -> MeshInstance3D:
	if shared_mesh == null:
		shared_mesh = SphereMesh.new()
		shared_mesh.radius = 1
		shared_mesh.height = 2
		shared_mesh.radial_segments = 32
		shared_mesh.rings = 16
	var visual := MeshInstance3D.new()
	visual.name = "SmokeCloud"
	visual.mesh = shared_mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Cloud age, radius and density vary independently during gameplay.
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/smoke.gdshader")
	visual.material_override = material
	return visual
