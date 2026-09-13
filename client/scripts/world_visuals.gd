extends RefCounted
## Presentation-only details. Uses its own random stream and creates no colliders.
static func military_materials(model: Node3D) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for index in range(mesh.mesh.get_surface_count()):
			var source = mesh.mesh.surface_get_material(index)
			if not source is StandardMaterial3D: continue
			if source.resource_name not in ["Field sleeves", "Ranger / field uniform", "Ranger / armor", "Wrist straps"]: continue
			var material: StandardMaterial3D = source.duplicate()
			material.albedo_color = Color(0.5, 0.5, 0.5) if source.resource_name == "Ranger / field uniform" else Color(0.3, 0.3, 0.3)
			material.albedo_texture = load("res://assets/realism/uniform.png")
			material.roughness = 1.0
			material.metallic_specular = 0.15
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			mesh.set_surface_override_material(index, material)

static func material_surface(material: StandardMaterial3D, color: String) -> void:
	# Supply-category colors must not be replaced by architectural plaster.
	if color in ["e8c77b", "77d7ad", "7bbee8", "d9844e", "c2d6c9", "b5a1dc"]:
		material.roughness = 0.85
		return
	if color == "303835":
		material.roughness = 0.8
		material.metallic = 0.35
		return
	var kind := "plaster"
	var scale := 0.28
	if color in ["737b68", "667b80"]:
		kind = "ground"
		scale = 0.18 if color == "737b68" else 0.035
	elif color == "3b484c":
		kind = "asphalt"
		scale = 0.125
	elif color == "465a61":
		kind = "roof"
		scale = 0.4
	elif color in ["bfc3a0", "dfb86b"]: return
	material.albedo_color = Color(0.48, 0.48, 0.48)
	if color == "829b9a": material.albedo_color = Color(0.29, 0.40, 0.34)
	if color == "a08773": material.albedo_color = Color(0.60, 0.43, 0.32)
	material.albedo_texture = load("res://assets/realism/" + kind + "_albedo.jpg")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/realism/" + kind + "_normal.jpg")
	material.normal_scale = 0.35
	material.roughness_texture = load("res://assets/realism/" + kind + "_roughness.jpg")
	material.roughness = 1.0
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if color == "737b68":
		# The arena is planar: avoid triplanar sampling and retain grazing-angle detail.
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3(40, 40, 1)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

static func environment(environment: Environment) -> void:
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/realism/sky.jpg")
	panorama.energy_multiplier = 0.85
	sky.sky_material = panorama
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bacbd4")
	environment.ambient_light_energy = 0.45
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.fog_light_color = Color("b4c6c8")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.08

static func building(world, at: Vector3, _style: int) -> void:
	var first_detail: int = world.get_child_count()
	for x in [-8.27, 8.27]:
		world.block(at + Vector3(x, 0.36, 0), Vector3(0.035, 0.34, 13), "5b625d", false)
		world.block(at + Vector3(x, 3.9, 0), Vector3(0.065, 0.12, 13), "465a61", false)
	for z in [-6.77, 6.77]:
		# Surface details stay outside the original clear doorway.
		for x in [-2.10, 2.10]:
			world.block(at + Vector3(x, 1.8, z), Vector3(0.20, 3.2, 0.10), "303835", false)
		world.block(at + Vector3(0, 3.5, z), Vector3(4.4, 0.20, 0.10), "303835", false)
		world.block(at + Vector3(0, 4.0, z), Vector3(17, 0.15, 0.18), "303835", false)
		world.block(at + Vector3(7.7, 2.05, z), Vector3(0.10, 3.9, 0.12), "303835", false)
		for y in [0.7, 2.0, 3.3]:
			world.block(at + Vector3(7.7, y, z), Vector3(0.20, 0.045, 0.15), "303835", false)
		for x in [-5, 5]:
			world.block(at + Vector3(x, 0.36, z), Vector3(6, 0.34, 0.035), "5b625d", false)
		var placements: Array = world.get_meta("shutter_placements", [])
		for x in [-5, 5]: placements.append(Transform3D(Basis(Vector3.UP, PI if z < 0 else 0), at + Vector3(x, 2.4, z)))
		world.set_meta("shutter_placements", placements)
	for index in range(first_detail, world.get_child_count()):
		var node = world.get_child(index)
		node.set_meta("visual_batch", "detail-" + str(node.material_override.get_instance_id()))

static func tree(world, at: Vector3) -> void:
	var model: Node3D = load("res://assets/realism/fir_near.glb").instantiate()
	model.position = at
	model.rotation.y = sin(at.x * 1.31 + at.z * 0.71) * PI
	world.add_child(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 25
	var distant := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(9.5, 9.5)
	distant.mesh = quad
	distant.position = at + Vector3(0, 4.5, 0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/realism/fir_impostor.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.35
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	distant.material_override = material
	distant.visibility_range_begin = 25
	distant.visibility_range_end = 300
	distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(distant)

static func supply_crate(world, at: Vector3) -> void:
	var model: Node3D = load("res://assets/realism/supply_crate.glb").instantiate()
	model.position = at
	world.add_child(model)

static func mountain(radius: float, height: float, index: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 941 + index
	noise.frequency = 0.018
	noise.fractal_octaves = 2
	var points := []
	for z in range(65):
		var row := []
		for x in range(65):
			var px := (x / 32.0 - 1.0) * radius
			var pz := (z / 32.0 - 1.0) * radius
			var distance := Vector2(px, pz).length() / radius
			var elevation := pow(maxf(0, 1.0 - distance * distance), 2) * height
			elevation *= 0.70 + 0.65 * (1.0 - absf(noise.get_noise_2d(px, pz)))
			elevation *= 0.88 + 0.12 * sin(px * 0.09 + pz * 0.045 + index)
			row.append(Vector3(px, elevation, pz))
		points.append(row)
	for z in range(64):
		for x in range(64):
			for point in [points[z][x], points[z][x + 1], points[z + 1][x], points[z][x + 1], points[z + 1][x + 1], points[z + 1][x]]:
				surface.add_vertex(point)
	surface.index()
	surface.generate_normals()
	return surface.commit()

static func ground_detail(world) -> void:
	world.block(Vector3(0, -0.25, 0), Vector3(650, 0.1, 650), "737b68", false)
	var random := RandomNumberGenerator.new()
	random.seed = 55191
	# Scenery beyond the playable ground, so it creates no invisible cover.
	for i in range(30):
		var rock: Node3D = load("res://assets/realism/boulder.glb").instantiate()
		var angle := i * TAU / 30.0
		var radius := random.randf_range(165, 188)
		rock.position = Vector3(cos(angle) * radius, -0.25, sin(angle) * radius)
		rock.rotation.y = random.randf() * TAU
		rock.scale = Vector3.ONE * random.randf_range(5, 12)
		world.add_child(rock)
	var template: Node3D = load("res://assets/realism/grass.glb").instantiate()
	var source: MeshInstance3D = template.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = source.mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cells := {}
	var density := FastNoiseLite.new()
	density.seed = 673
	density.frequency = 0.055
	for attempt in range(40000):
		var point := Vector2(random.randf_range(-109, 109), random.randf_range(-109, 109))
		if absf(point.x) < 10 or absf(point.y) < 9: continue
		if random.randf() > 0.65 + density.get_noise_2d(point.x, point.y): continue
		var blocked := false
		for obstacle in world.ground_obstacles:
			if obstacle.grow(0.5).has_point(point): blocked = true; break
		if blocked: continue
		var cell := Vector2i(floori(point.x / 24), floori(point.y / 24))
		if not cells.has(cell): cells[cell] = []
		var scale := random.randf_range(0.65, 1.15)
		var local := Vector3(point.x - cell.x * 24 - 12, 0.01, point.y - cell.y * 24 - 12)
		cells[cell].append(Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale), local))
	for cell in cells:
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = cells[cell].size()
		for index in range(instances.instance_count): instances.set_instance_transform(index, cells[cell][index])
		var grass := MultiMeshInstance3D.new()
		grass.name = "GrassCell"
		grass.multimesh = instances
		grass.material_override = material
		grass.position = Vector3(cell.x * 24 + 12, 0, cell.y * 24 + 12)
		grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grass.visibility_range_end = 75
		world.add_child(grass)
	template.free()

static func batch_details(world) -> void:
	var panel: Node3D = load("res://assets/realism/shutter_panel.glb").instantiate()
	world.add_child(panel)
	var placements: Array = world.get_meta("shutter_placements", [])
	for part in panel.find_children("*", "MeshInstance3D", true, false):
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = part.mesh
		instances.instance_count = placements.size()
		for i in range(placements.size()): instances.set_instance_transform(i, placements[i] * part.global_transform)
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = instances
		world.add_child(batch)
	world.remove_child(panel)
	panel.queue_free()
	var groups := {}
	for node in world.get_children():
		if node.has_meta("visual_batch"):
			var key: String = node.get_meta("visual_batch")
			if not groups.has(key): groups[key] = []
			groups[key].append(node)
	for key in groups:
		var nodes: Array = groups[key]
		var boxes: bool = nodes[0].mesh is BoxMesh
		var mesh: Mesh = BoxMesh.new() if boxes else nodes[0].mesh
		if boxes: mesh.size = Vector3.ONE
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = nodes.size()
		for index in range(nodes.size()):
			var node = nodes[index]
			var transform: Transform3D = node.transform
			if boxes: transform.basis = transform.basis.scaled(node.mesh.size)
			instances.set_instance_transform(index, transform)
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = instances
		batch.material_override = nodes[0].material_override
		world.add_child(batch)
		for node in nodes:
			world.remove_child(node)
			node.queue_free()
