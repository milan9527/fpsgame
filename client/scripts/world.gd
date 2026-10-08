extends Node3D

signal construction_finished
var construction_complete := false

const Visuals = preload("res://scripts/world_visuals.gd")

var loot_nodes: Dictionary = {}
var _loot_display_snapshot: Array = []
var _loot_proxy_meshes: Dictionary = {}
var highlighted_supply := -1
var zone_mesh: MeshInstance3D
var zone_radius := 110.0
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}
var navigation_region: NavigationRegion3D
var navigation_bake_ms := 0
var map_features: Array[Dictionary] = []
var ground_obstacles: Array[Rect2] = []
var _footstep_query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1)

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
	# Every collider (and a miss) within the road footprint resolves to hard.
	# Resolve that invariant before entering the physics server.
	var road := (absf(at.x) <= 8 and absf(at.z) <= 112.5) or (absf(at.z) <= 7 and absf(at.x) <= 112.5)
	if road:
		return "step_hard"
	_footstep_query.from = at + Vector3.UP * 0.3
	_footstep_query.to = at - Vector3.UP * 0.8
	var hit := get_world_3d().direct_space_state.intersect_ray(_footstep_query)
	if hit.is_empty() or hit.collider.get_meta("surface", "hard") != "terrain":
		return "step_hard"
	return "step_grass"

func mat(hex: String) -> StandardMaterial3D:
	if materials.has(hex):
		return materials[hex]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex).srgb_to_linear()
	m.roughness = 0.92
	Visuals.material_surface(m, hex)
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
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("8ca6b2")
	e.fog_density = 0.00095
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.environment(e)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP environment ", Time.get_ticks_msec())
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	# Raking afternoon light separates the curved shed from the road grove.
	sun.rotation_degrees = Vector3(-34, -142, 0)
	sun.light_color = Color("ffebce")
	sun.light_energy = 1.12
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.05
	# Grazing terrain needs normal offset to avoid dense self-shadow stripes.
	# Keep depth bias low; review canopy and actor contacts with this offset.
	sun.shadow_bias = 0.5
	sun.shadow_normal_bias = 2.0
	sun.directional_shadow_max_distance = 170
	# Spend more of the first cascade on entrance framing and actor contacts.
	# Thin steel otherwise falls into coarse cascades at normal review distance.
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	# One mesh owns road, drainage and yard: overlapping road/shoulder sheets
	# produced long hard seams and disagreed with the terrain collision.
	var asphalt := ShaderMaterial.new()
	asphalt.shader = load("res://shaders/road_surface_mobile.gdshader" if OS.has_feature("android") else "res://shaders/road_surface.gdshader")
	asphalt.set_shader_parameter("aggregate", load("res://assets/realism/terrain_rock_albedo.jpg"))
	asphalt.set_shader_parameter("pavement", load("res://assets/realism/asphalt_surface.png"))
	var adjoining_ground := Visuals.meadow_surface()
	for texture_name in ["soil", "gravel", "soil_normal", "gravel_normal", "colony_map", "noise_lattice", "cached_noise"]:
		asphalt.set_shader_parameter(texture_name, adjoining_ground.get_shader_parameter(texture_name))
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.excavated_surface(self, Rect2(-120, -120, 240, 240), asphalt, true)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP excavated_surface ", Time.get_ticks_msec())
	map_features.append({"rect": Rect2(-8, -112.5, 16, 225), "kind": "road"})
	map_features.append({"rect": Rect2(-112.5, -7, 225, 14), "kind": "road"})
	for i in range(-10, 11):
		block(Vector3(0, 0.05, i * 10), Vector3(0.2, 0.02, 4), "bfc3a0", false)
		block(Vector3(i * 10, 0.05, 0), Vector3(4, 0.02, 0.2), "bfc3a0", false)
	# Traversable buildings: separate walls, real doorways, roof and interior cover.
	for x in [-72, -42, 35, 68]:
		for z in [-70, -35, 34, 70]:
			var style := rng.randi_range(0, 2)
			# The eastern depot has a pitched workshop and a lower store behind it.
			if x == 35 and z == 34: style = 1
			if x == 68 and z == 34: style = 2
			# A legible west-side workshop row instead of randomly repeated
			# flat boxes in the road-level view.
			if x == -42: style = 1 if z == 34 or z == -70 else 2
			if x == -72 and z == -35: style = 1
			if x == 35 and z == -35: style = 1
			if x == 68 and z == -35: style = 2
			if x == -72 and z == -70: style = 2
			if OS.has_feature("android"):
				await get_tree().process_frame
			building(Vector3(x, 0, z), style)
			if OS.has_feature("android"):
				await get_tree().process_frame
			Visuals.building_verge(self, Vector3(x, 0, z))
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.depot_loading_area(self, Vector3(35, 0, 34))
	if OS.has_feature("android"):
		print("ANDROID_STARTUP depot_loading_area ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.repair_shelter(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP repair_shelter ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.western_verge_grove(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP western_verge_grove ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.arrival_canopy(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP arrival_canopy ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.roadside_waiting_shelter(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP roadside_waiting_shelter ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.depot_water_service(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP depot_water_service ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.workshop_monitor(self, Vector3(35, 0, 34))
	if OS.has_feature("android"):
		print("ANDROID_STARTUP workshop_monitor ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.workshop_monitor(self, Vector3(-42, 0, 34))
	if OS.has_feature("android"):
		print("ANDROID_STARTUP workshop_monitor ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.west_workshop_canopy(self, Vector3(-42, 0, 34))
	if OS.has_feature("android"):
		print("ANDROID_STARTUP west_workshop_canopy ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.workshop_frontage(self, Vector3(-42, 0, 34))
	if OS.has_feature("android"):
		print("ANDROID_STARTUP workshop_frontage ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.roadside_outcrops(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP roadside_outcrops ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.drainage_material_yards(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP drainage_material_yards ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.grain_silos(self, Vector3(-57, 0, -18))
	if OS.has_feature("android"):
		print("ANDROID_STARTUP grain_silos ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.verge_relief(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP verge_relief ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.western_road_ecotone(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP western_road_ecotone ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.workshop_service_bay(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP workshop_service_bay ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.workshop_workyard(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP workshop_workyard ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.utility_station(self, Vector3(-42, 0, -35))
	if OS.has_feature("android"):
		print("ANDROID_STARTUP utility_station ", Time.get_ticks_msec())
	# Broken shelter belts frame the road without sealing off cross-country
	# routes or either workshop's north/south doorway approaches.
	for point in [Vector2(-17, 18), Vector2(-21, 14), Vector2(-16, -19),
			Vector2(-21, -24), Vector2(-17, -52), Vector2(-22, -57),
			Vector2(21, -17), Vector2(25, -21), Vector2(19, -51)]:
		tree(Vector3(point.x, 0, point.y), 105.0)
	for i in range(32):
		var at := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
		if absf(at.x) < 12 or absf(at.z) < 10:
			continue
		# Reserve the whole crate footprint plus capsule clearance before creating
		# either its collider, visible asset, or minimap feature.
		var footprint := Rect2(at.x - 1.25, at.z - 1.0, 2.5, 2.0)
		if random_cover_blocks_access(footprint):
			continue
		var cover := block(at + Vector3(0, 0.75, 0), Vector3(2.5, 1.5, 2), "657477")
		cover.visible = false
		if OS.has_feature("android"):
			await get_tree().process_frame
		Visuals.supply_crate(self, at)
		map_features.append({"rect": Rect2(Vector2(at.x - 1.25, at.z - 1), Vector2(2.5, 2)), "kind": "cover"})
	for i in range(65):
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(95, 145)
		var at := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		tree(at)
	# Named landforms replace the evenly spaced ring. The northern drainage
	# corridor stays low, with overlapping western spurs and a distant divide.
	# x/z, radius, relief and watershed orientation are authored together;
	# metadata remains the single surface source for background tree roots.
	var landforms := [
		[-330.0, -235.0, 174.0, 66.0, 11], # western massif
		[-244.0, -247.0, 112.0, 31.0, 10], # descending foreground spur
		[-375.0, -430.0, 203.0, 82.0, 12], # distant western divide
		[-130.0, -445.0, 182.0, 40.0, 9],  # broad northern saddle
		[110.0, -460.0, 196.0, 32.0, 8],  # low valley head
		[310.0, -342.0, 176.0, 63.0, 7], # eastern watershed
		[280.0, -157.0, 112.0, 26.0, 6], # eastern foothill
		[359.0, 124.0, 174.0, 49.0, 4],
		[185.0, 366.0, 184.0, 57.0, 2],
		[-97.0, 392.0, 192.0, 42.0, 0],
		[-353.0, 167.0, 175.0, 60.0, 15],
	]
	for form in landforms:
		var mountain := MeshInstance3D.new()
		var ridge_radius: float = form[2]
		var ridge_height: float = form[3]
		var orientation: int = form[4]
		if OS.has_feature("android"):
			await get_tree().process_frame
		mountain.mesh = Visuals.mountain(ridge_radius, ridge_height, orientation)
		mountain.material_override = Visuals.terrain_material()
		mountain.position = Vector3(form[0], -3, form[1])
		mountain.set_meta("ridge", Vector3(ridge_radius, ridge_height, orientation))
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
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.ground_detail(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP ground_detail ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.clear_service_access_growth(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP clear_service_access_growth ", Time.get_ticks_msec())
	if OS.has_feature("android"):
		await get_tree().process_frame
	Visuals.batch_details(self)
	if OS.has_feature("android"):
		print("ANDROID_STARTUP batch_details ", Time.get_ticks_msec())
	construction_complete = true
	construction_finished.emit()

func building(at: Vector3, style: int) -> void:
	map_features.append({"rect": Rect2(Vector2(at.x - 8.5, at.z - 7), Vector2(17, 14)), "kind": "building"})
	var colors := ["b0a58c", "829b9a", "a08773"]
	var c: String = colors[style]
	var floor_material := ShaderMaterial.new()
	floor_material.shader = preload("res://shaders/warehouse_concrete.gdshader")
	floor_material.set_shader_parameter("building_origin", at)
	floor_material.set_shader_parameter("slab_joints", true)
	var slab := block(at + Vector3(0, 0.1, 0), Vector3(16, 0.2, 13), "a5a69a")
	slab.material_override = floor_material
	# Continuous concrete aprons bridge the 20 cm slab for real actor movement.
	for direction in [-1.0, 1.0]:
		var points := PackedVector3Array()
		for x in [-1.95, 1.95]:
			points.append(Vector3(x, 0, direction * 7.65))
			points.append(Vector3(x, 0, direction * 6.35))
			points.append(Vector3(x, 0.2, direction * 6.35))
		var apron := StaticBody3D.new()
		apron.name = "DoorwayApron"
		apron.position = at
		var collision := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		collision.shape = shape
		apron.add_child(collision)
		var geometry := MeshInstance3D.new()
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Two triangular ends and three rectangular faces of the concrete wedge.
		for index in [0, 2, 1, 3, 4, 5, 0, 3, 5, 0, 5, 2, 1, 2, 5, 1, 5, 4, 0, 1, 4, 0, 4, 3]:
			surface.add_vertex(points[index])
		surface.generate_normals()
		geometry.mesh = surface.commit()
		var apron_material := floor_material.duplicate() as ShaderMaterial
		apron_material.set_shader_parameter("doorway_apron", true)
		geometry.material_override = apron_material
		apron.add_child(geometry)
		add_child(apron)
	block(at + Vector3(-8, 2, 0), Vector3(0.5, 4, 13), c)
	block(at + Vector3(8, 2, 0), Vector3(0.5, 4, 13), c)
	for z in [-6.5, 6.5]:
		block(at + Vector3(-5, 2, z), Vector3(6, 4, 0.5), c)
		block(at + Vector3(5, 2, z), Vector3(6, 4, 0.5), c)
		block(at + Vector3(0, 3.7, z), Vector3(4, 0.6, 0.5), c)
	block(at + Vector3(0, 4.15, 0), Vector3(17, 0.3, 14), "465a61")
	var interior_cover := block(at + Vector3(-4, 0.8, 0), Vector3(2, 1.4, 3), "576b62")
	interior_cover.visible = false
	var cargo: Node3D = Visuals.vegetation_scene("res://assets/realism/supply_crate.glb").instantiate()
	cargo.position = at + Vector3(-4, 0.2, 0)
	cargo.scale = Vector3(0.8, 1.3 / 1.5, 1.5)
	add_child(cargo)
	if style != 0:
		var roof_kind := "gable" if style == 1 else "shed"
		var roof: Node3D = load("res://assets/realism/roof_" + roof_kind + ".glb").instantiate()
		roof.name = "RoofShell"
		roof.position = at + Vector3(0, 4.3, 0)
		add_child(roof)
		for part in roof.find_children("*", "MeshInstance3D", true, false):
			if str(part.name).begins_with("RoofEndWall"):
				part.material_override = mat(c)
			elif str(part.name).begins_with("RoofFlashing"):
				part.material_override = mat("303835")
			else:
				var sheet := ShaderMaterial.new()
				sheet.shader = preload("res://shaders/workshop_main_roof.gdshader")
				part.material_override = sheet
		var body := StaticBody3D.new()
		body.name = "RoofCollision"
		roof.add_child(body)
		var shape := CollisionShape3D.new()
		var hull := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for z in [-7.0, 7.0]:
			points.append(Vector3(-8.5, 0, z))
			points.append(Vector3(8.5, 0, z))
			if style == 1:
				points.append(Vector3(0, 1.7, z))
			else:
				points.append(Vector3(8.5, 1.2, z))
		hull.points = points
		shape.shape = hull
		body.add_child(shape)
	# Match the projecting rain hoods in facade_*.glb for bullets and actors.
	for direction in [-1.0, 1.0]:
		var hood := StaticBody3D.new()
		hood.name = "EntranceHoodCollision"
		hood.set_meta("entrance_hood", true)
		hood.position = at + Vector3(0, 3.98, direction * 7.30)
		hood.set_meta("surface", "hard")
		var hood_shape := CollisionShape3D.new()
		var hood_box := BoxShape3D.new()
		hood_box.size = Vector3(5.20, 0.08, 1.10)
		hood_shape.shape = hood_box
		hood.add_child(hood_shape)
		add_child(hood)
	Visuals.building(self, at, style)
	if style != 0:
		Visuals.service_yard(self, at)

func tree(at: Vector3, detail_distance := 25.0) -> void:
	var trunk := block(at + Vector3(0, 2, 0), Vector3(0.6, 4, 0.6), "60564a")
	trunk.visible = false
	Visuals.tree(self, at, detail_distance)

func set_zone(radius: float, center := Vector2.ZERO) -> void:
	zone_radius = radius
	if zone_mesh:
		# Physics and rendering both synchronize the circle. Avoid dirtying the
		# scene transform again while holding, or twice in the same frame.
		var target_scale := Vector3(radius, 1, radius)
		var target_position := Vector3(center.x, 8, center.y)
		if zone_mesh.scale != target_scale:
			zone_mesh.scale = target_scale
		if zone_mesh.position != target_position:
			zone_mesh.position = target_position

func show_loot(items: Dictionary) -> void:
	# Network snapshots and local frames usually contain the same supplies.
	# Compare scalar display inputs before touching any scene/resource properties.
	# Preserve iteration order: it determines the height of corpse loot stacks.
	if _loot_display_matches(items):
		return
	_loot_display_snapshot.clear()
	for id in loot_nodes.keys():
		if not items.has(id):
			loot_nodes[id].queue_free()
			loot_nodes.erase(id)
			if highlighted_supply == id:
				highlighted_supply = -1
	var colors := ["e8c77b", "77d7ad", "7bbee8", "d9844e", "c2d6c9", "b5a1dc"]
	var stack_heights := {}
	for id in items:
		var item: Dictionary = items[id]
		_loot_display_snapshot.append(id)
		_loot_display_snapshot.append(item.p)
		_loot_display_snapshot.append(item.kind)
		_loot_display_snapshot.append(item.has("drop_slot"))
		var offset := Vector3(0, 0.35, 0)
		if item.has("drop_slot"):
			# Keep interaction at the corpse position; compact stacks distinguish
			# the remaining categories without scattering supplies through walls.
			offset.y = 0.15 + int(stack_heights.get(item.p, 0)) * 0.2
			stack_heights[item.p] = int(stack_heights.get(item.p, 0)) + 1
		var size := Vector3(0.65, 0.2, 0.65) if item.has("drop_slot") else Vector3(0.65, 0.5, 0.65)
		if loot_nodes.has(id):
			var existing: MeshInstance3D = loot_nodes[id]
			if existing.position != item.p + offset:
				existing.position = item.p + offset
			var size_changed: bool = existing.mesh.size != size
			if size_changed:
				existing.mesh = loot_proxy_mesh(size)
			var kind_changed: bool = existing.get_meta("supply_kind", -1) != item.kind
			if kind_changed:
				# Category finishes share all properties except colour. Keep the
				# pickup's private material and shell bindings alive on updates.
				var finish: StandardMaterial3D = existing.material_override
				finish.albedo_color = mat(colors[item.kind]).albedo_color
				finish.emission = finish.albedo_color
				finish.emission_energy_multiplier = 0.0
				existing.set_meta("supply_kind", item.kind)
				if highlighted_supply == id:
					highlighted_supply = -1
			if size_changed or kind_changed:
				update_supply_attachment(existing, item.kind)
			continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = loot_proxy_mesh(size)
		mesh.position = item.p + offset
		mesh.material_override = loot_proxy_material(colors[item.kind])
		add_child(mesh)
		mesh.set_meta("supply_kind", item.kind)
		loot_nodes[id] = mesh
		update_supply_attachment(mesh, item.kind)

func loot_proxy_material(hex: String) -> StandardMaterial3D:
	var material: StandardMaterial3D = mat(hex).duplicate()
	# Keep the shader features stable when entering/leaving pickup range.
	# Only the emission uniform changes during gameplay.
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.0
	return material

func loot_proxy_mesh(size: Vector3) -> BoxMesh:
	# Drops have only two proxy sizes. Keep their geometry immutable and shared:
	# corpse/category updates must never resize another drop's mesh.
	if not _loot_proxy_meshes.has(size):
		var box := BoxMesh.new()
		box.size = size
		_loot_proxy_meshes[size] = box
	return _loot_proxy_meshes[size]

func _loot_display_matches(items: Dictionary) -> bool:
	if items.size() != loot_nodes.size() or _loot_display_snapshot.size() != items.size() * 4:
		return false
	var index := 0
	for id in items:
		var item: Dictionary = items[id]
		if (_loot_display_snapshot[index] != id
				or _loot_display_snapshot[index + 1] != item.p
				or _loot_display_snapshot[index + 2] != item.kind
				or _loot_display_snapshot[index + 3] != item.has("drop_slot")):
			return false
		index += 4
	return true

func update_supply_attachment(mesh: MeshInstance3D, kind: int) -> void:
	Visuals.supply_case(mesh)
	var existing = mesh.get_node_or_null("ForegripDisplay")
	if kind == 5 and existing == null:
		var model = preload("res://assets/foregrip.glb").instantiate()
		model.name = "ForegripDisplay"
		model.scale = Vector3.ONE * 2.5
		model.position.y = mesh.mesh.size.y / 2 + 0.4
		# Category updates can arrive between mobile detail passes.
		# Keep the new sibling attachment at the shell's current detail level.
		model.visible = mesh.get_node(^"SupplyCaseVisual").visible
		mesh.add_child(model)
	elif kind == 5 and existing != null:
		existing.position.y = mesh.mesh.size.y / 2 + 0.4
	elif kind != 5 and existing != null:
		mesh.remove_child(existing)
		existing.queue_free()

func highlight_supply(id: int) -> void:
	if highlighted_supply == id:
		return
	if loot_nodes.has(highlighted_supply):
		loot_nodes[highlighted_supply].material_override.emission_energy_multiplier = 0.0
	highlighted_supply = id
	if loot_nodes.has(id):
		var material: StandardMaterial3D = loot_nodes[id].material_override
		material.emission_energy_multiplier = 1.2

func random_cover_blocks_access(footprint: Rect2) -> bool:
	# Actor capsule radius is 0.38 m; include a small contact tolerance.
	if footprint.intersects(Rect2(11.5, 23, 8, 15).grow(0.40)):
		return true
	for feature in map_features:
		if feature.get("kind", "") != "building":
			continue
		var building_rect: Rect2 = feature["rect"]
		var center := building_rect.get_center()
		# Both entrances and the central aisle, including outside ramp approaches.
		if footprint.intersects(Rect2(center - Vector2(1.6, 10), Vector2(3.2, 20)).grow(0.40)):
			return true
	return false
