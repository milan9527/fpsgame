extends RefCounted

# Retain the exact line geometry/material drawn during Android loading so
# the first gameplay shot can reuse their rendering resources.
static var shared_mesh: ImmediateMesh
static var shared_material: StandardMaterial3D

static func create() -> MeshInstance3D:
	if shared_mesh == null:
		shared_material = StandardMaterial3D.new()
		shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_material.albedo_color = Color("ffe3a0")
		shared_mesh = ImmediateMesh.new()
		shared_mesh.surface_begin(Mesh.PRIMITIVE_LINES, shared_material)
		shared_mesh.surface_add_vertex(Vector3.ZERO)
		shared_mesh.surface_add_vertex(Vector3.BACK)
		shared_mesh.surface_end()
	var line := MeshInstance3D.new()
	line.name = "Tracer"
	line.mesh = shared_mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return line
