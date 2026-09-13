extends RefCounted
## Presentation-only details. Uses its own random stream and creates no colliders.
static func material_surface(material: StandardMaterial3D, color: String) -> void:
	var kind := "concrete"
	if color in ["737b68"]: kind = "soil"
	elif color == "3b484c": kind = "asphalt"
	elif color == "667b80": kind = "stone"
	elif color in ["3d6258", "bfc3a0", "dfb86b"]: return
	material.albedo_texture = load("res://assets/surfaces/" + kind + ".png")
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * (0.12 if kind == "soil" else 0.65)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.roughness = 0.98 if kind in ["soil", "asphalt"] else 0.85

static func environment(environment: Environment) -> void:
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("447b9d")
	atmosphere.sky_horizon_color = Color("d8d4bd")
	atmosphere.ground_bottom_color = Color("565d52")
	atmosphere.ground_horizon_color = Color("d8d4bd")
	atmosphere.sky_curve = 0.2
	atmosphere.sun_angle_max = 5.0
	sky.sky_material = atmosphere
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5c8d0")
	environment.ambient_light_energy = 0.4
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.fog_light_color = Color("c8cebf")
	environment.fog_light_energy = 0.65
	environment.fog_density = 0.0015
	environment.fog_sky_affect = 0.3

static func building(world, at: Vector3, style: int) -> void:
	var first_detail: int = world.get_child_count()
	var trim: String = ["d3c6a6", "bcc8c0", "cdb89c"][style]
	# Thin trims lie against existing solid surfaces, leaving doors and cover intact.
	for x in [-8.27, 8.27]:
		world.block(at + Vector3(x, 0.36, 0), Vector3(0.035, 0.34, 13), "5b625d", false)
		world.block(at + Vector3(x, 3.45, 0), Vector3(0.035, 0.13, 13), trim, false)
		for z in [-5.8, -1.8, 2.2, 5.8]:
			world.block(at + Vector3(x, 2, z), Vector3(0.035, 3.4, 0.12), trim, false)
	for z in [-6.77, 6.77]:
		for x in [-5, 5]:
			world.block(at + Vector3(x, 0.36, z), Vector3(6, 0.34, 0.035), "5b625d", false)
			world.block(at + Vector3(x, 3.45, z), Vector3(6, 0.13, 0.035), trim, false)
			# Painted recessed service panels, not transparent or traversable windows.
			world.block(at + Vector3(x, 2.3, z), Vector3(1.8, 0.7, 0.04), "465a61", false)
			for slat in range(4):
				world.block(at + Vector3(x, 2.06 + slat * 0.15, z * 1.001), Vector3(1.65, 0.035, 0.025), "829b9a", false)

	for index in range(first_detail, world.get_child_count()):
		var node = world.get_child(index)
		node.set_meta("visual_batch", "detail-" + str(node.material_override.get_instance_id()))

static func tree(world, at: Vector3) -> void:
	for layer in range(2):
		var crown := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0
		mesh.bottom_radius = 2.55 - layer * 0.65
		mesh.height = 4.6 - layer * 0.7
		mesh.radial_segments = 9
		crown.mesh = mesh
		crown.material_override = world.mat("4d6c51" if layer == 0 else "607756")
		crown.position = at + Vector3(0, 7.6 + layer * 1.8, 0)
		crown.rotation.y = layer * 0.7
		crown.set_meta("visual_batch", "pine-" + str(layer))
		world.add_child(crown)

static func mountain(radius: float, height: float, index: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	for tier in range(3):
		var points := []
		for segment in range(18):
			var angle := segment * TAU / 18
			var irregular := 1.0 + 0.18 * sin(angle * 3 + index) + 0.1 * cos(angle * 7 - index)
			var scale: float = [1.0, 0.53, 0.16][tier]
			points.append(Vector3(cos(angle) * radius * scale * irregular, height * [0.0, 0.39, 0.8][tier] * (1 + 0.16 * sin(angle * 4 + index)), sin(angle) * radius * scale * irregular))
		rings.append(points)
	for tier in range(2):
		for segment in range(18):
			var next := (segment + 1) % 18
			for point in [rings[tier][segment], rings[tier][next], rings[tier + 1][segment], rings[tier][next], rings[tier + 1][next], rings[tier + 1][segment]]:
				surface.add_vertex(point)
	for segment in range(18):
		for point in [rings[2][segment], rings[2][(segment + 1) % 18], Vector3(radius * 0.04, height, 0)]:
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()

static func ground_detail(world) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 55191
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI / 3, PI * 2 / 3]:
		var rotation := Basis(Vector3.UP, angle)
		var side := Vector3(0.025, 0, 0)
		var middle := Vector3(0, 0.11, 0)
		var tip := Vector3(0.035, 0.23, 0)
		for point in [-side, middle - side * 0.5, side, side, middle - side * 0.5, middle + side * 0.5, middle - side * 0.5, tip, middle + side * 0.5]:
			surface.set_color(Color("4e5940").srgb_to_linear().lerp(Color("8a9060").srgb_to_linear(), point.y / 0.23))
			surface.add_vertex(rotation * point)
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	var transforms: Array[Transform3D] = []
	for attempt in range(1800):
		var point := Vector2(random.randf_range(-109, 109), random.randf_range(-109, 109))
		if absf(point.x) < 10 or absf(point.y) < 9: continue
		var blocked := false
		for obstacle in world.ground_obstacles:
			if obstacle.grow(0.5).has_point(point): blocked = true; break
		if blocked: continue
		var scale := random.randf_range(0.55, 1.3)
		transforms.append(Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale), Vector3(point.x, 0.01, point.y)))
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()): multimesh.set_instance_transform(index, transforms[index])
	var grass := MultiMeshInstance3D.new()
	grass.multimesh = multimesh
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end = 65
	world.add_child(grass)

static func batch_details(world) -> void:
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
