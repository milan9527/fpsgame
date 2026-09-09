extends Node3D

var loot_nodes: Dictionary = {}
var zone_mesh: MeshInstance3D
var zone_radius := 110.0
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}

func mat(hex: String) -> StandardMaterial3D:
	if materials.has(hex):
		return materials[hex]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.92
	materials[hex] = m
	return m

func block(at: Vector3, size: Vector3, color: String, solid := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat(color)
	mesh.position = at
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		shape.shape = collision
		body.add_child(shape)
		mesh.add_child(body)
	return mesh

func _ready() -> void:
	rng.seed = 90210
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("8ca6b2")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b9ced2")
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("8ca6b2")
	e.fog_density = 0.0025
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("ffe5bd")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	add_child(sun)
	block(Vector3(0, -0.5, 0), Vector3(240, 1, 240), "737b68")
	block(Vector3(0, 0.012, 0), Vector3(16, 0.02, 225), "3b484c", false)
	block(Vector3(0, 0.025, 0), Vector3(225, 0.02, 14), "3b484c", false)
	for i in range(-10, 11):
		block(Vector3(0, 0.05, i * 10), Vector3(0.2, 0.02, 4), "bfc3a0", false)
		block(Vector3(i * 10, 0.05, 0), Vector3(4, 0.02, 0.2), "bfc3a0", false)
	# Traversable buildings: separate walls, real doorways, roof and interior cover.
	for x in [-72, -42, 35, 68]:
		for z in [-70, -35, 34, 70]:
			building(Vector3(x, 0, z), rng.randi_range(0, 2))
	for i in range(32):
		var at := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
		if absf(at.x) < 12 or absf(at.z) < 10:
			continue
		block(at + Vector3(0, 0.75, 0), Vector3(2.5, 1.5, 2), "657477")
	for i in range(65):
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(95, 145)
		var at := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		tree(at)
	for i in range(18):
		var angle := float(i) / 18 * TAU
		var mountain := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0
		cone.bottom_radius = rng.randf_range(35, 65)
		cone.height = rng.randf_range(35, 85)
		cone.radial_segments = 5
		mountain.mesh = cone
		mountain.material_override = mat("667b80")
		mountain.position = Vector3(sin(angle) * 210, cone.height / 2 - 3, cos(angle) * 210)
		add_child(mountain)
	zone_mesh = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1
	cylinder.bottom_radius = 1
	cylinder.height = 20
	cylinder.radial_segments = 96
	zone_mesh.mesh = cylinder
	var zone_mat := StandardMaterial3D.new()
	zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	zone_mat.albedo_color = Color(0.2, 0.7, 1, 0.11)
	zone_mesh.material_override = zone_mat
	zone_mesh.position.y = 8
	add_child(zone_mesh)
	set_zone(110)

func building(at: Vector3, style: int) -> void:
	var colors := ["b0a58c", "829b9a", "a08773"]
	var c: String = colors[style]
	block(at + Vector3(0, 0.1, 0), Vector3(16, 0.2, 13), "a5a69a")
	block(at + Vector3(-8, 2, 0), Vector3(0.5, 4, 13), c)
	block(at + Vector3(8, 2, 0), Vector3(0.5, 4, 13), c)
	for z in [-6.5, 6.5]:
		block(at + Vector3(-5, 2, z), Vector3(6, 4, 0.5), c)
		block(at + Vector3(5, 2, z), Vector3(6, 4, 0.5), c)
		block(at + Vector3(0, 3.7, z), Vector3(4, 0.6, 0.5), c)
	block(at + Vector3(0, 4.15, 0), Vector3(17, 0.3, 14), "465a61")
	block(at + Vector3(-4, 0.8, 0), Vector3(2, 1.4, 3), "576b62")
	block(at + Vector3(8.3, 2.5, 0), Vector3(0.1, 0.9, 6), "dfb86b", false)

func tree(at: Vector3) -> void:
	block(at + Vector3(0, 2, 0), Vector3(0.6, 4, 0.6), "60564a")
	var foliage := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = 3
	cone.height = 7
	cone.radial_segments = 7
	foliage.mesh = cone
	foliage.material_override = mat("3d6258")
	foliage.position = at + Vector3(0, 6, 0)
	add_child(foliage)

func set_zone(radius: float) -> void:
	zone_radius = radius
	if zone_mesh:
		zone_mesh.scale = Vector3(radius, 1, radius)

func show_loot(items: Dictionary) -> void:
	for id in loot_nodes.keys():
		if not items.has(id):
			loot_nodes[id].queue_free()
			loot_nodes.erase(id)
	for id in items:
		if loot_nodes.has(id):
			continue
		var item: Dictionary = items[id]
		var colors := ["e8c77b", "77d7ad", "7bbee8"]
		var mesh := block(item.p + Vector3(0, 0.35, 0), Vector3(0.65, 0.5, 0.65), colors[item.kind], false)
		loot_nodes[id] = mesh
