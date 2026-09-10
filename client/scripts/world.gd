extends Node3D

var loot_nodes: Dictionary = {}
var highlighted_supply := -1
var zone_mesh: MeshInstance3D
var zone_radius := 110.0
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}
var navigation_region: NavigationRegion3D
var navigation_bake_ms := 0
var map_features: Array[Dictionary] = []
var ground_obstacles: Array[Rect2] = []

func accepts_zone_center(center: Vector2) -> bool:
	# Final 4m circle plus a 0.5m player clearance. Read generated static
	# geometry, which is available before the navigation server's first sync.
	if absf(center.x) > 109.5 or absf(center.y) > 109.5:
		return false
	for obstacle in ground_obstacles:
		var nearest := center.clamp(obstacle.position, obstacle.end)
		if center.distance_to(nearest) <= 4.5:
			return false
	return true

func prepare_navigation() -> void:
	if navigation_region != null:
		return
	var started := Time.get_ticks_msec()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = 0.5
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.5
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.25
	mesh.filter_baking_aabb = AABB(Vector3(-114, -2, -114), Vector3(228, 12, 228))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, self)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, mesh.cell_size)
	navigation_region = NavigationRegion3D.new()
	navigation_region.navigation_mesh = mesh
	add_child(navigation_region)
	navigation_bake_ms = Time.get_ticks_msec() - started

func navigation_ready() -> bool:
	return navigation_region != null and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0

func navigation_point(at: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, at) if navigation_ready() else at

func footstep_surface(at: Vector3) -> String:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at - Vector3.UP * 0.8, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider.get_meta("surface", "hard") != "terrain":
		return "step_hard"
	var road := (absf(at.x) <= 8 and absf(at.z) <= 112.5) or (absf(at.z) <= 7 and absf(at.x) <= 112.5)
	return "step_hard" if road else "step_grass"

func mat(hex: String) -> StandardMaterial3D:
	if materials.has(hex):
		return materials[hex]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.92
	materials[hex] = m
	return m

func block(at: Vector3, size: Vector3, color: String, solid := true, surface := "hard") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat(color)
	mesh.position = at
	add_child(mesh)
	if solid:
		if surface != "terrain":
			ground_obstacles.append(Rect2(Vector2(at.x - size.x / 2, at.z - size.z / 2), Vector2(size.x, size.z)))
		var body := StaticBody3D.new()
		body.set_meta("surface", surface)
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
	block(Vector3(0, -0.5, 0), Vector3(240, 1, 240), "737b68", true, "terrain")
	block(Vector3(0, 0.012, 0), Vector3(16, 0.02, 225), "3b484c", false)
	block(Vector3(0, 0.025, 0), Vector3(225, 0.02, 14), "3b484c", false)
	map_features.append({"rect": Rect2(-8, -112.5, 16, 225), "kind": "road"})
	map_features.append({"rect": Rect2(-112.5, -7, 225, 14), "kind": "road"})
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
		map_features.append({"rect": Rect2(Vector2(at.x - 1.25, at.z - 1), Vector2(2.5, 2)), "kind": "cover"})
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
	map_features.append({"rect": Rect2(Vector2(at.x - 8.5, at.z - 7), Vector2(17, 14)), "kind": "building"})
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

func set_zone(radius: float, center := Vector2.ZERO) -> void:
	zone_radius = radius
	if zone_mesh:
		zone_mesh.scale = Vector3(radius, 1, radius)
		zone_mesh.position = Vector3(center.x, 8, center.y)

func show_loot(items: Dictionary) -> void:
	for id in loot_nodes.keys():
		if not items.has(id):
			loot_nodes[id].queue_free()
			loot_nodes.erase(id)
			if highlighted_supply == id:
				highlighted_supply = -1
	var colors := ["e8c77b", "77d7ad", "7bbee8", "d9844e"]
	var stack_heights := {}
	for id in items:
		var item: Dictionary = items[id]
		var offset := Vector3(0, 0.35, 0)
		if item.has("drop_slot"):
			# Keep interaction at the corpse position; compact stacks distinguish
			# the remaining categories without scattering supplies through walls.
			offset.y = 0.15 + int(stack_heights.get(item.p, 0)) * 0.2
			stack_heights[item.p] = int(stack_heights.get(item.p, 0)) + 1
		var size := Vector3(0.65, 0.2, 0.65) if item.has("drop_slot") else Vector3(0.65, 0.5, 0.65)
		if loot_nodes.has(id):
			var existing: MeshInstance3D = loot_nodes[id]
			existing.position = item.p + offset
			existing.mesh.size = size
			if existing.get_meta("supply_kind", -1) != item.kind:
				existing.material_override = mat(colors[item.kind]).duplicate()
				existing.set_meta("supply_kind", item.kind)
				if highlighted_supply == id:
					highlighted_supply = -1
			continue
		var mesh := block(item.p + offset, size, colors[item.kind], false)
		mesh.material_override = mesh.material_override.duplicate()
		mesh.set_meta("supply_kind", item.kind)
		loot_nodes[id] = mesh

func highlight_supply(id: int) -> void:
	if highlighted_supply == id:
		return
	if loot_nodes.has(highlighted_supply):
		loot_nodes[highlighted_supply].material_override.emission_enabled = false
	highlighted_supply = id
	if loot_nodes.has(id):
		var material: StandardMaterial3D = loot_nodes[id].material_override
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 1.2
