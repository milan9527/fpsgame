extends RefCounted

# Actors move and toggle their own instances; identical rendering resources
# stay alive across respawns and the loading-time draw.
static var shared_mesh: CylinderMesh
static var shared_material: StandardMaterial3D

static func create() -> MeshInstance3D:
	if shared_mesh == null:
		shared_mesh = CylinderMesh.new()
		shared_mesh.top_radius = 0.0
		shared_mesh.bottom_radius = 0.035
		shared_mesh.height = 0.12
		shared_mesh.radial_segments = 6
		shared_material = StandardMaterial3D.new()
		shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_material.albedo_color = Color("ffe7a0")
	var flash := MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.mesh = shared_mesh
	flash.material_override = shared_material
	flash.rotation.x = -PI / 2
	flash.position = Vector3(0, 0.012, -0.47)
	flash.visible = false
	return flash
