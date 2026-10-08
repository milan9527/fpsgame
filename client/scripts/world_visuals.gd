extends RefCounted
## Presentation-only details. Uses its own random stream and creates no colliders.
static var weapon_material_cache: Dictionary = {}
static var military_material_cache: Dictionary = {}
static var terrain_material_cache: ShaderMaterial
static var colony_texture: ImageTexture
static var mobile_colony_texture: ImageTexture
static var bake_android_ground := false
static var supply_case_scene: PackedScene

static func vegetation_scene(path: String) -> PackedScene:
	if OS.has_feature("android") or bake_android_ground:
		if OS.has_feature("android") and path.get_file() in ["verge_shrub.glb", "verge_fine_shrub.glb"]:
			return load(path.trim_suffix(".glb") + "_palette_mobile.glb") as PackedScene
		if path.get_file() in ["verge_fine_shrub.glb", "verge_birch.glb", "boulder.glb", "supply_crate.glb", "aircon.glb", "wall_lamp.glb"]:
			path = path.trim_suffix(".glb") + "_mobile.glb"
	return load(path) as PackedScene


# Shared by rendered triangles and grove root sampling.
static var RIDGE_CELLS: int = 24 if OS.has_feature("android") else 192
static var RIDGE_HALF: float = RIDGE_CELLS / 2.0

static func terrain_material() -> ShaderMaterial:
	if terrain_material_cache == null:
		terrain_material_cache = ShaderMaterial.new()
		terrain_material_cache.shader = load("res://shaders/terrain_slopes_mobile.gdshader" if OS.has_feature("android") or bake_android_ground else "res://shaders/terrain_slopes.gdshader")
		terrain_material_cache.set_shader_parameter("ground_map", load("res://assets/realism/ground_albedo.jpg"))
		for kind in ["albedo", "normal", "roughness"]:
			var key: String = "rock_map" if kind == "albedo" else "rock_" + kind
			terrain_material_cache.set_shader_parameter(key, load("res://assets/realism/terrain_rock_" + kind + ".jpg"))
	return terrain_material_cache

static func terrain_chunk_is_covered(chunk: MeshInstance3D) -> bool:
	# These baked terrain nodes remain static. Translation preserves normals;
	# conservatively retain the general shader for any other transform.
	if chunk.global_basis != Basis.IDENTITY or chunk.mesh == null:
		return false
	if chunk.mesh.get_surface_count() == 0:
		return false
	for surface in range(chunk.mesh.get_surface_count()):
		var arrays := chunk.mesh.surface_get_arrays(surface)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if normals.is_empty():
			return false
		for normal in normals:
			# Positive cone is convex under perspective interpolation. Checking
			# abs(y) would incorrectly accept mixed upward/downward normals.
			if not normal.is_finite() or normal.y <= 0.0 or normal.y * normal.y < (0.846 * 0.846) * normal.length_squared():
				return false
	return true

static func specialize_covered_terrain(terrain: Node3D, material: Material) -> void:
	# MSAA can evaluate normals outside a triangle at edge pixels. The cone
	# guarantee applies only to covered samples; Android uses disabled MSAA.
	if terrain.get_viewport() == null or terrain.get_viewport().msaa_3d != Viewport.MSAA_DISABLED:
		return
	if not material is ShaderMaterial or material.shader != load("res://shaders/terrain_slopes_mobile.gdshader"):
		return
	var covered: ShaderMaterial
	for chunk in terrain.find_children("*", "MeshInstance3D", true, false):
		if chunk.material_override != material or not terrain_chunk_is_covered(chunk):
			continue
		if covered == null:
			covered = material.duplicate() as ShaderMaterial
			# A compile-time constant removes the unused slope branch and its
			# samplers on drivers that retain uniform-controlled shader paths.
			covered.shader = preload("res://shaders/terrain_covered_mobile.gdshader")
		chunk.material_override = covered

static func weapon_finish(model: Node3D) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for index in range(mesh.mesh.get_surface_count()):
			var source = mesh.mesh.surface_get_material(index)
			if not source is StandardMaterial3D: continue
			var key: String = source.resource_name
			var polymer := key.begins_with("Slate /") or key in ["shotgun composite", "marksman composite"]
			var rubber := key.begins_with("Shoulder pad /")
			var brushed := key.begins_with("Bolt /")
			var optic := key.begins_with("Optic /")
			var alloy := key.begins_with("Receiver /") or key.begins_with("Receiver edge /")
			var alloy_edge := key.begins_with("Receiver edge /")
			if not (polymer or rubber or brushed or optic or alloy or key.begins_with("Graphite /")): continue
			var cache_key := "%s:%s" % [key, source.get_instance_id()]
			if not weapon_material_cache.has(cache_key):
				var finish: StandardMaterial3D = source.duplicate()
				# Coated steel has broad subdued reflections; exposed machined parts
				# retain a brighter, directional reflection. Stock pads are dielectric.
				finish.metallic = 0.0 if polymer or rubber else (0.92 if brushed else 0.56)
				if alloy: finish.metallic = 0.7
				finish.metallic_specular = 0.22 if rubber else (0.38 if polymer else 0.5)
				if brushed:
					finish.albedo_color = Color(0.46, 0.48, 0.50)
				elif optic:
					finish.albedo_color = Color(0.10, 0.105, 0.095)
				elif alloy:
					finish.albedo_color = Color(0.34, 0.36, 0.335) if alloy_edge else Color(0.285, 0.305, 0.28)
				elif not polymer and not rubber:
					finish.albedo_color = Color(0.19, 0.185, 0.17)
				elif polymer:
					finish.albedo_color = Color(0.075, 0.08, 0.06)
				# Use the authored UV maps directly. Avoid starting procedural texture
				# workers for maps that would immediately be replaced below.
				if source.albedo_texture == null:
					var noise := FastNoiseLite.new()
					noise.seed = 729
					noise.frequency = 0.18
					noise.fractal_octaves = 3
					var grain := NoiseTexture2D.new()
					grain.width = 256
					grain.height = 256
					grain.noise = noise
					grain.seamless = true
					var ramp := Gradient.new()
					var low := 0.84 if rubber else (0.66 if polymer else (0.23 if brushed else 0.48))
					var high := 0.97 if rubber else (0.85 if polymer else (0.36 if brushed else 0.68))
					if alloy:
						low = 0.34 if alloy_edge else 0.42
						high = 0.46 if alloy_edge else 0.56
					ramp.set_color(0, Color(low, low, low))
					ramp.set_color(1, Color(high, high, high))
					grain.color_ramp = ramp
					finish.roughness = 1.0
					finish.roughness_texture = grain
					finish.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
					finish.uv1_triplanar = true
					# Local triplanar coordinates keep grain fixed during reload/ADS.
					finish.uv1_scale = Vector3(10, 180, 10) if brushed else Vector3.ONE * (8.0 if polymer or rubber else 14.0)
					var micro := NoiseTexture2D.new()
					micro.width = 256
					micro.height = 256
					micro.noise = noise
					micro.seamless = true
					micro.as_normal_map = true
					micro.bump_strength = 0.7 if polymer else (0.45 if rubber else 0.08)
					finish.normal_enabled = true
					finish.normal_texture = micro
					finish.normal_scale = 0.65 if polymer else (0.5 if rubber else 0.12)
				finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				if source.albedo_texture != null:
					# Baked colours already contain the finish colour. Multiplying
					# by the legacy tint crushes receiver and stock into black.
					finish.albedo_color = Color.WHITE
					# Coated receiver metalness is authored in Blender; the
					# procedural fallback must not turn it back into bare metal.
					if alloy:
						finish.metallic = source.metallic
					finish.uv1_triplanar = false
					finish.uv1_scale = Vector3.ONE
					if source.roughness_texture != null:
						finish.roughness = source.roughness
						finish.roughness_texture = source.roughness_texture
						finish.roughness_texture_channel = source.roughness_texture_channel
					# Keep the baked tangent-space grain on the same UVs as the finish.
					if source.normal_enabled and source.normal_texture != null:
						finish.normal_enabled = source.normal_enabled
						finish.normal_texture = source.normal_texture
						finish.normal_scale = source.normal_scale
				weapon_material_cache[cache_key] = finish
			mesh.set_surface_override_material(index, weapon_material_cache[cache_key])

static func military_materials(model: Node3D) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for index in range(mesh.mesh.get_surface_count()):
			var source = mesh.mesh.surface_get_material(index)
			if not source is StandardMaterial3D: continue
			if source.resource_name not in ["Field sleeves", "Ranger / field uniform", "Ranger / armor", "Wrist straps"]: continue
			if military_material_cache.has(source):
				mesh.set_surface_override_material(index, military_material_cache[source])
				continue
			var material: StandardMaterial3D = source.duplicate()
			material.albedo_color = Color(0.7, 0.7, 0.7) if source.resource_name == "Ranger / field uniform" else Color(0.3, 0.3, 0.3)
			material.albedo_texture = load("res://assets/realism/uniform.png")
			if source.resource_name == "Field sleeves":
				# Preserve the authored first-person dye and weave.
				material.albedo_texture = source.albedo_texture
				material.albedo_color = source.albedo_color
			elif source.resource_name == "Wrist straps":
				# Solid woven cuff: camouflage must not overwrite its own material.
				material.albedo_texture = null
				material.albedo_color = source.albedo_color
			material.roughness = 1.0
			material.metallic_specular = 0.15
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			military_material_cache[source] = material
			mesh.set_surface_override_material(index, material)

static func meadow_surface() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	# Desktop export tools also build Android's serialized background ground.
	var mobile_ground := OS.has_feature("android") or bake_android_ground
	material.shader = load("res://shaders/meadow_ground_mobile.gdshader" if mobile_ground else "res://shaders/meadow_ground.gdshader")
	material.set_shader_parameter("noise_lattice", load("res://assets/realism/ground_noise.png"))
	material.set_shader_parameter("cached_noise", mobile_ground)
	material.set_shader_parameter("soil", load("res://assets/realism/ground_albedo.jpg"))
	material.set_shader_parameter("gravel", load("res://assets/realism/terrain_rock_albedo.jpg"))
	material.set_shader_parameter("soil_normal", load("res://assets/realism/ground_normal.jpg"))
	material.set_shader_parameter("gravel_normal", load("res://assets/realism/terrain_rock_normal.jpg"))
	# One world-space density field drives ground cover and the actual plants.
	# Cache the map across berm surfaces; never consume gameplay RNG.
	var cover_texture := mobile_colony_texture if mobile_ground else colony_texture
	if cover_texture == null:
		var density := FastNoiseLite.new()
		density.seed = 673
		density.frequency = 0.055
		var edges := FastNoiseLite.new()
		edges.seed = 1873
		edges.frequency = 0.32
		# Mobile shaders consume only RG, both normalized density/distance values.
		# Keep separate caches so desktop previews cannot affect Android baking.
		var image := Image.create(256, 256, false, Image.FORMAT_RG8 if mobile_ground else Image.FORMAT_RGBAF)
		for y in range(256):
			for x in range(256):
				var point := (Vector2(x, y) + Vector2(0.5, 0.5)) / 256.0 * 218.0 - Vector2(109, 109)
				image.set_pixel(x, y, Color(colony_field(point, density, edges).x, clampf(0.5 + road_recovery_distance(point) / 32.0, 0.0, 1.0), 0, 1))
		cover_texture = ImageTexture.create_from_image(image)
		if mobile_ground:
			mobile_colony_texture = cover_texture
		else:
			colony_texture = cover_texture
	material.set_shader_parameter("colony_map", cover_texture)
	return material

static func material_surface(material: StandardMaterial3D, color: String) -> void:
	# Supply-category colors must not be replaced by architectural plaster.
	if color in ["e8c77b", "77d7ad", "7bbee8", "d9844e", "c2d6c9", "b5a1dc"]:
		material.albedo_color *= Color(0.25, 0.25, 0.25, 1)
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
	elif color == "a5a69a":
		kind = "concrete"
		scale = 0.25
	elif color in ["bfc3a0", "dfb86b"]: return
	material.albedo_color = Color(0.48, 0.48, 0.48)
	if color == "829b9a": material.albedo_color = Color(0.29, 0.40, 0.34)
	if color == "a08773": material.albedo_color = Color(0.60, 0.43, 0.32)
	material.albedo_texture = load("res://assets/realism/" + kind + "_albedo.jpg")
	if color in ["b0a58c", "829b9a", "a08773"]:
		material.albedo_texture = load("res://assets/realism/plaster_painted.jpg")
		scale = 0.55
	material.normal_enabled = true
	material.normal_texture = load("res://assets/realism/" + kind + "_normal.jpg")
	material.normal_scale = 0.35
	material.roughness_texture = load("res://assets/realism/" + kind + "_roughness.jpg")
	material.roughness = 1.0
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if color == "a5a69a":
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3(4, 3.25, 1)
		material.normal_scale = 0.2
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if color == "737b68":
		# The arena is planar: avoid triplanar sampling and retain grazing-angle detail.
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		# One scan tile spans two metres, retaining soil grains in close views.
		material.uv1_scale = Vector3(120, 120, 1)
		material.normal_scale = 0.5
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
	# Rough metal still needs reflected sky in Compatibility (including
	# Android); direct light alone makes shaded weapons read as flat black.
	# Keep the low-resolution radiance map for a broad, inexpensive reflection.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if OS.has_feature("android") else Environment.REFLECTION_SOURCE_SKY
	environment.fog_light_color = Color("b4c6c8")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.00016
	environment.fog_sky_affect = 0.08
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		sky.radiance_size = Sky.RADIANCE_SIZE_64
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		# This is the final Forward+ setting, after world.gd's defaults.
		environment.ambient_light_energy = 0.40
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.ssao_enabled = true
		# Contact shade should describe door reveals without dirty broad halos
		# across the scanned plaster and corrugated wall surfaces.
		environment.ssao_radius = 0.62
		environment.ssao_intensity = 1.15
		environment.ssao_power = 1.1
		# Recover soft sky bounce in sheltered entrances while preserving
		# the directional contrast of sunlit ground and roof overhangs.
		environment.ssil_enabled = true
		environment.ssil_radius = 2.0
		environment.ssil_intensity = 0.44

static func building(world, at: Vector3, style: int) -> void:
	var facade: Node3D = load("res://assets/realism/facade_" + str(style) + ".glb").instantiate()
	facade.name = "WarehouseFacade"
	facade.position = at
	world.add_child(facade)
	var concrete: StandardMaterial3D = world.mat("a5a69a").duplicate()
	# Blender authored metre-based UVs, so the scan repeats every four metres.
	concrete.uv1_scale = Vector3(0.25, 0.25, 1)
	for part in facade.find_children("*", "MeshInstance3D", true, false):
		if str(part.name).begins_with("FacadeConcrete"):
			part.material_override = concrete
		elif style == 1 and str(part.name).begins_with("FacadeSteel"):
			var sheet: StandardMaterial3D = world.mat("465a61").duplicate()
			# Warm painted workshop cladding separates the western service row
			# from the cool galvanised eastern depot, retaining scanned wear.
			sheet.albedo_color = Color("f5e6cc") if at.x < 0 else Color("edf7fa")
			sheet.uv1_triplanar = false
			sheet.uv1_world_triplanar = false
			sheet.uv1_scale = Vector3(0.5, 0.5, 1)
			sheet.normal_scale = 0.25
			part.material_override = sheet
	var first_detail: int = world.get_child_count()
	# The two yard workshops have masonry splash courses and ventilated bays.
	# Relief sits against the existing solid side walls, away from door routes.
	if at.z == 34 and (at.x == 35 or at.x == -42):
		var yard_masonry := ShaderMaterial.new()
		yard_masonry.shader = preload("res://shaders/workshop_masonry.gdshader")
		for side in [-1.0, 1.0]:
			var plinth = world.block(at + Vector3(side * 8.29, 0.59, 0),
				Vector3(0.10, 1.18, 12.9), "77634d", false)
			plinth.material_override = yard_masonry
			world.block(at + Vector3(side * 8.33, 1.22, 0), Vector3(0.19, 0.08, 13.0), "95988a", false)
			for bay_z in [-5.9, -2.0, 2.0, 5.9]:
				world.block(at + Vector3(side * 8.34, 2.52, bay_z),
					Vector3(0.16, 2.5, 0.12), "66736e", false)
			for vent_z in [-3.95, 3.95]:
				world.block(at + Vector3(side * 8.36, 2.85, vent_z),
					Vector3(0.09, 1.05, 2.55), "303c3b", false)
				for blade in range(8):
					var louver = world.block(at + Vector3(side * 8.43, 2.39 + blade * 0.13, vent_z),
						Vector3(0.16, 0.045, 2.57), "89958d", false)
					louver.rotation.z = side * 0.35
				for trim_z in [-1.32, 1.32]:
					world.block(at + Vector3(side * 8.44, 2.85, vent_z + trim_z),
						Vector3(0.13, 1.13, 0.06), "a0a89b", false)
	# Flush grated drains define the loading apron, leaving the doorway and
	# canopy walking routes level. All pieces are batched with facade details.
	for z in [-8.1, 8.1]:
		for x in [-5.5, 5.5]:
			world.block(at + Vector3(x, 0.022, z), Vector3(6.0, 0.02, 0.38), "303835", false)
			for edge in [-0.22, 0.22]:
				world.block(at + Vector3(x, 0.033, z + edge), Vector3(6.1, 0.022, 0.065), "747970", false)
			for bar in range(50):
				world.block(at + Vector3(x - 2.94 + bar * 0.12, 0.041, z),
					Vector3(0.035, 0.024, 0.34), "59635f", false)
	# An electrical cabinet and surface conduit break up the blank front wall;
	# shallow fittings stay against the wall, outside the four-metre opening.
	for z in [-6.86, 6.86]:
		# The west workshop has a deeper, collidable cabinet on its front.
		if at.is_equal_approx(Vector3(-42, 0, 34)) and z > 0:
			continue
		var facing := signf(z)
		world.block(at + Vector3(-3.3, 1.45, z), Vector3(0.72, 0.95, 0.18), "59635f", false)
		world.block(at + Vector3(-3.3, 1.45, z + facing * 0.105), Vector3(0.64, 0.85, 0.035), "858c82", false)
		world.block(at + Vector3(-3.05, 1.45, z + facing * 0.13), Vector3(0.04, 0.18, 0.04), "303835", false)
		world.block(at + Vector3(-3.3, 2.55, z), Vector3(0.045, 1.25, 0.045), "59635f", false)
		world.block(at + Vector3(-4.8, 3.17, z), Vector3(3.04, 0.045, 0.045), "59635f", false)
		for y in [1.2, 1.4, 1.6]:
			world.block(at + Vector3(-3.42, y, z + facing * 0.127), Vector3(0.27, 0.018, 0.012), "303835", false)
	# Thin surface details remain within the existing wall/floor surfaces.
	for x in [-7.73, 7.73]:
		world.block(at + Vector3(x, 0.34, 0), Vector3(0.035, 0.28, 12.5), "5b625d", false)
	for z in [-6.23, 6.23]:
		for x in [-4.9, 4.9]:
			world.block(at + Vector3(x, 0.34, z), Vector3(5.6, 0.28, 0.035), "5b625d", false)
	# Painted lower wall protection and high cable trays give the working
	# interior a human scale; shallow surfaces preserve all walking routes.
	var wall_paint := StandardMaterial3D.new()
	wall_paint.albedo_color = Color("737c72")
	wall_paint.albedo_texture = load("res://assets/realism/plaster_painted.jpg")
	wall_paint.normal_enabled = true
	wall_paint.normal_texture = load("res://assets/realism/plaster_normal.jpg")
	wall_paint.normal_scale = 0.18
	wall_paint.roughness_texture = load("res://assets/realism/plaster_roughness.jpg")
	wall_paint.roughness = 1.0
	# Keep plaster grain at one physical size across long walls and door
	# returns instead of stretching a complete texture across each box.
	wall_paint.uv1_triplanar = true
	wall_paint.uv1_world_triplanar = true
	wall_paint.uv1_scale = Vector3.ONE * 0.55
	wall_paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for x in [-7.72, 7.72]:
		var lining = world.block(at + Vector3(x, 0.93, 0), Vector3(0.025, 1.08, 12.4), "5b625d", false)
		lining.material_override = wall_paint
		world.block(at + Vector3(x, 1.5, 0), Vector3(0.035, 0.045, 12.4), "303835", false)
		world.block(at + Vector3(x, 3.1, 0), Vector3(0.09, 0.065, 12.0), "59635f", false)
		for z in [-5.8, -3.0, 0.0, 3.0, 5.8]:
			world.block(at + Vector3(x, 3.0, z), Vector3(0.12, 0.22, 0.045), "59635f", false)
	for z in [-6.22, 6.22]:
		for x in [-4.9, 4.9]:
			var lining = world.block(at + Vector3(x, 0.93, z), Vector3(5.6, 1.08, 0.025), "5b625d", false)
			lining.material_override = wall_paint
			world.block(at + Vector3(x, 1.5, z), Vector3(5.6, 0.045, 0.035), "303835", false)
	# Floor joints are filtered in the slab material. Thin coplanar boxes
	# produce unstable dark lines at the entrance and while moving.
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
		for x in [-5, 5]: placements.append(Transform3D(Basis(Vector3.UP, PI if z < 0 else 0), at + Vector3(x, 2.4, z + signf(z) * 0.12)))
		world.set_meta("shutter_placements", placements)
		var facing := Basis(Vector3.UP, PI if z < 0 else 0)
		var outside: float = z + signf(z) * 0.18
		var aircons: Array = world.get_meta("aircon_placements", [])
		aircons.append(Transform3D(facing, at + Vector3(6.7, 1.8, outside)))
		world.set_meta("aircon_placements", aircons)
		var lamps: Array = world.get_meta("lamp_placements", [])
		lamps.append(Transform3D(facing, at + Vector3(2.8, 2.8, outside)))
		world.set_meta("lamp_placements", lamps)
	# Exposed steel framing gives the interior depth without lowering walkable headroom.
	for z in [-4.8, 0.0, 4.8]:
		world.block(at + Vector3(0, 3.77, z), Vector3(15.5, 0.30, 0.065), "414c48", false)
		for y in [3.61, 3.93]:
			world.block(at + Vector3(0, y, z), Vector3(15.5, 0.035, 0.24), "414c48", false)
		for x in [-7.62, 7.62]:
			world.block(at + Vector3(x, 3.51, z), Vector3(0.23, 0.52, 0.34), "505953", false)
	for x in [-5.2, -2.6, 2.6, 5.2]:
		world.block(at + Vector3(x, 3.95, 0), Vector3(0.10, 0.10, 12.5), "505953", false)
	for x in [-0.58, 0.58]:
		world.block(at + Vector3(x, 3.54, 0), Vector3(0.022, 0.23, 0.022), "414c48", false)
	world.block(at + Vector3(0, 3.405, 0), Vector3(1.5, 0.05, 0.34), "303835", false)
	var diffuser := StandardMaterial3D.new()
	diffuser.albedo_color = Color("fff2da")
	diffuser.emission_enabled = true
	diffuser.emission = Color("ffe6c1")
	diffuser.emission_energy_multiplier = 1.5
	for z in [-0.085, 0.085]:
		var panel = world.block(at + Vector3(0, 3.373, z), Vector3(1.35, 0.014, 0.075), "303835", false)
		panel.material_override = diffuser
	for index in range(first_detail, world.get_child_count()):
		var node = world.get_child(index)
		node.set_meta("visual_batch", "detail-" + str(node.material_override.get_instance_id()))
	var light := SpotLight3D.new()
	light.name = "InteriorLight"
	light.position = at + Vector3(0, 3.32, 0)
	light.light_color = Color("ffe6c1")
	light.light_energy = 3.5
	light.rotation_degrees.x = -90.0
	light.spot_range = 10.0
	light.spot_angle = 80.0
	light.spot_angle_attenuation = 1.65
	light.spot_attenuation = 0.85
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 10.0
	world.add_child(light)

static func depot_water_service(world) -> void:
	# A distinct utility side of the workshop: tank, manifold and a flush
	# drain define the yard without raising a curb across the door route.
	var at := Vector3(46, 0, 31)
	world.block(at + Vector3(0, 0.12, 0), Vector3(4.4, 0.24, 4.4), "62635c")
	var paint := ShaderMaterial.new()
	paint.shader = load("res://shaders/tank_paint.gdshader")
	var tank := MeshInstance3D.new()
	tank.name = "DepotWaterTank"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.65
	cylinder.bottom_radius = 1.65
	cylinder.height = 4.0
	cylinder.radial_segments = 64
	# Straight sides need no axial subdivisions; preserve radial detail.
	if OS.has_feature("android"):
		cylinder.rings = 0
	tank.mesh = cylinder
	tank.material_override = paint
	tank.position = at + Vector3(0, 2.24, 0)
	world.add_child(tank)
	var body := StaticBody3D.new()
	body.set_meta("surface", "hard")
	var shape := CollisionShape3D.new()
	var collider := CylinderShape3D.new()
	collider.radius = 1.65
	collider.height = 4.0
	shape.shape = collider
	body.add_child(shape)
	tank.add_child(body)
	world.ground_obstacles.append(Rect2(44.35, 29.35, 3.3, 3.3))
	for y in [0.38, 1.42, 2.82, 4.1]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.62
		torus.outer_radius = 1.70
		torus.rings = 48
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = paint
		ring.position = at + Vector3(0, y, 0)
		world.add_child(ring)
	var lid := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 1.65
	dome.height = 3.3
	lid.mesh = dome
	lid.scale = Vector3(1, 0.16, 1)
	lid.position = at + Vector3(0, 4.22, 0)
	lid.material_override = paint
	world.add_child(lid)
	# Bake the flattened cap into physics points; avoid scaled physics bodies.
	var cap_points := PackedVector3Array()
	for vertex in dome.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		cap_points.append(vertex * lid.scale)
	var cap_shape := ConvexPolygonShape3D.new()
	cap_shape.points = cap_points
	var cap_body := StaticBody3D.new()
	cap_body.position = lid.position
	cap_body.set_meta("surface", "hard")
	var cap_collision := CollisionShape3D.new()
	cap_collision.shape = cap_shape
	cap_body.add_child(cap_collision)
	world.add_child(cap_body)
	# Feed pipe is a physical obstruction only along the utility wall.
	for item in [
		{"at": Vector3(44.2, 1.0, 32.7), "size": Vector3(0.14, 1.8, 0.14)},
		{"at": Vector3(45.0, 0.32, 32.7), "size": Vector3(1.7, 0.14, 0.14)},
		{"at": Vector3(43.65, 1.9, 32.7), "size": Vector3(1.25, 0.14, 0.14)}]:
		world.block(item.at, item.size, "434b49")
	# Separate stencil glyphs follow the cylinder tangent instead of floating as a board.
	var stencil := "WATER 04"
	for i in range(stencil.length()):
		var angle := (float(i) - 3.5) * 0.115
		var label := Label3D.new()
		label.text = stencil[i]
		label.font_size = 64
		label.pixel_size = 0.004
		label.position = at + Vector3(sin(angle) * 1.658, 2.7, cos(angle) * 1.658)
		label.rotation.y = angle
		label.shaded = true
		label.modulate = Color("b6b5a3")
		world.add_child(label)
	var bounds: Array = world.get_meta("hardscape_bounds", [])
	bounds.append(Rect2(43.6, 28.6, 4.8, 4.8))
	# Flush grating and concrete shoulders read as drainage at walking height.
	for x in [28.0, 32.0, 36.0, 40.0, 44.0]:
		world.block(Vector3(x, 0.034, 45.1), Vector3(3.94, 0.025, 0.68), "62635c", false)
		world.block(Vector3(x, 0.049, 45.1), Vector3(3.86, 0.025, 0.38), "303835", false)
		for n in range(20):
			world.block(Vector3(x - 1.85 + n * 0.195, 0.068, 45.1), Vector3(0.055, 0.018, 0.38), "657477", false)
	bounds.append(Rect2(26, 44.7, 20, 0.8))
	world.set_meta("hardscape_bounds", bounds)

static func service_yard(world, at: Vector3) -> void:
	var exclusions: Array = world.get_meta("hardscape_bounds", [])
	var areas := [Rect2(Vector2(at.x - 11.5, at.z - 12.5), Vector2(23, 25))]
	# Only the inner plots connect directly to the main road: a connector to an
	# outer plot at the same Z would otherwise pass through its inner warehouse.
	if absf(at.x) < 45:
		var road_edge := signf(at.x) * 8.0
		var yard_edge := at.x - signf(at.x) * 11.5
		var connector := Rect2(Vector2(minf(road_edge, yard_edge), at.z - 3),
			Vector2(absf(yard_edge - road_edge), 6))
		# The eastern workshop shares the shelter's gravel access. A second
		# rectangular slab here crosses the shelter and cuts a hard seam through
		# its worn ground. Keep the parking court, but use that existing access.
		var shelter_site := Rect2(12.1, 25.6, 6.8, 8.0)
		if not connector.intersects(shelter_site):
			areas.append(connector)
	for area in areas:
		var center: Vector2 = area.get_center()
		var surface_height := 0.012 if area == areas[0] else 0.008
		var finish := ShaderMaterial.new()
		finish.shader = load("res://shaders/service_yard.gdshader")
		finish.set_shader_parameter("concrete", load("res://assets/realism/concrete_albedo.jpg"))
		finish.set_shader_parameter("gravel", load("res://assets/realism/terrain_rock_albedo.jpg"))
		finish.set_shader_parameter("soil", load("res://assets/realism/ground_albedo.jpg"))
		finish.set_shader_parameter("half_extent", area.size * 0.5)
		finish.set_shader_parameter("parking", area == areas[0])
		finish.set_shader_parameter("yard_center", center)
		# Follow the same excavated height field as the walking collider. A flat
		# overlay bridges roadside drainage and exposes a rectangular shelf.
		var slab := excavated_surface(world, area.grow(2.0), finish, false, surface_height)
		slab.name = "ServiceYardSurface"
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		exclusions.append(area.grow(0.15))
		# Paint yard surfaces before the building footprints on the tactical map.
		world.map_features.insert(0, {"rect": area, "kind": "road"})
	world.set_meta("hardscape_bounds", exclusions)

static func building_verge(world, at: Vector3) -> void:
	# Broad weathered soil shoulders connect buildings to their plots. They
	# stay outside the yard and door approaches, with no decorative collider.
	for x in [-14.0, 14.0]:
		var strip := MeshInstance3D.new()
		strip.name = "BuildingSoilVerge"
		var plane := PlaneMesh.new()
		plane.size = Vector2(6, 29)
		strip.mesh = plane
		strip.position = at + Vector3(x, 0.024, 0)
		var finish := ShaderMaterial.new()
		finish.shader = load("res://shaders/building_verge.gdshader")
		finish.set_shader_parameter("soil", load("res://assets/realism/ground_albedo.jpg"))
		strip.material_override = finish
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(strip)

static func tree(world, at: Vector3, detail_distance := 25.0) -> void:
	var litter := MeshInstance3D.new()
	var patch := PlaneMesh.new()
	patch.size = Vector2(7.2, 7.2)
	litter.mesh = patch
	if OS.has_feature("android") or bake_android_ground:
		litter.mesh = preload("res://scripts/tree_litter_mesh.gd").get_mesh()
	litter.position = at + Vector3(0, 0.023, 0)
	var soil := ShaderMaterial.new()
	soil.shader = load("res://shaders/tree_litter_mobile.gdshader" if OS.has_feature("android") or bake_android_ground else "res://shaders/tree_litter.gdshader")
	soil.set_shader_parameter("soil", load("res://assets/realism/ground_albedo.jpg"))
	litter.material_override = soil
	litter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(litter)

	var model: Node3D = load("res://assets/realism/fir_full.glb").instantiate()
	model.name = "fir_near"
	model.position = at
	# Keep trunk width aligned with the collider while breaking the uniform skyline.
	var height_scale := 0.82 + (sin(at.x * 2.17 + at.z * 0.93) * 0.5 + 0.5) * 0.46
	model.scale.y = height_scale
	model.rotation.y = sin(at.x * 1.31 + at.z * 0.71) * PI
	world.add_child(model)
	configure_fir_lod(world, model, minf(detail_distance, 18.0))

# Keep a lit, volumetric crown through the middle distance; all placements use
# the same policy, including the formerly unrestricted roadside trees.
static func configure_fir_lod(world, model: Node3D, near_end := 18.0) -> void:
	if OS.has_feature("android") or bake_android_ground:
		# Preserve the modeled crown and trunk with the least expensive source LOD.
		var mobile: Node3D = load("res://assets/realism/fir_mobile.glb").instantiate()
		mobile.transform = model.transform
		world.add_child(mobile)
		model.visible = false
		for mesh in mobile.find_children("*", "MeshInstance3D", true, false):
			mesh.visibility_range_end = 180.0
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	var middle: Node3D = load("res://assets/realism/fir_mid.glb").instantiate()
	middle.name = "FirMiddle"
	middle.transform = model.transform
	world.add_child(middle)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = near_end
	for mesh in middle.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_begin = near_end
		mesh.visibility_range_end = 70.0
	# Retain the actual branch silhouette and lighting at distance. The old
	# camera-facing unshaded card became a bright rectangular skyline cutout.
	var distant: Node3D = load("res://assets/realism/fir_far.glb").instantiate()
	distant.name = "FirDistant"
	distant.transform = model.transform
	world.add_child(distant)
	for mesh in distant.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_begin = 70.0
		mesh.visibility_range_end = 300.0
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func supply_crate(world, at: Vector3) -> void:
	var model: Node3D = vegetation_scene("res://assets/realism/supply_crate.glb").instantiate()
	model.position = at
	world.add_child(model)

static func supply_case(proxy: MeshInstance3D) -> void:
	var shell: Node3D = proxy.get_node_or_null("SupplyCaseVisual")
	if shell == null:
		# Keep the packed hierarchy alive across pickup removal/respawn cycles.
		if supply_case_scene == null:
			supply_case_scene = load("res://assets/realism/supply_case.glb") as PackedScene
		shell = supply_case_scene.instantiate()
		shell.name = "SupplyCaseVisual"
		proxy.add_child(shell)
		# Hide only the proxy geometry; its children and highlight material remain active.
		proxy.layers = 0
	if shell.scale != proxy.mesh.size:
		shell.scale = proxy.mesh.size
	if shell.get_meta("category_material", 0) == proxy.material_override.get_instance_id():
		return
	# The instantiated case hierarchy is fixed. Discover category surfaces once,
	# then reuse their bindings when a network snapshot changes the pickup kind.
	if not shell.has_meta("category_surfaces"):
		var bindings: Array = []
		for part in shell.find_children("*", "MeshInstance3D", true, false):
			for surface in range(part.mesh.get_surface_count()):
				var source: Material = part.mesh.surface_get_material(surface)
				if source != null and source.resource_name == "Supply body":
					bindings.append([part, surface])
		shell.set_meta("category_surfaces", bindings)
	for binding in shell.get_meta("category_surfaces"):
		binding[0].set_surface_override_material(binding[1], proxy.material_override)
	shell.set_meta("category_material", proxy.material_override.get_instance_id())

static func ridge_height(px: float, pz: float, radius: float, height: float, index: int, noise: FastNoiseLite) -> float:
	var distance := Vector2(px, pz).length() / radius
	if distance >= 1.0: return 0.0
	# An uneven crest follows a bent watershed. Its asymmetric summits and
	# descending spurs remain visible from the playable valley, rather than
	# repeating a rounded cap on every background mountain.
	var local := Vector2(px, pz).rotated(float(index) * TAU / 18.0) / radius
	var warp := noise.get_noise_2d(px * 0.72 + 219, pz * 0.72 - 87)
	var across := local.y + 0.19 * sin(local.x * 3.8 + index) + warp * 0.15
	var width := 0.60 + 0.13 * sin(index * 2.17)
	var flank_width := width * (0.70 if across < 0.0 else 1.18)
	var crest_rounding := 0.14 + 0.08 * (0.5 + 0.5 * sin(index * 2.41))
	var crest_distance := sqrt(across * across + crest_rounding * crest_rounding) - crest_rounding
	# A narrow, uneven crest above a concave lower slope reads as a ridge.
	# Some massifs retain a broad upper shoulder instead of the same pyramid.
	# A convex crest joins a concave talus slope. The former smoothstep
	# shelf flattened every watershed into the same soft inflated shoulder.
	var main := pow(maxf(0.0, 1.0 - crest_distance / flank_width), 1.25)
	var shoulder := exp(-pow((local.y + local.x * 0.54 + 0.24) / 0.30, 2.0))
	shoulder *= 0.28 + 0.19 * (0.5 + 0.5 * cos(index * 1.73))
	var along := maxf(0.0, 1.0 - pow(absf(local.x) / 0.98, 5.0))
	# A long rock escarpment carries several unequal crests. A broad backbone
	# keeps secondary peaks above the main peak's flanks instead of hiding
	# them inside another cone when seen from the playable valley.
	var phase := float(index) * 1.73
	# Broad unequal summit shoulders replace narrow peaks superimposed on a
	# noisy crest. The previous combined frequencies produced a ring of
	# pointed teeth, even though each individual ridge had a different seed.
	var backbone := 0.52 + 0.09 * sin(local.x * 2.8 + phase)
	var west_crest := (0.22 + 0.12 * sin(phase * 1.31)) * exp(-pow((local.x + 0.30 + 0.12 * sin(phase)) / 0.38, 4.0))
	var east_crest := (0.20 + 0.10 * cos(phase)) * exp(-pow((local.x - 0.40) / 0.32, 4.0))
	var summits := backbone + west_crest + east_crest
	summits -= 0.12 * exp(-pow((local.x + 0.09 + 0.12 * sin(phase)) / 0.24, 2.0))
	# Unequal rock blocks break the continuous rounded skyline at 15–40 m
	# scale. Keep small noise out of the silhouette: it reads as saw teeth.
	summits += noise.get_noise_2d(px * 0.45 - 82, pz * 0.35 + 57) * 0.10
	var crest_detail := noise.get_noise_2d(px * 1.6 + 137, pz * 1.3 - 91)
	summits += crest_detail * 0.045 * (1.0 - smoothstep(0.12, 0.48, absf(across)))
	var saddle := 0.0
	# Broad drainage basins vary in both axes. Avoid absolute-value noise
	# contours, which previously cut parallel comb-like grooves into every hill.
	var basin := noise.get_noise_2d(px * 1.15 - 71, pz * 1.15 + 183)
	var flank := smoothstep(0.03, 0.20, absf(across))
	# Unequal V-shaped catchments merge into wider talus fans downhill.
	# A branch joins only partway down each face, rather than repeating
	# three parallel Gaussian grooves across all eighteen mountains.
	# This same height field grounds the forest on the actual mesh.
	var gullies := 0.0
	var foothills := 0.0
	for channel in range(5):
		var channel_phase := index * 2.13 + channel * 4.71
		var axis := -0.73 + channel * 0.36 + 0.105 * sin(channel_phase)
		axis += across * (0.22 + 0.23 * sin(channel_phase + 0.8)) + warp * 0.14
		var spread := (0.045 + absf(across) * 0.23) * (0.8 + 0.3 * cos(channel_phase))
		# Smooth valley floors avoid the razor seams produced by V cuts.
		var cut := 1.0 - smoothstep(0.0, spread, absf(local.x - axis))
		var branch_axis := axis + (0.34 - absf(across)) * (0.6 if channel % 2 == 0 else -0.6)
		var branch := maxf(0.0, 1.0 - absf(local.x - branch_axis) / (spread * 0.65))
		branch *= smoothstep(0.08, 0.20, absf(across)) * (1.0 - smoothstep(0.30, 0.50, absf(across)))
		gullies = maxf(gullies, maxf(cut, branch * 0.65) * (0.7 + 0.3 * sin(channel_phase + 1.3)))
		# Each catchment deposits a broad, unequal fan at its mouth.
		# These overlapping lower shoulders change the actual silhouette
		# and break the uninterrupted plane from summit to valley floor.
		var fan_axis := axis + 0.16 + 0.07 * sin(channel_phase)
		var fan_width := 0.12 + absf(across) * 0.22
		var fan := exp(-pow((local.x - fan_axis) / fan_width, 2.0))
		fan *= exp(-pow((absf(across) - 0.38 - 0.07 * sin(channel_phase)) / 0.23, 2.0))
		foothills = maxf(foothills, fan * (0.16 + 0.07 * cos(channel_phase)))
	# Incised valleys cut the slope itself. Multiplying this cut by the
	# watershed used to erase most relief on the visible lower flanks.
	var erosion := basin * 0.16 * flank
	var watershed := maxf(main, shoulder) + minf(main, shoulder) * 0.18
	var spur_axis := local.y - local.x * 0.65 - 0.30
	var spur := exp(-pow(spur_axis / 0.24, 2.0)) * exp(-pow((local.x + 0.12) / 0.68, 2.0))
	watershed = maxf(watershed, spur * 0.64)
	var edge := 1.0 - smoothstep(0.75, 1.0, distance)
	var relief := watershed * (summits - saddle + erosion) * along
	var drainage := gullies * flank * 0.25 * along * smoothstep(0.02, 0.30, relief)
	# Bedrock shoulders interrupt the long smooth face between catchments.
	var rock := noise.get_noise_2d(px * 1.7 + 32, pz * 1.7 - 114)
	relief += rock * 0.24 * flank * smoothstep(0.08, 0.38, relief)
	# Broad erosion remains continuous. Quantizing elevation into bedding bands
	# created bright contour stripes on distant slopes under the low sun.
	# Broad fractured buttresses interrupt the uninterrupted convex
	# faces. Domain warping joins them into irregular descending ribs, rather
	# than adding evenly spaced grooves or horizontal elevation terraces.
	# Include this relief in the shared height function so forest placement
	# continues to sample precisely the mesh that is rendered.
	var fracture_warp := noise.get_noise_2d(px * 1.1 + 401, pz * 1.1 - 239)
	var fracture_field := noise.get_noise_2d(px * 1.8 + fracture_warp * 12.0, pz * 1.5 - fracture_warp * 9.0)
	var buttress := 1.0 - absf(fracture_field) * 2.0
	buttress = smoothstep(0.20, 0.86, buttress) - 0.48
	var rock_zone := smoothstep(0.10, 0.32, relief) * (1.0 - smoothstep(0.70, 0.98, distance))
	var eroded := maxf(0.0, relief - drainage + buttress * 0.065 * rock_zone) + foothills * along
	# Fault-bounded rock shoulders: broad upper shelves terminate in narrow
	# inclined faces, rather than another layer of rounded noise. Faults are
	# oblique to each ridge and broken along strike; no global elevation steps.
	# The 5–12 m escarpments occupy several grid cells, so their actual normals
	# expose rock in terrain_slopes and remain legible beyond the tree belt.
	var strike := local.x * radius
	var dip := local.y * radius
	var fault_warp := noise.get_noise_2d(strike * 0.65 + 713.0, dip * 0.65 - 327.0)
	var fault_axis := dip + strike * (0.28 + 0.16 * sin(index * 1.91)) + fault_warp * 19.0
	var fault_break := smoothstep(-0.28, 0.18, noise.get_noise_2d(strike * 1.3 - 521.0, dip * 0.45 + 619.0))
	var shelf := smoothstep(-19.0, -14.0, fault_axis) * (1.0 - smoothstep(-5.0, 24.0, fault_axis))
	var second_shelf := smoothstep(18.0, 23.0, fault_axis) * (1.0 - smoothstep(33.0, 58.0, fault_axis))
	var outcrop_zone := smoothstep(0.14, 0.34, relief) * (1.0 - smoothstep(0.62, 0.85, distance))
	eroded += (shelf + second_shelf * 0.65) * fault_break * outcrop_zone * 0.20
	return height * maxf(0.0, eroded) * edge

static func mountain(radius: float, height: float, index: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 941 + index
	noise.frequency = 0.018
	noise.fractal_octaves = 2
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for z in range(RIDGE_CELLS + 1):
		for x in range(RIDGE_CELLS + 1):
			var px := (x / RIDGE_HALF - 1.0) * radius
			var pz := (z / RIDGE_HALF - 1.0) * radius
			points.append(Vector3(px, ridge_height(px, pz, radius, height, index, noise), pz))
			normals.append(Vector3.ZERO)
	var stride := RIDGE_CELLS + 1
	# Average the actual incident faces, weighted by area. Sampling derivatives
	# below the mesh spacing lit unresolved gullies as isolated sharp facets.
	# Keep the same heights and triangulation used by background_height().
	for z in range(RIDGE_CELLS):
		for x in range(RIDGE_CELLS):
			var corner := z * stride + x
			for triangle in [[corner, corner + 1, corner + stride], [corner + 1, corner + stride + 1, corner + stride]]:
				var face := (points[triangle[2]] - points[triangle[0]]).cross(points[triangle[1]] - points[triangle[0]])
				for vertex in triangle:
					normals[vertex] += face
	for vertex in range(normals.size()):
		normals[vertex] = normals[vertex].normalized()
	for z in range(RIDGE_CELLS):
		for x in range(RIDGE_CELLS):
			var corner := z * stride + x
			for vertex in [corner, corner + 1, corner + stride, corner + 1, corner + stride + 1, corner + stride]:
				surface.set_normal(normals[vertex])
				surface.add_vertex(points[vertex])
	surface.index()
	if OS.has_feature("android"):
		# Reuse transformed ridge vertices across grid rows without changing
		# the silhouette, normals, or the height samples used by forest placement.
		surface.optimize_indices_for_cache()
	return surface.commit()

static func growth_overlaps_rect(node: Node3D, bounds: Rect2) -> bool:
	# Imported plants can have offset mesh origins and rotated, wide crowns.
	# Transform the mesh bounds, not just the placement point.
	if node is MeshInstance3D and node.mesh != null:
		var box: AABB = node.global_transform * node.mesh.get_aabb()
		var footprint := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		if footprint.intersects(bounds):
			return true
	for child in node.get_children():
		if child is Node3D and growth_overlaps_rect(child, bounds):
			return true
	return false

static func clear_service_access_growth(world) -> void:
	# All groundcover generators have run. Reserve the same two-segment
	# footprint as service_access.gdshader, including foliage overhang.
	var removed := 0
	var depot_removed := 0
	for child in world.get_children():
		if not child is Node3D:
			continue
		var asset: String = child.scene_file_path
		if not ("grass" in asset or "shrub" in asset):
			continue
		var on_loading_slab := false
		for bounds in world.get_meta("depot_loading_bounds", []):
			if growth_overlaps_rect(child, bounds):
				on_loading_slab = true
				break
		if on_loading_slab:
			world.remove_child(child)
			child.free()
			depot_removed += 1
			continue
		var p := Vector2(child.position.x, child.position.z)
		if p.y < 35.94 or p.y > 53.0 or p.x < 6.0:
			continue
		var distance := INF
		var path := service_access_path()
		for step in range(path.size() - 1):
			distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[step], path[step + 1])))
		if distance < 3.65:
			world.remove_child(child)
			child.free()
			removed += 1
	world.set_meta("service_access_removed_growth", removed)
	world.set_meta("depot_removed_growth", depot_removed)

static func service_access_point(t: float) -> Vector2:
	# A tangent-continuous vehicle turn: straight out of the door, then
	# horizontal at the asphalt. Shared by the surface and verge clearance.
	return Vector2(15.5, 35.9).bezier_interpolate(
		Vector2(15.5, 45.8), Vector2(13.8, 49.2), Vector2(6.0, 49.2), t)

static func service_access_path() -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(17):
		points.append(service_access_point(float(step) / 16.0))
	return points

static func configure_service_path(material: ShaderMaterial) -> void:
	var points := service_access_path()
	var projection := PackedVector3Array()
	for index in range(points.size() - 1):
		var segment := points[index + 1] - points[index]
		projection.append(Vector3(segment.x, segment.y, 1.0 / maxf(segment.length_squared(), 0.000001)))
	material.set_shader_parameter("access_points", points)
	material.set_shader_parameter("access_projection", projection)

static func service_ground_material() -> ShaderMaterial:
	var surface := ShaderMaterial.new()
	surface.shader = load("res://shaders/service_ground.gdshader")
	surface.set_shader_parameter("noise_lattice", load("res://assets/realism/ground_noise.png"))
	surface.set_shader_parameter("fracture_field", load("res://assets/realism/ground_fracture.png"))
	configure_service_path(surface)
	surface.set_shader_parameter("gravel_normal", load("res://assets/realism/terrain_rock_normal.jpg"))
	surface.set_shader_parameter("gravel", load("res://assets/realism/terrain_rock_albedo.jpg"))
	surface.set_shader_parameter("soil", load("res://assets/realism/ground_albedo.jpg"))
	return surface


# Excavate beneath both the road bed and its shoulders. Entrances and the
# crossroads retain grade; render and physics use the same sampled surface.
static func road_cut_height(point: Vector2) -> float:
	var cut := 0.0
	for east_west in [false, true]:
		var along := point.x if east_west else point.y
		var across := absf(point.y if east_west else point.x)
		var side := signf(point.y if east_west else point.x)
		var entrance := 1.0
		var accesses := [-72.0, -42.0, 35.0, 68.0] if east_west else [-70.0, -35.0, 34.0, 70.0]
		# Only the east shoulder feeds the curved repair-yard access.
		# The shelter's internal apron at z=26 is not a road crossing.
		if not east_west and side > 0.0:
			accesses.append(49.2)
		for access in accesses:
			# Keep the running width level, then splay the embankment toward
			# the field. An oblique toe avoids a rectangular flat earth strip.
			var bank_flare := smoothstep(5.0, 12.0, across)
			var skew := bank_flare * side * 1.15
			entrance = minf(entrance, smoothstep(3.2, 5.2 + bank_flare * 2.4, absf(along - access - skew)))
		var ends := smoothstep(11.0, 16.0, absf(along)) * (1.0 - smoothstep(105.0, 112.5, absf(along)))
		# A narrow drainage invert and unequal banks replace the four-metre
		# flat trench floor. Side-dependent meanders break the parallel strips
		# without moving the paved running surface or the level access mouths.
		var phase := side * 2.3 + (1.7 if east_west else 0.0)
		var wander := sin(along * 0.117 + phase) * 0.75 + sin(along * 0.31 - phase) * 0.25
		var invert := 7.2 + wander
		var outer_bank := 13.4 + wander + sin(along * 0.073 + phase) * 1.8
		var trench := smoothstep(4.8, invert, across) * (1.0 - smoothstep(invert, outer_bank, across))
		var depth := 0.58 + 0.20 * sin(along * 0.093 + phase)
		# Runoff cuts oblique gullies into the outer bank, rather than leaving
		# one smooth extruded ditch. Broad fans resolve on the physics mesh;
		# both their mouths and their upper ends taper back into the bank.
		# Independent catchments avoid a repeated sawtooth bank. Check the
		# neighbours so cuts remain continuous across catchment cell borders.
		var catchment := along + (across - invert) * 1.2
		var cell := floorf(catchment / 19.0)
		var channel := 0.0
		for neighbour in range(-1, 2):
			var seed := cell + float(neighbour)
			var jitter := fposmod(sin(seed * 127.1 + phase * 31.7) * 43758.5453, 1.0)
			var strength := fposmod(sin(seed * 269.5 + phase * 17.3) * 18341.173, 1.0)
			var center := (seed + 0.18 + jitter * 0.64) * 19.0
			var width := 1.2 + strength * 2.4
			channel = maxf(channel, (1.0 - smoothstep(0.0, width, absf(catchment - center))) * (0.3 + strength * 0.7))
		var bank := smoothstep(invert - 0.8, invert + 1.0, across) * (1.0 - smoothstep(outer_bank - 0.8, outer_bank + 1.5, across))
		var runoff := channel * bank * 0.23
		# A broken pair of depressed wheel paths along the unpaved shoulder
		# gives the road edge a physical profile, including grazing shadows.
		var wheel_offset := across - (5.0 + sin(along * 0.13 + phase) * 0.18)
		var wheels := 1.0 - smoothstep(0.12, 0.48, absf(absf(wheel_offset) - 0.48))
		var travelled := smoothstep(-0.5, 0.3, sin(along * 0.17 + phase))
		cut = minf(cut, (-depth * trench - runoff - wheels * travelled * 0.18) * entrance * ends)
	return cut + service_yard_relief(point)

static func service_yard_relief(point: Vector2) -> float:
	# Graded spoil settles into connected low shelves, not isolated conical
	# heaps. Keep the lane clear and share these slopes with terrain collision.
	if point.x < 8.5 or point.x > 26.0 or point.y < 35.5 or point.y > 52.0:
		return 0.0
	var lane_distance := 100.0
	var lane_side := 0.0
	var lane_t := 0.0
	for i in range(16):
		var a := service_access_point(float(i) / 16.0)
		var b := service_access_point(float(i + 1) / 16.0)
		var ab := b - a
		var fraction := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var nearest := a + ab * fraction
		var distance := point.distance_to(nearest)
		if distance < lane_distance:
			lane_distance = distance
			lane_side = signf(ab.cross(point - nearest))
			lane_t = (float(i) + fraction) / 16.0
	var envelope := smoothstep(8.5, 10.5, point.x) * (1.0 - smoothstep(23.0, 26.0, point.x))
	envelope *= smoothstep(35.5, 38.0, point.y) * (1.0 - smoothstep(48.0, 52.0, point.y))
	var bank_start := 3.7 + sin(point.y * 0.31) * 0.22
	var bank := smoothstep(bank_start, bank_start + 2.8, lane_distance)
	bank *= 1.0 - smoothstep(7.0, 10.0, lane_distance)
	var settled_height := 0.32 + sin(point.y * 0.37 + point.x * 0.13) * 0.055
	settled_height += sin(point.y * 0.79 - point.x * 0.24) * 0.025
	# A shallow drainage toe separates the gravel fill from the earth bank.
	# Its broad section can be walked across without a collision ledge.
	var toe := smoothstep(3.55, 4.05, lane_distance) * (1.0 - smoothstep(4.3, 5.2, lane_distance))
	# Different wheels cut different arcs through the turn. Broad shallow
	# depressions disappear on firm patches instead of two continuous raised
	# rails; no positive lip is added along the entire vehicle path.
	var wheel_center := 1.02 + lane_side * sin(lane_t * PI) * 0.22
	wheel_center += sin(lane_t * 13.0 + lane_side * 1.6) * 0.16
	var wheel_distance := absf(lane_distance - wheel_center)
	var wheel_width := 0.62 + 0.17 * sin(lane_t * 17.0 + lane_side)
	var rut := 1.0 - smoothstep(0.08, wheel_width, wheel_distance)
	var wear := smoothstep(-0.65, 0.55, sin(lane_t * 24.0 + lane_side * 2.4))
	wear *= 0.55 + 0.45 * smoothstep(-0.8, 0.7, sin(lane_t * 11.0 - lane_side))
	var rut_envelope := smoothstep(12.0, 14.0, point.x) * smoothstep(36.3, 38.5, point.y)
	rut_envelope *= 1.0 - smoothstep(48.5, 50.5, point.y)
	return (bank * settled_height - toe * 0.045) * envelope - rut * 0.11 * wear * rut_envelope

static func service_surface_axis(start: float, end: float, fine_start: float, fine_end: float) -> PackedFloat32Array:
	# Locally resolve the 40 cm tyre section without tripling resolution
	# across the entire map. World-aligned samples also align overlay/ground.
	# Mobile keeps the yard samples but halves subdivision elsewhere. The
	# terrain and collision bake use this same axis, avoiding floating players.
	var outer_stride := 6 if OS.has_feature("android") or bake_android_ground else 3
	var samples := PackedFloat32Array([start])
	var value := ceilf(start * 4.0) / 4.0
	while value < end:
		if value > start and (value >= fine_start and value <= fine_end or posmod(roundi(value * 4.0), outer_stride) == 0):
			samples.append(value)
		value += 0.25
	samples.append(end)
	return samples

static func service_ground_regions() -> Array[Rect2]:
	# Conservative support of service_ground.gdshader (noise is in [0,1]).
	# Yard dilation <= 1.1 + 1.5 + 1.025; access radius <= 6.5125,
	# storage dilation <= 1.3; bay radius <= 1.6575. Rounded outward.
	# Revisit these bounds if the shader's coverage or access path changes.
	return [Rect2(7, 23, 18, 20), Rect2(7, 29, 16, 27),
		Rect2(-25, 29, 12, 10), Rect2(11, 11, 12, 12),
		Rect2(-26, 24, 4, 20)]

static func excavated_surface(world, bounds: Rect2, material: Material, solid: bool, offset: float = 0.0, visible_regions: Array[Rect2] = []) -> MeshInstance3D:
	# The Android packager bakes the exact mesh and collision from this source.
	# Avoid rebuilding hundreds of thousands of triangles on the phone.
	if OS.has_feature("android") and solid and offset == 0.0 and bounds == Rect2(-120, -120, 240, 240) and ResourceLoader.exists("res://assets/android_terrain.res"):
		var cached := MeshInstance3D.new()
		cached.name = "ExcavatedTerrain"
		if ResourceLoader.exists("res://assets/android_terrain_chunks.scn"):
			var chunks: Node3D = load("res://assets/android_terrain_chunks.scn").instantiate()
			for chunk in chunks.get_children():
				chunk.material_override = material
			cached.add_child(chunks)
		else:
			cached.mesh = load("res://assets/android_terrain.res")
			cached.material_override = material
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		collision.shape = load("res://assets/android_terrain_collision.res")
		body.add_child(collision)
		body.set_meta("surface", "terrain")
		cached.add_child(body)
		cached.move_child(body, 0)
		world.add_child(cached)
		specialize_covered_terrain(cached, material)
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := service_surface_axis(bounds.position.x, bounds.end.x, -15.0, 20.0)
	var zs := service_surface_axis(bounds.position.y, bounds.end.y, -15.0, 51.0)
	var nx := xs.size() - 1
	var nz := zs.size() - 1
	for z in range(nz + 1):
		for x in range(nx + 1):
			var point := Vector2(xs[x], zs[z])
			st.set_uv(point)
			st.add_vertex(Vector3(point.x, road_cut_height(point) + offset, point.y))
	for z in range(nz):
		for x in range(nx):
			var a := z * (nx + 1) + x
			for index in [a, a + 1, a + nx + 2, a, a + nx + 2, a + nx + 1]:
				st.add_index(index)
	st.generate_normals()
	var arrays := st.commit_to_arrays()
	if not visible_regions.is_empty() and not solid:
		# Generate normals on the original connected surface first: removing
		# invisible neighbours before this step changes lighting at the margin.
		var retained := PackedInt32Array()
		for z in range(nz):
			for x in range(nx):
				var cell := Rect2(xs[x], zs[z], xs[x + 1] - xs[x], zs[z + 1] - zs[z])
				for region in visible_regions:
					if cell.intersects(region, true):
						var a := z * (nx + 1) + x
						retained.append_array(PackedInt32Array([a, a + 1, a + nx + 2, a, a + nx + 2, a + nx + 1]))
						break
		arrays[Mesh.ARRAY_INDEX] = retained
	if OS.has_feature("android") and not solid:
		arrays = road_surface_cache_order(arrays)
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh := MeshInstance3D.new()
	mesh.name = "ExcavatedTerrain" if solid else "ConformingRoadBed"
	mesh.mesh = surface
	mesh.material_override = material
	world.add_child(mesh)
	if solid:
		mesh.create_trimesh_collision()
		mesh.get_child(0).set_meta("surface", "terrain")
	return mesh

static func road_surface_cache_order(arrays: Array) -> Array:
	# The clipped road bed still has long grid rows. Keep all authored
	# attributes and oriented triangles; optimize triangle order and lay out
	# vertex attributes in first-use order to avoid fetching scattered grid rows.
	# This is presentation geometry, independent of the baked solid terrain.
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var optimizer := SurfaceTool.new()
	optimizer.create_from(mesh, 0)
	optimizer.optimize_indices_for_cache()
	var result := arrays.duplicate()
	result[Mesh.ARRAY_INDEX] = optimizer.commit_to_arrays()[Mesh.ARRAY_INDEX]
	# Clipping removes indices after normal generation. Do not upload orphaned
	# grid attributes: only referenced vertices contribute to this road bed.
	preload("res://scripts/terrain_mesh_lod.gd").reorder_vertex_fetch(result, {}, false)
	return result

static func road_graded_shoulders(world, material: Material, east_west: bool) -> void:
	# A continuous graded earth section replaces the flat rectangular road edge.
	# Its outside edge intersects the meadow, while entrances taper to grade.
	# Flush aggregate apron falls gently outward; it must not read as a
	# continuous raised levee beside a wide asphalt plaza.
	# A real shallow ditch replaces the formerly raised 82 cm embankment.
	var profile := [Vector2(3.4, -0.015), Vector2(4.2, 0.028),
		Vector2(4.9, 0.060), Vector2(5.6, 0.022), Vector2(6.6, -0.18),
		Vector2(7.8, -0.44), Vector2(9.2, -0.20),
		Vector2(10.6, 0.12), Vector2(12.0, -0.065)]
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1),
			Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0)]
		if (side < 0.0) == east_west:
			corners.reverse()
		for segment in range(300):
			for strip in range(profile.size() - 1):
				for corner in corners:
					var along := lerpf(-112.5, 112.5, float(segment + corner.y) / 300.0)
					var section: Vector2 = profile[strip + corner.x]
					var outer_weight := smoothstep(4.9, 12.0, section.x)
					# Unequal sediment lobes taper back to grade between deposits.
					# Keep the inner running edge fixed; vary only the field edge.
					var deposit := smoothstep(-0.15, 0.70, sin(along * 0.19 + side * 2.0) * 0.65 + sin(along * 0.071 - side) * 0.35)
					var wander := sin(along * 0.23 + side) * 0.85 + sin(along * 0.71) * 0.22 + deposit * 1.4
					var across: float = side * (section.x + wander * outer_weight)
					# Form the service turning mouth in the shoulder itself.
					# A separate swept apron intersected this surface across
					# its full width, exposing a straight lighting/material seam.
					if not east_west and side > 0.0:
						var mouth := 1.0 - smoothstep(1.5, 8.5, absf(along - 49.2))
						across += 7.0 * mouth * smoothstep(4.9, 9.0, section.x)
					var taper := smoothstep(11.0, 16.0, absf(along)) * (1.0 - smoothstep(105.0, 112.5, absf(along)))
					# Keep the shoulder continuous through the service frontage.
					# Burying this entire strip exposed the rectangular road slab
					# and made a transverse step at both ends of the frontage.
					var relief := section.y
					# Runoff cuts across the bank at unequal intervals. These
					# are geometry, shared by rendering and trimesh collision.
					var runoff := smoothstep(0.72, 0.98, sin(along * 0.63 + sin(along * 0.17) * 1.7 + section.x * 0.3))
					relief *= 1.0 - 0.72 * runoff * smoothstep(6.6, 8.0, section.x)
					# Vehicle entrances cross a flattened swale, without abrupt
					# transverse ends. Preserve the service mouth and the
					# building routes at z=26 and z=34 on both road sides.
					var entrance := 1.0
					if not east_west:
						for access_z in [-70.0, -35.0, 26.0, 34.0, 49.2, 70.0]:
							entrance = minf(entrance, smoothstep(3.2, 8.5, absf(along - access_z)))
					else:
						for access_x in [-72.0, -42.0, 35.0, 68.0]:
							entrance = minf(entrance, smoothstep(3.2, 8.5, absf(along - access_x)))
					var bank_weight := smoothstep(5.6, 6.5, section.x)
					var bank_variation := 0.65 + 0.35 * deposit
					# Never lift the buried outer boundary when flattening an
					# entrance: that used to expose a rectangular sheet edge.
					var flattened := clampf(relief, 0.0, 0.025)
					relief = lerpf(relief, lerpf(flattened, relief * bank_variation, entrance), bank_weight)
					var height := lerpf(-0.025, relief, taper)
					var point := Vector3(along, height, across) if east_west else Vector3(across, height, along)
					# Join the outside edge to the excavated field rather than
					# leaving a raised sheet or an open gap along the ditch.
					if strip + corner.x == profile.size() - 1:
						point.y = road_cut_height(Vector2(point.x, point.z)) - 0.015
					st.set_uv(Vector2(point.x, point.z))
					st.add_vertex(point)
		st.generate_normals()
		var shoulder := MeshInstance3D.new()
		shoulder.name = "RoadGradedShoulderEW" if east_west else "RoadGradedShoulderNS"
		if OS.has_feature("android"):
			# Weld only identical complete vertices after normals are authored.
			# Keep every bank triangle and its shading/collision; adjacent
			# triangles can now reuse transformed vertices on the GPU.
			st.index()
			st.optimize_indices_for_cache()
		shoulder.mesh = st.commit()
		shoulder.material_override = material
		world.add_child(shoulder)
		shoulder.create_trimesh_collision()

static func service_asphalt_connector(world, material: Material) -> void:
	# Swept turning apron with a crowned running surface and buried outer edges.
	# The far end slips beneath the existing concrete, avoiding a raised curb.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1),
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]
	# Godot uses clockwise front faces; upward collision normals must match
	# the surrounding shoulder so capsules land on, rather than under, it.
	corners.reverse()
	for segment in range(32):
		for strip in range(12):
			var triangle: Array[Vector3] = []
			for corner in corners:
				var t := lerpf(0.67, 1.0, float(segment + corner.y) / 32.0)
				var center := service_access_point(t)
				var tangent := (service_access_point(minf(t + 0.001, 1.0)) - service_access_point(t - 0.001)).normalized()
				var normal := Vector2(-tangent.y, tangent.x)
				var across := lerpf(-4.5, 4.5, float(strip + corner.x) / 12.0)
				var point := center + normal * across
				# Terminate at the main road's east boundary, never above it.
				# The end rows collapse onto the boundary instead of leaving
				# a second surface with a different normal over the main lane.
				point.x = maxf(point.x, 8.0)
				var height := lerpf(0.042, 0.028, smoothstep(0.67, 1.0, t))
				height -= smoothstep(2.5, 4.5, absf(across)) * 0.11
				height = lerpf(0.022, height, smoothstep(8.0, 11.0, point.x))
				triangle.append(Vector3(point.x, height, point.y))
				if triangle.size() == 3:
					if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).length_squared() > 0.00000001:
						for vertex in triangle:
							st.set_uv(Vector2(vertex.x, vertex.z))
							st.add_vertex(vertex)
					triangle.clear()
	st.generate_normals()
	if OS.has_feature("android"):
		# Share only identical complete vertices after generating the authored
		# normals, preserving the crowned apron and its collision triangles.
		st.index()
		st.optimize_indices_for_cache()
	var apron := MeshInstance3D.new()
	apron.name = "ServiceAsphaltConnector"
	apron.mesh = st.commit()
	apron.material_override = material
	world.add_child(apron)
	apron.create_trimesh_collision()

static func repair_access_earthwork(world) -> void:
	# A graded, compacted shoulder follows the swept turn. The outer edge sinks
	# into the ground; the inner edge sits under the feathered concrete.
	# Keep the straight entrance's existing drainage channels unobstructed.
	var material := service_ground_material()
	material.set_shader_parameter("physical_shoulder", true)
	var profile := [Vector2(-0.95, 0.018), Vector2(-0.45, 0.025),
		Vector2(0.0, 0.14), Vector2(0.32, 0.11),
		Vector2(1.05, 0.045), Vector2(1.85, 0.008), Vector2(2.65, -0.09)]
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
			Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]
		if side > 0.0:
			corners.reverse()
		for segment_index in range(72):
			for strip in range(profile.size() - 1):
				for corner in corners:
					var t := lerpf(0.30, 1.0, float(segment_index + corner.y) / 72.0)
					var center := service_access_point(t)
					var tangent := (service_access_point(minf(t + 0.002, 1.0)) - service_access_point(maxf(t - 0.002, 0.0))).normalized()
					var width := lerpf(2.45, 3.40, smoothstep(0.34, 0.86, t))
					if side > 0.0:
						width -= 0.42 * sin(t * PI)
					var section: Vector2 = profile[strip + corner.x]
					var irregularity := sin(t * 39.0 + side) * 0.13 + sin(t * 91.0) * 0.045
					# Broad, uneven fill fans replace the narrow constant-width bank.
					# Keep the crest fixed so the drivable grade remains predictable.
					var fill_spread := 1.0 + maxf(section.x, 0.0) * (0.15 + 0.18 * sin(t * 17.0 + side))
					var point: Vector2 = center + Vector2(-tangent.y, tangent.x) * side * (width + section.x * fill_spread + irregularity)
					var taper := smoothstep(0.30, 0.48, t)
					# Both ends and the perimeter terminate below the flat ground.
					taper *= 1.0 - smoothstep(0.96, 1.0, t)
					var junction_height := minf(section.y, 0.058)
					var graded_height := lerpf(junction_height, section.y + sin(t * 53.0) * 0.018, smoothstep(8.0, 10.0, point.x))
					var height := lerpf(-0.035, graded_height, taper)
					# Fade before the bank intersects the flat service-ground layer.
					# A buried perimeter alone still exposes a hard contour at y=0.
					var feather := 1.0 - smoothstep(0.32, 1.85, section.x)
					feather *= smoothstep(0.30, 0.44, t) * (1.0 - smoothstep(0.90, 1.0, t))
					st.set_color(Color(1.0, 1.0, 1.0, feather))
					st.set_uv(point * 1.65)
					st.add_vertex(Vector3(point.x, height, point.y))
		st.generate_normals()
		if OS.has_feature("android"):
			# Preserve the feather color and UV/normal seams when welding.
			st.index()
			st.optimize_indices_for_cache()
		var shoulder := MeshInstance3D.new()
		shoulder.name = "RepairAccessGradedShoulder"
		shoulder.mesh = st.commit()
		shoulder.material_override = material
		world.add_child(shoulder)
		shoulder.create_trimesh_collision()

static func repair_service_access(world) -> void:
	# Swept graded slab: join the shelter floor at its actual height, flare
	# at the doorway, then sink the ragged shoulders into the compacted bed.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0)]
	for segment in range(64):
		for strip in range(48):
			for corner in corners:
				var t := float(segment + corner.y) / 64.0
				var center := service_access_point(t)
				var tangent := (service_access_point(minf(t + 0.001, 1.0)) - service_access_point(maxf(t - 0.001, 0.0))).normalized()
				var across := lerpf(-4.1, 4.1, float(strip + corner.x) / 48.0)
				var point := center + Vector2(-tangent.y, tangent.x) * across
				var throat := lerpf(3.15, 2.45, smoothstep(0.0, 0.3, t))
				var width := lerpf(throat, 3.4, smoothstep(0.34, 0.86, t))
				var height := lerpf(0.085, 0.065, smoothstep(0.0, 0.65, t))
				# Concrete ends outside the door; the turning approach is a
				# crowned aggregate bed with two depressed wheel corridors.
				var gravel := smoothstep(38.8, 41.2, point.y)
				# Follow the excavated bed instead of bridging its wheel ruts with
				# a second crowned slab. The same height feeds this mesh's collider.
				# Preserve the doorway and blend back to the asphalt mouth.
				var road_blend := 1.0 - smoothstep(0.55, 0.85, t)
				height = lerpf(height, road_cut_height(point) + 0.065, gravel * road_blend)
				# Keep the whole shader feather above the 4.4 cm ground overlay.
				# Previously the mesh crossed it before alpha faded, cutting a
				# perfectly smooth boundary through the eroded material.
				height -= smoothstep(width + 0.10, width + 0.65, absf(across)) * 0.13
				surface.set_uv(point)
				surface.add_vertex(Vector3(point.x, height, point.y))
	surface.index()
	surface.generate_normals()
	if OS.has_feature("android"):
		# Keep normals fixed before reordering the wide grid's triangles.
		# Adjacent rows otherwise revisit vertices after they leave the cache.
		surface.optimize_indices_for_cache()
	var access_arrays := surface.commit_to_arrays()
	if OS.has_feature("android"):
		# Store neighboring triangle attributes together after cache ordering.
		# Renumbering preserves the surface and its generated collision exactly.
		preload("res://scripts/terrain_mesh_lod.gd").reorder_vertex_fetch(access_arrays, {})
	var access := MeshInstance3D.new()
	access.name = "RepairServiceAccess"
	var access_mesh := ArrayMesh.new()
	access_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, access_arrays)
	access.mesh = access_mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/service_access.gdshader")
	material.set_shader_parameter("noise_lattice", load("res://assets/realism/ground_noise.png"))
	configure_service_path(material)
	material.set_shader_parameter("aggregate", load("res://assets/realism/terrain_rock_albedo.jpg"))
	access.material_override = material
	world.add_child(access)
	access.create_trimesh_collision()
	repair_access_earthwork(world)
	# Broken colonies follow the turning shoulder, keeping the swept lane bare.
	var random := RandomNumberGenerator.new()
	random.seed = 30942
	# The older verge stones lie below the flush apron overlay. Place this
	# loose aggregate on the finished surface, outside the clear wheel route.
	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radial_segments = 6
	# Centimetre-scale surface chips retain their equator and vertex bounds
	# with one latitude ring; keep the desktop tessellation unchanged.
	pebble_mesh.rings = 1 if OS.has_feature("android") else 3
	pebble_mesh.radius = 1.0
	pebble_mesh.height = 2.0
	var pebbles := MultiMesh.new()
	pebbles.transform_format = MultiMesh.TRANSFORM_3D
	pebbles.use_colors = true
	pebbles.mesh = pebble_mesh
	pebbles.instance_count = 820
	for i in range(pebbles.instance_count):
		var t := random.randf()
		var center := service_access_point(t)
		var tangent := (service_access_point(minf(t + 0.002, 1.0)) - service_access_point(maxf(t - 0.002, 0.0))).normalized()
		var side := -1.0 if i % 2 else 1.0
		var bank := 2.90 + sin(t * 31.0 + side) * 0.22
		var point := center + Vector2(-tangent.y, tangent.x) * side * random.randf_range(bank - 0.22, bank + 0.54)
		# Keep the asphalt mouth free of a dotted gravel line across the road.
		if point.x < 8.4:
			point = center.lerp(point, smoothstep(6.0, 8.4, point.x))
		var radius := random.randf_range(0.012, 0.043) * smoothstep(6.0, 8.4, point.x)
		var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3(radius, radius * 0.38, radius * 0.72))
		pebbles.set_instance_transform(i, Transform3D(basis, Vector3(point.x, 0.052 - radius * 0.10, point.y)))
		var tone := random.randf_range(0.34, 0.49)
		pebbles.set_instance_color(i, Color(tone, tone * 0.96, tone * 0.86))
	var gravel := MultiMeshInstance3D.new()
	gravel.name = "RepairApronSurfaceAggregate"
	gravel.multimesh = pebbles
	var gravel_material := StandardMaterial3D.new()
	gravel_material.vertex_color_use_as_albedo = true
	# Muted limestone: vertex variation lifts the old black-looking grit,
	# while the base tint keeps sunlit chips from reading as white confetti.
	gravel_material.albedo_color = Color("797363")
	gravel_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	gravel_material.roughness = 0.96
	gravel.material_override = gravel_material
	world.add_child(gravel)
	for i in range(64):
		var along := random.randf()
		if along > 0.40 and along < 0.58:
			continue
		var side := -1.0 if i % 2 == 0 else 1.0
		var tangent := (service_access_point(minf(along + 0.002, 1.0)) - service_access_point(maxf(along - 0.002, 0.0))).normalized()
		var point := service_access_point(along) + Vector2(-tangent.y, tangent.x) * side * random.randf_range(3.5, 4.1)
		if point.x < 9.0 or point.y < 44.0:
			continue
		var plant: Node3D = load("res://assets/realism/grass_fine.glb" if i % 3 else "res://assets/realism/grass_broadleaf.glb").instantiate()
		plant.name = "RepairAccessShoulderGrowth"
		plant.position = Vector3(point.x, verge_height(point), point.y)
		plant.rotation.y = random.randf() * TAU
		plant.scale = Vector3.ONE * random.randf_range(0.26, 0.58)
		world.add_child(plant)
	# Rooted meadow tongues outside the swept access corridor: broad colonies
	# give the paved foreground an irregular, human-scale planted boundary.
	for colony in range(18):
		var along := (float(colony) + 0.5) / 18.0
		var center := service_access_point(along)
		var tangent := (service_access_point(minf(along + 0.002, 1.0)) - service_access_point(maxf(along - 0.002, 0.0))).normalized()
		var side := -1.0 if colony % 2 == 0 else 1.0
		for tuft in range(24):
			var offset := random.randf_range(-0.85, 0.85)
			var lateral := random.randf_range(3.78, 4.85)
			var point := center + tangent * offset + Vector2(-tangent.y, tangent.x) * lateral * side
			if point.x < 9.0 or point.y < 36.5:
				continue
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if tuft % 4 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			plant.name = "RepairApronRootedMeadow"
			plant.position = Vector3(point.x, maxf(0.025, verge_height(point)), point.y)
			plant.rotation.y = random.randf() * TAU
			var spread := random.randf_range(0.48, 0.88)
			plant.scale = Vector3(spread, random.randf_range(0.22, 0.52), spread)
			world.add_child(plant)
	# Asymmetric low scrub at the outer bend grounds the apron in the meadow.
	# Each island stays beyond the 3.65 m swept corridor used by clearance.
	for island in [Vector3(20.4,0,46.8), Vector3(19.7,0,49.0),
		Vector3(11.0,0,39.8), Vector3(10.7,0,43.1),
		Vector3(18.9,0,47.0), Vector3(17.4,0,48.9), Vector3(15.9,0,50.1)]:
		var shrub: Node3D = vegetation_scene("res://assets/realism/verge_fine_shrub.glb").instantiate()
		shrub.name = "RepairBendScrub"
		shrub.position = Vector3(island.x,verge_height(Vector2(island.x,island.z)),island.z)
		shrub.rotation.y = random.randf()*TAU
		# Unequal crowns and open understory avoid repeated hedge pillows.
		var crown := random.randf_range(0.55, 1.04)
		shrub.scale = Vector3(crown, random.randf_range(0.23, 0.48), crown * 0.78)
		world.add_child(shrub)
		for tuft in range(random.randi_range(15, 31)):
			var angle := random.randf()*TAU
			var radius := sqrt(random.randf())
			var point := Vector2(island.x,island.z)+Vector2(cos(angle)*0.90,sin(angle)*1.3)*radius
			var grass: Node3D = load("res://assets/realism/grass_broadleaf.glb" if tuft % 5 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			grass.name = "RepairBendUnderstory"
			grass.position = Vector3(point.x,verge_height(point),point.y)
			grass.rotation.y = random.randf()*TAU
			grass.scale = Vector3(0.58,random.randf_range(0.22,0.48),0.58)
			world.add_child(grass)
	# Unequal low colonies flank the straight approach. Keep their centres
	# outside clearance, and leave open gaps instead of outlining every edge.
	for colony in [Vector2(19.55, 38.3), Vector2(19.65, 41.4),
		Vector2(11.45, 37.9), Vector2(11.30, 41.9)]:
		for tuft in range(28):
			var point: Vector2 = colony + Vector2(random.randf_range(-0.28, 0.28),
				random.randf_range(-0.72, 0.72))
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if tuft % 4 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			plant.name = "RepairStraightShoulderColony"
			plant.position = Vector3(point.x, verge_height(point), point.y)
			plant.rotation.y = random.randf() * TAU
			plant.scale = Vector3(0.62, random.randf_range(0.22, 0.43), 0.62)
			world.add_child(plant)


static func repair_approach_drainage(world) -> void:
	# Cast-in-place shallow swales collect the roof outfalls. Their raised
	# lips remain outside the 5.8 m vehicle approach and taper into the soil.
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("#878778")
	concrete.albedo_texture = load("res://assets/realism/terrain_rock_albedo.jpg")
	concrete.roughness = 0.96
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Both banks stay below the actor's walkable slope, including crouching.
		var profile := [Vector2(-0.40, 0.06), Vector2(-0.30, 0.12),
			Vector2(-0.20, 0.12), Vector2(-0.13, 0.067),
			Vector2(0.13, 0.067), Vector2(0.20, 0.12),
			Vector2(0.30, 0.12), Vector2(0.40, 0.06)]
		for segment in range(36):
			for strip in range(profile.size() - 1):
				for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
						Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var t := float(segment + corner.y) / 36.0
					var section: Vector2 = profile[strip + corner.x]
					var x: float = 15.5 + side * lerpf(3.88, 3.60, t)
					var z := lerpf(35.4, 44.4, t)
					var taper := smoothstep(0.0, 0.07, t) * (1.0 - smoothstep(0.90, 1.0, t))
					st.set_uv(Vector2((x + section.x) * 0.7, z * 0.7))
					st.add_vertex(Vector3(x + section.x,
						lerpf(0.058, section.y, taper), z))
		st.generate_normals()
		var drain := MeshInstance3D.new()
		drain.name = "RepairApproachSwale"
		if OS.has_feature("android"):
			# Share identical shaded vertices along the swale grid while keeping
			# the complete tapered banks and their walkable collision surface.
			st.index()
			st.optimize_indices_for_cache()
		drain.mesh = st.commit()
		drain.material_override = concrete
		world.add_child(drain)
		drain.create_trimesh_collision()


static func shelter_roof_meshes(center: Vector3) -> Array[ArrayMesh]:
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rooflights := SurfaceTool.new()
	rooflights.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rolled corrugated sheet: 200 mm pitch, 36 mm peak-to-trough.
	# Real cross sections preserve grazing highlights and the eave silhouette.
	# Collision retains the smooth arch envelope above the walkable room.
	# 32 arch segments retain every longitudinal corrugation sample and the
	# exact daylight boundaries (multiples of one eighth of the arch).
	# Maximum circular chord error is under 4.1 mm at the outer radius.
	# Collision uses the independent arch envelope in repair_shelter.
	var arch_segments := 32 if OS.has_feature("android") else 64
	for i in range(arch_segments):
		var a := float(i) * PI / float(arch_segments)
		var b := float(i + 1) * PI / float(arch_segments)
		for strip in range(280):
			var z0 := -3.5 + float(strip) * 7.0 / 280.0
			var z1 := -3.5 + float(strip + 1) * 7.0 / 280.0
			# Two full curved daylight strips replace metal, rather than overlay it.
			var daylight := i >= arch_segments / 8 and i < arch_segments * 7 / 8 and (absf((z0+z1)*0.5-1.75) < 0.40 or absf((z0+z1)*0.5+1.75) < 0.40)
			var sheet: SurfaceTool = rooflights if daylight else roof
			for corner in [Vector2(a,z0),Vector2(b,z0),Vector2(b,z1),Vector2(a,z0),Vector2(b,z1),Vector2(a,z1)]:
				var phase: float = (corner.y + 3.5) * TAU / 0.20
				var radius: float = 3.318 + 0.018 * cos(phase)
				var slope: float = -0.018 * TAU / 0.20 * sin(phase)
				sheet.set_normal(Vector3(cos(corner.x),sin(corner.x),-slope).normalized())
				sheet.set_uv(Vector2(corner.x * 3.3, corner.y))
				sheet.add_vertex(center + Vector3(cos(corner.x)*radius,1.9+sin(corner.x)*radius,corner.y))
	# Preserve every triangle and its attributes while reusing vertex work on Android.
	if OS.has_feature("android"):
		roof.index()
		roof.optimize_indices_for_cache()
		rooflights.index()
		rooflights.optimize_indices_for_cache()
	return [roof.commit(), rooflights.commit()]


static func repair_shelter(world) -> void:
	repair_shelter_services(world)
	repair_shelter_roof_vents(world)
	repair_approach_drainage(world)
	var ground: MeshInstance3D
	# Built offline by tests/bake_android_service_yard.gd. Retains the full
	# base surface and adds index LODs without simplifying during device startup.
	if OS.has_feature("android") and ResourceLoader.exists("res://assets/android_service_yard.res"):
		var cached := load("res://assets/android_service_yard.res") as ArrayMesh
		if cached != null:
			ground = MeshInstance3D.new()
			ground.mesh = cached
			ground.material_override = service_ground_material()
			world.add_child(ground)
	if ground == null:
		ground = excavated_surface(world, Rect2(-27, 10, 52, 46), service_ground_material(), false, 0.044, service_ground_regions())
	ground.name = "ServiceYardGround"
	# Bound the surface to the service yards and curved approach, including
	# the feather margins. Never layer an elevated decal across both roads.
	var exclusions: Array = world.get_meta("hardscape_bounds", [])
	# Protect the actual apron; the access centreline is excluded separately.
	# The old 14x16 rectangle also suppressed growth on unused dirt shoulders.
	exclusions.append(Rect2(11, 25, 9, 11))
	world.set_meta("hardscape_bounds", exclusions)
	service_lane_verges(world)
	repair_apron_drainage(world)
	repair_service_access(world)
	# An open barrel-roof repair shelter gives the yard a distinct silhouette.
	# Curved roof and low sidewalls are physical; both ends remain walkable.
	var center := Vector3(15.5, 0, 29.5)
	# Raised brick foundations weather differently from the metal shell.
	# These share the sidewall footprint and never cross either entrance.
	var foundation_finish := ShaderMaterial.new()
	foundation_finish.shader = preload("res://shaders/workshop_masonry.gdshader")
	foundation_finish.set_shader_parameter("exposed_brick_height", 0.91)
	for side in [-1.0, 1.0]:
		var foundation = world.block(center + Vector3(side * 3.30, 0.36, 0),
			Vector3(0.24, 0.72, 7.0), "77634d")
		foundation.material_override = foundation_finish
		world.block(center + Vector3(side * 3.30, 0.745, 0),
			Vector3(0.30, 0.07, 7.05), "89897c")
	# Masonry door reveals anchor the metal shell; central 3.9 m stays open.
	for jamb_x in [12.30, 18.70]:
		var jamb = world.block(Vector3(jamb_x, 1.55, 33.12), Vector3(0.34, 3.10, 0.44), "8a8774")
		jamb.name = "RepairEntranceMasonryReveal"
		jamb.material_override = foundation_finish
		world.block(Vector3(jamb_x, 3.13, 33.12), Vector3(0.43, 0.10, 0.50), "a5a28e")
	var paint := ShaderMaterial.new()
	paint.shader = load("res://shaders/shelter_metal.gdshader")
	var roof_meshes := shelter_roof_meshes(center)
	for i in range(48):
		var midpoint := (float(i) + 0.5) * PI / 48.0
		var panel = world.block(center+Vector3(cos(midpoint)*3.3,1.9+sin(midpoint)*3.3,0),Vector3(0.055,0.22,7), "687d79")
		panel.visible = false
		panel.rotation.z = midpoint
	var mesh := MeshInstance3D.new()
	mesh.mesh = roof_meshes[0]
	mesh.material_override = paint
	world.add_child(mesh)
	var daylight_mesh := MeshInstance3D.new()
	daylight_mesh.name = "ShelterCurvedRooflights"
	daylight_mesh.mesh = roof_meshes[1]
	var daylight_finish := ShaderMaterial.new()
	daylight_finish.shader = preload("res://shaders/shelter_rooflight.gdshader")
	daylight_mesh.material_override = daylight_finish
	# Diffusing GRP admits daylight; retained arch collision prevents roof falls.
	daylight_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(daylight_mesh)
	# Curved perimeter flashings make the inserted panels readable at eye level.
	for band_z in [-1.75,1.75]:
		for edge_z in [band_z-0.40,band_z+0.40]:
			for segment in range(8,56):
				var theta := (float(segment)+0.5)*PI/64.0
				var flashing = world.block(center+Vector3(cos(theta)*3.35,1.9+sin(theta)*3.35,edge_z),Vector3(0.035,0.17,0.065),"68766c",false)
				flashing.rotation.z = theta

	# Raised standing seams give the barrel roof actual contact shadows and
	# a readable end profile. These thin exterior folds need no extra collider.
	var seam_finish := StandardMaterial3D.new()
	seam_finish.albedo_color = Color("45594f")
	seam_finish.metallic = 0.35
	seam_finish.roughness = 0.78
	seam_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	var seams := SurfaceTool.new()
	seams.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seam_index in range(7):
		var seam_z := -3.5 + float(seam_index) * 7.0 / 6.0
		for segment in range(64):
			var a := float(segment) * PI / 64.0
			var b := float(segment + 1) * PI / 64.0
			# Fold sides and narrow cap, in radial/longitudinal cross-section.
			var profile := [Vector2(3.30,-0.025),Vector2(3.375,-0.025),Vector2(3.375,0.025),Vector2(3.30,0.025)]
			for face in range(3):
				for vertex in [Vector2i(0,face),Vector2i(1,face),Vector2i(1,face+1),Vector2i(0,face),Vector2i(1,face+1),Vector2i(0,face+1)]:
					var theta: float = a if vertex.x == 0 else b
					var section: Vector2 = profile[vertex.y]
					seams.add_vertex(center + Vector3(cos(theta)*section.x,1.9+sin(theta)*section.x,seam_z+section.y))
	seams.generate_normals()
	if OS.has_feature("android"):
		# Index after generating normals so the authored folds keep their shading.
		seams.index()
		seams.optimize_indices_for_cache()
	var seam_mesh := MeshInstance3D.new()
	seam_mesh.name = "ShelterStandingSeams"
	seam_mesh.mesh = seams.commit()
	seam_mesh.material_override = seam_finish
	world.add_child(seam_mesh)
	# Open half-round gutters catch the barrel roof runoff. Pipes stay against
	# the rear sidewalls, outside both central entrance collision corridors.
	var gutter_finish := StandardMaterial3D.new()
	gutter_finish.albedo_color = Color("626c66")
	gutter_finish.metallic = 0.45
	gutter_finish.roughness = 0.72
	gutter_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		var trough := SurfaceTool.new()
		trough.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in range(12):
			var a := PI + float(segment) * PI / 12.0
			var b := PI + float(segment + 1) * PI / 12.0
			for corner in [Vector2(a,-3.62),Vector2(b,-3.62),Vector2(b,3.62),Vector2(a,-3.62),Vector2(b,3.62),Vector2(a,3.62)]:
				trough.set_normal(Vector3(cos(corner.x),sin(corner.x),0))
				trough.add_vertex(center + Vector3(side * 3.39 + cos(corner.x) * 0.14, 1.91 + sin(corner.x) * 0.14, corner.y))
		var gutter := MeshInstance3D.new()
		if OS.has_feature("android"):
			trough.index()
			trough.optimize_indices_for_cache()
		gutter.mesh = trough.commit()
		gutter.material_override = gutter_finish
		world.add_child(gutter)
		var pipe := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.065
		tube.bottom_radius = 0.065
		tube.height = 1.65
		tube.radial_segments = 12
		# Straight sides need no axial subdivisions; preserve radial detail.
		if OS.has_feature("android"):
			tube.rings = 0
		pipe.mesh = tube
		pipe.position = center + Vector3(side * 3.43, 0.955, -3.22)
		pipe.material_override = gutter_finish
		world.add_child(pipe)
		for bracket_z in [-3.2, -1.6, 0.0, 1.6, 3.2]:
			world.block(center + Vector3(side * 3.39, 1.745, bracket_z), Vector3(0.32,0.045,0.05), "424b48", false)
	# Ridge extraction is constructed once in repair_shelter_services.
	# Masonry piers anchor the glazed bays to the foundation. The existing
	# side wall owns collision; these shallow exterior finishes sit on it.
	for side in [-1.0, 1.0]:
		for pier_z in [-3.30, -1.12, 1.12, 3.30]:
			var pier = world.block(center + Vector3(side * 3.31, 0.46, pier_z),
				Vector3(0.28, 0.92, 0.28), "786f58", false)
			pier.name = "RepairWindowMasonryPier"
			pier.material_override = foundation_finish
			var pier_cap = world.block(center + Vector3(side * 3.31, 0.95, pier_z),
				Vector3(0.32, 0.06, 0.32), "817e6d", false)
			pier_cap.name = "RepairPierWeatherCap"
			var upright = world.block(center + Vector3(side * 3.34, 1.43, pier_z),
				Vector3(0.14, 0.90, 0.12), "465452", false)
			upright.name = "RepairWindowSteelUpright"
			var upright_finish := ShaderMaterial.new()
			upright_finish.shader = preload("res://shaders/shelter_structural_steel.gdshader")
			upright.material_override = upright_finish
	# Continuous side windows above a masonry knee wall give the repair bay
	# daylight and an exterior view. Actual glass colliders retain the enclosure.
	var side_glass := ShaderMaterial.new()
	side_glass.shader = preload("res://shaders/shelter_side_glass.gdshader")
	var window_frame := ShaderMaterial.new()
	window_frame.shader = preload("res://shaders/shelter_structural_steel.gdshader")
	for side in [-1.0,1.0]:
		var knee_wall = world.block(center+Vector3(side*3.3,0.45,0),Vector3(0.12,0.9,7),"77634d")
		knee_wall.material_override = foundation_finish
		for rail_y in [0.94, 1.85]:
			var rail = world.block(center+Vector3(side*3.3,rail_y,0),Vector3(0.19,0.1,7.0),"526862")
			rail.material_override = window_frame
		# Three broad bays, each divided into two lights, avoid a featureless wall.
		for bay in range(3):
			var bay_z := -2.34 + float(bay) * 2.34
			var pane = world.block(center+Vector3(side*3.3,1.395,bay_z),Vector3(0.12,0.81,2.22),"607b78")
			pane.material_override = side_glass
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mullion = world.block(center+Vector3(side*3.3,1.395,bay_z),Vector3(0.18,0.81,0.045),"526862")
			mullion.material_override = window_frame
			var transom = world.block(center+Vector3(side*3.32,1.64,bay_z),Vector3(0.20,0.045,2.22),"526862",false)
			transom.material_override = window_frame
			for hinge_z in [-0.76, 0.76]:
				world.block(center+Vector3(side*3.42,1.78,bay_z+hinge_z),Vector3(0.045,0.10,0.13),"424b48",false)
		for post_z in [-3.47, -1.17, 1.17, 3.47]:
			var jamb = world.block(center+Vector3(side*3.3,1.395,post_z),Vector3(0.20,0.91,0.10),"526862")
			jamb.material_override = window_frame
		# Projecting concrete sill sheds water and catches the side light.
		for cap_index in range(12):
			var cap = world.block(center+Vector3(side*3.34,0.88,-3.26+cap_index*0.593),
				Vector3(0.36,0.08,0.583),"89897c")
			cap.name = "RepairMasonryCoping_%d" % cap_index
		world.block(center+Vector3(side*3.3,0.12,0),Vector3(0.32,0.24,7.2),"777c74")
		# Exterior louvres shade the glazing with actual geometric shadows.
		# Their lowest edge is above head height; the entrance stays clear.
		for blade in range(5):
			var hood = world.block(center+Vector3(side*(3.42+blade*0.135),2.30-blade*0.025,0),
				Vector3(0.15,0.018,7.12),"526862",false)
			hood.material_override = window_frame
			hood.rotation_degrees.z = side * -12.0
		for bracket_z in [-3.38,-1.17,1.17,3.38]:
			var bracket = world.block(center+Vector3(side*3.67,2.20,bracket_z),
				Vector3(0.72,0.035,0.035),"526862",false)
			bracket.material_override = window_frame
		var hood_edge = world.block(center+Vector3(side*4.035,2.20,0),
			Vector3(0.025,0.055,7.16),"526862",false)
		hood_edge.material_override = window_frame
	# Roof-edge drainage links the long side elevation to a stone splash bed.
	for side in [-1.0, 1.0]:
		var gutter = world.block(center+Vector3(side*3.42,1.98,0),Vector3(0.18,0.13,7.26),"526862",false)
		gutter.material_override = window_frame
		var pipe := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.055
		cylinder.bottom_radius = 0.055
		cylinder.height = 1.76
		cylinder.radial_segments = 12
		# Straight sides need no axial subdivisions; preserve radial detail.
		if OS.has_feature("android"):
			cylinder.rings = 0
		pipe.mesh = cylinder
		pipe.material_override = window_frame
		pipe.position = center + Vector3(side*3.47,1.04,2.91)
		world.add_child(pipe)
		for height in [0.45,1.60]:
			world.block(center+Vector3(side*3.48,height,2.91),Vector3(0.16,0.055,0.15),"69766d",false)
		# Open stone-lined outfall sits outside the foundation and walking routes.
		# Its recessed bed and irregular rim catch sun/shadow at normal eye level.
		var drain_finish := StandardMaterial3D.new()
		drain_finish.albedo_color = Color("777969")
		drain_finish.roughness = 0.94
		var drain_rng := RandomNumberGenerator.new()
		drain_rng.seed = 295032 + int(side)
		var drain_origin := center + Vector3(side*3.88,0,2.91)
		for rim_side in [-1.0,1.0]:
			for stone in range(12):
				var piece = world.block(drain_origin+Vector3(rim_side*0.29,
					0.076+drain_rng.randf_range(-0.009,0.009),-0.82+stone*0.235),
					Vector3(drain_rng.randf_range(0.14,0.20),0.085,
					drain_rng.randf_range(0.20,0.225)),"777969",false)
				piece.material_override = drain_finish
				piece.rotation.y = drain_rng.randf_range(-0.09,0.09)
		var wet_bed = world.block(drain_origin+Vector3(0,0.047,0.47),
			Vector3(0.43,0.008,2.80),"3e453a",false)
		var wet_finish := StandardMaterial3D.new()
		wet_finish.albedo_color = Color("3e453a")
		wet_finish.roughness = 0.77
		wet_bed.material_override = wet_finish
		var outlet := MeshInstance3D.new()
		var outlet_mesh := CylinderMesh.new()
		outlet_mesh.top_radius = 0.057
		outlet_mesh.bottom_radius = 0.057
		outlet_mesh.height = 0.42
		outlet_mesh.radial_segments = 12
		# Straight sides need no axial subdivisions; preserve radial detail.
		if OS.has_feature("android"):
			outlet_mesh.rings = 0
		outlet.mesh = outlet_mesh
		outlet.material_override = window_frame
		outlet.position = center+Vector3(side*3.63,0.18,2.91)
		outlet.rotation.z = side*1.13
		world.add_child(outlet)
	# Independently seeded colonies leave bare maintenance gaps, rather than
	# repeating equally spaced shrubs along the entire wall.
	var sill_random := RandomNumberGenerator.new()
	sill_random.seed = 280032
	var sill_grass: PackedScene = load("res://assets/realism/grass_fine.glb")
	for planting in range(145):
		var z := sill_random.randf_range(25.9,33.65)
		var x := sill_random.randf_range(10.55,11.96)
		var colony := sin(z*2.1+x*1.4) + sin(z*0.91)*0.6
		if colony < -0.2 or (x < 11.15 and colony < 0.55):
			continue
		var plant: Node3D = sill_grass.instantiate()
		plant.position = Vector3(x,maxf(0.048,verge_height(Vector2(x,z))),z)
		plant.rotation.y = sill_random.randf()*TAU
		var spread := sill_random.randf_range(0.40,0.85)
		plant.scale = Vector3(spread,sill_random.randf_range(0.35,0.85),spread)
		world.add_child(plant)
	for planting in range(5):
		var shrub: Node3D = vegetation_scene("res://assets/realism/verge_fine_shrub.glb").instantiate()
		shrub.position = Vector3(11.35,0.06,[26.5,30.25,31.05,27.45,32.5][planting])
		shrub.rotation.y = planting*2.39
		shrub.scale = Vector3.ONE * [0.43,0.68,0.39,0.82,0.56][planting]
		world.add_child(shrub)
	# Low irregular grass islands bridge the wall planting and the service lane.
	# Keep the central vehicle apron and the pedestrian approach unobstructed.
	var verge_random := RandomNumberGenerator.new()
	verge_random.seed = 281032
	for patch in [Vector3(9.9,0,32.8),Vector3(10.4,0,35.3),
		Vector3(10.8,0,38.1),Vector3(11.1,0,41.0),Vector3(20.4,0,40.3),
		Vector3(21.1,0,44.2)]:
		for tuft in range(34):
			var angle := verge_random.randf()*TAU
			var radius := sqrt(verge_random.randf())
			var x: float = patch.x+cos(angle)*radius*0.85
			var z: float = patch.z+sin(angle)*radius*1.45
			var plant: Node3D = sill_grass.instantiate()
			plant.position = Vector3(x,maxf(0.048,verge_height(Vector2(x,z))),z)
			plant.rotation.y = verge_random.randf()*TAU
			var spread := verge_random.randf_range(0.65,1.15)
			plant.scale = Vector3(spread,verge_random.randf_range(0.24,0.52),spread)
			world.add_child(plant)
	# Mixed-height colonies follow the outside shoulder, leaving the apron,
	# door swing and tested walking lane clear. Broad leaves break up the
	# fine grass silhouette without turning each patch into a repeated bush.
	var shelter_colony_random := RandomNumberGenerator.new()
	shelter_colony_random.seed = 286032
	var shelter_broad_grass: PackedScene = load("res://assets/realism/grass_broadleaf.glb")
	var shelter_colony_shrub: PackedScene = vegetation_scene("res://assets/realism/verge_fine_shrub.glb")
	for colony_center in [Vector3(9.4,0,29.3),Vector3(9.5,0,32.1),
		Vector3(9.1,0,35.5),Vector3(9.4,0,39.0),Vector3(9.7,0,43.1),
		Vector3(8.8,0,46.6),Vector3(20.8,0,38.3),Vector3(21.7,0,42.5),
		Vector3(20.8,0,46.0)]:
		for tuft in range(72):
			var angle := shelter_colony_random.randf()*TAU
			var radius := sqrt(shelter_colony_random.randf())
			var location: Vector3 = colony_center + Vector3(cos(angle)*radius*1.10,0,sin(angle)*radius*1.35)
			var plant: Node3D = (shelter_broad_grass if tuft % 17 == 0 and radius < 0.65 else sill_grass).instantiate()
			location.y = maxf(0.048,verge_height(Vector2(location.x,location.z)))
			plant.position = location
			plant.rotation.y = shelter_colony_random.randf()*TAU
			var spread := shelter_colony_random.randf_range(0.65,1.30)
			var height := shelter_colony_random.randf_range(0.30,0.72)*(1.0-radius*0.78)
			if tuft % 17 == 0 and radius < 0.65:
				spread *= 0.48
				height *= 0.65
			plant.scale = Vector3(spread,height,spread)
			world.add_child(plant)
		var shrub: Node3D = shelter_colony_shrub.instantiate()
		shrub.position = colony_center + Vector3(shelter_colony_random.randf_range(-0.40,0.40),0,shelter_colony_random.randf_range(-0.9,0.9))
		shrub.position.y = maxf(0.048,verge_height(Vector2(shrub.position.x,shrub.position.z)))
		shrub.rotation.y = shelter_colony_random.randf()*TAU
		var shrub_size := shelter_colony_random.randf_range(0.32,0.68)
		shrub.scale = Vector3(shrub_size * 1.4, shrub_size * 0.90, shrub_size)
		world.add_child(shrub)
	# Sheltered wall-foot colonies form a continuous, uneven low edge outside
	# the porch returns. Keep roots outside the masonry and the walking portal.
	for wall_side in [-1.0, 1.0]:
		for tuft in range(95):
			var along := shelter_colony_random.randf_range(32.8, 36.1)
			var outward := shelter_colony_random.randf_range(0.28, 0.82)
			var location := Vector3(15.5 + wall_side * (3.26 + outward), 0.048, along)
			location.y = maxf(location.y, verge_height(Vector2(location.x, location.z)))
			var plant: Node3D = (shelter_broad_grass if tuft % 7 == 0 else sill_grass).instantiate()
			plant.name = "RepairPorchWallFootHerbs"
			plant.position = location
			plant.rotation.y = shelter_colony_random.randf() * TAU
			var spread := shelter_colony_random.randf_range(0.55, 1.05)
			var height := shelter_colony_random.randf_range(0.22, 0.50) * (1.1 - outward * 0.55)
			if tuft % 7 == 0:
				spread *= 0.55
				height *= 0.65
			plant.scale = Vector3(spread, height, spread)
			world.add_child(plant)
	var splash_mesh := SphereMesh.new()
	splash_mesh.radius = 0.5
	splash_mesh.height = 1.0
	splash_mesh.radial_segments = 7
	# These flattened 4–13 cm stones need only one latitude ring on mobile,
	# as with the nearby apron aggregate; retain every stone and its material.
	splash_mesh.rings = 1 if OS.has_feature("android") else 3
	var splash_finish := StandardMaterial3D.new()
	splash_finish.albedo_color = Color("504b3d")
	splash_finish.roughness = 0.96
	splash_finish.vertex_color_use_as_albedo = true
	var splash := MultiMesh.new()
	splash.transform_format = MultiMesh.TRANSFORM_3D
	splash.use_colors = true
	splash.mesh = splash_mesh
	splash.instance_count = 460
	for stone in range(460):
		var z := sill_random.randf_range(25.85,33.05)
		var width := 0.20 + 0.38*sill_random.randf()
		var x := 11.97 - pow(sill_random.randf(),1.8)*width
		var size := sill_random.randf_range(0.04,0.13)
		var stone_height := size*sill_random.randf_range(0.18,0.38)
		var basis := Basis(Vector3.UP,sill_random.randf()*TAU).scaled(Vector3(size,stone_height,size*0.72))
		splash.set_instance_transform(stone,Transform3D(basis,Vector3(x,0.044+stone_height*0.16,z)))
		splash.set_instance_color(stone,Color("b3a58b").lerp(Color("65695e"),sill_random.randf()))
	var splash_instance := MultiMeshInstance3D.new()
	splash_instance.name = "RepairShelterSplashStones"
	splash_instance.multimesh = splash
	splash_instance.material_override = splash_finish
	world.add_child(splash_instance)
	# Structural arch frames have depth and stand inside the cladding.
	for z in [-3.53,-1.17,1.17,3.53]:
		for side in [-1.0, 1.0]:
			# Web and projecting flanges read as steel sections at the open entrance.
			world.block(center+Vector3(side*3.22,0.95,z),Vector3(0.07,1.9,0.24),"455c59")
			for flange in [-0.12, 0.12]:
				world.block(center+Vector3(side*3.22,0.95,z+flange),Vector3(0.24,1.9,0.035),"526862")
			world.block(center+Vector3(side*3.22,0.08,z),Vector3(0.40,0.08,0.40),"62685e")
			world.block(center+Vector3(side*3.22,1.86,z+0.15),Vector3(0.28,0.36,0.045),"69766d")
		# Continuous rolled I-section: radial web with broad axial flanges.
		# The old overlapping boxes produced a stair-stepped inner silhouette.
		var arch_finish := ShaderMaterial.new()
		arch_finish.shader = preload("res://shaders/shelter_structural_steel.gdshader")
		for band in [Vector3(3.115, 3.14, 0.24), Vector3(3.14, 3.30, 0.045), Vector3(3.30, 3.325, 0.24)]:
			curved_steel_band(world, center + Vector3(0, 1.9, z), band.x, band.y, band.z, arch_finish)
	# A recessed rear gable gives the open front a readable enclosed work bay.
	# Retain a 2.6 m wide, 2.7 m high pedestrian exit through the rear.
	var end_finish := ShaderMaterial.new()
	end_finish.shader = preload("res://shaders/shelter_end_cladding.gdshader")
	for side in [-1.0, 1.0]:
		var wall = world.block(center + Vector3(side * 2.3, 1.35, -3.42),
			Vector3(2.0, 2.7, 0.12), "687d79")
		wall.material_override = end_finish
		# Folded sheet seams catch light at eye height. Visual folds sit on
		# the wall face; existing full wall collision still defines the exit.
		for seam_index in range(5):
			var fold := MeshInstance3D.new()
			var fold_mesh := BoxMesh.new()
			fold_mesh.size = Vector3(0.026, 2.68, 0.038)
			fold.mesh = fold_mesh
			fold.position = center + Vector3(side * 2.3 - 0.98 + seam_index * 0.49, 1.35, -3.35)
			fold.material_override = end_finish
			fold.name = "RepairRearSheetFold"
			world.add_child(fold)
		# A continuous base flashing and exit casing make the wall thickness
		# legible without intruding into the 2.6 m pedestrian opening.
		world.block(center + Vector3(side * 2.3, 0.075, -3.34),
			Vector3(2.0, 0.15, 0.08), "455c59")
		world.block(center + Vector3(side * 1.34, 1.35, -3.34),
			Vector3(0.08, 2.7, 0.08), "455c59")
		# Deep service vents break the broad sheet wall into functional bays.
		# Everything stays against the closed panels, outside the rear exit.
		world.block(center + Vector3(side * 2.3, 2.10, -3.31),
			Vector3(1.35, 0.64, 0.08), "202d2c", false)
		for blade_index in range(6):
			var blade = world.block(center + Vector3(side * 2.3, 1.85 + blade_index * 0.1, -3.22),
				Vector3(1.38, 0.04, 0.16), "52645d", false)
			blade.rotation_degrees.x = -24
		for jamb in [-0.72, 0.72]:
			world.block(center + Vector3(side * 2.3 + jamb, 2.1, -3.22),
				Vector3(0.055, 0.7, 0.16), "455c59", false)
	var gable := SurfaceTool.new()
	gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_angle := asin(0.8 / 3.3)
	for i in range(40):
		var a := lerpf(base_angle, PI - base_angle, float(i) / 40.0)
		var b := lerpf(base_angle, PI - base_angle, float(i + 1) / 40.0)
		for point in [Vector3(0, 2.7, -3.42),
			Vector3(cos(b) * 3.3, 1.9 + sin(b) * 3.3, -3.42),
			Vector3(cos(a) * 3.3, 1.9 + sin(a) * 3.3, -3.42)]:
			gable.set_normal(Vector3(0, 0, 1))
			gable.set_uv(Vector2(point.y, point.x))
			gable.add_vertex(center + point)
	if OS.has_feature("android"):
		gable.index()
	var end_panel := MeshInstance3D.new()
	end_panel.mesh = gable.commit()
	end_panel.material_override = end_finish
	world.add_child(end_panel)
	end_panel.create_trimesh_collision()
	var end_shape := end_panel.get_child(0).get_child(0) as CollisionShape3D
	(end_shape.shape as ConcavePolygonShape3D).backface_collision = true
	world.block(center + Vector3(0, 2.7, -3.34), Vector3(6.4, 0.14, 0.18), "455c59")
	# Recessed clerestory closes the upper entrance, above the vehicle clearance.
	var front_gable := SurfaceTool.new()
	front_gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front_angle := asin(1.0 / 3.3)
	for i in range(40):
		var a := lerpf(front_angle, PI - front_angle, float(i) / 40.0)
		var b := lerpf(front_angle, PI - front_angle, float(i + 1) / 40.0)
		for point in [Vector3(0, 2.9, 3.48),
			Vector3(cos(a) * 3.3, 1.9 + sin(a) * 3.3, 3.48),
			Vector3(cos(b) * 3.3, 1.9 + sin(b) * 3.3, 3.48)]:
			front_gable.set_normal(Vector3(0, 0, 1))
			front_gable.set_uv(Vector2(point.x, point.y))
			front_gable.add_vertex(center + point)
	if OS.has_feature("android"):
		front_gable.index()
	var clerestory := MeshInstance3D.new()
	clerestory.mesh = front_gable.commit()
	var glazing := ShaderMaterial.new()
	glazing.shader = preload("res://shaders/shelter_clerestory.gdshader")
	clerestory.material_override = glazing
	world.add_child(clerestory)
	clerestory.create_trimesh_collision()
	var front_shape := clerestory.get_child(0).get_child(0) as CollisionShape3D
	(front_shape.shape as ConcavePolygonShape3D).backface_collision = true
	# Thin concrete apron and transverse drainage slot interrupt the bare soil pad.
	var apron = world.block(Vector3(15.5, 0.055, 31), Vector3(6.3, 0.06, 10), "88877d", false)
	var apron_finish := ShaderMaterial.new()
	apron_finish.shader = preload("res://shaders/warehouse_concrete.gdshader")
	apron_finish.set_shader_parameter("building_origin", Vector3(15.5, 0, 31))
	apron_finish.set_shader_parameter("shelter_apron", true)
	apron.material_override = apron_finish
	# Segmented retaining kerbs expose the slab thickness and cast contact
	# shadows along the entrance, leaving the entire vehicle opening clear.
	for edge_x in [12.25, 18.75]:
		for section in range(4):
			var kerb = world.block(Vector3(edge_x, 0.13, 33.2 + section * 0.92),
				Vector3(0.22, 0.22, 0.89), "77796e")
			kerb.material_override = apron_finish
	# Taller uncut tufts gather against the outside kerb; the centre stays worn.
	var apron_rng := RandomNumberGenerator.new()
	apron_rng.seed = 229031
	for edge_x in [11.95, 19.05]:
		for tuft in range(18):
			if tuft % 7 == 0:
				continue
			var plant: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
			plant.position = Vector3(edge_x + apron_rng.randf_range(-0.12, 0.12),
				0.045, 33.35 + apron_rng.randf_range(0.0, 3.1))
			plant.rotation.y = apron_rng.randf() * TAU
			var tuft_width := apron_rng.randf_range(0.40, 0.85)
			plant.scale = Vector3(tuft_width, apron_rng.randf_range(0.24, 0.65), tuft_width)
			world.add_child(plant)
	# Partly parked sliding door leaves frame a clear 3.9 m central entrance.
	# Uneven groups spread out from the damp foundation and fade into the
	# approach verge. Preserve the central vehicle and pedestrian route.
	for cluster in [Vector3(11.4, 0.045, 35.8), Vector3(20.2, 0.045, 37.0),
		Vector3(10.8, 0.045, 40.8), Vector3(20.6, 0.045, 43.5),
		Vector3(9.4, 0.045, 37.4), Vector3(9.0, 0.045, 42.0),
		Vector3(21.8, 0.045, 35.8), Vector3(22.2, 0.045, 42.0)]:
		for tuft in range(27):
			var plant: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
			var angle := apron_rng.randf() * TAU
			var radius := sqrt(apron_rng.randf()) * 1.40
			plant.position = cluster + Vector3(cos(angle) * radius * 0.65, 0, sin(angle) * radius * 1.10)
			plant.position.y = maxf(0.045, verge_height(Vector2(plant.position.x, plant.position.z)) + 0.007)
			plant.rotation.y = apron_rng.randf() * TAU
			var width := apron_rng.randf_range(0.65, 1.25)
			plant.scale = Vector3(width, apron_rng.randf_range(0.45, 1.10), width)
			world.add_child(plant)
	# Broad leaves occupy the damp outer verge in broken colonies. Keep the
	# central approach and both kerb faces clear rather than filling the yard.
	for colony in [Vector3(10.7, 0, 36.1), Vector3(20.3, 0, 38.7), Vector3(11.3, 0, 42.1),
		Vector3(9.2, 0, 39.4), Vector3(21.7, 0, 36.3), Vector3(22.0, 0, 42.5)]:
		for leaf_index in range(9):
			var leaf: Node3D = load("res://assets/realism/grass_broadleaf.glb").instantiate()
			var offset := Vector2(apron_rng.randf_range(-0.75, 0.75), apron_rng.randf_range(-1.0, 1.0))
			leaf.position = colony + Vector3(offset.x, 0, offset.y)
			leaf.position.y = maxf(0.045, verge_height(Vector2(leaf.position.x, leaf.position.z)) + 0.007)
			leaf.rotation.y = apron_rng.randf() * TAU
			var leaf_width := apron_rng.randf_range(0.60, 1.0)
			leaf.scale = Vector3(leaf_width, apron_rng.randf_range(0.35, 0.60), leaf_width)
			world.add_child(leaf)
	# Visible panels and supports share the physical collision geometry.
	var door_steel := ShaderMaterial.new()
	door_steel.shader = preload("res://shaders/shelter_structural_steel.gdshader")
	# The aligned RepairPorchFrontKneeBrace pair below carries the front beam.
	# Low woody clumps give the grass a middle storey along unused shoulders.
	for shrub_location in [Vector3(10.6, 0, 38.7), Vector3(21.3, 0, 40.2), Vector3(10.3, 0, 44.4),
		Vector3(21.4, 0, 46.8), Vector3(22.6, 0, 45.9), Vector3(20.9, 0, 47.9),
		Vector3(8.8, 0, 39.2), Vector3(9.3, 0, 40.4)]:
		var shrub: Node3D = vegetation_scene("res://assets/realism/verge_fine_shrub.glb").instantiate()
		shrub.position = shrub_location
		shrub.position.y = maxf(0.045, verge_height(Vector2(shrub_location.x, shrub_location.z)))
		shrub.rotation.y = apron_rng.randf() * TAU
		var shrub_width := apron_rng.randf_range(1.2, 1.9)
		shrub.scale = Vector3(shrub_width, apron_rng.randf_range(0.95, 1.65), shrub_width * 0.88)
		world.add_child(shrub)
	# Recessed panes have projecting glazing bars and a sill that catch light
	# above the canopy. The existing gable collider remains the glass barrier.
	for bar_x in [-2.25, -1.5, -0.75, 0.0, 0.75, 1.5, 2.25]:
		var bar_top := minf(4.55, 1.9 + sqrt(3.3 * 3.3 - bar_x * bar_x) - 0.06)
		var glazing_bar = world.block(Vector3(15.5 + bar_x, (3.45 + bar_top) * 0.5, 33.015),
			Vector3(0.045, bar_top - 3.45, 0.085), "536967", false)
		glazing_bar.material_override = door_steel
	for bar_y in [3.46, 4.54]:
		var glazing_rail = world.block(Vector3(15.5, bar_y, 33.025),
			Vector3(4.58 if bar_y < 4.0 else 3.85, 0.055, 0.12), "536967", false)
		glazing_rail.material_override = door_steel
	for side in [-1.0, 1.0]:
		var door = world.block(Vector3(15.5 + side * 2.60, 0.565, 33.13),
			Vector3(1.3, 1.07, 0.10), "536967")
		var door_finish := ShaderMaterial.new()
		door_finish.shader = preload("res://shaders/shelter_door.gdshader")
		door.material_override = door_finish
		# Raised folded sheet ribs catch grazing daylight independently of paint.
		for rib_index in range(9):
			var rib = world.block(Vector3(15.5 + side * 2.60 - 0.56 + rib_index * 0.14, 0.565, 33.202),
				Vector3(0.026, 0.96, 0.04), "9c9983", false)
			rib.rotation.y = 0.30
			rib.material_override = door_finish
		# Upper wired glazing reveals depth behind each parked sliding leaf.
		# Solid panes retain the original door obstruction above the kick panel.
		var door_glass := ShaderMaterial.new()
		door_glass.shader = preload("res://shaders/shelter_door_glass.gdshader")
		var pane = world.block(Vector3(15.5 + side * 2.60, 1.875, 33.13),
			Vector3(1.20, 1.55, 0.045), "647975")
		pane.material_override = door_glass
		for divider in [-0.20, 0.20]:
			var bar = world.block(Vector3(15.5 + side * 2.60 + divider, 1.875, 33.20),
				Vector3(0.035, 1.55, 0.075), "536967", false)
			bar.material_override = door_steel
		var transom = world.block(Vector3(15.5 + side * 2.60, 1.88, 33.20),
			Vector3(1.30, 0.045, 0.075), "536967", false)
		transom.material_override = door_steel
		# Applied perimeter stiles and cross rail give the sheet a built frame.
		for edge_x in [-0.61, 0.61]:
			var stile = world.block(Vector3(15.5 + side * 2.60 + edge_x, 1.38, 33.23),
				Vector3(0.055, 2.56, 0.065), "536967", false)
			stile.material_override = door_steel
		for height in [0.12, 1.10, 2.65]:
			var rail = world.block(Vector3(15.5 + side * 2.60, height, 33.21),
				Vector3(1.34, 0.08, 0.08), "536967", false)
			rail.material_override = door_steel
		var handle = world.block(Vector3(15.5 + side * 2.04, 0.89, 33.25),
			Vector3(0.035, 0.28, 0.07), "a8aaa0", false)
		handle.material_override = door_steel
	# Sliding leaves hang from an exposed twin-flange track, with recessed
	# web and roller hangers; the structure stays above the vehicle opening.
	for track_y in [2.76, 2.96]:
		var track = world.block(Vector3(15.5, track_y, 33.40), Vector3(6.85, 0.035, 0.24), "536967", false)
		track.material_override = door_steel
	for side in [-1.0, 1.0]:
		for offset in [-0.42, 0.42]:
			var hanger_x: float = 15.5 + side * 2.60 + offset
			var hanger = world.block(Vector3(hanger_x, 2.70, 33.44), Vector3(0.065, 0.33, 0.055), "536967", false)
			hanger.material_override = door_steel
			var roller := MeshInstance3D.new()
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.085
			wheel.bottom_radius = 0.085
			wheel.height = 0.055
			wheel.radial_segments = 16
			# Straight sides need no axial subdivisions; preserve radial detail.
			if OS.has_feature("android"):
				wheel.rings = 0
			roller.mesh = wheel
			roller.rotation_degrees.x = 90
			roller.position = Vector3(hanger_x, 2.855, 33.44)
			roller.material_override = door_steel
			world.add_child(roller)
	var header = world.block(Vector3(15.5, 2.85, 33.15), Vector3(6.65, 0.16, 0.18), "536967")
	header.material_override = door_steel
	# Folded oxide-metal fascia gives the porch a legible weather edge.
	# A shallow folded edge exposes the soffit without a heavy solid lintel.
	var fascia_finish := ShaderMaterial.new()
	fascia_finish.shader = load("res://shaders/porch_fascia.gdshader")
	for bay in range(7):
		var fascia = world.block(Vector3(12.5 + bay, 3.12, 35.34),
			Vector3(0.986, 0.15, 0.045), "785246")
		fascia.name = "PorchFoldedFascia_%d" % bay
		fascia.material_override = fascia_finish
		# One folded seam per sheet, instead of a dense decorative grille.
		for fold in range(1):
			var rib = world.block(Vector3(12.01 + bay, 3.12, 35.375),
				Vector3(0.018, 0.15, 0.024), "785246", false)
			rib.material_override = fascia_finish
	for height in [3.045, 3.21]:
		var flashing = world.block(Vector3(15.5, height, 35.37),
			Vector3(7.04, 0.035, 0.105), "536967", false)
		flashing.material_override = door_steel
	# Deep folded jamb returns frame the open vehicle bay; the clear route
	# remains 3.8 m wide. Unlike applied trim these cast a visible reveal.
	for jamb_x in [13.53, 17.47]:
		var reveal = world.block(Vector3(jamb_x, 1.40, 32.80),
			Vector3(0.14, 2.70, 0.55), "536967")
		reveal.name = "RepairBayDeepJamb"
		reveal.material_override = door_steel
	var lintel_return = world.block(Vector3(15.5, 2.77, 32.80),
		Vector3(4.08, 0.14, 0.55), "536967")
	lintel_return.material_override = door_steel
	# Two full-depth rooflights interrupt the opaque porch roof. Matching
	# openings in the timber lining expose sky from the normal approach.
	var canopy_finish := ShaderMaterial.new()
	canopy_finish.shader = preload("res://shaders/canopy_sheet.gdshader")
	var rooflight_finish := StandardMaterial3D.new()
	rooflight_finish.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rooflight_finish.albedo_color = Color(0.64, 0.77, 0.74, 0.30)
	rooflight_finish.roughness = 0.28
	rooflight_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	for panel_index in range(14):
		var is_rooflight := panel_index in [3, 4, 9, 10]
		# Thin folded sheet: the corrugated underside is visible from the door.
		# Keep the previous overhead collision envelope as an invisible mesh.
		var envelope = world.block(Vector3(12.25 + panel_index * 0.5, 3.22, 34.12),
			Vector3(0.5, 0.10, 2.4), "536967")
		envelope.rotation.x = 0.10
		envelope.hide()
		var roof_surface := SurfaceTool.new()
		roof_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for fold in range(20):
			var x0 := -0.25 + fold * 0.025
			var x1 := x0 + 0.025
			var y0 := 0.0 if fold % 4 in [0, 3] else 0.035
			var y1 := 0.0 if (fold + 1) % 4 in [0, 3] else 0.035
			var vertices := [Vector3(x0,y0,-1.2),Vector3(x1,y1,-1.2),Vector3(x1,y1,1.2),Vector3(x0,y0,1.2)]
			for index in [0,2,1,0,3,2,0,1,2,0,2,3]:
				roof_surface.add_vertex(vertices[index])
		roof_surface.generate_normals()
		if OS.has_feature("android"):
			# Keep triangle order for transparent panes; reuse identical attributes.
			roof_surface.index()
		var panel := MeshInstance3D.new()
		panel.name = "PorchCorrugatedSheet_%d" % panel_index
		panel.mesh = roof_surface.commit()
		panel.position = envelope.position
		panel.rotation.x = 0.10
		panel.material_override = rooflight_finish if is_rooflight else canopy_finish
		if is_rooflight:
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(panel)
	for x in [13.48, 14.52, 16.48, 17.52]:
		var curb = world.block(Vector3(x, 3.23, 34.12), Vector3(0.055, 0.18, 2.42), "536967", false)
		curb.rotation.x = 0.10
		curb.material_override = door_steel
	# Cantilevered west service awning: a separate lower roof breaks the
	# symmetric silhouette and shades the window-side pedestrian route.
	# All supports remain overhead; no new posts narrow the tested walkway.
	var side_roof = world.block(Vector3(10.60, 2.83, 29.2), Vector3(3.35, 0.075, 5.6), "738079")
	side_roof.name = "WestServiceAwning"
	side_roof.rotation.z = 0.12
	side_roof.material_override = canopy_finish
	for depth in [26.6, 29.2, 31.8]:
		var rafter = world.block(Vector3(10.60, 2.74, depth), Vector3(3.30, 0.09, 0.08), "536967", false)
		rafter.rotation.z = 0.12
		rafter.material_override = door_steel
		var knee = world.block(Vector3(11.68, 2.42, depth), Vector3(0.80, 0.065, 0.08), "536967", false)
		knee.rotation.z = 0.70
		knee.material_override = door_steel
	for depth_index in range(9):
		var seam = world.block(Vector3(10.60, 2.885, 26.5 + depth_index * 0.675), Vector3(3.36, 0.025, 0.025), "738079", false)
		seam.rotation.z = 0.12
		seam.material_override = door_steel
	var drip_edge = world.block(Vector3(8.93, 2.58, 29.2), Vector3(0.065, 0.15, 5.7), "536967", false)
	drip_edge.material_override = door_steel
	# Task lighting is attached to a visible housing below the service awning.
	# Broad pools reveal masonry and planted footing without a floating fill.
	var service_diffuser := StandardMaterial3D.new()
	service_diffuser.albedo_color = Color("e3d5ac")
	service_diffuser.emission_enabled = true
	service_diffuser.emission = Color("ffe7be")
	service_diffuser.emission_energy_multiplier = 0.10
	for depth in [27.35,30.85]:
		var housing = world.block(Vector3(11.35,2.78,depth),Vector3(0.18,0.09,0.9),"45594f",false)
		housing.material_override = door_steel
		var diffuser = world.block(Vector3(11.35,2.722,depth),Vector3(0.12,0.024,0.80),"e3d5ac",false)
		diffuser.material_override = service_diffuser
		var service_light := SpotLight3D.new()
		service_light.position = Vector3(11.30,2.68,depth)
		service_light.rotation_degrees.x = -90
		service_light.light_color = Color("ffe8c5")
		service_light.light_energy = 1.1
		service_light.spot_range = 4.0
		service_light.spot_angle = 68
		service_light.spot_attenuation = 0.7
		service_light.shadow_enabled = true
		world.add_child(service_light)
	# Exposed folded roof replaces the flat timber backing below the rooflights.
	# Folded seams run down the fall; exposed purlins break up the flat underside.
	for panel_index in range(15):
		if panel_index in [4, 10]:
			continue
		var seam = world.block(Vector3(12.0 + panel_index * 0.5, 3.300, 34.12), Vector3(0.025, 0.035, 2.38), "78847d", false)
		seam.rotation.x = 0.10
		seam.material_override = door_steel
	for depth in [33.35, 34.12, 34.91]:
		var beam_y: float = 3.12 - (depth - 34.12) * 0.10
		var web = world.block(Vector3(15.5, beam_y, depth), Vector3(6.65, 0.11, 0.008), "455750", false)
		web.material_override = door_steel
		for flange_y in [-0.055, 0.055]:
			var flange = world.block(Vector3(15.5, beam_y + flange_y, depth + 0.032), Vector3(6.65, 0.008, 0.072), "455750", false)
			flange.material_override = door_steel
	var front_beam = world.block(Vector3(15.5, 3.045, 35.12), Vector3(6.65, 0.12, 0.065), "455750", false)
	front_beam.material_override = door_steel
	for side in [-1.0, 1.0]:
		var post = world.block(Vector3(15.5 + side * 3.26, 1.785, 35.12),
			Vector3(0.012, 2.47, 0.12), "536967")
		post.material_override = door_steel
		for flange_z in [-0.07, 0.07]:
			var flange = world.block(Vector3(15.5 + side * 3.26, 1.785, 35.12 + flange_z),
				Vector3(0.10, 2.47, 0.012), "536967")
			flange.material_override = door_steel
		# Baseplates and knee braces terminate on the existing physical posts.
		var baseplate = world.block(Vector3(15.5 + side * 3.26, 0.5575, 35.12), Vector3(0.32, 0.035, 0.30), "777d73", false)
		baseplate.material_override = door_steel
		for bolt_x in [-0.105, 0.105]:
			for bolt_z in [-0.095, 0.095]:
				world.block(Vector3(15.5 + side * 3.26 + bolt_x, 0.59, 35.12 + bolt_z), Vector3(0.035, 0.025, 0.035), "93968b", false)
		# Bolted end plates expose the canopy beam-to-post connections.
		var end_plate = world.block(Vector3(15.5 + side * 3.14, 2.94, 35.185),
			Vector3(0.32, 0.25, 0.025), "747f76", false)
		end_plate.material_override = door_steel
		for fastener_x in [-0.10, 0.10]:
			for fastener_y in [-0.075, 0.075]:
				var bolt = MeshInstance3D.new()
				var bolt_mesh := CylinderMesh.new()
				bolt_mesh.top_radius = 0.018
				bolt_mesh.bottom_radius = 0.018
				bolt_mesh.height = 0.025
				bolt_mesh.radial_segments = 6
				# Straight sides need no axial subdivisions; preserve radial detail.
				if OS.has_feature("android"):
					bolt_mesh.rings = 0
				bolt.mesh = bolt_mesh
				bolt.rotation.x = PI / 2.0
				bolt.position = Vector3(15.5 + side * 3.14 + fastener_x, 2.94 + fastener_y, 35.218)
				var bolt_finish := StandardMaterial3D.new()
				bolt_finish.albedo_color = Color("77796e")
				bolt_finish.roughness = 0.78
				bolt.material_override = bolt_finish
				world.add_child(bolt)
		var rafter = world.block(Vector3(15.5 + side * 3.26, 3.005, 34.12),
			Vector3(0.09, 0.13, 2.4), "536967")
		rafter.rotation.x = 0.10
		rafter.material_override = door_steel
	var gutter = world.block(Vector3(15.5, 3.03, 35.30), Vector3(7.08, 0.065, 0.13), "536967")
	gutter.material_override = door_steel
	# Discharge beside the posts into the rubble, outside the clear entrance.
	for side in [-1.0, 1.0]:
		var pipe_x: float = 15.5 + side * 3.43
		var joints: Array[Vector3] = [Vector3(pipe_x, 3.03, 35.30),
			Vector3(pipe_x, 2.73, 35.43), Vector3(pipe_x, 0.30, 35.43),
			Vector3(pipe_x + side * 0.46, 0.14, 35.64)]
		for j in range(joints.size() - 1):
			var delta: Vector3 = joints[j + 1] - joints[j]
			var pipe := MeshInstance3D.new()
			var pipe_mesh := CylinderMesh.new()
			pipe_mesh.top_radius = 0.042
			pipe_mesh.bottom_radius = 0.042
			pipe_mesh.height = delta.length()
			pipe_mesh.radial_segments = 12
			# Straight sides need no axial subdivisions; preserve radial detail.
			if OS.has_feature("android"):
				pipe_mesh.rings = 0
			pipe.mesh = pipe_mesh
			pipe.material_override = door_steel
			pipe.position = (joints[j] + joints[j + 1]) * 0.5
			pipe.basis = Basis(Quaternion(Vector3.UP, delta.normalized()))
			world.add_child(pipe)
		for height in [0.65, 2.35]:
			var collar = world.block(Vector3(pipe_x, height, 35.43),
				Vector3(0.115, 0.028, 0.11), "747f76", false)
			collar.material_override = door_steel
	# Recessed three-pane industrial windows sit on the masonry returns.
	# Glazing carries collision; neither return projects into the central aisle.
	var screen_finish := ShaderMaterial.new()
	screen_finish.shader = load("res://shaders/porch_timber.gdshader")
	var porch_glass := ShaderMaterial.new()
	porch_glass.shader = load("res://shaders/shelter_side_glass.gdshader")
	for side_x in [12.24, 18.76]:
		for rail_y in [1.43, 2.76]:
			var rail = world.block(Vector3(side_x, rail_y, 34.15), Vector3(0.065, 0.040, 1.64), "405954")
			rail.material_override = door_steel
		for rail_z in [33.36, 33.89, 34.42, 34.94]:
			var upright = world.block(Vector3(side_x, 2.095, rail_z), Vector3(0.065, 1.33, 0.035), "405954")
			upright.material_override = door_steel
		for pane_z in [33.625, 34.155, 34.68]:
			var pane = world.block(Vector3(side_x, 2.095, pane_z), Vector3(0.035, 1.255, 0.485), "698078")
			pane.name = "RepairPorchRecessedGlass"
			pane.material_override = porch_glass
		var sill = world.block(Vector3(side_x, 1.385, 34.15), Vector3(0.24, 0.045, 1.68), "69766c")
		sill.material_override = door_steel
		# A slim crossbar divides the fixed upper light from the main panes.
		var transom = world.block(Vector3(side_x, 2.43, 34.15), Vector3(0.055, 0.025, 1.58), "405954")
		transom.material_override = door_steel
	# Longitudinal roof braces expose the load path on the open east flank.
	# They cast diagonal shade without occupying the doorway or walking height.
	for ends in [[Vector3(18.76, 2.22, 35.10), Vector3(18.76, 3.08, 34.15)],
			[Vector3(18.76, 2.22, 33.35), Vector3(18.76, 3.08, 34.15)]]:
		var delta: Vector3 = ends[1] - ends[0]
		var support = world.block((ends[0] + ends[1]) * 0.5,
			Vector3(0.07, delta.length(), 0.07), "536967")
		support.name = "RepairPorchLongitudinalBrace"
		support.basis = Basis(Quaternion(Vector3.UP, delta.normalized()))
		support.material_override = door_steel
	# Enamel fascia identifies the vehicle bay from the southern approach.
	# Folded, aged enamel with recessed light lettering on the outer canopy edge, ahead of all beams.
	var bay_sign = world.block(Vector3(15.5, 3.12, 35.41),
		Vector3(4.0, 0.27, 0.06), "c4b894", false)
	var bay_sign_finish := ShaderMaterial.new()
	bay_sign_finish.shader = preload("res://shaders/porch_fascia.gdshader")
	bay_sign.material_override = bay_sign_finish
	var bay_label := Label3D.new()
	bay_label.name = "RepairBayEntranceSign"
	bay_label.text = "02  /  VEHICLE SERVICE"
	bay_label.font_size = 96
	bay_label.pixel_size = 0.0022
	bay_label.position = Vector3(15.5, 3.12, 35.45)
	bay_label.modulate = Color("c5bd9c")
	bay_label.outline_size = 0
	bay_label.shaded = true
	world.add_child(bay_label)
	for end_x in [13.58, 17.42]:
		world.block(Vector3(end_x, 3.12, 35.45), Vector3(0.035, 0.21, 0.012), "bda16c", false)
	# Folded rim and fasteners give the sign thickness in normal approach views.
	for rim_y in [2.975, 3.265]:
		world.block(Vector3(15.5, rim_y, 35.455), Vector3(4.08, 0.035, 0.09), "596052", false)
	for bolt_x in [13.60, 17.40]:
		for bolt_y in [3.015, 3.225]:
			world.block(Vector3(bolt_x, bolt_y, 35.475), Vector3(0.027, 0.027, 0.015), "969383", false)
	# Luminous diffuser and downlight make the fixture legible in daylight.
	var diffuser := StandardMaterial3D.new()
	diffuser.albedo_color = Color("ece3cb")
	diffuser.emission_enabled = true
	diffuser.emission = Color("ffe2aa")
	diffuser.emission_energy_multiplier = 0.10
	var lamp = world.block(Vector3(15.5, 2.74, 33.5), Vector3(1.10, 0.04, 0.16), "ece3cb", false)
	lamp.material_override = diffuser
	# Recess the diffuser in a folded weatherproof channel with dark lips.
	for offset_z in [-0.105, 0.105]:
		var lamp_lip = world.block(Vector3(15.5, 2.745, 33.5 + offset_z),
			Vector3(1.22, 0.10, 0.035), "414b44", false)
		lamp_lip.material_override = door_steel
	for offset_x in [-0.59, 0.59]:
		var lamp_cap = world.block(Vector3(15.5 + offset_x, 2.755, 33.5),
			Vector3(0.045, 0.10, 0.24), "414b44", false)
		lamp_cap.material_override = door_steel
	var entrance_light := SpotLight3D.new()
	entrance_light.position = Vector3(15.5, 2.69, 33.5)
	entrance_light.rotation_degrees.x = -90
	entrance_light.light_color = Color("ffe5bd")
	entrance_light.light_energy = 1.35
	entrance_light.spot_range = 5.0
	entrance_light.spot_angle = 58
	entrance_light.spot_angle_attenuation = 0.65
	entrance_light.light_size = 0.35
	entrance_light.shadow_enabled = true
	world.add_child(entrance_light)
	var apron_daylight := SpotLight3D.new()
	apron_daylight.name = "RepairApronReflectedDaylight"
	apron_daylight.position = Vector3(15.5, 2.0, 34.8)
	apron_daylight.rotation_degrees.x = -16.0
	apron_daylight.light_color = Color("e1ded0")
	apron_daylight.light_energy = 0.72
	apron_daylight.spot_range = 7.0
	apron_daylight.spot_angle = 78.0
	apron_daylight.spot_angle_attenuation = 0.35
	apron_daylight.light_size = 1.2
	apron_daylight.shadow_enabled = true
	world.add_child(apron_daylight)
	# Two translucent roof strips admit cool skylight between the purlins.
	# Keep the pools local so the shaded brick piers retain their depth.
	for rooflight_x in [14.0, 17.0]:
		var rooflight := SpotLight3D.new()
		rooflight.name = "RepairPorchRooflight"
		rooflight.position = Vector3(rooflight_x, 3.12, 34.12)
		rooflight.rotation_degrees.x = -90
		rooflight.light_color = Color("d6e5ed")
		rooflight.light_energy = 1.20
		rooflight.spot_range = 4.2
		rooflight.spot_angle = 38.0
		rooflight.spot_attenuation = 0.8
		rooflight.light_size = 0.6
		rooflight.shadow_enabled = true
		world.add_child(rooflight)
	# Folded fascia closes the exposed corrugated ends. Return flanges cast
	# narrow shadows and give the porch a readable thickness from the road.
	for fascia_z in [35.30, 32.94]:
		var fascia = world.block(Vector3(15.5, 3.19, fascia_z),
			Vector3(6.82, 0.075, 0.012), "526862", false)
		fascia.name = "RepairPorchFoldedFascia"
		fascia.material_override = door_steel
		for lip_y in [3.1525, 3.2275]:
			var lip = world.block(Vector3(15.5, lip_y, fascia_z + 0.025),
				Vector3(6.86, 0.012, 0.045), "526862", false)
			lip.material_override = door_steel
	# Local skylight bounce exposes the roof structure without lifting outdoor exposure.
	var shelter_bounce := OmniLight3D.new()
	shelter_bounce.position = Vector3(15.5, 3.25, 30.8)
	shelter_bounce.light_color = Color("cedbe0")
	shelter_bounce.light_energy = 0.52
	shelter_bounce.omni_range = 5.8
	shelter_bounce.omni_attenuation = 1.35
	shelter_bounce.shadow_enabled = true
	world.add_child(shelter_bounce)
	# Broad daylight entering through the vehicle opening reaches the rear
	# wall; keep the source inside the aperture rather than behind its lintel.
	var bay_daylight := SpotLight3D.new()
	bay_daylight.name = "RepairBayOpeningDaylight"
	bay_daylight.position = Vector3(15.5, 2.35, 32.65)
	bay_daylight.rotation_degrees.x = -8
	bay_daylight.light_color = Color("d7e3e7")
	bay_daylight.light_energy = 1.15
	bay_daylight.spot_range = 10.0
	bay_daylight.spot_angle = 65.0
	bay_daylight.spot_attenuation = 0.65
	bay_daylight.light_size = 1.5
	bay_daylight.shadow_enabled = true
	world.add_child(bay_daylight)
	# A working bench gives the right bay a readable purpose while leaving the
	# central doorway and rear exit unobstructed. All large parts are solid.
	var bench_top = world.block(Vector3(18.0, 0.93, 29.4), Vector3(0.85, 0.09, 2.8), "8b795c")
	bench_top.name = "RepairShelterWorkbench"
	for bench_z in [28.25, 30.55]:
		for bench_x in [17.68, 18.32]:
			var leg = world.block(Vector3(bench_x, 0.45, bench_z), Vector3(0.06, 0.9, 0.06), "536967")
			leg.material_override = door_steel
	var shelf = world.block(Vector3(18.0, 0.29, 29.4), Vector3(0.76, 0.045, 2.65), "536967")
	shelf.material_override = door_steel
	# Rearward work light illuminates the bench and side ribs, adding depth.
	var bench_light := SpotLight3D.new()
	bench_light.position = Vector3(17.6, 2.7, 29.0)
	bench_light.rotation_degrees = Vector3(-78, -90, 0)
	bench_light.light_color = Color("ffe4b8")
	bench_light.light_energy = 1.8
	bench_light.spot_range = 4.8
	bench_light.spot_angle = 68
	bench_light.shadow_enabled = true
	world.add_child(bench_light)
	var bench_fixture = world.block(bench_light.position, Vector3(0.12, 0.045, 0.85), "ece3cb", false)
	bench_fixture.material_override = diffuser
	# Continuous recessed channel with narrow steel ribs, rather than isolated
	# dark rectangles. Everything remains flush with the traversable apron.
	world.block(Vector3(15.45, 0.084, 35.7),
		Vector3(6.15, 0.009, 0.19), "202720", false)
	for rail_z in [35.60, 35.80]:
		var channel_edge = world.block(Vector3(15.45, 0.092, rail_z),
			Vector3(6.19, 0.012, 0.022), "676958", false)
		channel_edge.material_override = door_steel
	for x in range(77):
		world.block(Vector3(12.41 + x * 0.08, 0.093, 35.7),
			Vector3(0.018, 0.013, 0.18), "626459", false)
	for joint_x in [13.43, 14.46, 15.49, 16.52, 17.55]:
		world.block(Vector3(joint_x, 0.094, 35.7),
			Vector3(0.033, 0.014, 0.21), "434c43", false)
	# Stacked sawn boards occupy only the left work bay, outside the central aisle.
	for layer in range(7):
		for board in range(4):
			world.block(Vector3(13.0 + board * 0.21, 0.16 + layer * 0.12, 29.6),
				Vector3(0.19, 0.10, 3.4 - (layer % 2) * 0.12), "8b795c")
	var task_light := SpotLight3D.new()
	task_light.position = center + Vector3(1.7, 3.7, -1.0)
	task_light.rotation_degrees.x = -78
	task_light.light_color = Color("ffe5c1")
	task_light.light_energy = 0.85
	task_light.spot_range = 6
	task_light.spot_angle = 48
	task_light.shadow_enabled = true
	world.add_child(task_light)
	world.block(task_light.position, Vector3(0.6, 0.08, 0.2), "bbb9a8", false)
	# Weathered timber fascia gives the porch a continuous readable edge.
	# Mounted behind the gutter; it does not narrow either entrance.
	var porch_fascia = world.block(Vector3(15.5, 3.055, 35.205), Vector3(6.85, 0.12, 0.045), "8b795c", false)
	var fascia_material := ShaderMaterial.new()
	fascia_material.shader = load("res://shaders/canopy_soffit.gdshader")
	porch_fascia.material_override = fascia_material
	# A visible warm strip under the soffit lights the doorway without washing
	# out the entire outdoor scene or changing the solid doorway geometry.
	var porch_fixture = world.block(Vector3(15.5, 2.97, 34.8), Vector3(1.65, 0.045, 0.18), "ece3cb", false)
	porch_fixture.material_override = diffuser
	# A folded steel housing and end caps locate the strip under the porch.
	var strip_housing = world.block(Vector3(15.5, 3.01, 34.8),
		Vector3(1.78, 0.045, 0.24), "414b44", false)
	strip_housing.material_override = door_steel
	for end_x in [14.64, 16.36]:
		world.block(Vector3(end_x, 2.97, 34.8), Vector3(0.05, 0.08, 0.24), "414b44", false)
	# Masonry porch returns protect the lower side bays from vehicle splash.
	# Full central aisle remains open; caps shed rain toward the gravel beds.
	var porch_masonry := ShaderMaterial.new()
	porch_masonry.shader = load("res://shaders/workshop_masonry.gdshader")
	porch_masonry.set_shader_parameter("exposed_brick_height", 1.32)
	porch_masonry.set_shader_parameter("reclaimed_variation", 0.35)
	porch_masonry.set_shader_parameter("aged_plinth_render", 1.0)
	var coping := ShaderMaterial.new()
	coping.shader = load("res://shaders/shelter_coping.gdshader")
	for return_x in [12.24, 18.76]:
		var return_wall = world.block(Vector3(return_x, 0.72, 34.15),
			Vector3(0.36, 1.14, 1.48), "897b66")
		return_wall.name = "RepairPorchMasonryReturn"
		return_wall.material_override = porch_masonry
		var cap = world.block(Vector3(return_x, 1.325, 34.15),
			Vector3(0.46, 0.10, 1.60), "aaa18d")
		cap.material_override = coping
	# Low splash plinths carry exposed steel posts: the porch reads as an
	# open workshop frame, with daylight through both sides above the walls.
	for pier_x in [12.24, 18.76]:
		var pier = world.block(Vector3(pier_x, 0.73, 35.0), Vector3(0.36, 1.16, 0.36), "897b66")
		pier.name = "RepairPorchMasonryPier"
		pier.material_override = porch_masonry
		var cap = world.block(Vector3(pier_x, 1.345, 35.0), Vector3(0.46, 0.10, 0.46), "aaa18d")
		cap.material_override = coping
		var post = world.block(Vector3(pier_x, 2.12, 35.0), Vector3(0.13, 1.48, 0.13), "414b44")
		post.material_override = door_steel
		var foot = world.block(Vector3(pier_x, 1.398, 35.0), Vector3(0.25, 0.04, 0.25), "414b44", false)
		foot.material_override = door_steel
		for bolt_x in [-0.085, 0.085]:
			for bolt_z in [-0.085, 0.085]:
				world.block(Vector3(pier_x + bolt_x, 1.427, 35.0 + bolt_z), Vector3(0.025, 0.018, 0.025), "807e70", false)
		# Front knee braces transfer the canopy load into the posts. The lowest
		# point stays above head clearance; the full-width route remains open.
		var inward := 1.0 if pier_x < 15.5 else -1.0
		var brace_start := Vector3(pier_x, 2.32, 35.0)
		var brace_end := Vector3(pier_x + inward * 0.70, 2.94, 35.0)
		var brace = world.block((brace_start + brace_end) * 0.5,
			Vector3(0.085, brace_start.distance_to(brace_end), 0.105), "414b44")
		brace.name = "RepairPorchFrontKneeBrace"
		brace.quaternion = Quaternion(Vector3.UP, (brace_end - brace_start).normalized())
		brace.material_override = door_steel
		for connection in [brace_start, brace_end]:
			var plate = world.block(connection + Vector3(0, 0, 0.065),
				Vector3(0.18, 0.18, 0.022), "414b44", false)
			plate.material_override = door_steel
		world.block(Vector3(pier_x, 0.20, 35.0),
			Vector3(0.40, 0.10, 0.40), "66685b", false)
	# Shield the luminous strip from oblique approach views with steel lips.
	for lip_z in [34.69, 34.91]:
		var lip = world.block(Vector3(15.5, 2.96, lip_z), Vector3(1.78, 0.11, 0.025), "414b44", false)
		lip.material_override = door_steel
	# Aim the strip's illumination below its housing: an omnidirectional bulb
	# this close to the soffit created a bright, unmotivated ceiling hotspot.
	var porch_light := SpotLight3D.new()
	porch_light.name = "RepairPorchStripDownlight"
	porch_light.position = Vector3(15.5, 2.90, 34.8)
	porch_light.rotation_degrees.x = -90
	porch_light.light_color = Color("ffe0ab")
	porch_light.light_energy = 0.85
	porch_light.spot_range = 4.2
	porch_light.spot_angle = 75
	porch_light.spot_attenuation = 0.8
	porch_light.light_size = 0.55
	porch_light.shadow_enabled = true
	world.add_child(porch_light)
	# A timber ventilation screen sits above the sliding-door clearance.
	# Its projecting blades shade one another and reveal the arched shell behind.
	for row in range(6):
		var blade = world.block(Vector3(15.5, 3.43 + row * 0.125, 33.18), Vector3(4.15, 0.065, 0.21), "8b795c", false)
		blade.rotation.x = -0.20
		var louver_timber := ShaderMaterial.new()
		louver_timber.shader = load("res://shaders/porch_timber.gdshader")
		louver_timber.set_shader_parameter("board_seed", float(row) * 1.73)
		blade.material_override = louver_timber
		# Recessed battens support the long blades and add a readable shadow gap.
	for batten_x in [14.12, 16.88]:
		world.block(Vector3(batten_x, 3.74, 33.055),
			Vector3(0.045, 0.79, 0.055), "39413b", false)
	for x in [13.40, 17.60]:
		world.block(Vector3(x, 3.74, 33.17), Vector3(0.06, 0.80, 0.23), "414b44", false)
	var doorway_fill := SpotLight3D.new()
	doorway_fill.position = Vector3(15.5, 3.0, 34.7)
	doorway_fill.rotation_degrees = Vector3(-32, 0, 0)
	doorway_fill.light_color = Color("d6e1e5")
	doorway_fill.light_energy = 0.95
	doorway_fill.spot_range = 6.0
	doorway_fill.spot_angle = 53.0
	doorway_fill.shadow_enabled = true
	world.add_child(doorway_fill)
	# Side-plane bracing ties the canopy to the building; the central portal
	# retains its full clearance. Real depth gives the thin posts a structure.
	for side in [-1.0, 1.0]:
		var diagonal = world.block(Vector3(15.5 + side * 3.26, 2.35, 34.55),
			Vector3(0.055, 1.62, 0.055), "536967", false)
		diagonal.rotation.x = -0.78
		diagonal.material_override = door_steel
	# Separate streams keep changes to understory from rotating distant trees.
	var window_bounce := OmniLight3D.new()
	window_bounce.name = "RepairWindowReflectedDaylight"
	window_bounce.position = Vector3(13.15, 2.05, 34.1)
	window_bounce.light_color = Color("d2dddf")
	window_bounce.light_energy = 0.45
	window_bounce.omni_range = 2.6
	window_bounce.shadow_enabled = true
	world.add_child(window_bounce)
	# Runoff-fed vegetation follows the two outer drainage shoulders. Density
	# tapers away from each downpipe instead of making another straight hedge.
	var runoff_random := RandomNumberGenerator.new()
	runoff_random.seed = 407035
	for side in [-1.0, 1.0]:
		for i in range(74):
			var distance := runoff_random.randf_range(0.0, 7.8)
			var spread := runoff_random.randf_range(0.0, 1.0)
			if spread > 1.0 - distance * 0.065:
				continue
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 3 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			plant.name = "RepairDrainageVerge"
			plant.position = Vector3(15.5 + side * (3.85 + spread * 1.4), 0, 35.65 + distance)
			plant.position.y = maxf(0.045, verge_height(Vector2(plant.position.x, plant.position.z)) + 0.01)
			plant.rotation.y = runoff_random.randf() * TAU
			var width := runoff_random.randf_range(0.55, 1.05)
			plant.scale = Vector3(width, runoff_random.randf_range(0.30, 0.65) * (1.0 - distance * 0.04), width)
			world.add_child(plant)
	# Irregular low broadleaf colonies occupy sheltered wall feet and yard edges.
	var foot_random := RandomNumberGenerator.new()
	foot_random.seed = 364071
	for island in [Vector3(11.55, 0, 34.2), Vector3(19.45, 0, 34.1), Vector3(22.0, 0, 43.5), Vector3(24.0, 0, 47.5), Vector3(9.4, 0, 43.0)]:
		for i in range(32):
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb").instantiate()
			var angle := foot_random.randf() * TAU
			var radius := sqrt(foot_random.randf())
			plant.position = island + Vector3(cos(angle) * radius * 0.48, 0, sin(angle) * radius * 1.05)
			plant.position.y = verge_height(Vector2(plant.position.x, plant.position.z)) + 0.025
			plant.rotation.y = foot_random.randf() * TAU
			var size := foot_random.randf_range(0.42, 0.73)
			plant.scale = Vector3(size, size * (1.0 - radius * 0.45), size)
			world.add_child(plant)
	var shrub_random := RandomNumberGenerator.new()
	shrub_random.seed = 220091
	for island in [Vector3(9.7, 0, 36.8), Vector3(21.1, 0, 38.2),
		Vector3(22.5, 0, 46.5), Vector3(26.5, 0, 48.2), Vector3(9.1, 0, 43.6)]:
		for i in range(3):
			var angle := shrub_random.randf() * TAU
			var radius := sqrt(shrub_random.randf())
			var shrub: Node3D = vegetation_scene("res://assets/realism/verge_fine_shrub.glb").instantiate()
			shrub.position = island + Vector3(cos(angle) * radius * 0.85, 0, sin(angle) * radius * 0.95)
			shrub.position.y = verge_height(Vector2(shrub.position.x, shrub.position.z)) + 0.02
			shrub.rotation.y = shrub_random.randf() * TAU
			# One open crown per island, with low satellites instead of a hedge.
			var spread := shrub_random.randf_range(0.55, 0.90)
			var crown_height := (1.10 + 0.25 * sin(island.x * 1.7)) if i == 0 else shrub_random.randf_range(0.30, 0.55)
			shrub.scale = Vector3(spread, crown_height * (1.0 - radius * 0.3), spread)
			shrub.set_meta("repair_yard_understory", true)
			world.add_child(shrub)
	# Taller sheltered growth against the apron breaks its long bare edges.
	# Taper toward the lane; all plants remain outside the central passage.
	var apron_random := RandomNumberGenerator.new()
	apron_random.seed = 221083
	for island in [Vector3(10.1, 0, 35.2), Vector3(20.1, 0, 35.3), Vector3(9.0, 0, 48.2)]:
		for i in range(3):
			var offset := Vector3(apron_random.randf_range(-0.9, 0.9), 0, apron_random.randf_range(-1.5, 1.5))
			var shrub: Node3D = vegetation_scene("res://assets/realism/verge_fine_shrub.glb").instantiate()
			shrub.position = island + offset
			shrub.position.y = verge_height(Vector2(shrub.position.x, shrub.position.z)) + 0.02
			shrub.rotation.y = apron_random.randf() * TAU
			var size := apron_random.randf_range(0.45, 0.75)
			shrub.scale = Vector3(size, size * (0.72 if i == 0 else 0.38), size)
			shrub.set_meta("repair_yard_understory", true)
			world.add_child(shrub)
	var yard_random := RandomNumberGenerator.new()
	yard_random.seed = 139041
	# Connected, low groundcover under the west canopy and beside the yard:
	# irregular edges and height taper avoid isolated identical grass tufts.
	var carpet_random := RandomNumberGenerator.new()
	carpet_random.seed = 298071
	var carpet_scene: PackedScene = load("res://assets/realism/grass_fine.glb")
	for patch in [Vector3(6.2, 0.025, 34.0), Vector3(7.5, 0.025, 37.0),
			Vector3(8.8, 0.025, 39.8), Vector3(9.0, 0.025, 43.4),
			Vector3(8.6, 0.025, 46.8), Vector3(21.8, 0.025, 36.0),
			Vector3(21.8, 0.025, 39.0), Vector3(23.0, 0.025, 43.4),
			Vector3(24.5, 0.025, 50.5)]:
		for i in range(210):
			var angle := carpet_random.randf() * TAU
			var radius := sqrt(carpet_random.randf())
			if radius > 0.72 and carpet_random.randf() < 0.45:
				continue
			var plant := carpet_scene.instantiate() as Node3D
			plant.position = patch + Vector3(cos(angle) * radius * 1.65, 0, sin(angle) * radius * 2.35)
			plant.position.y = verge_height(Vector2(plant.position.x, plant.position.z)) + 0.025
			plant.rotation.y = angle
			var spread := carpet_random.randf_range(0.55, 0.95)
			plant.scale = Vector3(spread, carpet_random.randf_range(0.35, 0.72) * (1.0 - radius * 0.65), spread)
			world.add_child(plant)
	# Short interrupted regeneration between wheel paths, following the same
	# bent centerline as the ground shader. No decorative plant adds collision.
	var lane_random := RandomNumberGenerator.new()
	lane_random.seed = 169
	for i in range(130):
		var along := lane_random.randf_range(0.0, 1.0)
		if along > 0.34 and along < 0.49:
			continue
		var lane_at := Vector3(15.7, 0.07, 40.0).lerp(Vector3(16.0, 0.07, 46.0), along)
		if along > 0.72:
			lane_at = Vector3(16.0, 0.07, 46.0).lerp(Vector3(12.5, 0.07, 49.0), (along - 0.72) / 0.28)
		var grass: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
		grass.position = lane_at + Vector3(lane_random.randf_range(-0.32, 0.32), 0, lane_random.randf_range(-0.20, 0.20))
		grass.rotation.y = lane_random.randf() * TAU
		var spread := lane_random.randf_range(0.35, 0.72)
		grass.scale = Vector3(spread, lane_random.randf_range(0.12, 0.30), spread)
		world.add_child(grass)
	for verge in [Vector3(11.3, 0, 34.8), Vector3(20.5, 0, 36.0)]:
		for i in range(310):
			var broadleaf := i % 7 == 0
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if broadleaf else "res://assets/realism/grass_fine.glb").instantiate()
			# Unequal colonies leave broad worn gaps instead of periodic stripes.
			var colony := i % 3
			var centres := [-2.8, 0.25, 3.85] if verge.x < 15.0 else [-3.1, 1.0, 4.0]
			var widths := [0.65, 1.25, 0.48]
			var radius := sqrt(yard_random.randf())
			var angle := yard_random.randf() * TAU
			var along: float = centres[colony] + sin(angle) * radius * widths[colony]
			if yard_random.randf() < radius * 0.30:
				plant.free()
				continue
			plant.position = verge + Vector3(cos(angle) * radius * (0.55 + colony * 0.18), 0.02, along)
			plant.rotation.y = yard_random.randf() * TAU
			# Low spreading leaves bridge bare soil to occasional upright stems.
			var plant_size := yard_random.randf_range(0.23, 0.48) if broadleaf else yard_random.randf_range(0.45, 0.95)
			plant.scale = Vector3(plant_size * 0.85, plant_size * yard_random.randf_range(0.65, 1.25), plant_size * 0.85)
			if not service_growth_sample(Vector2(plant.position.x, plant.position.z)):
				plant.free()
				continue
			world.add_child(plant)

	# Low pioneer growth tapers into the worn apron in unequal islands.
	# Keep the lane centre clear; foliage has no blocking physics bodies.
	var pioneer_random := RandomNumberGenerator.new()
	pioneer_random.state = yard_random.state
	for island in [Vector3(12.0, 0.03, 39.2), Vector3(19.5, 0.03, 40.7), Vector3(20.1, 0.03, 43.1)]:
		for i in range(56):
			var angle := pioneer_random.randf() * TAU
			var radius := sqrt(pioneer_random.randf())
			var plant: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
			plant.position = island + Vector3(cos(angle) * radius * 1.2, 0, sin(angle) * radius * 1.8)
			plant.rotation.y = angle
			var spread := pioneer_random.randf_range(0.38, 0.72)
			plant.scale = Vector3(spread, pioneer_random.randf_range(0.18, 0.46) * (1.0 - radius * 0.45), spread)
			if not service_growth_sample(Vector2(plant.position.x, plant.position.z)):
				plant.free()
				continue
			world.add_child(plant)

	# Sparse short plants soften the bare track edge without closing the wheel
	# beds. Independent randomness preserves all established scenery positions.
	var shoulder_random := RandomNumberGenerator.new()
	shoulder_random.seed = 256031
	var shoulder_grass: PackedScene = load("res://assets/realism/grass_fine.glb")
	for i in range(420):
		var along := shoulder_random.randf()
		var shoulder_position := Vector3(16, 0, 46).lerp(Vector3(9, 0, 52), along)
		var lateral := shoulder_random.randf_range(1.9, 3.8)
		if i % 2 == 0:
			lateral = -lateral
		shoulder_position += Vector3(0.651, 0, 0.759) * lateral
		if sin(shoulder_position.x * 1.2 + shoulder_position.z * 0.65) > 0.48:
			continue
		var grass: Node3D = shoulder_grass.instantiate()
		grass.position = shoulder_position
		grass.position.y = verge_height(Vector2(shoulder_position.x, shoulder_position.z)) + 0.045
		grass.rotation.y = shoulder_random.randf() * TAU
		# Outside the wheel corridor, alternate taller seed heads with cropped
		# grass. Broad patches remain readable from a standing game camera.
		var patch := 0.5 + 0.5 * sin(along * 19.0 + lateral * 1.4)
		var spread := shoulder_random.randf_range(0.42, 0.78)
		grass.scale = Vector3(spread, shoulder_random.randf_range(0.16, 0.32) + patch * 0.22, spread)
		if not service_growth_sample(Vector2(grass.position.x, grass.position.z)):
			grass.free()
			continue
		world.add_child(grass)

	# Irregular regeneration beyond the worn yard, clear of the shelter and depot
	# approach lanes. Full geometry receives sunlight and casts local shadows.
	# Preserve the stage219 sequence, independent of pioneer island count.
	for i in range(56 * 3 * 4):
		yard_random.randf()
	# Leave clearance for the irregular fir crown beyond the loading roof.
	for sapling in [Vector3(22.4, 0.95, 42.25), Vector3(24.7, 0.42, 44.0),
		Vector3(26.8, 1.15, 44.6), Vector3(28.4, 0.58, 41.6)]:
		var broadleaf: bool = sapling.x > 24.0 and sapling.x < 28.0
		var fir: Node3D = vegetation_scene("res://assets/realism/verge_birch.glb" if broadleaf else "res://assets/realism/fir_full.glb").instantiate()
		fir.name = "RepairYardSapling"
		fir.set_meta("repair_yard_sapling", true)
		fir.position = Vector3(sapling.x, 0.02, sapling.z)
		fir.scale = Vector3(sapling.y * (1.12 if broadleaf else 0.85), sapling.y, sapling.y * 0.85)
		fir.rotation.y = yard_random.randf() * TAU
		world.add_child(fir)
		if not broadleaf:
			configure_fir_lod(world, fir)
		var trunk := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.14 * sapling.y
		cylinder.height = 5.0 * sapling.y
		shape.shape = cylinder
		trunk.position = fir.position + Vector3(0, cylinder.height * 0.5, 0)
		trunk.add_child(shape)
		world.add_child(trunk)
		for i in range(58):
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 3 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			var angle := yard_random.randf() * TAU
			var radius := sqrt(yard_random.randf()) * 1.9
			plant.position = fir.position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
			plant.position.y = verge_height(Vector2(plant.position.x, plant.position.z)) + 0.025
			plant.rotation.y = angle
			plant.scale = Vector3(0.32, 0.38, 0.32) * yard_random.randf_range(0.7, 1.2) if i % 3 == 0 else Vector3(0.85, 0.48, 0.85) * yard_random.randf_range(0.7, 1.2)
			world.add_child(plant)

	# Tall, irregular understory islands bridge the bare yard and tree crowns.
	# A separate generator leaves existing tree rotations and test locations stable.
	var understory_rng := RandomNumberGenerator.new()
	understory_rng.seed = 392
	for island in [Vector3(23.8, 0, 43.5), Vector3(27.7, 0, 42.8), Vector3(29.2, 0, 46.0)]:
		for index in range(28):
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if index % 4 != 0 else "res://assets/realism/grass_fine.glb").instantiate()
			var angle := understory_rng.randf() * TAU
			var radius := sqrt(understory_rng.randf()) * 1.25
			plant.position = island + Vector3(cos(angle) * radius, 0, sin(angle) * radius * 0.7)
			plant.position.y = verge_height(Vector2(plant.position.x, plant.position.z)) + 0.02
			plant.rotation.y = angle
			var size := understory_rng.randf_range(0.52, 0.92)
			plant.scale = Vector3(size, size * (1.15 - radius * 0.25), size)
			plant.name = "RepairYardUnderstory"
			world.add_child(plant)

	# Stagger mature conifers behind the birches: the pedestrian view reads
	# distinct pointed crowns above the broadleaf layer, with young trees below.
	# Keep trunks within the verge, clear of the road and shelter entrance.
	var grove_random := RandomNumberGenerator.new()
	grove_random.seed = 142
	var grove_specs := [
		Vector4(10.2, 0.48, 24.1, 1), Vector4(11.8, 1.28, 17.8, 0),
		Vector4(13.0, 1.12, 11.9, 1), Vector4(9.7, 0.87, 20.8, 1),
		Vector4(13.6, 1.10, 15.2, 0), Vector4(10.3, 0.32, 13.6, 0),
		Vector4(16.8, 1.72, 10.2, 0), Vector4(19.8, 0.76, 12.4, 1),
		Vector4(19.0, 0.78, 18.0, 1), Vector4(9.8, 0.38, 10.8, 1),
		Vector4(11.1, 0.49, 18.6, 0), Vector4(17.6, 0.35, 14.8, 0)]
	for spec in grove_specs:
		var broadleaf: bool = spec.w > 0.5
		var tree: Node3D = vegetation_scene("res://assets/realism/verge_birch.glb" if broadleaf else "res://assets/realism/fir_full.glb").instantiate()
		tree.name = "RoadsideGroveBirch" if broadleaf else "RoadsideGroveFir"
		tree.set_meta("roadside_grove", true)
		tree.position = Vector3(spec.x, 0.02, spec.z)
		# Broad lower crowns and occasional emergent firs replace the
		# equal-width vertical columns behind the workshop roof.
		tree.scale = (Vector3(1.36, 1.0, 1.12) if broadleaf else Vector3(1.08, 1.0, 0.96)) * spec.y
		tree.rotation.y = grove_random.randf() * TAU
		world.add_child(tree)
		if not broadleaf:
			configure_fir_lod(world, tree)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.14 * spec.y * (1.36 if broadleaf else 1.08)
		cylinder.height = 5.0 * spec.y
		shape.shape = cylinder
		body.position = tree.position + Vector3(0, cylinder.height * 0.5, 0)
		body.add_child(shape)
		world.add_child(body)
		# Broken colonies leave visible soil between stems instead of identical
		# circular skirts. Lower regrowth frames the open service awning.
		for i in range(34):
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 3 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			var angle := grove_random.randf() * TAU
			var radius := sqrt(grove_random.randf()) * 2.05
			plant.position = tree.position + Vector3(cos(angle) * radius * 0.66, 0, sin(angle) * radius)
			plant.position.y = verge_height(Vector2(plant.position.x, plant.position.z)) + 0.02
			plant.rotation.y = angle
			plant.scale = Vector3(0.38, 0.42, 0.38) * grove_random.randf_range(0.7, 1.3) if i % 3 == 0 else Vector3(0.9, 0.55, 0.9) * grove_random.randf_range(0.7, 1.3)
			world.add_child(plant)
	for colony in [Vector3(9.6, 0, 25.7), Vector3(10.8, 0, 22.8),
			Vector3(9.2, 0, 18.7)]:
		for i in range(18):
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb").instantiate()
			var angle := grove_random.randf() * TAU
			var radius := sqrt(grove_random.randf()) * 0.95
			plant.position = colony + Vector3(cos(angle) * radius * 0.7, 0, sin(angle) * radius)
			plant.position.y = verge_height(Vector2(plant.position.x, plant.position.z)) + 0.02
			var size := grove_random.randf_range(0.55, 0.95)
			plant.scale = Vector3(size, size * (1.3 - radius * 0.45), size)
			plant.rotation.y = angle
			plant.name = "ServiceGroveRegrowth"
			world.add_child(plant)
	for rock_at in [Vector3(10.4, 0.02, 25.0), Vector3(10.9, -0.04, 24.2), Vector3(12.0, 0.01, 14.0)]:
		var rock: Node3D = vegetation_scene("res://assets/realism/boulder.glb").instantiate()
		rock.position = rock_at
		rock.scale = Vector3(0.8, 0.76 if rock_at.z > 24.5 else 0.59, 0.7)
		rock.rotation.y = grove_random.randf() * TAU
		world.add_child(rock)
		for child in rock.find_children("*", "MeshInstance3D", true, false):
			child.create_trimesh_collision()

static func repair_shelter_roof_vents(world) -> void:
	# A continuous ventilated monitor breaks the barrel silhouette at walking
	# distance. The original curved roof remains the collision boundary.
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://shaders/shelter_structural_steel.gdshader")
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("202c29")
	dark.roughness = 0.94
	var throat = world.block(Vector3(15.5, 5.70, 29.3), Vector3(1.90, 1.08, 4.7), "202c29", false)
	throat.name = "ContinuousRidgeMonitor"
	throat.material_override = dark
	for side in [-1.0, 1.0]:
		var flashing = world.block(Vector3(15.5 + side * 1.02, 5.03, 29.3), Vector3(0.48, 0.045, 5.12), "53645d", false)
		flashing.rotation.z = -side * 0.18
		flashing.material_override = finish
		for blade in range(8):
			var louvre = world.block(Vector3(15.5 + side * 1.02, 5.23 + blade * 0.135, 29.3), Vector3(0.22, 0.035, 4.78), "53645d", false)
			louvre.rotation.z = side * 0.48
			louvre.material_override = finish
		var cap = world.block(Vector3(15.5 + side * 0.57, 6.40, 29.3), Vector3(1.20, 0.055, 5.24), "53645d", false)
		cap.rotation.z = -side * 0.22
		cap.material_override = finish
		for z in [26.90, 28.50, 30.10, 31.70]:
			var stile = world.block(Vector3(15.5 + side * 1.05, 5.72, z), Vector3(0.065, 1.15, 0.065), "53645d", false)
			stile.material_override = finish
	for end in [-1.0, 1.0]:
		for blade in range(8):
			var louvre = world.block(Vector3(15.5, 5.23 + blade * 0.135, 29.3 + end * 2.41), Vector3(2.05, 0.035, 0.22), "53645d", false)
			louvre.rotation.x = -end * 0.48
			louvre.material_override = finish


static func repair_apron_drainage(world) -> void:
	# Shallow rubble-filled soakaways at the apron edges. Their broken outline
	# transitions concrete into soil rather than another rectangular grass bed.
	var random := RandomNumberGenerator.new()
	random.seed = 226071
	var source := SphereMesh.new()
	source.radial_segments = 7
	source.rings = 3
	source.radius = 0.5
	source.height = 1.0
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		var v := vertices[i]
		# Position-based deformation keeps duplicated UV seam vertices joined.
		var variation := 1.0 + 0.22 * sin(v.x * 19.0 + v.z * 13.0) + 0.13 * cos(v.y * 23.0 - v.x * 7.0)
		vertices[i] = v * variation
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if OS.has_feature("android"):
		# SphereMesh emits collapsed pole triangles. Discard them before
		# flat-normal expansion: all visible faces and their attributes remain.
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var visible_indices := PackedInt32Array()
		for face in range(0, source_indices.size(), 3):
			var a := source_indices[face]
			var b := source_indices[face + 1]
			var c := source_indices[face + 2]
			if (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length_squared() > 1e-14:
				visible_indices.append_array(PackedInt32Array([a, b, c]))
		arrays[Mesh.ARRAY_INDEX] = visible_indices
	var rough_mesh := ArrayMesh.new()
	rough_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(rough_mesh, 0)
	surface.deindex()
	surface.set_smooth_group(-1)
	surface.generate_normals()
	var stone_mesh := surface.commit()
	var stone_finish := StandardMaterial3D.new()
	stone_finish.albedo_texture = load("res://assets/realism/terrain_rock_albedo.jpg")
	stone_finish.albedo_color = Color("98968a")
	stone_finish.roughness = 0.96
	stone_finish.vertex_color_use_as_albedo = true
	stone_mesh.surface_set_material(0, stone_finish)
	var stones := MultiMesh.new()
	stones.transform_format = MultiMesh.TRANSFORM_3D
	stones.use_colors = true
	stones.mesh = stone_mesh
	stones.instance_count = 560
	for i in range(stones.instance_count):
		var side := -1.0 if i < 280 else 1.0
		var z := random.randf_range(33.5, 42.5)
		var edge := 15.5 + side * (4.0 + maxf(z - 37.0, 0.0) * 0.12)
		var x := edge + random.randf_range(-0.38, 0.38)
		var size := random.randf_range(0.025, 0.095)
		var basis := Basis.from_euler(Vector3(random.randf(), random.randf() * TAU, random.randf()))
		basis = basis.scaled(Vector3(size, size * 0.38, size * random.randf_range(0.65, 1.4)))
		stones.set_instance_transform(i, Transform3D(basis, Vector3(x, verge_height(Vector2(x, z)) + 0.009, z)))
		var tint := random.randf_range(0.65, 1.1)
		stones.set_instance_color(i, Color(tint, tint, tint * 0.94))
	var rubble := MultiMeshInstance3D.new()
	rubble.name = "RepairApronDrainageRubble"
	rubble.multimesh = stones
	world.add_child(rubble)
	# Embedded access gravel catches sun at walking height. Clustered shoulders
	# and a sparse wheel bed avoid an evenly sprinkled decorative stone carpet.
	var access_stones := MultiMesh.new()
	access_stones.transform_format = MultiMesh.TRANSFORM_3D
	access_stones.use_colors = true
	access_stones.mesh = stone_mesh
	access_stones.instance_count = 1400
	for i in range(access_stones.instance_count):
		var branch := i % 3
		var start := Vector2(15.5, 36.8) if branch == 0 else Vector2(15.5, 44)
		var end := Vector2(15.5, 44) if branch == 0 else (Vector2(8.2, 49.2) if branch == 1 else Vector2(27, 47))
		var axis := (end - start).normalized()
		# Most aggregate collects in irregular shoulder pockets; only a small
		# remainder is loose across the travelled surface.
		var pocket_index := (i / 3) % 9
		var along := clampf(random.randf() + 0.10 * sin(float(pocket_index) * 4.7), 0.0, 1.0)
		var shoulder := -1.0 if pocket_index % 2 == 0 else 1.0
		var lateral := shoulder * (2.0 + sin(float(pocket_index) * 2.3) * 0.55) + random.randfn(0.0, 0.25)
		if i % 5 == 0:
			along = random.randf()
			lateral = random.randf_range(-2.8, 2.8)
		var point := start.lerp(end, along) + Vector2(-axis.y, axis.x) * lateral
		# Poured access is swept clear; loose aggregate collects at its edge.
		if branch < 2:
			lateral = shoulder * (3.15 + 0.30 * sin(along * 23.0 + float(branch)) + random.randf_range(0.0, 0.85))
			axis = (service_access_point(minf(along + 0.002, 1.0)) - service_access_point(maxf(along - 0.002, 0.0))).normalized()
			point = service_access_point(along) + Vector2(-axis.y, axis.x) * lateral
		var pocket := 0.5 + 0.5 * sin(point.x * 2.7 + sin(point.y * 1.8) * 2.0)
		var wheel_bed := absf(absf(lateral) - 1.05) < 0.32
		var size := random.randf_range(0.018, 0.060) * lerpf(0.35, 1.0, pocket)
		if branch < 2:
			size *= smoothstep(6.0, 8.4, point.x)
		if wheel_bed:
			size *= 0.45
		var basis := Basis(Vector3.UP, random.randf() * TAU)
		basis = basis.scaled(Vector3(size, size * 0.62, size * random.randf_range(0.75, 1.2)))
		access_stones.set_instance_transform(i, Transform3D(basis,
			# The service surface is at y=.044, above the soil origin.
			# Keep the aggregate partly embedded but its upper facets exposed.
			Vector3(point.x, maxf(0.044, verge_height(point)) - size * 0.16, point.y)))
		var tint := random.randf_range(0.55, 0.95)
		access_stones.set_instance_color(i, Color(tint, tint * 0.97, tint * 0.89))
	var access_gravel := MultiMeshInstance3D.new()
	access_gravel.name = "RepairAccessEmbeddedGravel"
	access_gravel.multimesh = access_stones
	# Centimetre aggregate uses mineral colour, avoiding three multiplied dark
	# albedos and oversized scanned texture features on tiny stones.
	var access_finish := StandardMaterial3D.new()
	access_finish.albedo_color = Color("535347")
	access_finish.vertex_color_use_as_albedo = true
	access_finish.roughness = 0.97
	access_gravel.material_override = access_finish
	world.add_child(access_gravel)
	# Low irregular grass colonies follow the gravel drainage shoulders. Their
	# gaps expose stone and preserve the central walking/vehicle approach.
	for i in range(160):
		var side := -1.0 if i < 80 else 1.0
		var pocket := (i % 80) / 16
		var z := 34.9 + float(pocket) * 1.65 + random.randf_range(-0.55, 0.55)
		var x := 15.5 + side * (4.0 + maxf(z - 37.0, 0.0) * 0.12) + random.randf_range(-0.32, 0.32)
		var plant: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
		plant.name = "RepairDrainageGrassColony"
		plant.position = Vector3(x, verge_height(Vector2(x, z)), z)
		plant.rotation.y = random.randf() * TAU
		var spread := random.randf_range(0.28, 0.52)
		plant.scale = Vector3(spread, random.randf_range(0.20, 0.46), spread)
		world.add_child(plant)

static func western_verge_grove(world) -> void:
	# Visible across the road from the normal wide camera. Keep the x=-12
	# walking verge and the pipe yard (z>31) open, with irregular tree spacing.
	var random := RandomNumberGenerator.new()
	random.seed = 144
	for spec in [Vector3(-15.2, 0.78, 26.8), Vector3(-20.8, 1.36, 21.4),
			Vector3(-16.0, 0.46, 19.0), Vector3(-23.0, 1.05, 28.0),
			Vector3(-21.8, 0.33, 17.5), Vector3(-25.7, 1.48, 16.2),
			Vector3(-28.6, 1.23, 21.3), Vector3(-27.2, 0.41, 13.4),
			Vector3(-18.8, 0.62, 15.6)]:
		var broadleaf: bool = is_equal_approx(spec.x, -15.2) or is_equal_approx(spec.x, -23.0) or is_equal_approx(spec.x, -25.7) or is_equal_approx(spec.x, -18.8) or is_equal_approx(spec.x, -28.6)
		var fir: Node3D = vegetation_scene("res://assets/realism/verge_birch.glb" if broadleaf else "res://assets/realism/fir_full.glb").instantiate()
		fir.name = "WesternVergeBirch" if broadleaf else "WesternVergeFir"
		fir.position = Vector3(spec.x, 0.02, spec.z)
		# Upright firs rise between spreading birches; avoid a row of equally
		# swollen crowns. Trunk collision uses the same horizontal scaling.
		var crown_width := random.randf_range(1.10, 1.42) if broadleaf else random.randf_range(0.92, 1.12)
		fir.scale = Vector3(crown_width, 1.0, crown_width * random.randf_range(0.72, 1.05)) * spec.y
		fir.rotation.y = random.randf() * TAU
		world.add_child(fir)
		if not broadleaf:
			configure_fir_lod(world, fir)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.14 * spec.y * crown_width
		cylinder.height = 5.0 * spec.y
		shape.shape = cylinder
		body.position = fir.position + Vector3(0, cylinder.height * 0.5, 0)
		body.add_child(shape)
		world.add_child(body)
		world.ground_obstacles.append(Rect2(spec.x - cylinder.radius, spec.z - cylinder.radius,
			cylinder.radius * 2.0, cylinder.radius * 2.0))
	# Uneven islands of undergrowth connect trunks to the ground; their gaps
	# preserve sight through the grove instead of making a uniform hedge.
	for i in range(370):
		var x := random.randf_range(-29.5, -13.4)
		var z := random.randf_range(12.5, 29.5)
		if sin(x * 0.8 + z * 0.5) < -0.35: continue
		var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 3 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
		plant.position = Vector3(x, 0.02, z)
		plant.rotation.y = random.randf() * TAU
		plant.scale = Vector3.ONE * random.randf_range(0.9, 2.0)
		world.add_child(plant)

	var shrub_random := RandomNumberGenerator.new()
	shrub_random.seed = 237091
	for at in [Vector3(-14.5, 0.02, 27.8), Vector3(-16.3, 0.02, 25.6), Vector3(-22.1, 0.02, 27.9),
			Vector3(-24.0, 0.02, 25.2), Vector3(-18.4, 0.02, 19.8), Vector3(-26.8, 0.02, 17.5),
			Vector3(-15.6, 0.02, 29.1), Vector3(-20.3, 0.02, 28.5),
			Vector3(-24.8, 0.02, 29.0), Vector3(-28.1, 0.02, 24.8)]:
		var shrub: Node3D = vegetation_scene("res://assets/realism/verge_shrub.glb").instantiate()
		shrub.name = "WesternGroveUnderstory"
		shrub.position = at
		shrub.rotation.y = shrub_random.randf() * TAU
		shrub.scale = Vector3(1.65, 1.35, 1.3) * shrub_random.randf_range(0.75, 1.3)
		world.add_child(shrub)

static func depot_loading_area(world, at: Vector3) -> void:
	# Folded steel guards sit outside the existing four-metre clear opening.
	# Their masonry footings and return flanges give the entrance real depth.
	var guard_paint := StandardMaterial3D.new()
	guard_paint.albedo_color = Color("b39343")
	guard_paint.roughness = 0.48
	guard_paint.metallic = 0.35
	var stripe_paint := StandardMaterial3D.new()
	stripe_paint.albedo_color = Color("29322e")
	stripe_paint.roughness = 0.62
	for side in [-1.0, 1.0]:
		var guard_at: Vector3 = at + Vector3(side * 2.38, 0, 7.02)
		world.block(guard_at + Vector3(0, 0.12, 0), Vector3(0.54, 0.24, 0.52), "73756c", true)
		var guard = world.block(guard_at + Vector3(0, 0.77, 0.08), Vector3(0.38, 1.3, 0.09), "9c8553", true)
		guard.material_override = guard_paint
		var flange = world.block(guard_at + Vector3(side * 0.17, 0.77, -0.09), Vector3(0.055, 1.3, 0.34), "59635f", false)
		flange.material_override = guard_paint
		for height in [0.34, 0.86, 1.32]:
			var stripe = world.block(guard_at + Vector3(0, height, 0.132), Vector3(0.31, 0.11, 0.012), "303835", false)
			stripe.material_override = stripe_paint
	# Sheltered colonies accumulate around the outer canopy feet, leaving
	# the loading surface, entrance ramp and service route clear.
	var planting := RandomNumberGenerator.new()
	planting.seed = 200034
	for center in [Vector3(-13.65, 0, -4.7), Vector3(-13.8, 0, 1.4), Vector3(-12.7, 0, 6.2)]:
		for index in range(18):
			var grass: Node3D = load("res://assets/realism/grass_broadleaf.glb" if index % 5 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			var angle := planting.randf() * TAU
			var radius := sqrt(planting.randf())
			grass.position = at + center + Vector3(cos(angle) * radius * 0.65, 0, sin(angle) * radius * 1.05)
			grass.rotation.y = planting.randf() * TAU
			var plant_size := planting.randf_range(0.75, 1.35)
			grass.scale = Vector3(0.40, 0.48, 0.40) * plant_size if index % 5 == 0 else Vector3(0.64, 0.68, 0.64) * plant_size
			world.add_child(grass)
	# Side loading shelter leaves both central doorways and their aprons clear.
	# Solid members share their visible transform with bullet/actor collision.
	var apron = world.block(at + Vector3(-10.5, 0.015, 0), Vector3(5.4, 0.03, 11), "a5a69a", false)
	var apron_finish := ShaderMaterial.new()
	apron_finish.shader = preload("res://shaders/warehouse_concrete.gdshader")
	apron_finish.set_shader_parameter("building_origin", at + Vector3(-10.5, 0, 0))
	apron_finish.set_shader_parameter("slab_joints", true)
	apron_finish.set_shader_parameter("depot_apron", true)
	apron.material_override = apron_finish
	var loading_bounds: Array = world.get_meta("depot_loading_bounds", [])
	loading_bounds.append(Rect2(at.x - 13.3, at.z - 5.6, 5.6, 11.2))
	world.set_meta("depot_loading_bounds", loading_bounds)
	var shoulder := MeshInstance3D.new()
	shoulder.name = "DepotGravelShoulder"
	var shoulder_mesh := PlaneMesh.new()
	shoulder_mesh.size = Vector2(7.6, 13.2)
	shoulder.mesh = shoulder_mesh
	shoulder.position = at + Vector3(-10.5, 0.037, 0)
	var gravel := ShaderMaterial.new()
	gravel.shader = load("res://shaders/yard_gravel.gdshader")
	gravel.set_shader_parameter("gravel", load("res://assets/realism/terrain_rock_albedo.jpg"))
	gravel.set_shader_parameter("soil", load("res://assets/realism/ground_albedo.jpg"))
	shoulder.material_override = gravel
	shoulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(shoulder)
	# Painted, rough steel stays readable in skylight under the canopy.
	var steel := StandardMaterial3D.new()
	# Opaque paint is dielectric, even on steel. Rock albedo produced large
	# mineral blotches on these narrow members at ordinary eye distance.
	steel.albedo_color = Color("596965")
	steel.roughness = 0.52
	steel.metallic = 0.0
	# Folded sheet louvers have a thin edge and a recessed centre support,
	# replacing deep rectangular planks at the road-facing loading shelter.
	var louver_finish := ShaderMaterial.new()
	louver_finish.shader = load("res://shaders/depot_louver.gdshader")
	for row in range(9):
		for bay in range(2):
			# Unequal top openings admit daylight and break the fence-like silhouette.
			# The middle sheets and structural mullions still block the loading edge.
			if row >= (6 if bay == 0 else 8):
				continue
			var center := at + Vector3(-13.0, 0.55 + row * 0.265, -3.81 + bay * 2.52)
			var slat = world.block(center, Vector3(0.018, 0.23, 2.46), "798781", true)
			slat.name = "DepotWindbreakSlat"
			slat.rotation_degrees.z = -18
			slat.material_override = louver_finish
			# Folded returns stiffen each sheet without thickening its broad face.
			for edge in [-1.0, 1.0]:
				var offset := Basis(Vector3.FORWARD, deg_to_rad(18.0)) * Vector3(0.014, edge * 0.108, 0)
				var lip = world.block(center + offset, Vector3(0.038, 0.014, 2.46), "798781", false)
				lip.rotation_degrees.z = -18
				lip.material_override = louver_finish
	for rail_z in [-5.04, -2.55, -0.06]:
		var rail = world.block(at + Vector3(-12.93, 1.58, rail_z), Vector3(0.065, 2.65, 0.055), "596965", true)
		rail.material_override = steel
		var foot = world.block(at + Vector3(-12.93, 0.12, rail_z), Vector3(0.25, 0.24, 0.24), "797d72", true)
		foot.name = "DepotLouverFooting"
	# Low irregular weeds connect the base to the existing gravel shoulder.
	var louver_plants := RandomNumberGenerator.new()
	louver_plants.seed = 341021
	for index in range(64):
		var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if index % 4 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
		plant.position = at + Vector3(louver_plants.randf_range(-13.65, -13.22), 0.02, louver_plants.randf_range(-5.2, -0.1))
		plant.rotation.y = louver_plants.randf() * TAU
		plant.scale = Vector3.ONE * louver_plants.randf_range(0.32, 0.68)
		world.add_child(plant)
	# Unequal shrub groups break the long straight edge outside the traffic apron.
	for shrub_data in [Vector4(-14.0, -4.0, 0.62, 0.3), Vector4(-14.25, -2.8, 0.43, 1.8), Vector4(-13.8, 1.9, 0.54, 2.6)]:
		var shrub: Node3D = vegetation_scene("res://assets/realism/verge_fine_shrub.glb").instantiate()
		shrub.position = at + Vector3(shrub_data.x, 0, shrub_data.y)
		shrub.scale = Vector3.ONE * shrub_data.z
		shrub.rotation.y = shrub_data.w
		world.add_child(shrub)
	var bounds: Array = world.get_meta("hardscape_bounds", [])
	bounds.append(Rect2(at.x - 13.2, at.z - 5.5, 5.4, 11))
	world.set_meta("hardscape_bounds", bounds)
	var roof_finish := ShaderMaterial.new()
	roof_finish.shader = preload("res://shaders/depot_roof.gdshader")
	# Thin sheet bays and two daylight strips replace the monolithic lid.
	# The strips admit direct sunlight onto the loading apron.
	for bay in [Vector2(-5.5, -3.4), Vector2(-2.6, 1.0), Vector2(1.8, 5.5)]:
		var sheet = world.block(at + Vector3(-10.5, 3.25, (bay.x + bay.y) * 0.5), Vector3(5.6, 0.035, bay.y - bay.x), "465a61")
		sheet.material_override = roof_finish
	var glazing := StandardMaterial3D.new()
	glazing.albedo_color = Color(0.67, 0.79, 0.79, 0.28)
	glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glazing.roughness = 0.36
	for strip_z in [-3.0, 1.4]:
		var skylight = world.block(at + Vector3(-10.5, 3.25, strip_z), Vector3(5.56, 0.018, 0.8), "a6c1c0", false)
		skylight.name = "DepotDaylightStrip"
		skylight.material_override = glazing
		skylight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for edge_z in [-0.4, 0.4]:
			var flashing = world.block(at + Vector3(-10.5, 3.28, strip_z + edge_z), Vector3(5.6, 0.045, 0.055), "72817d", false)
			flashing.material_override = steel
	# Folded perimeter fascia and longitudinal purlins give the canopy a
	# constructed edge and layered underside at ordinary player eye height.
	for edge_x in [-13.26, -7.74]:
		var fascia = world.block(at + Vector3(edge_x, 3.22, 0), Vector3(0.035, 0.12, 11.1), "465a61")
		fascia.material_override = steel
		world.block(at + Vector3(edge_x, 3.16, 0), Vector3(0.085, 0.018, 11.1), "89958e", false)
	# Open folded gutters cap the exposed ends; their lip and underside cast
	# a legible shadow without closing the daylight strips or walking bays.
	for end_z in [-5.58, 5.58]:
		for fold in [Vector4(0, 3.10, 0.22, 0.025), Vector4(0.10, 3.18, 0.025, 0.18), Vector4(-0.10, 3.15, 0.025, 0.12)]:
			var gutter = world.block(at + Vector3(-10.5, fold.y, end_z + fold.x), Vector3(5.74, fold.w, fold.z), "596c6c", false)
			gutter.name = "DepotFoldedGutter"
			gutter.material_override = steel
		# Downpipe follows the outer column; the open center stays accessible.
		var pipe = world.block(at + Vector3(-13.12, 1.53, end_z), Vector3(0.10, 3.06, 0.10), "596c6c", false)
		pipe.name = "DepotRainwaterDownpipe"
		pipe.material_override = steel
		for clamp_y in [0.55, 2.35]:
			world.block(at + Vector3(-13.12, clamp_y, end_z), Vector3(0.15, 0.035, 0.14), "303835", false)
	for purlin_x in [-12.0, -10.5, -9.0]:
		var purlin = world.block(at + Vector3(purlin_x, 3.15, 0), Vector3(0.085, 0.15, 10.9), "465a61", false)
		purlin.material_override = steel
	var diffuser := StandardMaterial3D.new()
	diffuser.albedo_color = Color("eee2c9")
	diffuser.emission_enabled = true
	diffuser.emission = Color("ffe2ae")
	diffuser.emission_energy_multiplier = 0.55
	for fixture_z in [-2.55, 2.55]:
		world.block(at + Vector3(-10.5, 2.98, fixture_z), Vector3(1.3, 0.12, 0.28), "303835", false)
		var lens = world.block(at + Vector3(-10.5, 2.91, fixture_z), Vector3(1.16, 0.025, 0.20), "eee2c9", false)
		lens.material_override = diffuser
		var lamp := SpotLight3D.new()
		lamp.rotation_degrees.x = -90
		lamp.name = "DepotCanopyWorkLight"
		lamp.position = at + Vector3(-10.5, 2.78, fixture_z)
		lamp.light_color = Color("ffe2b6")
		lamp.light_energy = 2.0
		lamp.spot_range = 4.8
		lamp.spot_angle = 65.0
		lamp.spot_attenuation = 1.4
		lamp.shadow_enabled = true
		world.add_child(lamp)
	for z in [-5.1, 0.0, 5.1]:
		var post = world.block(at + Vector3(-13, 1.6, z), Vector3(0.14, 3.2, 0.14), "303835")
		post.material_override = steel
		var beam = world.block(at + Vector3(-10.5, 3.06, z), Vector3(5.2, 0.22, 0.12), "303835")
		beam.material_override = steel
		for flange_y in [2.95, 3.17]:
			var flange = world.block(at + Vector3(-10.5, flange_y, z), Vector3(5.2, 0.018, 0.14), "303835", false)
			flange.material_override = steel
		var plate = world.block(at + Vector3(-13, 2.99, z + 0.09), Vector3(0.32, 0.34, 0.035), "434b49", false)
		plate.name = "DepotBeamConnection"
		for bolt_x in [-13.10, -12.90]:
			for bolt_y in [2.89, 3.09]:
				world.block(at + Vector3(bolt_x, bolt_y, z + 0.12), Vector3(0.035, 0.035, 0.022), "a2a69b", false)
		var foot = world.block(at + Vector3(-13, 0.055, z), Vector3(0.32, 0.11, 0.32), "62635c", false)
		foot.name = "DepotPostBase"
		for x in [-12.75, -8.25]:
			var brace = world.block(at + Vector3(x, 2.78, z), Vector3(0.09, 0.8, 0.09), "303835")
			brace.rotation.z = -0.65 if x < -10 else 0.65
			brace.material_override = steel
	for z in [-3.7, -1.5]:
		var proxy = world.block(at + Vector3(-9.7, 0.75, z), Vector3(2.5, 1.5, 2), "657477")
		proxy.visible = false

		supply_crate(world, at + Vector3(-9.7, 0, z))
	# Storage boundary north of the loading apron; a five-metre opening aligns
	# with the existing walk/vehicle lane at x=23.5. No random crate scatter.
	var wire := StandardMaterial3D.new()
	wire.albedo_texture = load("res://assets/realism/depot_wire.png")
	wire.albedo_color = Color("45534a")
	# Stable sample coverage avoids stochastic dots in the rear doorway.
	# MSAA keeps the filtered wire edges softer than hard clipping alone.
	wire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	wire.alpha_scissor_threshold = 0.5
	wire.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	wire.alpha_antialiasing_edge = 0.3
	wire.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	wire.cull_mode = BaseMaterial3D.CULL_DISABLED
	wire.roughness = 0.85
	for interval in [Vector2(10, 21), Vector2(26, 29)]:
		var length: float = interval.y - interval.x
		var mesh := MeshInstance3D.new()
		var panel := QuadMesh.new()
		panel.size = Vector2(length, 1.8)
		mesh.mesh = panel
		mesh.position = Vector3((interval.x + interval.y) * 0.5, 1.1, 22)
		var finish: StandardMaterial3D = wire.duplicate()
		finish.uv1_scale = Vector3(length / 0.8, 2.25, 1)
		mesh.material_override = finish
		world.add_child(mesh)
		# Fence collider matches the visible permeable boundary; opening stays free.
		var proxy = world.block(mesh.position, Vector3(length, 1.8, 0.035), "434b49")
		proxy.visible = false
		for level in [0.2, 2.0]:
			world.block(Vector3(mesh.position.x, level, 22), Vector3(length, 0.035, 0.035), "626e68", false)
		var bays := ceili(length / 2.8)
		for bay in range(bays + 1):
			var x := lerpf(interval.x, interval.y, float(bay) / bays)
			world.block(Vector3(x, 1.05, 22), Vector3(0.075, 2.1, 0.075), "596965")
			world.block(Vector3(x, 0.12, 22), Vector3(0.28, 0.24, 0.28), "82877d")
	var signboard = world.block(at + Vector3(-4.9, 3.2, 6.84), Vector3(5.1, 0.72, 0.06), "303835", false)
	signboard.name = "DepotSign"
	var lettering := Label3D.new()
	lettering.text = "04  /  FIELD WORKSHOP"
	lettering.font_size = 64
	lettering.pixel_size = 0.0018
	lettering.modulate = Color("dbd6bc")
	lettering.outline_size = 0
	lettering.position = at + Vector3(-4.9, 3.2, 6.89)
	world.add_child(lettering)

	# Seams and drainage sit on existing structural surfaces, outside travel.
	for seam in range(19):
		var rib = world.block(at + Vector3(-13.1 + seam * 0.29, 3.325, 0), Vector3(0.025, 0.035, 10.9), "596965", false)
		rib.material_override = steel
	for edge_z in [-5.55, 5.55]:
		var gutter = world.block(at + Vector3(-10.5, 3.18, edge_z), Vector3(5.7, 0.17, 0.14), "596965", false)
		gutter.material_override = steel
		# Connected gutter offset, downpipe and outward discharge above the soakaway.
		var pipe_z: float = edge_z - signf(edge_z) * 0.4
		var joints: Array[Vector3] = [Vector3(-13.08, 3.18, edge_z), Vector3(-13.08, 2.91, pipe_z), Vector3(-13.08, 0.36, pipe_z), Vector3(-13.55, 0.12, pipe_z)]
		for joint in range(joints.size() - 1):
			var pipe := MeshInstance3D.new()
			var tube := CylinderMesh.new()
			tube.top_radius = 0.055
			tube.bottom_radius = 0.055
			tube.height = joints[joint].distance_to(joints[joint + 1])
			tube.radial_segments = 12
			# Straight sides need no axial subdivisions; preserve radial detail.
			if OS.has_feature("android"):
				tube.rings = 0
			pipe.mesh = tube
			pipe.material_override = steel
			pipe.position = at + (joints[joint] + joints[joint + 1]) * 0.5
			pipe.quaternion = Quaternion(Vector3.UP, (joints[joint + 1] - joints[joint]).normalized())
			world.add_child(pipe)
	# Shallow aggregate outside the posts; no raised kerb across the walking lane.
	var drain_stone := StandardMaterial3D.new()
	drain_stone.albedo_color = Color("85867b")
	drain_stone.albedo_texture = load("res://assets/realism/terrain_rock_albedo.jpg")
	drain_stone.roughness = 0.94
	var stones := MultiMesh.new()
	stones.transform_format = MultiMesh.TRANSFORM_3D
	var pebble := SphereMesh.new()
	pebble.radius = 1.0
	pebble.height = 2.0
	pebble.radial_segments = 6
	pebble.rings = 3
	pebble.material = drain_stone
	stones.mesh = pebble
	stones.instance_count = 280
	for index in range(280):
		var z := planting.randf_range(-5.8, 5.8)
		var x := -13.57 + planting.randf_range(-0.3, 0.3) + sin(z * 2.1) * 0.05
		var size := planting.randf_range(0.045, 0.10)
		stones.set_instance_transform(index, Transform3D(Basis.from_euler(Vector3(0, planting.randf() * TAU, 0)).scaled(Vector3(size, size * 0.4, size * 0.8)), at + Vector3(x, 0.045, z)))
	var drain := MultiMeshInstance3D.new()
	drain.name = "CanopyDrainAggregate"
	drain.multimesh = stones
	world.add_child(drain)
	for index in range(28):
		var grass: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
		grass.position = at + Vector3(-14.0 + planting.randf_range(-0.12, 0.12), 0, planting.randf_range(-5.9, 5.9))
		grass.rotation.y = planting.randf() * TAU
		grass.scale = Vector3.ONE * planting.randf_range(0.38, 0.72)
		world.add_child(grass)
	var fascia = world.block(at + Vector3(-10.5, 3.0, 5.62), Vector3(5.5, 0.34, 0.07), "354c50", false)
	var fascia_paint := steel.duplicate() as StandardMaterial3D
	fascia_paint.albedo_color = Color("354c50")
	fascia.material_override = fascia_paint
	var loading := Label3D.new()
	loading.text = "LOADING  /  04"
	loading.font_size = 96
	loading.pixel_size = 0.0024
	loading.modulate = Color("ddd7bd")
	loading.position = at + Vector3(-10.5, 3.0, 5.67)
	world.add_child(loading)

# Shared by the ground map and root placement: irregular mineral lobes follow
# the excavated road, with a separate service mouth rather than rectangular strips.
static func road_recovery_distance(point: Vector2) -> float:
	var distance := INF
	for east_west in [false, true]:
		var along := point.x if east_west else point.y
		var across := point.y if east_west else point.x
		var phase := signf(across) * 2.3 + (1.7 if east_west else 0.0)
		# Aggregate ends at the upper cut bank, exposing the drainage section
		# instead of painting another broad parallel apron.
		var width := 4.95 + sin(along * 0.117 + phase) * 0.55
		width += sin(along * 0.31 - phase) * 0.25
		distance = minf(distance, maxf(absf(across) - width, absf(along) - 112.5))
	var mouth := point.distance_to(Geometry2D.get_closest_point_to_segment(
		point, Vector2(5, 49.2), Vector2(12, 47.7))) - 2.8
	return minf(distance, mouth)

static func colony_field(point: Vector2, density: FastNoiseLite, edges: FastNoiseLite) -> Vector3:
	var shelter_lane := minf(
		point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(15.5, 36), Vector2(16, 46))),
		point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(16, 46), Vector2(9, 52))))
	# Metre-scale interruptions break up the edges of broad colonies.
	var patch := density.get_noise_2d(point.x, point.y)
	var coverage := smoothstep(-0.38, 0.12, patch + edges.get_noise_2d(point.x, point.y) * 0.25)
	# No forced high-density roadside band: mineral pockets and meadow islands
	# share the same field as roots, instead of painting an empty green ribbon.
	var road_edge := road_recovery_distance(point)
	var shelter_verge := 1.0 - smoothstep(2.1, 4.5, shelter_lane + edges.get_noise_2dv(point) * 0.9)
	coverage = maxf(coverage, shelter_verge * 0.96)
	# Recovery apron around the southern approach: a connected low sward,
	# interrupted by the existing footpath and hardscape exclusions below.
	var approach_recovery := 1.0 - smoothstep(10.0, 24.0, (point - Vector2(19, 45)).length())
	coverage = maxf(coverage, approach_recovery * lerpf(0.72, 0.98, smoothstep(-0.3, 0.3, patch)))
	# An irregular unmanaged verge follows the depot yard, thinning into
	# low worn ground. Noise warps its edge instead of a rectangular hedge.
	var yard_offset := (point - Vector2(35, 34)).abs() - Vector2(11.5, 12.5)
	var yard_distance := Vector2(maxf(yard_offset.x, 0), maxf(yard_offset.y, 0)).length()
	var verge := (1.0 - smoothstep(1.2, 5.5, yard_distance + edges.get_noise_2d(point.x, point.y) * 2.5))
	coverage = maxf(coverage, verge * 0.95)
	# Continue the rough grass along warehouse side boundaries, including
	# the western plots visible across the main road.
	for building_x in [-72.0, -42.0, 35.0, 68.0]:
		var side_distance := absf(absf(point.x - building_x) - 14.0)
		if side_distance > 3.0: continue
		for building_z in [-70.0, -35.0, 34.0, 70.0]:
			var end_distance := absf(point.y - building_z)
			var wall_verge := (1.0 - smoothstep(0.8, 3.0, side_distance + edges.get_noise_2dv(point)))
			wall_verge *= 1.0 - smoothstep(11.0, 15.0, end_distance)
			coverage = maxf(coverage, wall_verge * 0.98)
	var bay_edge := 1.0 - smoothstep(0.7, 2.8, absf(point.x + 22.7) + edges.get_noise_2dv(point))
	bay_edge *= 1.0 - smoothstep(6.5, 10.0, absf(point.y - 34.0))
	coverage = maxf(coverage, bay_edge * 0.92)
	# Irregular recovery islands connect the middle-distance station to its verge.
	var station_distance := (point - Vector2(-28, -25)).length()
	var station_patch := 1.0 - smoothstep(3.0, 10.0, station_distance + edges.get_noise_2dv(point) * 3.0)
	coverage = maxf(coverage, station_patch * 0.95)
	# Connected but irregular road-bank colonies fill the bare middle ground.
	# Keep the asphalt and the building collision exclusion bands clear.
	var bank := smoothstep(0.4, 3.0, road_edge) * smoothstep(-0.08, 0.28, patch)
	# Mature meadow colonies follow the raised ground. A meandering worn
	# strip stays low through the western bank, retaining a readable route.
	var raised := smoothstep(0.015, 0.32, verge_height(point))
	var track := absf(point.x + 26.0 + sin(point.y * 0.35) * 0.9)
	var meadow := raised * smoothstep(0.65, 1.8, track)
	# Broad, feathered meadow islands beyond the shelter's worn approach.
	# The same field colors the soil and places plants, avoiding green decals.
	var shelter_meadow := 1.0 - smoothstep(7.0, 17.0,
		(point - Vector2(24, 57)).length() + edges.get_noise_2dv(point) * 3.0)
	shelter_meadow *= smoothstep(1.2, 4.0, road_edge)
	meadow = maxf(meadow, shelter_meadow * 0.72)
	# Recover the unused southern yard with a connected sward; the worn
	# shelter access remains excluded when placing roots and shading soil.
	var southern_sward := 1.0 - smoothstep(10.0, 21.0,
		(point - Vector2(21, 48)).length() + edges.get_noise_2dv(point) * 4.2)
	southern_sward *= smoothstep(2.0, 3.8, shelter_lane)
	meadow = maxf(meadow, southern_sward * 0.88)
	coverage = maxf(coverage, meadow * 0.99)
	var recovery := smoothstep(-0.4, 2.4, road_edge)
	var road_influence := 1.0 - smoothstep(3.0, 11.0, road_edge)
	var islands := smoothstep(-0.20, 0.22, patch + edges.get_noise_2dv(point * 0.45) * 0.55)
	coverage *= recovery * lerpf(1.0, islands, road_influence)
	return Vector3(coverage, bank * recovery, meadow * recovery)

static func ground_detail(world) -> void:
	if OS.has_feature("android") and ResourceLoader.exists("res://assets/android_ground.scn"):
		var cached: Node3D = load("res://assets/android_ground.scn").instantiate()
		# Keep direct children so access clearing and batching see the same nodes.
		# PackedScene ownership is only needed for saving. Clear it before
		# moving the runtime hierarchy out of its temporary scene root.
		for descendant in cached.find_children("*", "", true, false):
			descendant.owner = null
		for child in cached.get_children():
			cached.remove_child(child)
			world.add_child(child)
		cached.free()
		return
	var first_child: int = world.get_child_count()
	world.block(Vector3(0, -0.25, 0), Vector3(650, 0.1, 650), "737b68", false).material_override = meadow_surface()
	var random := RandomNumberGenerator.new()
	random.seed = 55191
	background_forest(world)
	# Scenery beyond the playable ground, so it creates no invisible cover.
	for i in range(30):
		var rock: Node3D = vegetation_scene("res://assets/realism/boulder.glb").instantiate()
		var angle := i * TAU / 30.0
		var radius := random.randf_range(165, 188)
		rock.position = Vector3(cos(angle) * radius, -0.25, sin(angle) * radius)
		rock.rotation.y = random.randf() * TAU
		rock.scale = Vector3.ONE * random.randf_range(5, 12)
		world.add_child(rock)
	var meshes: Array[Mesh] = []
	for asset in ["grass", "grass_fine", "grass_broadleaf"]:
		var template: Node3D = vegetation_scene("res://assets/realism/" + asset + ".glb").instantiate()
		var source: MeshInstance3D = template.find_children("*", "MeshInstance3D", true, false)[0]
		meshes.append(source.mesh)
		template.free()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/grass.gdshader")
	material.set_shader_parameter("fade_begin", 42.0)
	material.set_shader_parameter("fade_end", 80.0)
	var cells := {}
	var density := FastNoiseLite.new()
	density.seed = 673
	density.frequency = 0.055
	var edges := FastNoiseLite.new()
	edges.seed = 1873
	edges.frequency = 0.32
	var hues := FastNoiseLite.new()
	hues.seed = 913
	hues.frequency = 0.085
	var exclusions: Array = world.ground_obstacles.duplicate()
	exclusions.append_array(world.get_meta("hardscape_bounds", []))
	var exclusion_cells := grass_exclusion_cells(exclusions)
	# Low, fine blades form patches instead of isolated tall tufts.
	# Keep the random stream independent of gameplay and all paved areas clear.
	for attempt in range(732000):
		var point := Vector2(random.randf_range(-109, 109), random.randf_range(-109, 109))
		# Additional low undergrowth only in the foreground recovery plot.
		# Concentrate the extra samples away from the rest of the map.
		if attempt >= 680000:
			point = Vector2(random.randf_range(8, 36), random.randf_range(37, 59))
		var road_distance := road_recovery_distance(point)
		# Leave the pavement clear, but vary the first roots along its shoulder.
		if road_distance < 0.22 + (edges.get_noise_2dv(point * 1.7) + 0.5) * 1.15: continue
		# Same centreline as meadow_ground: keep vehicle ruts and the loading
		# approach clear while retaining irregular low growth on the shoulders.
		var lane_distance := minf(
			point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(-10, 50), Vector2(-35, 48))),
			point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(-35, 48), Vector2(-42, 42))))
		if lane_distance < 2.0 + edges.get_noise_2dv(point) * 1.0: continue
		var shelter_lane := minf(
			point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(15.5, 36), Vector2(16, 46))),
			point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(16, 46), Vector2(9, 52))))
		if shelter_lane < 1.9 + edges.get_noise_2dv(point * 0.8) * 1.25: continue
		var colony := colony_field(point, density, edges)
		var coverage := colony.x
		var bank := colony.y
		var meadow := colony.z
		if point.x > 9.0 and point.x < 36.0 and point.y > 37.0 and point.y < 59.0:
			# Uneven open pockets interrupt the continuous foreground carpet;
			# use world-space noise so the extra samples follow the same gaps.
			var opening := smoothstep(-0.18, 0.18, edges.get_noise_2dv(point * 0.85))
			if random.randf() > lerpf(0.30, 1.0, opening): continue
		# Broad low-growth pockets across the approach, distinct from fine
		# per-tuft noise: preserve isolated colonies instead of a hedge fringe.
		var approach_distance := point.distance_to(Vector2(19, 43))
		if approach_distance < 25.0:
			var opening_field := edges.get_noise_2dv(point * 0.35 + Vector2(31, -17))
			var colony_retention := lerpf(0.16, 1.0, smoothstep(-0.12, 0.20, opening_field))
			if random.randf() > lerpf(colony_retention, 1.0, smoothstep(16.0, 25.0, approach_distance)): continue
		if random.randf() > lerpf(0.08, 0.98, coverage): continue
		var blocked := false
		var paving_distance := 10.0
		for obstacle in exclusion_cells.get(Vector2i(floori(point.x / 12.0), floori(point.y / 12.0)), []):
			if obstacle.grow(0.5).has_point(point): blocked = true; break
			var outside: Vector2 = (point - obstacle.get_center()).abs() - obstacle.size * 0.5
			paving_distance = minf(paving_distance, Vector2(maxf(outside.x, 0.0), maxf(outside.y, 0.0)).length())
		if blocked: continue
		# Feather roots outside the protected paving; keep every collision and
		# access exclusion intact while breaking the rectangular grass fringe.
		var edge_recovery := smoothstep(0.5, 5.5, paving_distance + edges.get_noise_2dv(point * 0.65) * 5.0)
		if random.randf() > lerpf(0.16, 1.0, edge_recovery): continue
		if not service_growth_sample(point): continue
		var species_roll := random.randf()
		# Neighbouring plants share soil/moisture conditions. Broadleaf colonies
		# occupy pockets instead of being sprinkled uniformly through every tuft.
		var pocket := smoothstep(-0.22, 0.24, edges.get_noise_2dv(point * 0.48))
		var species := 0
		if species_roll < lerpf(0.94, 0.84, pocket): species = 1
		elif pocket > 0.78 and species_roll > 0.97: species = 2
		var cell := Vector3i(floori(point.x / 12), floori(point.y / 12), species)
		if not cells.has(cell): cells[cell] = []
		var scale := random.randf_range(0.45, 1.45) * lerpf(0.7, 1.1, coverage)
		var local := Vector3(point.x - cell.x * 12 - 6, 0.01 + verge_height(point), point.y - cell.y * 12 - 6)
		var proportions := Vector3(scale, scale * random.randf_range(0.35, 0.95), scale)
		# Broad leaves retain their upright silhouette instead of becoming
		# overlapping horizontal plates in the foreground recovery plot.
		if species == 2:
			proportions *= Vector3(0.65, 1.25, 0.65)
		if attempt >= 680000:
			proportions *= Vector3(0.82, 0.7, 0.82)
		proportions.y *= lerpf(0.22, 1.0, edge_recovery)
		proportions.y *= lerpf(1.0, 1.65, bank)
		proportions.y *= lerpf(1.0, 1.8, meadow)
		proportions.y *= lerpf(0.55, 1.3, pocket)
		proportions.x *= lerpf(1.0, 1.35, meadow)
		proportions.z *= lerpf(1.0, 1.35, meadow)
		# Low trampled growth around the western work yard gradually gives way
		# to taller colonies; avoid a uniform tall strip at the paving boundary.
		var west_offset := (point - Vector2(-42, 34)).abs() - Vector2(11.5, 12.5)
		var west_distance := Vector2(maxf(west_offset.x, 0), maxf(west_offset.y, 0)).length()
		var recovery := smoothstep(0.0, 7.0, west_distance + edges.get_noise_2dv(point) * 2.0)
		proportions.y *= lerpf(0.24, 1.0, recovery)
		# Fine grasses knit into low colonies, leaving sparse taller seed stems.
		if species == 1:
			var approach_sward := 1.0 - smoothstep(10.0, 24.0, (point - Vector2(19, 45)).length())
			proportions *= Vector3(lerpf(1.25, 1.55, approach_sward), lerpf(0.58, 0.52, approach_sward), lerpf(1.25, 1.55, approach_sward))
		# Rosettes stay below the seed heads, with variable footprints rather
		# than repeating the same oversized radial silhouette on every bank.
		if species == 2: proportions *= Vector3(0.38, 0.32, 0.38)
		# Trampled verge blades spread low before becoming upright meadow.
		var roadside_sward := 1.0 - smoothstep(1.0, 5.0, road_distance)
		proportions *= Vector3(lerpf(1.0, 1.25, roadside_sward), lerpf(1.0, 0.65, roadside_sward), lerpf(1.0, 1.25, roadside_sward))
		# Unmown approach shoulders have upright colonies beyond the clear lane.
		# Apply after the general trampling factors so fine blades remain visible.
		var approach_shoulder := (1.0 - smoothstep(12.0, 24.0, point.distance_to(Vector2(19, 43)))) * smoothstep(2.0, 3.4, shelter_lane)
		var shoulder_patch := smoothstep(-0.18, 0.30, edges.get_noise_2dv(point * 0.65))
		# Low sward separates unequal upright colonies; only sparse seed heads
		# retain the old height, avoiding a continuous wall along the approach.
		var shoulder_height := lerpf(0.30, 1.65, smoothstep(0.25, 0.82, shoulder_patch))
		if species == 1 and random.randf() < 0.055:
			shoulder_height *= 1.45
		proportions.y *= lerpf(1.0, shoulder_height, approach_shoulder)
		var dry := smoothstep(-0.28, 0.3, hues.get_noise_2d(point.x, point.y))
		dry = clampf(dry + random.randf_range(-0.12, 0.12), 0.0, 1.0)
		proportions.y *= lerpf(0.25, 1.0, service_growth(point))
		cells[cell].append({
			"transform": Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(proportions), local),
			"variation": Color(dry, random.randf_range(0.8, 1.15), 0, 1),
		})
	for cell in cells:
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_custom_data = true
		# Compatibility rendering needs an explicit white instance multiplier
		# to preserve the grass mesh's authored vertex colors.
		instances.use_colors = true
		instances.mesh = meshes[cell.z]
		instances.instance_count = cells[cell].size()
		for index in range(instances.instance_count):
			instances.set_instance_transform(index, cells[cell][index].transform)
			instances.set_instance_custom_data(index, cells[cell][index].variation)
			instances.set_instance_color(index, Color.WHITE)
		var grass := MultiMeshInstance3D.new()
		grass.name = "GrassCell"
		grass.set_meta("mobile_grass", true)
		grass.multimesh = instances
		grass.material_override = material
		grass.position = Vector3(cell.x * 12 + 6, 0, cell.y * 12 + 6)
		grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Include the half-cell diagonal after the 80m blade fade.
		grass.visibility_range_end = 90
		world.add_child(grass)
	ground_litter(world, exclusions)
	if bake_android_ground:
		var cache := Node3D.new()
		for child in world.get_children().slice(first_child):
			world.remove_child(child)
			cache.add_child(child)
		for child in cache.find_children("*", "", true, false):
			# Bake a flat snapshot; imported scene inheritance plus reassigned
			# owners can instantiate duplicate mesh children when reloaded.
			child.scene_file_path = ""
			child.owner = cache
		var scene := PackedScene.new()
		assert(scene.pack(cache) == OK, "Android vegetation packing failed")
		assert(ResourceSaver.save(scene, "res://assets/android_ground.scn") == OK,
			"Android vegetation saving failed")
		print("ANDROID_GROUND_BAKED nodes=", cache.get_child_count())
		for child in cache.find_children("*", "", true, false):
			child.owner = null
		for child in cache.get_children():
			cache.remove_child(child)
			world.add_child(child)
		cache.free()

static func grass_exclusion_cells(exclusions: Array) -> Dictionary:
	# The sampler caps paving distance at 10m. Rectangles farther away cannot
	# change either that distance or the 0.5m root exclusion. Preserve input
	# order within each cell and never consume the vegetation random stream.
	var cells := {}
	for obstacle: Rect2 in exclusions:
		var bounds := obstacle.grow(10.0)
		var first := Vector2i(floori(bounds.position.x / 12.0), floori(bounds.position.y / 12.0))
		var last := Vector2i(floori(bounds.end.x / 12.0), floori(bounds.end.y / 12.0))
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				if not cells.has(cell): cells[cell] = []
				cells[cell].append(obstacle)
	return cells

static func ground_litter(world, exclusions: Array) -> void:
	# Small non-blocking debris breaks up bare soil between grass colonies.
	# Separate RNG preserves all existing vegetation placements.
	var random := RandomNumberGenerator.new()
	random.seed = 13781
	var density := FastNoiseLite.new()
	density.seed = 761
	density.frequency = 0.18
	var pebble := SphereMesh.new()
	pebble.radial_segments = 5
	pebble.rings = 2
	pebble.radius = 0.5
	pebble.height = 1.0
	var leaf := PrismMesh.new()
	leaf.size = Vector3(1, 0.12, 1)
	var meshes: Array[Mesh] = [pebble, leaf]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	var cells := {}
	for attempt in range(38000):
		var point := Vector2(random.randf_range(-100,100),random.randf_range(-100,100))
		if absf(point.x) < 9.1 or absf(point.y) < 8.1: continue
		if random.randf() > smoothstep(-0.2,0.35,density.get_noise_2dv(point)): continue
		var blocked := false
		for obstacle in exclusions:
			if obstacle.grow(0.25).has_point(point):
				blocked = true
				break
		if blocked: continue
		var species := 0 if random.randf() < 0.35 else 1
		var cell := Vector3i(floori(point.x / 12),floori(point.y / 12),species)
		if not cells.has(cell): cells[cell] = []
		var size := random.randf_range(0.06,0.19)
		var height := size * random.randf_range(0.22,0.45) if species == 0 else 0.025
		var position := Vector3(point.x-cell.x*12-6,verge_height(point)+height*0.45+0.006,point.y-cell.y*12-6)
		var tint := random.randf_range(0.65,1.15)
		var color := Color(0.24,0.25,0.23) if species == 0 else Color(0.19,0.16,0.105)
		cells[cell].append([Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3(size,height,size*0.65)),position),color*tint])
	for cell in cells:
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.mesh = meshes[cell.z]
		instances.instance_count = cells[cell].size()
		for i in range(instances.instance_count):
			instances.set_instance_transform(i,cells[cell][i][0])
			instances.set_instance_color(i,cells[cell][i][1])
		var batch := MultiMeshInstance3D.new()
		batch.name = "GroundLitterCell"
		batch.set_meta("mobile_ground_litter", true)
		batch.multimesh = instances
		batch.material_override = material
		batch.position = Vector3(cell.x*12+6,0,cell.y*12+6)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = 42
		world.add_child(batch)

static func background_height(point: Vector2, ridges: Array) -> float:
	var result := -0.2
	for ridge in ridges:
		var profile: Vector3 = ridge.profile
		var origin: Vector3 = ridge.origin
		var grid := (point - Vector2(origin.x, origin.z)) / profile.x * RIDGE_HALF + Vector2.ONE * RIDGE_HALF
		if grid.x < 0 or grid.y < 0 or grid.x >= RIDGE_CELLS or grid.y >= RIDGE_CELLS: continue
		var x := floori(grid.x)
		var z := floori(grid.y)
		var fraction := grid - Vector2(x, z)
		var heights: Array = ridge.heights
		var h00: float = heights[z][x]
		var h10: float = heights[z][x + 1]
		var h01: float = heights[z + 1][x]
		var h11: float = heights[z + 1][x + 1]
		# Match the two actual triangles in mountain(), not the curved function
		# between vertices, so roots do not float on a steep or narrow spur.
		var elevation: float
		if fraction.x + fraction.y <= 1:
			elevation = h00 + (h10 - h00) * fraction.x + (h01 - h00) * fraction.y
		else:
			elevation = h11 + (h01 - h11) * (1 - fraction.x) + (h10 - h11) * (1 - fraction.y)
		result = maxf(result, origin.y + elevation)
	return result

static func background_forest(world) -> void:
	# Background groves remain outside the playable square. They need no
	# invisible collision and do not allocate the high-detail near-tree mesh.
	var random := RandomNumberGenerator.new()
	random.seed = 8127
	var density := FastNoiseLite.new()
	density.seed = 522
	density.frequency = 0.035
	var quad := QuadMesh.new()
	quad.size = Vector2(9.5, 9.5)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/realism/fir_background.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.28
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.vertex_color_use_as_albedo = true
	var placements := []
	var ridges := []
	for node in world.get_children():
		if not node.has_meta("ridge"): continue
		var profile: Vector3 = node.get_meta("ridge")
		var noise := FastNoiseLite.new()
		noise.seed = 941 + int(profile.z)
		noise.frequency = 0.018
		noise.fractal_octaves = 2
		var heights := []
		for z in range(RIDGE_CELLS + 1):
			var row := PackedFloat32Array()
			for x in range(RIDGE_CELLS + 1):
				row.append(ridge_height((x / RIDGE_HALF - 1.0) * profile.x,
					(z / RIDGE_HALF - 1.0) * profile.x, profile.x, profile.y, int(profile.z), noise))
			heights.append(row)
		ridges.append({"origin": node.position, "profile": profile, "heights": heights})
	for attempt in range(62000):
		var angle := random.randf() * TAU
		var radius := random.randf_range(138, 385)
		var point := Vector2(cos(angle), sin(angle)) * radius
		if maxf(absf(point.x), absf(point.y)) < 126: continue
		var ground_height := background_height(point, ridges)
		var gradient := Vector2(
			background_height(point + Vector2(1, 0), ridges) - background_height(point - Vector2(1, 0), ridges),
			background_height(point + Vector2(0, 1), ridges) - background_height(point - Vector2(0, 1), ridges)) * 0.5
		if gradient.length() > 1.55: continue
		# Lowland groves thin into exposed upper slopes while retaining clearings.
		var patch := density.get_noise_2d(point.x * 2.8 + 123, point.y * 2.8 - 61)
		var clearing := density.get_noise_2d(point.x * 0.32 + 347, point.y * 0.32 - 218)
		var colony := smoothstep(-0.18, 0.25, density.get_noise_2d(point.x, point.y) + patch * 0.45)
		colony *= smoothstep(-0.24, 0.09, clearing)
		# Exposure depends on local relief as well as altitude: sparse crowns
		# on ridges, larger connected groves in sheltered drainage basins.
		var surrounding_height := (background_height(point + Vector2(12, 0), ridges)
			+ background_height(point - Vector2(12, 0), ridges)
			+ background_height(point + Vector2(0, 12), ridges)
			+ background_height(point - Vector2(0, 12), ridges)) * 0.25
		var exposure := smoothstep(0.35, 2.5, ground_height - surrounding_height)
		var sheltered := smoothstep(0.0, 2.5, surrounding_height - ground_height)
		colony = clampf(colony + sheltered * 0.48, 0.0, 1.0)
		var treeline := (1.0 - smoothstep(38.0 + clearing * 22.0, 72.0 + patch * 18.0, ground_height)) * (1.0 - exposure * 0.78)
		var slope_cover := 1.0 - smoothstep(0.9, 1.55, gradient.length())
		# Connected lower-slope crowns read as woodland at normal eye height.
		# Suppress isolated tall summit spikes while keeping rocky clearings.
		if random.randf() > colony * lerpf(0.0, 0.95, treeline) * lerpf(0.35, 1.0, slope_cover): continue
		# Sheltered mature stands and young clearing edges have different crowns.
		var maturity := smoothstep(-0.25, 0.30, patch + sheltered * 0.20)
		var scale := random.randf_range(0.25, 0.92) * lerpf(0.65, 1.0, maturity) * lerpf(0.48, 1.0, treeline)
		var width := scale * random.randf_range(0.70, 1.48) * lerpf(0.85, 1.12, maturity)
		placements.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width, scale, width)),
			Vector3(point.x, ground_height + 4.5 * scale - 0.15, point.y)))
		# Seedlings share a grove's suitable soil instead of filling the whole
		# arena with uniformly spaced trees. Keep roots on the sampled surface.
		if random.randf() < 0.32:
			var seedling := point + Vector2(random.randf_range(-3, 3), random.randf_range(-3, 3))
			if maxf(absf(seedling.x), absf(seedling.y)) < 126: continue
			var seedling_height := background_height(seedling, ridges)
			if absf(seedling_height - ground_height) > 1.5: continue
			var small := random.randf_range(0.16, 0.36)
			placements.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * small),
				Vector3(seedling.x, seedling_height + 4.5 * small - 0.05, seedling.y)))
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = quad
	instances.instance_count = placements.size()
	for index in range(placements.size()):
		instances.set_instance_transform(index, placements[index])
		var origin: Vector3 = placements[index].origin
		var moisture := density.get_noise_2d(origin.x * 0.67, origin.z * 0.67)
		var canopy := Color(0.36, 0.44, 0.32).lerp(Color(0.59, 0.61, 0.46),
			smoothstep(-0.35, 0.35, moisture))
		instances.set_instance_color(index, canopy * random.randf_range(0.82, 1.0))
	var grove := MultiMeshInstance3D.new()
	grove.name = "BackgroundGroves"
	grove.multimesh = instances
	grove.material_override = material
	grove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(grove)

static func batch_facade(world, asset: String, placement_key: String) -> void:
	var placements: Array = world.get_meta(placement_key, [])
	# Empty facade categories need no imported scene or temporary render nodes.
	if placements.is_empty():
		return
	var panel: Node3D = vegetation_scene("res://assets/realism/" + asset + ".glb").instantiate()
	world.add_child(panel)
	# A map-wide MultiMesh also has a map-wide bounding box: every local
	# light and shadow pass can submit all its windows, lamps and aircons.
	var cells := {}
	for placement: Transform3D in placements:
		var cell := Vector2i(floori(placement.origin.x / 16.0), floori(placement.origin.z / 16.0))
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(placement)
	var world_inverse: Transform3D = world.global_transform.affine_inverse()
	for part in panel.find_children("*", "MeshInstance3D", true, false):
		var part_transform: Transform3D = world_inverse * part.global_transform
		var part_bounds: AABB = part.mesh.get_aabb()
		for cell: Vector2i in cells:
			var local_placements: Array = cells[cell]
			var anchor := Vector3(cell.x * 16.0 + 8.0, 0, cell.y * 16.0 + 8.0)
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.mesh = part.mesh
			instances.instance_count = local_placements.size()
			# Submit each static cell once instead of updating the renderer for
			# every window, air conditioner or lamp in that cell.
			var transforms := PackedFloat32Array()
			transforms.resize(local_placements.size() * 12)
			var bounds := AABB()
			for i in range(local_placements.size()):
				var transform: Transform3D = local_placements[i] * part_transform
				transform.origin -= anchor
				var local_bounds: AABB = transform * part_bounds
				bounds = local_bounds if i == 0 else bounds.merge(local_bounds)
				for axis in range(3):
					var offset := i * 12 + axis * 4
					transforms[offset] = transform.basis.x[axis]
					transforms[offset + 1] = transform.basis.y[axis]
					transforms[offset + 2] = transform.basis.z[axis]
					transforms[offset + 3] = transform.origin[axis]
			instances.buffer = transforms
			# Facades never move: retain the full cell union without asking
			# the renderer to derive bounds from its instance buffer.
			instances.custom_aabb = bounds
			var batch := MultiMeshInstance3D.new()
			batch.name = "FacadeCell_" + asset
			batch.position = anchor
			batch.multimesh = instances
			world.add_child(batch)
	world.remove_child(panel)
	panel.queue_free()

static func batch_details(world) -> void:
	batch_static_grass(world)
	batch_facade(world, "window_shutter", "shutter_placements")
	batch_facade(world, "aircon", "aircon_placements")
	batch_facade(world, "wall_lamp", "lamp_placements")
	var groups := {}
	for node in world.get_children():
		if node.has_meta("visual_batch"):
			var cell := Vector2i(floori(node.position.x / 16.0), floori(node.position.z / 16.0))
			var key: String = str(node.get_meta("visual_batch")) + ":" + str(cell)
			if not groups.has(key): groups[key] = []
			groups[key].append(node)
	var detail_batch_index := 0
	# Box dimensions live in instance transforms; every cell can reuse the
	# same unit geometry while retaining its own material and culling bounds.
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	var mesh_bounds_cache := {}
	for key in groups:
		var nodes: Array = groups[key]
		var boxes: bool = nodes[0].mesh is BoxMesh
		var mesh: Mesh = unit_box if boxes else nodes[0].mesh
		# Adjacent cells share geometry; query each mesh's local bounds once.
		if not mesh_bounds_cache.has(mesh):
			mesh_bounds_cache[mesh] = mesh.get_aabb()
		var mesh_bounds: AABB = mesh_bounds_cache[mesh]
		var bounds := AABB()
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = nodes.size()
		# Static details need one upload per cell, not one server update per prop.
		var transforms := PackedFloat32Array()
		transforms.resize(nodes.size() * 12)
		for index in range(nodes.size()):
			var node = nodes[index]
			var transform: Transform3D = node.transform
			if boxes: transform.basis = transform.basis * Basis.from_scale(node.mesh.size)
			var local_bounds: AABB = transform * mesh_bounds
			bounds = local_bounds if index == 0 else bounds.merge(local_bounds)
			var offset := index * 12
			for axis in range(3):
				transforms[offset + axis * 4] = transform.basis.x[axis]
				transforms[offset + axis * 4 + 1] = transform.basis.y[axis]
				transforms[offset + axis * 4 + 2] = transform.basis.z[axis]
				transforms[offset + axis * 4 + 3] = transform.origin[axis]
		instances.buffer = transforms
		# Static props keep these transforms for their lifetime. Include every
		# scaled/rotated mesh in the union, avoiding renderer bounds reduction.
		instances.custom_aabb = bounds
		var batch := MultiMeshInstance3D.new()
		# Cached ground contains generated @MultiMeshInstance3D names. Avoid
		# reusing those names, which can make cached children unreachable.
		batch.name = "DetailCell_%d" % detail_batch_index
		detail_batch_index += 1
		batch.multimesh = instances
		batch.material_override = nodes[0].material_override
		world.add_child(batch)
		for node in nodes:
			world.remove_child(node)
			node.queue_free()

static func batch_static_grass(world: Node3D) -> void:
	# Small cells keep frustum culling local. Only imported, static grass with
	# no distance gates or custom shader is eligible; collision nodes stay put.
	var groups := {}
	var leaf_material := ShaderMaterial.new()
	leaf_material.shader = preload("res://shaders/static_grass.gdshader")
	var properties := ["layers", "cast_shadow", "gi_mode", "lightmap_scale",
		"transparency", "extra_cull_margin", "ignore_occlusion_culling",
		"sorting_offset", "sorting_use_aabb_center", "material_override", "material_overlay"]
	# The discovery pass does not move the world. Reuse its inverse for all
	# eligible tufts instead of inverting the same matrix for each one.
	var world_inverse := world.global_transform.affine_inverse()
	for node: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or node.get_script() != null or node.skin != null or node.get_child_count() != 0:
			continue
		var source := node.mesh.resource_path
		if not (source.begins_with("res://assets/realism/grass_fine.glb::") or
				source.begins_with("res://assets/realism/grass_broadleaf.glb::")):
			continue
		if not node.is_visible_in_tree() or node.visibility_range_begin != 0.0 or node.visibility_range_end != 0.0:
			continue
		if not node.visibility_parent.is_empty() or node.custom_aabb != AABB():
			continue
		var supported := node.material_overlay == null
		for surface in range(node.mesh.get_surface_count()):
			if node.get_surface_override_material(surface) != null or node.get_active_material(surface) is ShaderMaterial:
				supported = false
		if not supported:
			continue
		var local := world_inverse * node.global_transform
		var cell := Vector2i(floori(local.origin.x / 12.0), floori(local.origin.z / 12.0))
		var key := str(node.mesh.get_instance_id()) + ":" + str(cell)
		for property in properties:
			key += ":" + str(node.get(property))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(node)
	var replaced := 0
	var batches := 0
	for nodes: Array in groups.values():
		if nodes.size() < 2:
			continue
		var first: MeshInstance3D = nodes[0]
		var anchor := world.to_local(first.global_position)
		anchor = Vector3(floorf(anchor.x / 12.0) * 12.0 + 6.0, 0, floorf(anchor.z / 12.0) * 12.0 + 6.0)
		var batch := MultiMeshInstance3D.new()
		batch.name = "StaticGrassCell"
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = first.mesh
		instances.instance_count = nodes.size()
		for property in properties:
			batch.set(property, first.get(property))
		# Preserve authored overrides; default imported leaves need the same
		# linear-color conversion and soft foliage normals as meadow grass.
		if first.material_override == null:
			batch.material_override = leaf_material
		# Prepare the complete resource before attaching a render instance.
		# The future batch transform is world * translation(anchor).
		var inverse := Transform3D(Basis.IDENTITY, -anchor) * world_inverse
		var bounds := AABB()
		# Group members share a mesh and have no custom AABB. Query its local
		# bounds once; each tuft still contributes its transformed bounds.
		var mesh_bounds := first.get_aabb()
		# Upload one contiguous transform buffer instead of issuing a rendering
		# server update for every tuft while constructing the scene.
		var transforms := PackedFloat32Array()
		transforms.resize(nodes.size() * 12)
		for index in range(nodes.size()):
			var node: MeshInstance3D = nodes[index]
			var local_transform := inverse * node.global_transform
			var offset := index * 12
			for axis in range(3):
				transforms[offset + axis * 4] = local_transform.basis.x[axis]
				transforms[offset + axis * 4 + 1] = local_transform.basis.y[axis]
				transforms[offset + axis * 4 + 2] = local_transform.basis.z[axis]
				transforms[offset + axis * 4 + 3] = local_transform.origin[axis]
			var local_bounds := local_transform * mesh_bounds
			bounds = local_bounds if index == 0 else bounds.merge(local_bounds)
			node.get_parent().remove_child(node)
			node.queue_free()
		instances.buffer = transforms
		# These imported tufts have no vertex displacement and never move.
		# Supply their union once, avoiding renderer-side instance bounds work.
		# extra_cull_margin remains on the batch and is applied by the renderer.
		instances.custom_aabb = bounds
		batch.position = anchor
		batch.multimesh = instances
		world.add_child(batch)
		replaced += nodes.size()
		batches += 1
	world.set_meta("static_grass_batch_stats", {"replaced_mesh_nodes": replaced, "batches": batches})

# Raised ventilation monitors give selected workshops an industrial silhouette.
# The existing sealed roof remains intact; these are not accessible skylights.
static func verge_height(point: Vector2) -> float:
	var relief := verge_bank_height(point)
	if point.x >= 9.0 and point.x <= 28.0 and point.y >= 35.0 and point.y <= 53.0:
		return relief
	# Soil banks and their roots follow the excavated terrain datum.
	return road_cut_height(point) + relief

static func verge_bank_height(point: Vector2) -> float:
	# The service yard is graded directly into ExcavatedTerrain. Its planting
	# datum follows that shared collision surface and the 44 mm yard finish;
	# do not superimpose the retired, metre-high grass-bank meshes here.
	if point.x >= 9.0 and point.x <= 28.0 and point.y >= 35.0 and point.y <= 53.0:
		return road_cut_height(point) + 0.044
	# Compact smooth banks return exactly to the existing flat ground. Keep
	# roadway, building foundations and doorway corridors on their old datum.
	var height := 0.0
	for bank in [Vector4(-26, 56, 10, 5), Vector4(12, -38, 3, 10), Vector4(-25, -13, 7, 3),
			Vector4(-14.2, 44.0, 3.2, 4.0), Vector4(-20.8, 46.5, 3.0, 2.8),
			Vector4(-14.0, 25.0, 3.5, 5.0), Vector4(-13.0, 17.0, 2.5, 3.5)]:
		var q := (point - Vector2(bank.x, bank.y)) / Vector2(bank.z, bank.w)
		var falloff := maxf(0.0, 1.0 - q.length_squared())
		# Unequal spoil lobes and shallow erosion channels keep the footprint
		# compact while breaking the smooth, manufactured oval silhouette.
		var lobes := 1.0 + 0.16 * sin(q.y * 4.0 + 0.8) + 0.08 * sin(q.x * 4.0 - q.y * 2.0)
		var relief := 0.94 if bank.x > 9.0 and bank.y > 34.0 and bank.y < 45.0 else 0.72
		if bank.x < -10.0 and bank.y > 15.0 and bank.y < 30.0:
			relief = 0.85
			# Runoff fingers split the raised shoulder without raising asphalt.
			lobes *= 1.0 - 0.55 * exp(-pow((q.y + 0.12 - q.x * 0.28) / 0.20, 2.0))
		if bank.x < -10.0 and bank.y > 40.0 and bank.y < 50.0:
			# Raised scrub islands leave the workshop cross-access and road flat.
			relief = 1.05 if bank.x > -18.0 else 0.78
			lobes *= 1.0 - 0.30 * exp(-pow((q.y - q.x * 0.4) / 0.24, 2.0))
		height += relief * falloff * falloff * lobes
	# Clear the drainage bed in the same height field used by collision and
	# plant roots; feather the excavation into the existing eroded shoulders.
	if point.y > 35.0 and point.y < 45.0:
		var t := clampf((point.y - 35.4) / 9.0, 0.0, 1.0)
		var distance_to_swale := absf(absf(point.x - 15.5) - lerpf(3.88, 3.60, t))
		var cut := (1.0 - smoothstep(0.40, 0.80, distance_to_swale))
		cut *= smoothstep(35.0, 35.5, point.y) * (1.0 - smoothstep(44.3, 45.0, point.y))
		height *= 1.0 - cut
	return height

static func western_road_ecotone(world) -> void:
	# Islands of scrub follow the unused west shoulder. The road and the
	# workshop cross-access at z=34 remain clear, with low feathered edges.
	var rng := RandomNumberGenerator.new()
	rng.seed = 305071
	var colonies := [Vector4(-13.4, 44.0, 2.5, 3.0),
		Vector4(-18.2, 40.2, 3.1, 1.8), Vector4(-14.0, 26.0, 2.8, 3.5),
		Vector4(-20.0, 22.0, 3.8, 2.4), Vector4(-12.9, 17.0, 1.9, 2.7),
		Vector4(-16.5, 48.5, 2.2, 1.25), Vector4(-22.0, 46.8, 3.0, 1.4)]
	for k in range(colonies.size()):
		var colony: Vector4 = colonies[k]
		for i in range(100):
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf())
			var p := Vector2(colony.x, colony.y) + Vector2(cos(angle)*colony.z, sin(angle)*colony.w)*radius
			if absf(p.x) < 10.5 or absf(p.y - 34.0) < 4.0: continue
			# Interrupt the road-facing thicket with exposed drainage fingers;
			# keep tall woody growth at the back of each colony.
			if sin(p.x * 1.4 + sin(p.y * 0.8) * 2.0) < -0.38: continue
			# Break the two exposed southern patches into fingers and bare
			# gaps instead of adding another oval carpet along the shoulder.
			if k >= 5 and sin(p.x * 2.1 + p.y * 0.9) < -0.12: continue
			var woody := i < 6 and radius < 0.65 and p.x < colony.x
			var asset := "verge_fine_shrub" if woody else ("grass_broadleaf" if i % 4 == 0 else "grass_fine")
			var plant: Node3D = vegetation_scene("res://assets/realism/%s.glb" % asset).instantiate()
			plant.name = "WesternRoadEcotone_%d_%d" % [k,i]
			plant.position = Vector3(p.x, verge_height(p) + 0.018, p.y)
			plant.rotation.y = rng.randf() * TAU
			var spread := rng.randf_range(0.70, 1.25)
			var growth := rng.randf_range(0.9, 1.7) if woody else rng.randf_range(0.30, 0.65)
			if asset == "grass_broadleaf": spread *= 0.50
			growth *= lerpf(1.0, 0.42, radius)
			plant.scale = Vector3(spread, growth, spread)
			world.add_child(plant)

static func verge_relief(world) -> void:
	# Southern spoil shoulders frame the repair approach. Their compact support
	# stops before the road, canopy slab and clear central vehicle lane.
	# Grass roots and collision use this same height function.
	for region in [Rect2(-36, 51, 20, 10), Rect2(9, -48, 6, 20), Rect2(-32, -16, 14, 6),
			Rect2(-24, 40, 13, 9.5),
			Rect2(-17.5, 13.5, 7, 16.5)]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var step := 0.5
		for ix in range(int(region.size.x / step)):
			for iz in range(int(region.size.y / step)):
				var p: Vector2 = region.position + Vector2(ix, iz) * step
				# Do not draw the rectangular sampling domain outside the bank.
				# These flat cells otherwise replace the surrounding yard surface.
				var peak := maxf(maxf(verge_bank_height(p), verge_bank_height(p + Vector2(step, 0))),
					maxf(verge_bank_height(p + Vector2(0, step)), verge_bank_height(p + Vector2(step, step))))
				if peak < 0.004:
					continue
				for offset in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE,
						Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
					var sample: Vector2 = p + offset * step
					surface.set_uv(sample / 240.0)
					# Shared analytical slope normals avoid lighting seams between triangles.
					var dx := (verge_height(sample + Vector2(0.01, 0)) - verge_height(sample - Vector2(0.01, 0))) / 0.02
					var dz := (verge_height(sample + Vector2(0, 0.01)) - verge_height(sample - Vector2(0, 0.01))) / 0.02
					surface.set_normal(Vector3(-dx, 1, -dz).normalized())
					# Bury the feather edge beneath the existing ground; keep
					# the raised, walkable bank at its original height.
					var height := verge_bank_height(sample)
					surface.add_vertex(Vector3(sample.x, verge_height(sample) + lerpf(-0.018, 0.003, smoothstep(0.0, 0.06, height)), sample.y))
		# Analytical normals and UVs agree at shared grid corners. Reuse these
		# vertices on Android without changing the bank surface or collision.
		if OS.has_feature("android"):
			surface.index()
			surface.optimize_indices_for_cache()
		var bank := MeshInstance3D.new()
		bank.name = "TraversableGrassBank_%d_%d" % [region.position.x, region.position.y]
		bank.mesh = surface.commit()
		bank.material_override = meadow_surface()
		world.add_child(bank)
		bank.create_trimesh_collision()
		for child in bank.get_children():
			if child is StaticBody3D: child.set_meta("surface", "terrain")
	verge_cover(world)

static func verge_cover(world) -> void:
	# Dedicated slope colonies bypass the flat-meadow exclusion masks that
	# previously left the new shoulders bare. All roots share the physics datum.
	var template: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
	var source: MeshInstance3D = template.find_children("*", "MeshInstance3D", true, false)[0]
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.use_colors = true
	batch.mesh = source.mesh
	template.free()
	batch.instance_count = 2200
	var rng := RandomNumberGenerator.new()
	rng.seed = 217091
	var patches := FastNoiseLite.new()
	patches.seed = 217
	patches.frequency = 1.1
	var colonies := FastNoiseLite.new()
	colonies.seed = 333
	colonies.frequency = 0.32
	var count := 0
	# The sampling regions are fixed throughout generation. Reuse this array
	# instead of allocating it for each candidate root during scene loading.
	var domains := [Rect2(9,35,4,12), Rect2(20,45,8,8), Rect2(19,37.8,5.6,7),
		Rect2(-17.5,20,7,10), Rect2(-15.5,13.5,5,7)]
	for attempt in 6200:
		var domain: Rect2 = domains[attempt % domains.size()]
		var p := domain.position + Vector2(rng.randf(), rng.randf()) * domain.size
		var height := verge_height(p)
		if height < 0.035 or count >= batch.instance_count: continue
		if p.x >= 9.0 and p.y >= 35.0 and height < 0.079: continue
		var coverage := smoothstep(-0.4,0.35,patches.get_noise_2dv(p))
		var colony := smoothstep(-0.22, 0.34, colonies.get_noise_2dv(p))
		if rng.randf() > (coverage * 0.8 + 0.12) * colony: continue
		# Tall sheltered colony centres and low exposed fringes give each
		# patch a silhouette instead of evenly distributed identical tufts.
		var centre := smoothstep(0.45, 0.95, coverage * colony)
		var width := rng.randf_range(0.45,0.85) * lerpf(0.85, 1.2, centre)
		var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(width,rng.randf_range(0.12,0.28) + centre * 0.30,width))
		batch.set_instance_transform(count,Transform3D(basis,Vector3(p.x,height+0.007,p.y)))
		batch.set_instance_custom_data(count,Color(coverage,rng.randf_range(0.85,1.15),0,1))
		batch.set_instance_color(count, Color.WHITE)
		count += 1
	batch.visible_instance_count = count
	var cover := MultiMeshInstance3D.new()
	cover.name = "SpoilBankGrassColonies"
	cover.multimesh = batch
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/grass.gdshader")
	material.set_shader_parameter("fade_begin",42.0)
	material.set_shader_parameter("fade_end",80.0)
	cover.material_override = material
	world.add_child(cover)

static func grain_silos(world, at: Vector3) -> void:
	# Curved storage volumes break the low warehouse skyline. Cylinder physics
	# follows the visible shell rather than blocking its rectangular bounds.
	var steel := ShaderMaterial.new()
	steel.shader = preload("res://shaders/silo_galvanized.gdshader")
	var smooth_steel := steel.duplicate() as ShaderMaterial
	smooth_steel.set_shader_parameter("corrugation_strength", 0.0)
	for index in range(2):
		var center := at + Vector3(index * 6.2, 0, 0)
		var height := 11.0 if index == 0 else 8.8
		var shell := MeshInstance3D.new()
		shell.name = "GrainSilo"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 2.5
		cylinder.bottom_radius = 2.5
		cylinder.height = height
		cylinder.radial_segments = 48
		if OS.has_feature("android"):
			cylinder.rings = 0
		shell.mesh = cylinder
		shell.position = center + Vector3(0, height * 0.5, 0)
		shell.material_override = steel
		world.add_child(shell)
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 2.5
		shape.height = height
		collision.shape = shape
		body.add_child(collision)
		shell.add_child(body)
		world.ground_obstacles.append(Rect2(Vector2(center.x - 2.5, center.z - 2.5), Vector2(5, 5)))
		var roof := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.16
		cone.bottom_radius = 2.72
		cone.height = 1.65
		cone.radial_segments = 48
		roof.mesh = cone
		roof.position = center + Vector3(0, height + 0.825, 0)
		roof.material_override = smooth_steel
		world.add_child(roof)
		roof.create_trimesh_collision()
		if OS.has_feature("android"):
			# Keep the original collision mesh; straight cone sides need no
			# intermediate latitude rings in the rendered mesh.
			cone.rings = 0
		for band_index in range(int(height / 0.65)):
			var band := MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.inner_radius = 2.48
			ring.outer_radius = 2.55
			ring.rings = 48
			ring.ring_segments = 6
			band.mesh = ring
			band.position = center + Vector3(0, 0.35 + band_index * 0.65, 0)
			band.material_override = smooth_steel
			world.add_child(band)
		# A full-height ladder gives an immediate human scale to the vessel.
		for x in [-0.32, 0.32]:
			world.block(center + Vector3(x, height * 0.5, 2.65),
				Vector3(0.06, height, 0.06), "494f4d", false)
		for rung in range(int(height / 0.32)):
			world.block(center + Vector3(0, 0.25 + rung * 0.32, 2.68),
				Vector3(0.7, 0.04, 0.06), "494f4d", false)

static func workshop_monitor(world, at: Vector3) -> void:
	for item in [
		[Vector3(0, 5.9, 0), Vector3(3.4, 0.7, 8.8), "494f4d"],
		[Vector3(0, 6.64, 0), Vector3(2.8, 1.2, 8.0), "343e3e"]]:
		var part = world.block(at + item[0], item[1], item[2])
		# world.block returns the mesh; preserve its matching collision.
		var finish := StandardMaterial3D.new()
		finish.albedo_color = Color(item[2]).srgb_to_linear()
		finish.roughness = 0.83
		if part is MeshInstance3D: part.material_override = finish
	for x in [-1.43, 1.43]:
		for z in [-3.9, -2.6, -1.3, 0.0, 1.3, 2.6, 3.9]:
			world.block(at + Vector3(x, 6.64, z), Vector3(0.10, 1.2, 0.10), "777970")
		for y in [6.30, 6.54, 6.78, 7.02]:
			world.block(at + Vector3(x, y, 0), Vector3(0.18, 0.07, 8.0), "777970")
	# A capped ridge and overhanging slopes shed rain beyond the louvers.
	# Rotating the structural panels also rotates their collision children.
	var roofing := StandardMaterial3D.new()
	roofing.albedo_color = Color("6e7771").srgb_to_linear()
	roofing.roughness = 0.78
	roofing.metallic = 0.25
	var pitch := atan2(0.8, 1.95)
	for side in [-1.0, 1.0]:
		var slope = world.block(at + Vector3(side * 0.975, 7.60, 0),
			Vector3(Vector2(1.95, 0.8).length(), 0.085, 9.2), "6e7771")
		slope.rotation.z = -side * pitch
		slope.material_override = roofing
		for seam in range(13):
			var rib = world.block(at + Vector3(side * 0.975, 7.66, -4.5 + seam * 0.75),
				Vector3(2.12, 0.035, 0.035), "788179", false)
			rib.rotation.z = -side * pitch
			rib.material_override = roofing
		world.block(at + Vector3(side * 1.96, 7.18, 0),
			Vector3(0.06, 0.16, 9.26), "454e49", false)
	# Cover the meeting edges with a solid ridge cap so shots hit the
	# visible top rather than the end faces of the two sloping sheets.
	world.block(at + Vector3(0, 8.04, 0), Vector3(0.16, 0.09, 9.28), "788179")
	var ends := SurfaceTool.new()
	ends.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var points := [Vector3(-1.43, 7.2, side * 4.02),
			Vector3(1.43, 7.2, side * 4.02), Vector3(0, 7.83, side * 4.02)]
		if side > 0: points.reverse()
		for point in points: ends.add_vertex(at + point)
	ends.generate_normals()
	var gables := MeshInstance3D.new()
	gables.name = "WorkshopMonitorGables"
	gables.mesh = ends.commit()
	gables.material_override = roofing
	world.add_child(gables)
	gables.create_trimesh_collision()

static func west_workshop_canopy(world, at: Vector3) -> void:
	# A working frontage with a continuous clear central doorway. All structural
	# meshes carry their matching collision, including the pitched sheet roof.
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("66716d").srgb_to_linear()
	metal.roughness = 0.78
	metal.metallic = 0.25
	# Brick infill and a weather cap ground the sheet-metal hall at human scale.
	# The central 4 m opening remains clear; these solids match the wall skins.
	var masonry := ShaderMaterial.new()
	masonry.shader = load("res://shaders/workshop_masonry.gdshader")
	# Recessed industrial window bays sit on the solid facade, outside the
	# four metre doorway. Opaque dusty glazing avoids a false view indoors.
	var glazing := ShaderMaterial.new()
	glazing.shader = load("res://shaders/workshop_glass.gdshader")
	for bay_x in [-5.0, 5.0]:
		var pane = world.block(at + Vector3(bay_x, 2.22, 7.06),
			Vector3(4.7, 1.72, 0.10), "304440")
		pane.material_override = glazing
		for offset_x in [-2.4, -1.2, 0.0, 1.2, 2.4]:
			var mullion = world.block(at + Vector3(bay_x + offset_x, 2.22, 7.15),
				Vector3(0.065, 1.88, 0.13), "66716d")
			mullion.material_override = metal
		for height in [1.29, 2.22, 3.15]:
			var rail = world.block(at + Vector3(bay_x, height, 7.15),
				Vector3(4.86, 0.07, 0.15), "66716d")
			rail.material_override = metal
		var hood = world.block(at + Vector3(bay_x, 3.27, 7.29),
			Vector3(5.02, 0.07, 0.68), "66716d")
		hood.rotation.x = 0.12
		hood.material_override = metal
		var sill = world.block(at + Vector3(bay_x, 1.25, 7.24),
			Vector3(5.0, 0.09, 0.40), "66716d")
		sill.material_override = metal
		# A vent replaces the outer lower pane. Tilted blades create real
		# alternating shadow and edge highlights at normal walking height.
		var vent_x: float = bay_x + signf(bay_x) * 1.8
		var backing = world.block(at + Vector3(vent_x, 1.75, 7.16),
			Vector3(1.10, 0.78, 0.07), "202923")
		backing.name = "WorkshopVentBacking"
		for blade_index in range(6):
			var blade = world.block(at + Vector3(vent_x, 1.40 + blade_index * 0.13, 7.27),
				Vector3(1.09, 0.028, 0.22), "66716d")
			blade.name = "WorkshopVentBlade"
			blade.rotation.x = -0.42
			blade.material_override = metal
		for edge_x in [-0.57, 0.57]:
			var trim = world.block(at + Vector3(vent_x + edge_x, 1.75, 7.27),
				Vector3(0.045, 0.84, 0.25), "66716d")
			trim.material_override = metal
	for side in [-1.0, 1.0]:
		var plinth = world.block(at + Vector3(side * 5.0, 0.56, 6.91), Vector3(6.0, 1.12, 0.24), "79503c")
		plinth.material_override = masonry
		world.block(at + Vector3(side * 5.0, 1.15, 6.92), Vector3(6.0, 0.09, 0.30), "9a9483")
		# Masonry reveals and sills give the glazed infill real depth in an
		# eye-level view. They remain on the existing closed facade wings.
		for jamb_x in [2.52, 7.48]:
			var reveal = world.block(at + Vector3(side * jamb_x, 2.22, 7.16), Vector3(0.16, 1.96, 0.38), "79503c")
			reveal.material_override = masonry
		var drain = world.block(at + Vector3(side * 7.72, 1.65, 7.30), Vector3(0.11, 3.12, 0.12), "66716d")
		drain.material_override = metal
		for clip_y in [0.55, 1.65, 2.8]:
			world.block(at + Vector3(side * 7.72, clip_y, 7.38), Vector3(0.19, 0.045, 0.045), "454d48", false)
		# Knee braces read from the approach without crossing the central aisle.
		var knee = world.block(at + Vector3(side * 6.85, 2.84, 11.0), Vector3(0.14, 1.32, 0.14), "424b49")
		knee.rotation.z = side * -0.76
	var roof = world.block(at + Vector3(0, 3.65, 8.8), Vector3(15.8, 0.09, 5.4), "66716d")
	roof.name = "WorkshopFrontCanopyRoof"
	roof.rotation.x = 0.10
	var canopy_coating := ShaderMaterial.new()
	canopy_coating.shader = load("res://shaders/workshop_main_roof.gdshader")
	roof.material_override = canopy_coating
	# Separate pale underside from the exposed roofing. This remains above
	# the structural rafters and does not narrow the traversable entrance.
	var lining = world.block(at + Vector3(0, 3.59, 8.8), Vector3(15.65, 0.018, 5.3), "89938b", false)
	lining.rotation.x = 0.10
	var lining_material := ShaderMaterial.new()
	lining_material.shader = load("res://shaders/workshop_soffit.gdshader")
	lining.material_override = lining_material
	for x in [-4.8, 4.8]:
		var bounce := SpotLight3D.new()
		bounce.name = "WorkshopCanopyCeilingBounce"
		bounce.position = at + Vector3(x, 2.15, 9.0)
		bounce.rotation_degrees.x = 90
		bounce.light_color = Color("e5dbc8")
		bounce.light_energy = 0.75
		bounce.spot_range = 5.0
		bounce.spot_angle = 78.0
		bounce.shadow_enabled = true
		world.add_child(bounce)
	# Broad reflected daylight from the open apron reaches the facade under
	# the canopy. Shadowing keeps the closed wall from lighting the interior.
	for x in [-4.8, 4.8]:
		var fill := SpotLight3D.new()
		fill.name = "WorkshopApronDaylight"
		fill.position = at + Vector3(x, 2.9, 11.5)
		fill.rotation_degrees.x = -24.0
		fill.light_color = Color("d8dedb")
		fill.light_energy = 1.25
		fill.spot_range = 6.5
		fill.spot_angle = 68.0
		fill.shadow_enabled = true
		world.add_child(fill)
	# Colonies at the drip line anchor the canopy in the unpaved verge;
	# the central doorway and crate access stay clear.
	var verge_rng := RandomNumberGenerator.new()
	verge_rng.seed = 18403
	for side in [-1.0, 1.0]:
		for i in range(42):
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 3 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			var colony_z := 7.1 + (i % 3) * 1.8
			plant.position = at + Vector3(side * (8.05 + verge_rng.randf_range(-0.45, 0.55)), 0.035, colony_z + verge_rng.randf_range(-0.55, 0.55))
			plant.rotation.y = verge_rng.randf_range(0.0, TAU)
			plant.scale *= verge_rng.randf_range(0.65, 1.15)
			world.add_child(plant)
	for x in [-7.3, -2.8, 2.8, 7.3]:
		world.block(at + Vector3(x, 1.68, 11.0), Vector3(0.13, 3.36, 0.13), "424b49")
		world.block(at + Vector3(x, 0.09, 11.0), Vector3(0.32, 0.18, 0.32), "89877b")
		var rafter = world.block(at + Vector3(x, 3.49, 8.8), Vector3(0.10, 0.18, 5.3), "424b49")
		rafter.rotation.x = 0.10
		var brace = world.block(at + Vector3(x, 3.04, 10.64), Vector3(0.075, 0.85, 0.075), "424b49")
		brace.rotation.x = -0.72
	world.block(at + Vector3(0, 3.30, 11.0), Vector3(15.5, 0.18, 0.12), "424b49")
	world.block(at + Vector3(0, 3.42, 11.48), Vector3(15.9, 0.16, 0.14), "59645e")
	# Open gutter and downpipes give the long eave a readable drainage profile.
	world.block(at + Vector3(0, 3.37, 11.51), Vector3(15.9, 0.045, 0.28), "59645e", false)
	world.block(at + Vector3(0, 3.46, 11.65), Vector3(15.9, 0.18, 0.035), "66716d", false)
	for drain_x in [-7.55, 7.55]:
		var pipe := workyard_round_fitting(world, at + Vector3(drain_x, 0.25, 11.44), at + Vector3(drain_x, 3.39, 11.44), 0.09, "66716d")
		pipe.material_override = metal
		pipe.create_trimesh_collision()
		workyard_round_fitting(world, at + Vector3(drain_x, 0.25, 11.44), at + Vector3(drain_x, 0.15, 11.78), 0.09, "66716d")
		for band_y in [0.65, 2.65]:
			world.block(at + Vector3(drain_x, band_y, 11.44), Vector3(0.21, 0.055, 0.21), "424b49", false)
	# A shallow enamel fascia makes this entrance recognisable from the road.
	world.block(at + Vector3(0, 3.65, 11.57), Vector3(5.0, 0.62, 0.08), "343f3b", false)
	var sign := Label3D.new()
	sign.name = "WorkshopEntranceSign"
	sign.text = "03  /  WORKSHOP"
	sign.font_size = 96
	sign.pixel_size = 0.004
	sign.position = at + Vector3(0, 3.65, 11.62)
	sign.modulate = Color("e8dcc1")
	sign.outline_size = 0
	sign.no_depth_test = false
	sign.shaded = true
	world.add_child(sign)
	# Raised standing seams follow the fall of the roof.
	for seam in range(27):
		var rib = world.block(at + Vector3(-7.8 + seam * 0.6, 3.72, 8.8), Vector3(0.025, 0.045, 5.4), "66716d", false)
		rib.rotation.x = 0.10
		rib.material_override = canopy_coating
	for x in [-5.0, 5.0]:
		world.block(at + Vector3(x, 3.35, 7.8), Vector3(1.3, 0.1, 0.24), "454c49", false)
		var diffuser = world.block(at + Vector3(x, 3.285, 7.8), Vector3(1.15, 0.025, 0.18), "fff0d3", false)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("fff0d3")
		glow.emission_enabled = true
		glow.emission = Color("ffe1b0")
		glow.emission_energy_multiplier = 0.35
		diffuser.material_override = glow
		var light := SpotLight3D.new()
		light.name = "WorkshopCanopyLight"
		light.position = at + Vector3(x, 3.23, 7.8)
		light.rotation_degrees.x = -90
		light.light_color = Color("ffe9ce")
		light.light_energy = 1.15
		light.spot_range = 6.5
		light.spot_angle = 65
		light.shadow_enabled = true
		world.add_child(light)
	# Supplies stay in the two sheltered bays, away from the 5.6 m central aisle.
	for x in [-5.7, 5.7]:
		var crate = vegetation_scene("res://assets/realism/supply_crate.glb").instantiate()
		crate.position = at + Vector3(x, 0.04, 8.1)
		world.add_child(crate)
		var proxy = world.block(at + Vector3(x, 0.75, 8.1), Vector3(2.5, 1.5, 2.0), "59564a")
		proxy.visible = false

	# Rear-wall parts rack: open framing and task lighting give the entrance
	# a readable working interior while preserving the four-metre through aisle.
	for x in [2.8, 6.3]:
		for z in [-5.6, -4.8]:
			world.block(at + Vector3(x, 1.4, z), Vector3(0.065, 2.65, 0.065), "586362")
	var carton_materials: Array[StandardMaterial3D] = []
	for tint in ["887458", "a08a65", "756851"]:
		var carton_material := StandardMaterial3D.new()
		carton_material.albedo_color = Color(tint)
		carton_material.roughness = 0.96
		carton_materials.append(carton_material)
	# Separate shipments, with gaps for access; dimensions stay inside the rack.
	# Vector4 stores centre X, width, height and depth.
	var shelf_cargo := [
		[Vector4(3.4, 0.92, 0.52, 0.70), Vector4(4.65, 1.12, 0.30, 0.64), Vector4(5.85, 0.55, 0.46, 0.62)],
		[Vector4(3.28, 0.62, 0.34, 0.55), Vector4(4.12, 0.70, 0.45, 0.62), Vector4(5.62, 1.02, 0.24, 0.68)],
		[Vector4(3.62, 1.18, 0.26, 0.64), Vector4(5.12, 0.52, 0.42, 0.56)]
	]
	for shelf_index in range(3):
		var y: float = [0.45, 1.25, 2.05][shelf_index]
		world.block(at + Vector3(4.55, y, -5.2), Vector3(3.55, 0.065, 0.9), "666a60")
		world.block(at + Vector3(4.55, y - 0.08, -4.77), Vector3(3.55, 0.12, 0.035), "a18145", false)
		for i in range(shelf_cargo[shelf_index].size()):
			var cargo: Vector4 = shelf_cargo[shelf_index][i]
			var z := -5.22 + 0.035 * ((i + shelf_index) % 3)
			var base_y := y + 0.033
			var front := z + cargo.w * 0.5
			var carton = world.block(at + Vector3(cargo.x, base_y + cargo.z * 0.5, z),
				Vector3(cargo.y, cargo.z, cargo.w), "887458")
			carton.material_override = carton_materials[(i + shelf_index) % carton_materials.size()]
			# Fold seam and sealing tape continue over the top and front edge.
			var seam = world.block(at + Vector3(cargo.x, base_y + cargo.z + 0.002, z),
				Vector3(0.009, 0.004, cargo.w), "454037", false)
			var seam_material := StandardMaterial3D.new()
			seam_material.albedo_color = Color("454037")
			seam_material.roughness = 1.0
			seam.material_override = seam_material
			var tape_material := StandardMaterial3D.new()
			tape_material.albedo_color = Color("b39a6e")
			tape_material.roughness = 0.65
			for tape_spec in [
				[Vector3(cargo.x + cargo.y * 0.22, base_y + cargo.z + 0.004, z), Vector3(0.065, 0.004, cargo.w)],
				[Vector3(cargo.x + cargo.y * 0.22, base_y + cargo.z * 0.5, front + 0.003), Vector3(0.065, cargo.z, 0.004)]
			]:
				var tape = world.block(at + tape_spec[0], tape_spec[1], "b39a6e", false)
				tape.material_override = tape_material
			var label = world.block(at + Vector3(cargo.x - cargo.y * 0.2, base_y + cargo.z * 0.53, front + 0.006),
				Vector3(0.15, 0.09, 0.003), "c3beaa", false)
			var label_material := StandardMaterial3D.new()
			label_material.albedo_color = Color("c3beaa")
			label_material.roughness = 1.0
			label.material_override = label_material
	world.block(at + Vector3(4.55, 2.8, -5.7), Vector3(3.5, 0.07, 0.16), "b6bdb0", false)
	var task_light := SpotLight3D.new()
	task_light.name = "WorkshopPartsTaskLight"
	task_light.position = at + Vector3(4.55, 3.2, -3.8)
	task_light.rotation_degrees = Vector3(-62, 0, 0)
	task_light.light_color = Color("ffe9cb")
	task_light.light_energy = 2.6
	task_light.spot_range = 5.5
	task_light.spot_angle = 62
	task_light.shadow_enabled = true
	world.add_child(task_light)

	# Entrance service equipment has a narrow silhouette beside the opening.
	# Keep all solid equipment outside the existing four-metre through route.
	world.block(at + Vector3(-2.65, 1.55, 7.13), Vector3(0.72, 1.05, 0.34), "697471")
	world.block(at + Vector3(-2.65, 1.55, 7.315), Vector3(0.65, 0.96, 0.035), "828980", false)
	for y in [1.25, 1.32, 1.39, 1.46]:
		world.block(at + Vector3(-2.65, y, 7.34), Vector3(0.44, 0.018, 0.012), "333c38", false)
	world.block(at + Vector3(-2.42, 1.72, 7.35), Vector3(0.035, 0.15, 0.04), "303936", false)
	world.block(at + Vector3(-2.72, 1.84, 7.34), Vector3(0.22, 0.13, 0.015), "c7ad63", false)
	# Round rainwater leaders and electrical conduit avoid another box-only facade.
	for spec in [Vector3(-7.55, 0.075, 11.45), Vector3(7.55, 0.075, 11.45),
			Vector3(-2.65, 0.025, 7.09)]:
		var pipe := MeshInstance3D.new()
		pipe.name = "WorkshopServicePipe"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = spec.y
		cylinder.bottom_radius = spec.y
		cylinder.height = 3.15
		cylinder.radial_segments = 16
		if OS.has_feature("android"):
			cylinder.rings = 0
		pipe.mesh = cylinder
		pipe.material_override = metal
		pipe.position = at + Vector3(spec.x, 1.78, spec.z)
		world.add_child(pipe)
		for y in [0.5, 2.6]:
			world.block(at + Vector3(spec.x, y, spec.z), Vector3(spec.y * 2.5, 0.055, spec.y * 2.5), "343e3b", false)
	# Rear wall services and frame bays give the entrance view a readable
	# depth reference. Keep all structure outside the central through route.
	for x in [-6.6, -3.4, 3.4, 6.6]:
		world.block(at + Vector3(x, 1.85, -6.48), Vector3(0.18, 3.7, 0.24), "505956")
		world.block(at + Vector3(x, 0.14, -6.35), Vector3(0.38, 0.28, 0.40), "72746b")
	# Shallow tool board and bench against the wall, with a solid worktop
	# and legs so collision follows the visible furniture.
	var bench_enamel := StandardMaterial3D.new()
	bench_enamel.albedo_color = Color("454e4c")
	bench_enamel.metallic = 0.25
	bench_enamel.roughness = 0.62
	var tool_steel := StandardMaterial3D.new()
	tool_steel.albedo_color = Color("8b918d")
	tool_steel.metallic = 0.85
	tool_steel.roughness = 0.38
	var bench_top := ShaderMaterial.new()
	bench_top.shader = load("res://shaders/workbench_wood.gdshader")
	var bench_joint := StandardMaterial3D.new()
	bench_joint.albedo_color = Color("393b32")
	bench_joint.roughness = 1.0
	# Use furniture materials explicitly: the world block palette otherwise
	# treats these muted colors as exterior plaster.
	var tool_board = world.block(at + Vector3(-4.9, 1.82, -6.22), Vector3(2.55, 1.1, 0.12), "454e4c")
	var pegboard_material := ShaderMaterial.new()
	pegboard_material.shader = load("res://shaders/workshop_pegboard.gdshader")
	tool_board.material_override = pegboard_material
	for edge_y in [1.285, 2.355]:
		var folded_edge = world.block(at + Vector3(-4.9, edge_y, -6.145), Vector3(2.55, 0.025, 0.035), "454e4c", false)
		folded_edge.material_override = bench_enamel
	for edge_x in [-6.16, -3.64]:
		var folded_edge = world.block(at + Vector3(edge_x, 1.82, -6.145), Vector3(0.025, 1.05, 0.035), "454e4c", false)
		folded_edge.material_override = bench_enamel
		for bolt_y in [1.35, 2.29]:
			var bolt := MeshInstance3D.new()
			var bolt_mesh := CylinderMesh.new()
			bolt_mesh.top_radius = 0.012
			bolt_mesh.bottom_radius = 0.012
			bolt_mesh.height = 0.008
			bolt_mesh.radial_segments = 6
			if OS.has_feature("android"):
				bolt_mesh.rings = 0
			bolt.mesh = bolt_mesh
			bolt.material_override = tool_steel
			bolt.position = at + Vector3(edge_x, bolt_y, -6.119)
			bolt.rotation_degrees.x = 90
			world.add_child(bolt)
	var worktop = world.block(at + Vector3(-4.9, 0.92, -5.92), Vector3(2.8, 0.10, 0.85), "82745c")
	worktop.material_override = bench_top
	for z in [-6.07, -5.79]:
		var joint = world.block(at + Vector3(-4.9, 0.971, z), Vector3(2.77, 0.002, 0.005), "393b32", false)
		joint.material_override = bench_joint
	for x in [-6.1, -3.7]:
		for z in [-6.20, -5.62]:
			var leg = world.block(at + Vector3(x, 0.43, z), Vector3(0.075, 0.86, 0.075), "39413f")
			leg.material_override = bench_enamel
		var stretcher = world.block(at + Vector3(x, 0.22, -5.91), Vector3(0.055, 0.065, 0.62), "39413f")
		stretcher.material_override = bench_enamel
	var rear_rail = world.block(at + Vector3(-4.9, 0.29, -6.2), Vector3(2.4, 0.09, 0.055), "39413f")
	rear_rail.material_override = bench_enamel
	# Original Blender mesh: rounded grips, forged jaws/ring ends and hooks.
	# Decorative only; the board and bench retain their existing collision.
	var workshop_tools: Node3D = load("res://assets/realism/workshop_tools.glb").instantiate()
	workshop_tools.name = "WorkshopHandTools"
	workshop_tools.position = at + Vector3(-4.9, 0, -6.15)
	world.add_child(workshop_tools)
	# Two overlapping emitters approximate the long diffuser instead of a
	# single circular hotspot on the pegboard. Keep total energy unchanged.
	for offset in [-0.43, 0.43]:
		var bench_light := SpotLight3D.new()
		bench_light.name = "WorkshopBenchTaskLightLeft" if offset < 0 else "WorkshopBenchTaskLightRight"
		bench_light.position = at + Vector3(-4.9 + offset, 2.575, -5.88)
		bench_light.rotation_degrees = Vector3(-78, 0, 0)
		bench_light.light_color = Color("ffe0af")
		bench_light.light_energy = 0.9
		bench_light.spot_range = 4.0
		bench_light.spot_angle = 65.0
		bench_light.spot_angle_attenuation = 0.45
		bench_light.shadow_enabled = true
		world.add_child(bench_light)
	# Suspended task lights illuminate the floor, not a near-ceiling omni hotspot.
	var diffuser := StandardMaterial3D.new()
	diffuser.albedo_color = Color("e4dcc9")
	diffuser.emission_enabled = true
	diffuser.emission = Color("e4dcc9")
	diffuser.emission_energy_multiplier = 0.3
	for x in [-2.4, 2.4]:
		for z in [-1.0, 3.0]:
			for end in [-0.65, 0.65]:
				world.block(at + Vector3(x + end, 3.57, z), Vector3(0.025, 0.86, 0.025), "434b49", false)
			world.block(at + Vector3(x, 3.08, z), Vector3(1.6, 0.12, 0.28), "434b49", false)
			var lens := MeshInstance3D.new()
			var shape := BoxMesh.new()
			shape.size = Vector3(1.42, 0.025, 0.22)
			lens.mesh = shape
			lens.material_override = diffuser
			lens.position = at + Vector3(x, 3.01, z)
			world.add_child(lens)
			var task := SpotLight3D.new()
			task.name = "WorkshopSuspendedTaskLight"
			task.position = at + Vector3(x, 2.98, z)
			task.rotation_degrees.x = -90
			task.light_color = Color("e4dcc9")
			task.light_energy = 0.55
			task.spot_range = 7.0
			task.spot_angle = 58.0
			task.shadow_enabled = true
			world.add_child(task)

static func workshop_frontage(world, at: Vector3) -> void:
	# Clerestory glazing above the canopy breaks the large blank metal wall.
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/workshop_glass.gdshader")
	for side in [-1.0, 1.0]:
		var center := at + Vector3(side * 4.8, 4.55, 6.96)
		world.block(center, Vector3(5.2, 1.02, 0.14), "343b39")
		for pane in range(5):
			var window = world.block(center + Vector3(-2.04 + pane * 1.02, 0, 0.09),
				Vector3(0.94, 0.82, 0.035), "344b50", false)
			window.material_override = glass
		# Projecting steel frames shade the dusty glazing at walking distance.
		for mullion in range(6):
			world.block(center + Vector3(-2.55 + mullion * 1.02, 0, 0.14), Vector3(0.055, 1.04, 0.12), "89958e", false)
		for rail_y in [-0.49, 0.49]:
			world.block(center + Vector3(0, rail_y, 0.14), Vector3(5.2, 0.055, 0.12), "89958e", false)
		world.block(center + Vector3(0, -0.55, 0.08), Vector3(5.5, 0.09, 0.32), "85877c")
		# Roll-up door guides stay against the existing jambs.
		world.block(at + Vector3(side * 2.06, 1.43, 7.04), Vector3(0.12, 2.86, 0.20), "4d5854")
	# Folded jamb guards, separate fixing plates and exposed bolt heads make
	# the opening read as assembled steel. Keep every solid outside |x| < 2 m.
	var guard_finish := ShaderMaterial.new()
	guard_finish.shader = load("res://shaders/workshop_jamb.gdshader")
	for side in [-1.0, 1.0]:
		var guard = world.block(at + Vector3(side * 2.19, 0.49, 7.19), Vector3(0.26, 0.98, 0.095), "a88741")
		guard.material_override = guard_finish
		world.block(at + Vector3(side * 2.19, 0.035, 7.18), Vector3(0.36, 0.07, 0.34), "67665c")
		for y in [0.16, 0.83, 1.55, 2.5]:
			world.block(at + Vector3(side * 2.19, y, 7.16), Vector3(0.25, 0.14, 0.04), "777b70", false)
			for offset in [-0.075, 0.075]:
				var bolt := MeshInstance3D.new()
				var head := CylinderMesh.new()
				head.top_radius = 0.021
				head.bottom_radius = 0.021
				head.height = 0.018
				head.radial_segments = 6
				if OS.has_feature("android"):
					head.rings = 0
				bolt.mesh = head
				var steel := StandardMaterial3D.new()
				steel.albedo_color = Color("81887f")
				steel.metallic = 0.7
				steel.roughness = 0.62
				bolt.material_override = steel
				bolt.position = at + Vector3(side * 2.19 + offset, y, 7.25 if y < 1.0 else 7.19)
				bolt.rotation_degrees.x = 90
				world.add_child(bolt)
		# Continuous return reveals the guide's depth; rounded existing housing above.
		world.block(at + Vector3(side * 2.13, 1.85, 7.20), Vector3(0.045, 1.68, 0.08), "899187", false)
	# A shallow head flashing casts a contact shadow above the existing opening.
	world.block(at + Vector3(0, 2.94, 7.13), Vector3(4.46, 0.075, 0.33), "7f887f")
	# Folded rain hood projects far enough to read from the normal entrance view.
	var hood = world.block(at + Vector3(0, 3.18, 7.56), Vector3(4.85, 0.055, 1.12), "7f887f")
	hood.name = "WorkshopRainHood"
	hood.rotation.x = 0.12
	var hood_finish := ShaderMaterial.new()
	hood_finish.shader = preload("res://shaders/canopy_sheet.gdshader")
	hood.material_override = hood_finish
	# Folded seams and underside stiffeners inherit the sheet slope exactly.
	for index in range(7):
		var seam = world.block(Vector3.ZERO, Vector3(0.026, 0.035, 1.10), "929b90", false)
		seam.reparent(hood, false)
		seam.position = Vector3(-2.04 + index * 0.68, 0.042, 0)
	for depth in [-0.37, 0.37]:
		var stiffener = world.block(Vector3.ZERO, Vector3(4.65, 0.055, 0.045), "65776f", false)
		stiffener.reparent(hood, false)
		stiffener.position = Vector3(0, -0.05, depth)
	world.block(at + Vector3(0, 3.10, 8.10), Vector3(4.88, 0.16, 0.045), "465a61", false)
	for side in [-1.0, 1.0]:
		var bracket = world.block(at + Vector3(side * 2.28, 2.98, 7.62), Vector3(0.065, 0.08, 0.94), "424b49", false)
		bracket.rotation.x = -0.38
	# The imported facade already includes the roll-up shutter housing.

static func drainage_pipe_mesh() -> ArrayMesh:
	# Hollow precast drainage sections give the workshop yard a readable purpose.
	# Four ring surfaces share real mesh collision, including the open bore.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(48):
		var a := float(segment) * TAU / 48.0
		var b := float(segment + 1) * TAU / 48.0
		var outer_a := Vector2(cos(a), sin(a)) * 0.88
		var outer_b := Vector2(cos(b), sin(b)) * 0.88
		var inner_a := Vector2(cos(a), sin(a)) * 0.66
		var inner_b := Vector2(cos(b), sin(b)) * 0.66
		var points := [
			Vector3(outer_a.x, outer_a.y, -1.8), Vector3(outer_b.x, outer_b.y, -1.8),
			Vector3(outer_a.x, outer_a.y, 1.8), Vector3(outer_b.x, outer_b.y, 1.8),
			Vector3(inner_a.x, inner_a.y, -1.8), Vector3(inner_b.x, inner_b.y, -1.8),
			Vector3(inner_a.x, inner_a.y, 1.8), Vector3(inner_b.x, inner_b.y, 1.8)]
		for quad in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3]]:
			for index in [0, 1, 2, 0, 2, 3]:
				var vertex: Vector3 = points[quad[index]]
				var normal := Vector3(vertex.x, vertex.y, 0).normalized()
				if quad[0] == 4:
					normal = -normal
				elif quad[0] == 0 and quad[1] == 1:
					normal = Vector3(0, 0, -1)
				elif quad[0] == 2:
					normal = Vector3(0, 0, 1)
				surface.set_normal(normal)
				surface.set_uv(Vector2(vertex.x + vertex.z, vertex.y + vertex.z) * 0.7)
				surface.add_vertex(vertex)
	# Reuse identical vertex attributes across adjoining triangles on mobile.
	# Index after assigning normals to preserve the hard rim edges and open bore.
	if OS.has_feature("android"):
		surface.index()
		surface.optimize_indices_for_cache()
	return surface.commit()

static func drainage_material_yards(world) -> void:
	var pipe_mesh := drainage_pipe_mesh()
	var concrete := ShaderMaterial.new()
	concrete.shader = load("res://shaders/precast_concrete.gdshader")
	concrete.set_shader_parameter("concrete_texture", load("res://assets/realism/concrete_albedo.jpg"))
	var random := RandomNumberGenerator.new()
	random.seed = 133082
	for center in [Vector3(-19, 0, 34), Vector3(17, 0, 17)]:
		world.ground_obstacles.append(Rect2(center.x - 3.2, center.z - 2.2, 6.4, 4.4))
		for offset in [Vector3(-0.9, 0.9, 0), Vector3(0.9, 0.9, 0.15),
				Vector3(0, 2.43, 0.05)]:
			var pipe := MeshInstance3D.new()
			pipe.name = "PrecastDrainagePipe"
			pipe.mesh = pipe_mesh
			pipe.material_override = concrete
			pipe.position = center + offset
			world.add_child(pipe)
			pipe.create_trimesh_collision()
		# Timber chocks keep the bottom row visibly supported.
		for side in [-1.0, 1.0]:
			for z in [-1.2, 1.2]:
				world.block(center + Vector3(side * 1.68, 0.15, z),
					Vector3(0.26, 0.3, 0.65), "74664e")
		# Low, separated colonies expose the cast wall and timber chocks.
		# Dense oversized cards previously read as fur attached to the pipes.
		for i in range(48):
			var angle := random.randf_range(0.15, PI - 0.15)
			var radius := random.randf_range(3.0, 5.0)
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb").instantiate()
			plant.position = center + Vector3(cos(angle) * radius, 0.025, -sin(angle) * radius)
			plant.rotation.y = random.randf() * TAU
			plant.scale = Vector3.ONE * random.randf_range(0.65, 1.15)
			world.add_child(plant)

static func roadside_outcrops(world) -> void:
	# Low scanned rock groups connect the foreground verge to the shelter belt.
	# Detailed collision follows the visible mesh; these never occupy door routes.
	var random := RandomNumberGenerator.new()
	random.seed = 132041
	for center in [Vector3(-13.8, 0, 42), Vector3(-16, 0, 28),
			Vector3(-15, 0, -11), Vector3(13.5, 0, -32)]:
		for i in range(5):
			var rock: Node3D = vegetation_scene("res://assets/realism/boulder.glb").instantiate()
			rock.name = "VergeOutcrop"
			rock.position = center + Vector3(i * 0.64 - 1.28, -0.16, random.randf_range(-0.85, 0.85))
			rock.rotation = Vector3(random.randf_range(-0.22, 0.22), random.randf() * TAU, random.randf_range(-0.18, 0.18))
			var stone_size := random.randf_range(0.48, 0.85) if i < 3 else random.randf_range(0.22, 0.40)
			rock.scale = Vector3(1.0, 0.46, 0.78) * stone_size
			world.add_child(rock)
			for mesh in rock.find_children("*", "MeshInstance3D", true, false):
				mesh.create_trimesh_collision()
		# Fine grass and scattered low shrubs soften the rock/soil junction.
		for i in range(64):
			var angle := random.randf() * TAU
			var radius := random.randf_range(0.65, 2.8)
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 5 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			plant.position = center + Vector3(cos(angle) * radius, 0.025, sin(angle) * radius)
			plant.rotation.y = random.randf() * TAU
			plant.scale = Vector3.ONE * random.randf_range(0.45, 1.10)
			world.add_child(plant)
		# Tussocks follow the actual verge surface rather than the global zero
		# plane. Cluster them at rock toes, leaving irregular patches of stone
		# exposed instead of surrounding the outcrop with an even green ring.
		var roots := RandomNumberGenerator.new()
		roots.seed = 371041 + int(center.z * 10.0)
		for i in range(94):
			var lobe := Vector2(-0.95, 0.55) if i < 55 else Vector2(0.85, -0.70)
			var angle := roots.randf() * TAU
			var radius := sqrt(roots.randf())
			var point := Vector2(center.x, center.z) + lobe + Vector2(cos(angle)*1.15, sin(angle)*0.75)*radius
			var plant: Node3D = load("res://assets/realism/grass_fine.glb" if i % 7 else "res://assets/realism/grass_broadleaf.glb").instantiate()
			plant.name = "OutcropRootTussock"
			plant.position = Vector3(point.x, verge_height(point) + 0.012, point.y)
			plant.rotation.y = roots.randf() * TAU
			var spread := roots.randf_range(0.45, 0.85)
			plant.scale = Vector3(spread, roots.randf_range(0.42, 0.85), spread)
			world.add_child(plant)
		for offset in [Vector3(-1.7, 0, -0.8), Vector3(0.5, 0, -1.5)]:
			var shrub: Node3D = vegetation_scene("res://assets/realism/verge_fine_shrub.glb").instantiate()
			shrub.position = center + offset
			shrub.rotation.y = random.randf() * TAU
			shrub.scale = Vector3.ONE * random.randf_range(0.48, 0.75)
			world.add_child(shrub)

static func workyard_round_fitting(world, start: Vector3, end: Vector3, radius: float, color: String) -> MeshInstance3D:
	var fitting := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = start.distance_to(end)
	tube.radial_segments = 24
	if OS.has_feature("android"):
		tube.rings = 0
	fitting.mesh = tube
	fitting.position = (start + end) * 0.5
	fitting.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	fitting.material_override = world.mat(color)
	world.add_child(fitting)
	return fitting

static func tank_head_exterior(dome: SphereMesh, end: float) -> ArrayMesh:
	# Keep the original vertex attributes and rim-crossing triangles. Only
	# remove triangles wholly inside the closed 64-sided tank cylinder.
	# Its inscribed circle is a conservative bound regardless of orientation.
	var arrays := dome.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	var inner_radius := 1.12 * cos(PI / 64.0)
	for offset in range(0, indices.size(), 3):
		var internal := true
		for corner in range(3):
			var point := vertices[indices[offset + corner]]
			var axial := end * (end * 2.3 + point.y * 0.24)
			if axial >= 2.3 or axial <= -2.3 or Vector2(point.x, point.z).length() >= inner_radius:
				internal = false
				break
		if not internal:
			kept.append_array(indices.slice(offset, offset + 3))
	arrays[Mesh.ARRAY_INDEX] = kept
	var exterior := ArrayMesh.new()
	exterior.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return exterior

static func workshop_workyard(world) -> void:
	# Service-water tank sits east of the loading route. Curved shell and
	# collision share geometry; fittings and guardrails give human scale.
	var bounds: Array = world.get_meta("hardscape_bounds", [])
	bounds.append(Rect2(-27, 40, 8, 7))
	world.set_meta("hardscape_bounds", bounds)
	var slab = world.block(Vector3(-23, 0.025, 43), Vector3(7.5, 0.05, 5.7), "a5a69a", false)
	slab.material_override = world.mat("a5a69a")
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://shaders/workyard_tank.gdshader")
	var shell := MeshInstance3D.new()
	shell.name = "WorkshopServiceTank"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.12
	cylinder.bottom_radius = 1.12
	cylinder.height = 4.6
	cylinder.radial_segments = 64
	if OS.has_feature("android"):
		cylinder.rings = 0
	shell.mesh = cylinder
	shell.position = Vector3(-23, 1.72, 43)
	shell.rotation.z = PI / 2
	shell.material_override = paint
	world.add_child(shell)
	shell.create_trimesh_collision()
	# Dished welded heads catch the sun around the rim instead of presenting
	# a flat primitive disk. Collision follows the added curved surface.
	for end in [-1.0, 1.0]:
		var head := MeshInstance3D.new()
		head.name = "DishedTankHead"
		var dome := SphereMesh.new()
		dome.radius = 1.12
		dome.height = 2.24
		dome.radial_segments = 48
		dome.rings = 24
		head.mesh = dome
		head.position = Vector3(0, end * 2.3, 0)
		head.scale = Vector3(1, 0.24, 1)
		head.material_override = paint
		shell.add_child(head)
		head.create_trimesh_collision()
		if OS.has_feature("android"):
			head.mesh = tank_head_exterior(dome, end)
		var weld := MeshInstance3D.new()
		var bead := TorusMesh.new()
		bead.inner_radius = 1.105
		bead.outer_radius = 1.135
		bead.rings = 64
		bead.ring_segments = 8
		weld.mesh = bead
		weld.position = Vector3(0, end * 2.3, 0)
		weld.material_override = world.mat("66716a")
		shell.add_child(weld)
	for x in [-24.65, -21.35]:
		world.block(Vector3(x, 0.34, 43), Vector3(0.45, 0.68, 2.1), "89877b")
		var band := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 1.11
		ring.outer_radius = 1.16
		ring.rings = 64
		ring.ring_segments = 8
		band.mesh = ring
		band.position = Vector3(x, 1.72, 43)
		band.rotation.z = PI / 2
		band.material_override = world.mat("424b49")
		world.add_child(band)
	# Raised circular manway, bolted cover and a real round delivery line.
	workyard_round_fitting(world, Vector3(-23, 2.75, 43), Vector3(-23, 3.04, 43), 0.29, "59645e")
	workyard_round_fitting(world, Vector3(-23, 3.04, 43), Vector3(-23, 3.12, 43), 0.39, "424b49")
	for i in range(8):
		var angle := float(i) * TAU / 8
		var bolt := Vector3(-23 + cos(angle) * 0.33, 3.12, 43 + sin(angle) * 0.33)
		workyard_round_fitting(world, bolt, bolt + Vector3(0, 0.045, 0), 0.025, "92958b")
	workyard_round_fitting(world, Vector3(-20.85, 1.25, 43.55), Vector3(-19.8, 1.25, 43.55), 0.095, "65736a")
	workyard_round_fitting(world, Vector3(-19.8, 0.18, 43.55), Vector3(-19.8, 1.34, 43.55), 0.095, "65736a")
	for x in [-20.5, -20.35]:
		workyard_round_fitting(world, Vector3(x, 1.25, 43.55), Vector3(x + 0.06, 1.25, 43.55), 0.18, "424b49")
	workyard_round_fitting(world, Vector3(-20.05, 1.25, 43.55), Vector3(-20.05, 1.25, 43.88), 0.04, "92958b")
	var wheel := MeshInstance3D.new()
	var wheel_ring := TorusMesh.new()
	wheel_ring.inner_radius = 0.18
	wheel_ring.outer_radius = 0.215
	wheel_ring.rings = 32
	wheel_ring.ring_segments = 8
	wheel.mesh = wheel_ring
	wheel.position = Vector3(-20.05, 1.25, 43.9)
	wheel.rotation.x = PI / 2
	wheel.material_override = world.mat("854d36")
	world.add_child(wheel)
	for axis in [Vector3(0.19, 0, 0), Vector3(0, 0.19, 0)]:
		workyard_round_fitting(world, wheel.position - axis, wheel.position + axis, 0.018, "854d36")
	workyard_round_fitting(world, Vector3(-20.5, 2.1, 43), Vector3(-20.18, 2.1, 43), 0.065, "59645e")
	workyard_round_fitting(world, Vector3(-20.18, 2.1, 43), Vector3(-20.18, 2.42, 43), 0.045, "59645e")
	workyard_round_fitting(world, Vector3(-20.25, 2.45, 43), Vector3(-20.10, 2.45, 43), 0.19, "424b49")
	workyard_round_fitting(world, Vector3(-20.095, 2.45, 43), Vector3(-20.08, 2.45, 43), 0.155, "d5d0b4")
	workyard_round_fitting(world, Vector3(-20.065, 2.45, 43), Vector3(-20.065, 2.54, 43.07), 0.009, "343b38")
	# Front access ladder, anchored feet and open steel saddle ribs break the
	# primitive silhouette at the normal workshop approach camera distance.
	for x in [-24.05, -23.43]:
		workyard_round_fitting(world, Vector3(x, 0.08, 44.28), Vector3(x, 3.32, 44.05), 0.035, "899087")
		world.block(Vector3(x, 0.09, 44.28), Vector3(0.18, 0.1, 0.23), "424b49", false)
	for i in range(10):
		var y := 0.28 + i * 0.29
		var z := 44.28 - (y - 0.08) / 3.24 * 0.23
		workyard_round_fitting(world, Vector3(-24.05, y, z), Vector3(-23.43, y, z), 0.025, "899087")
	for x in [-24.65, -21.35]:
		world.block(Vector3(x, 0.14, 43), Vector3(0.85, 0.12, 2.35), "424b49", false)
		for z in [42.2, 43.8]:
			world.block(Vector3(x, 0.62, z), Vector3(0.12, 0.82, 0.14), "59645e", false)
	world.block(Vector3(-20.1, 0.76, 44.5), Vector3(0.75, 1.5, 0.48), "465a61")
	for x in [-25.4, -22.525, -19.65]:
		world.block(Vector3(x, 0.6, 45.45), Vector3(0.09, 1.2, 0.09), "59645e")
	for y in [0.5, 1.05]:
		world.block(Vector3(-22.525, y, 45.45), Vector3(5.75, 0.07, 0.07), "59645e")
	# A shielded task light models the tank underside/supports at dusk.
	var light := SpotLight3D.new()
	light.position = Vector3(-25.4, 3.8, 44.5)
	light.rotation_degrees = Vector3(-55, -65, 0)
	light.light_color = Color("ffe5bd")
	light.light_energy = 2.0
	light.spot_range = 8
	light.spot_angle = 55
	light.shadow_enabled = true
	world.add_child(light)
	world.block(Vector3(-25.4, 1.9, 44.5), Vector3(0.09, 3.8, 0.09), "424b49")
	world.block(Vector3(-25.4, 3.8, 44.5), Vector3(0.4, 0.14, 0.3), "424b49", false)
	var random := RandomNumberGenerator.new()
	random.seed = 138041
	# Broken continuous verge, with taller growth against the equipment apron
	# and low gaps along the walking edge, instead of three circular islands.
	for i in range(320):
		var x := random.randf_range(-29.5, -6.2)
		var edge := 46.0 + sin(x * 0.41) * 0.48
		var z := edge + random.randf_range(-0.35, 2.4)
		if sin(x * 1.3) > 0.82 and random.randf() > 0.25:
			continue
		var broadleaf := i % 7 == 0
		var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if broadleaf else "res://assets/realism/grass_fine.glb").instantiate()
		plant.position = Vector3(x, 0.02, z)
		plant.rotation.y = random.randf() * TAU
		var size := random.randf_range(0.55, 0.95) if broadleaf else random.randf_range(0.85, 1.55)
		plant.scale = Vector3(size * 1.3, size * random.randf_range(0.28, 0.55), size * 1.3)
		world.add_child(plant)

	# Foreground colonies follow the bank, leaving the road and apron unobstructed.
	# Broadleaf rosettes break up the repeated upright grass silhouette.
	for i in range(1120):
		var colony := i % 9
		var center := Vector2(-34.0 + float(colony % 5) * 3.3, 50.0 + float(colony / 5) * 4.0 + sin(float(colony) * 2.37) * 1.9)
		var angle := random.randf() * TAU
		var radius := sqrt(random.randf()) * 3.6
		var point := center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.65)
		var broadleaf := i % 7 == 0
		var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if broadleaf else "res://assets/realism/grass_fine.glb").instantiate()
		plant.position = Vector3(point.x, 0.015, point.y)
		plant.rotation = Vector3(random.randf_range(-0.16, 0.16), angle, random.randf_range(-0.18, 0.18))
		var size := random.randf_range(0.6, 1.0) if broadleaf else random.randf_range(0.75, 1.35)
		plant.scale = Vector3(size, size * (0.8 if broadleaf else 0.65), size)
		world.add_child(plant)

static func workshop_service_bay(world) -> void:
	# Lower east-side repair bay: open on two sides, distinct from the high hall.
	# A flush apron gives foot traffic continuous access without hidden steps.
	var bounds: Array = world.get_meta("hardscape_bounds", [])
	bounds.append(Rect2(-34, 26, 10, 17))
	world.set_meta("hardscape_bounds", bounds)
	var bay_concrete := ShaderMaterial.new()
	bay_concrete.shader = preload("res://shaders/warehouse_concrete.gdshader")
	bay_concrete.set_shader_parameter("building_origin", Vector3(-30, 0, 33.5))
	bay_concrete.set_shader_parameter("service_bay", true)
	var steel := ShaderMaterial.new()
	steel.shader = load("res://shaders/shelter_structural_steel.gdshader")
	# A continuous cast apron with shader saw cuts replaces the paving grid.
	var slab = world.block(Vector3(-29, 0.012, 34),
		Vector3(10.0, 0.018, 16.0), "a5a69a", false)
	slab.material_override = bay_concrete
	# Low pioneer plants follow the open gravel margin, leaving the aisle
	# and both approaches free. Uneven colonies avoid a planted hedge.
	var verge_random := RandomNumberGenerator.new()
	verge_random.seed = 380
	for i in range(120):
		var z := verge_random.randf_range(27.5, 39.6)
		if z > 32.0 and z < 35.7:
			continue
		var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 5 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
		plant.position = Vector3(-23.7 + verge_random.randf_range(-0.22, 0.60), 0.02, z)
		plant.rotation.y = verge_random.randf() * TAU
		var size := verge_random.randf_range(0.55, 1.10)
		plant.scale = Vector3(size, size * 0.48, size)
		world.add_child(plant)
	var shoulder := MeshInstance3D.new()
	shoulder.name = "WorkshopGravelShoulder"
	var shoulder_mesh := PlaneMesh.new()
	shoulder_mesh.size = Vector2(12, 18)
	shoulder.mesh = shoulder_mesh
	shoulder.position = Vector3(-29, 0.037, 34)
	var gravel := ShaderMaterial.new()
	gravel.shader = load("res://shaders/yard_gravel.gdshader")
	gravel.set_shader_parameter("half_extent", Vector2(5, 8))
	gravel.set_shader_parameter("gravel", load("res://assets/realism/terrain_rock_albedo.jpg"))
	gravel.set_shader_parameter("soil", load("res://assets/realism/ground_albedo.jpg"))
	shoulder.material_override = gravel
	shoulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(shoulder)
	# Two glazed strips break up the sheet roof and admit daylight over the
	# aisle. All five roof sections retain physical cover collision.
	var sheet := ShaderMaterial.new()
	sheet.shader = load("res://shaders/workshop_bay_roof.gdshader")
	for span in [Vector2(26.1, 29.8), Vector2(32.2, 35.6), Vector2(38.0, 40.9)]:
		var roof = world.block(Vector3(-30, 3.75, (span.x + span.y) * 0.5),
			Vector3(8.3, 0.12, span.y - span.x), "465a61")
		roof.rotation.z = -0.12
		roof.name = "WorkshopServiceBayRoof"
		roof.material_override = sheet
	var glazing := ShaderMaterial.new()
	glazing.shader = load("res://shaders/workshop_roof_glazing_mobile.gdshader") if OS.has_feature("android") else load("res://shaders/workshop_roof_glazing.gdshader")
	for center_z in [31.0, 36.8]:
		var pane = world.block(Vector3(-30, 3.78, center_z), Vector3(8.3, 0.035, 2.4), "a8c4be")
		pane.rotation.z = -0.12
		pane.material_override = glazing
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for edge_z in [center_z - 1.2, center_z + 1.2]:
			var curb = world.block(Vector3(-30, 3.79, edge_z), Vector3(8.3, 0.14, 0.065), "59645e")
			curb.rotation.z = -0.12
			curb.material_override = steel
		# Narrow glazing bars divide full-width sheets into supported panels.
		for bar_x in [-32.7, -30.0, -27.3]:
			var bar = world.block(Vector3(bar_x, 3.82 - (bar_x + 30.0) * sin(0.12), center_z),
				Vector3(0.045, 0.055, 2.4), "59645e", false)
			bar.name = "WorkshopRooflightGlazingBar"
			bar.material_override = steel
		# Diffuse daylight admitted by each translucent roof strip. Small
		# local pools retain the shaded bay, with shadows on tools/structure.
		var skylight := SpotLight3D.new()
		skylight.name = "WorkshopRoofstripDaylight"
		skylight.position = Vector3(-29.5, 3.49, center_z)
		skylight.rotation_degrees.x = -90.0
		skylight.light_color = Color("dce6eb")
		skylight.light_energy = 2.0
		skylight.spot_range = 5.8
		skylight.spot_angle = 76.0
		skylight.spot_attenuation = 0.55
		skylight.shadow_enabled = true
		world.add_child(skylight)
	# Folded wall abutment: upstand, roof lap and drip terminate the lean-to
	# against the tall workshop instead of sheets disappearing into the wall.
	for fold in [Vector3(-33.92, 4.31, 33.5), Vector3(-33.77, 4.24, 33.5),
		Vector3(-33.62, 4.20, 33.5)]:
		var flashing = world.block(fold,
			Vector3(0.035, 0.22, 14.85) if fold.x < -33.9 else Vector3(0.30, 0.035, 14.85),
			"59645e", false)
		flashing.material_override = steel
		if fold.x > -33.9:
			flashing.rotation.z = -0.12
	# Open cold-formed C sections: thin web, two flanges and return lips.
	# Open side faces the yard so the section reads from the normal bay camera.
	for x in [-32.7, -30.0, -27.3]:
		var center_y: float = 3.56 - (x + 30) * sin(0.12)
		var web = world.block(Vector3(x - 0.05, center_y, 33.5), Vector3(0.012, 0.18, 14.8), "59645e")
		web.material_override = steel
		for offset_y in [-0.09, 0.09]:
			var flange = world.block(Vector3(x, center_y + offset_y, 33.5), Vector3(0.11, 0.012, 14.8), "59645e")
			flange.material_override = steel
			var lip = world.block(Vector3(x + 0.05, center_y + offset_y * 0.83, 33.5), Vector3(0.012, 0.035, 14.8), "59645e")
			lip.material_override = steel
	for z in [27.0, 33.5, 40.0]:
		# Rolled I columns: real flanges/web and real open-profile collision.
		for flange_x in [-26.39, -26.21]:
			var flange = world.block(Vector3(flange_x, 1.62, z), Vector3(0.025, 3.24, 0.22), "424b49")
			flange.material_override = steel
		var web = world.block(Vector3(-26.3, 1.62, z), Vector3(0.16, 3.24, 0.025), "424b49")
		web.material_override = steel
		world.block(Vector3(-26.3, 0.08, z), Vector3(0.4, 0.16, 0.4), "a5a69a")
		var beam = world.block(Vector3(-30, 3.62, z), Vector3(8, 0.19, 0.035), "424b49")
		beam.rotation.z = -0.12
		beam.material_override = steel
		for height in [3.52, 3.72]:
			var flange = world.block(Vector3(-30, height, z), Vector3(8, 0.025, 0.20), "424b49")
			flange.rotation.z = -0.12
			flange.material_override = steel
		var brace = world.block(Vector3(-26.65, 2.97, z), Vector3(0.12, 0.95, 0.12), "424b49")
		brace.rotation.z = -0.7
		brace.material_override = steel
	# Folded eave channel replaces the solid rectangular fascia.
	var eave_web = world.block(Vector3(-26.22, 3.32, 33.5), Vector3(0.014, 0.22, 15), "59645e")
	eave_web.material_override = steel
	for height in [3.21, 3.43]:
		var eave_flange = world.block(Vector3(-26.15, height, 33.5), Vector3(0.16, 0.014, 15), "59645e")
		eave_flange.material_override = steel
	for z in range(25):
		var rib_z: float = 26.3 + z * 0.6
		if (rib_z > 29.8 and rib_z < 32.2) or (rib_z > 35.6 and rib_z < 38.0):
			continue
		var rib = world.block(Vector3(-30, 3.84, rib_z), Vector3(8.3, 0.04, 0.03), "59645e", false)
		rib.rotation.z = -0.12
		rib.material_override = sheet
	# Folded gutter and closed end caps make the low eave readable from the yard.
	world.block(Vector3(-26.04, 3.25, 33.5), Vector3(0.28, 0.06, 15.1), "424b49")
	world.block(Vector3(-25.91, 3.32, 33.5), Vector3(0.035, 0.18, 15.1), "59645e")
	for end_z in [25.96, 41.04]:
		world.block(Vector3(-26.04, 3.32, end_z), Vector3(0.28, 0.18, 0.04), "59645e")
	# Square rain leader stays beside the rear post, outside the open bay aisle.
	world.block(Vector3(-26.04, 1.63, 27.0), Vector3(0.10, 3.2, 0.10), "59645e")
	for height in [0.45, 1.65, 2.85]:
		world.block(Vector3(-26.04, height, 27.0), Vector3(0.13, 0.05, 0.13), "424b49", false)
	# A masonry back wall and its coping provide usable cover inside the bay.
	var back_wall = world.block(Vector3(-30, 1.3, 26.5), Vector3(7.5, 2.6, 0.24), "a5a69a")
	var masonry := ShaderMaterial.new()
	masonry.shader = load("res://shaders/workshop_masonry.gdshader")
	back_wall.material_override = masonry
	world.block(Vector3(-30, 2.65, 26.5), Vector3(7.7, 0.12, 0.36), "89877b")
	# Dusty industrial glazing, deep sills and small rain hoods give the
	# previously blank end wall human scale. The sealed wall remains cover.
	var end_glass := ShaderMaterial.new()
	end_glass.shader = load("res://shaders/workshop_glass.gdshader")
	for window_x in [-28.15]:
		var pane = world.block(Vector3(window_x, 1.83, 26.655),
			Vector3(2.72, 1.12, 0.045), "748782", false)
		pane.material_override = end_glass
		for dx in [-1.40, -0.47, 0.47, 1.40]:
			var mullion = world.block(Vector3(window_x + dx, 1.83, 26.70),
				Vector3(0.055, 1.22, 0.095), "424b49", false)
			mullion.material_override = steel
		for height in [1.23, 1.83, 2.43]:
			var rail = world.block(Vector3(window_x, height, 26.70),
				Vector3(2.85, 0.055, 0.095), "424b49", false)
			rail.material_override = steel
		var sill = world.block(Vector3(window_x, 1.18, 26.76),
			Vector3(2.98, 0.08, 0.38), "89877b", false)
		sill.material_override = masonry
		var hood = world.block(Vector3(window_x, 2.53, 26.83),
			Vector3(3.04, 0.035, 0.54), "59645e", false)
		hood.rotation.x = 0.10
		hood.material_override = steel
		# A broad, low-energy bounce lights the wall beneath the roof.
		var wall_bounce := SpotLight3D.new()
		wall_bounce.position = Vector3(window_x, 3.0, 28.8)
		wall_bounce.rotation_degrees.x = -24.0
		wall_bounce.light_color = Color("d6e0db")
		wall_bounce.light_energy = 0.65
		wall_bounce.spot_range = 4.0
		wall_bounce.spot_angle = 58.0
		wall_bounce.shadow_enabled = true
		world.add_child(wall_bounce)
	# The parts-store end is ventilated rather than a second identical window.
	# Recessed blades sit against the existing solid cover wall.
	world.block(Vector3(-31.85, 1.89, 26.66), Vector3(2.6, 0.96, 0.045), "202c2c", false)
	for i in range(9):
		var blade = world.block(Vector3(-31.85, 1.49 + i * 0.10, 26.73),
			Vector3(2.62, 0.035, 0.16), "59645e", false)
		blade.rotation.x = -0.42
		blade.material_override = steel
	# Flush trench grating collects runoff at the exposed apron edge.
	# No raised collider: the walking surface remains continuous.
	world.block(Vector3(-24.65, 0.024, 34), Vector3(0.32, 0.006, 15.5), "171c1a", false)
	for x in [-24.83, -24.47]:
		var rim = world.block(Vector3(x, 0.032, 34), Vector3(0.035, 0.016, 15.5), "59645e", false)
		rim.material_override = steel
	for i in range(130):
		var bar = world.block(Vector3(-24.65, 0.032, 26.3 + i * 0.12),
			Vector3(0.32, 0.016, 0.035), "59645e", false)
		bar.material_override = steel
	for z in [29.0, 37.0]:
		if z == 29.0:
			# Full-height open parts shelving replaces the duplicated tool bench.
			# All solids remain inside its previous one-metre-deep footprint.
			for dz in [-1.24, 1.24]:
				for x in [-33.42, -32.58]:
					var upright = world.block(Vector3(x, 1.18, z + dz),
						Vector3(0.055, 2.36, 0.055), "59645e")
					upright.material_override = steel
			for level in [0.22, 0.86, 1.5, 2.14]:
				var shelf = world.block(Vector3(-33, level, z),
					Vector3(0.94, 0.045, 2.6), "59645e")
				shelf.material_override = steel
				# Open-front folded bins: silhouettes and dark cavities remain
				# visible from the normal aisle camera.
				for slot in range(3 if level < 1.0 else 2):
					var bin_z: float = z - 0.84 + slot * 0.78
					var tint := "686b5a" if slot % 2 == 0 else "59645e"
					world.block(Vector3(-33.30, level + 0.21, bin_z),
						Vector3(0.035, 0.38, 0.62), tint)
					world.block(Vector3(-33.04, level + 0.045, bin_z),
						Vector3(0.55, 0.045, 0.62), tint)
					for side in [-0.3, 0.3]:
						world.block(Vector3(-33.04, level + 0.21, bin_z + side),
							Vector3(0.55, 0.38, 0.025), tint)
					world.block(Vector3(-32.76, level + 0.10, bin_z),
						Vector3(0.025, 0.14, 0.62), tint)
					world.block(Vector3(-32.743, level + 0.105, bin_z),
						Vector3(0.008, 0.06, 0.18), "c2bd9c", false)
			var store_light := OmniLight3D.new()
			store_light.position = Vector3(-31.8, 2.6, z)
			store_light.light_color = Color("d6e0db")
			store_light.light_energy = 0.48
			store_light.omni_range = 3.4
			store_light.shadow_enabled = true
			world.add_child(store_light)
			continue
		# Full-size tool panels distinguish the two working stations from an
		# empty shed. Thin folded panels and hanging tools preserve the aisle.
		var panel = world.block(Vector3(-33.57, 1.65, z), Vector3(0.045, 1.35, 2.65), "526461")
		panel.material_override = steel
		for h in [1.05, 2.25]:
			world.block(Vector3(-33.52, h, z), Vector3(0.075, 0.045, 2.72), "89877b", false)
		for i in range(7):
			var tool_z: float = z - 0.97 + i * 0.31
			var bottom: float = 1.30 + (i % 3) * 0.08
			workyard_round_fitting(world, Vector3(-33.46, bottom, tool_z),
				Vector3(-33.46, 1.94, tool_z), 0.018, "8f9893")
			world.block(Vector3(-33.46, 1.92, tool_z),
				Vector3(0.04, 0.07, 0.10), "8f9893", false)
		var task_light := OmniLight3D.new()
		task_light.position = Vector3(-33.0, 2.22, z)
		task_light.light_color = Color("ffe2b3")
		task_light.light_energy = 0.55
		task_light.omni_range = 2.0
		task_light.shadow_enabled = true
		world.add_child(task_light)
		var top = world.block(Vector3(-33.0, 0.86, z), Vector3(1.0, 0.055, 2.6), "59645e")
		top.material_override = steel
		for dx in [-0.38, 0.38]:
			for dz in [-1.1, 1.1]:
				var leg = world.block(Vector3(-33 + dx, 0.41, z + dz), Vector3(0.065, 0.82, 0.065), "424b49")
				leg.material_override = steel
		# Slatted shelf retains visible space under the working surface.
		for slat in range(5):
			var shelf = world.block(Vector3(-33.32 + slat * 0.16, 0.22, z), Vector3(0.12, 0.035, 2.3), "424b49")
			shelf.material_override = steel
		for dz in [-1.12, 1.12]:
			world.block(Vector3(-33, 0.76, z + dz), Vector3(0.82, 0.12, 0.04), "424b49")
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(-31.8, 3.15, z)
		lamp.light_color = Color("ffe8c9")
		lamp.rotation_degrees.x = -90
		lamp.light_energy = 1.6
		lamp.spot_range = 5.8
		lamp.spot_angle = 72.0
		lamp.spot_angle_attenuation = 0.7
		lamp.shadow_enabled = true
		world.add_child(lamp)
		world.block(Vector3(-31.8, 3.39, z), Vector3(0.38, 0.14, 1.3), "424b49", false)
		var fixture = world.block(Vector3(-31.8, 3.305, z), Vector3(0.24, 0.025, 1.12), "fff1da", false)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("b9b7a9")
		glow.emission_enabled = true
		glow.emission = Color("ffe8c9")
		glow.emission_energy_multiplier = 0.65
		fixture.material_override = glow

	# Broken clusters outside the east apron; the openings stay free of plants.
	var verge_rng := RandomNumberGenerator.new()
	verge_rng.seed = 30017
	for patch in [Vector3(27.4, 0.65, 4), Vector3(33.3, 0.85, 9), Vector3(41.3, 0.5, 3)]:
		for i in range(int(patch.z)):
			var herb: Node3D = load("res://assets/realism/grass_broadleaf.glb").instantiate()
			herb.position = Vector3(verge_rng.randf_range(-23.9, -23.1), 0.0,
				patch.x + verge_rng.randf_range(-patch.y, patch.y))
			herb.rotation.y = verge_rng.randf_range(0.0, TAU)
			herb.scale *= verge_rng.randf_range(0.35, 0.65)
			herb.scale.y *= verge_rng.randf_range(0.65, 0.95)
			world.add_child(herb)
	for i in range(64):
		var z := verge_rng.randf_range(27.0, 42.0)
		if abs(z - 30.5) < 1.7 or abs(z - 36.5) < 1.7:
			continue
		var plant: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
		plant.position = Vector3(verge_rng.randf_range(-24.0, -22.4), 0.0, z)
		plant.rotation.y = verge_rng.randf_range(0.0, TAU)
		plant.scale *= verge_rng.randf_range(0.55, 1.2)
		world.add_child(plant)
	# Low irregular tufts at the apron ends soften the hard rectangle while
	# leaving the front approach and the two side crossings unobstructed.
	for corner in [Vector3(-24.1, 0, 42.2), Vector3(-24.0, 0, 26.0),
			Vector3(-26.05, 0, 40.25), Vector3(-26.0, 0, 27.15)]:
		for i in range(20):
			var tuft = load("res://assets/realism/grass_fine.glb").instantiate()
			tuft.position = corner + Vector3(verge_rng.randf_range(-0.25, 0.75), 0,
				verge_rng.randf_range(-0.4, 0.4))
			tuft.rotation.y = verge_rng.randf_range(0, TAU)
			tuft.scale *= verge_rng.randf_range(0.35, 0.75)
			world.add_child(tuft)

static func utility_station(world, at: Vector3) -> void:
	# A distinct service station in the middle distance. The central four-metre
	# doorway and through aisle remain clear; solid roof/posts stop shots.
	var roof = world.block(at + Vector3(0, 3.55, 8.6), Vector3(16.8, 0.12, 4.8), "59665f")
	roof.rotation.x = 0.12
	for x in [-7.5, 7.5]:
		world.block(at + Vector3(x, 1.65, 10.6), Vector3(0.18, 3.3, 0.18), "454e48")
		world.block(at + Vector3(x, 0.1, 10.6), Vector3(0.42, 0.2, 0.42), "8b897a")
	world.block(at + Vector3(0, 3.28, 10.6), Vector3(16.6, 0.22, 0.15), "454e48")
	for i in range(29):
		var rib = world.block(at + Vector3(-8.2 + i * 0.58, 3.635, 8.6), Vector3(0.03, 0.055, 4.8), "65726a", false)
		rib.rotation.x = 0.12
	# Broad masonry flue with a stepped cap, offset from the entrance axis.
	world.block(at + Vector3(-6.4, 5.2, -4.5), Vector3(1.45, 10.4, 1.55), "80776a")
	world.block(at + Vector3(-6.4, 10.45, -4.5), Vector3(1.75, 0.22, 1.85), "555c56")
	world.block(at + Vector3(-6.4, 10.78, -4.5), Vector3(1.2, 0.45, 1.3), "444c46")
	world.block(at + Vector3(-6.4, 11.05, -4.5), Vector3(1.9, 0.14, 2.0), "62685f")
	for x in [-5.2, 5.2]:
		world.block(at + Vector3(x, 3.25, 7.4), Vector3(1.1, 0.12, 0.25), "555a50", false)
		var lamp := SpotLight3D.new()
		lamp.position = at + Vector3(x, 3.15, 7.4)
		lamp.rotation_degrees.x = -90
		lamp.light_color = Color("ffe0ab")
		lamp.light_energy = 2.2
		lamp.spot_range = 7
		lamp.spot_angle = 68
		lamp.shadow_enabled = true
		world.add_child(lamp)

static func arrival_canopy(world) -> void:
	# Roadside waiting/loading bay: two open ends and an unobstructed road.
	var steel := ShaderMaterial.new()
	steel.shader = preload("res://shaders/shelter_structural_steel.gdshader")
	var roof_finish := ShaderMaterial.new()
	roof_finish.shader = preload("res://shaders/canopy_sheet.gdshader")
	var brick := ShaderMaterial.new()
	brick.shader = preload("res://shaders/workshop_masonry.gdshader")
	var concrete := ShaderMaterial.new()
	concrete.shader = preload("res://shaders/warehouse_concrete.gdshader")
	concrete.set_shader_parameter("building_origin", Vector3(-12, 0, 65))
	var apron = world.block(Vector3(-12, 0.02, 65), Vector3(7, 0.04, 12), "96978b", false)
	apron.material_override = concrete
	for z in [60.0, 65.0, 70.0]:
		for x in [-15.0, -9.0]:
			var height: float = 3.8 if x == -15.0 else 3.25
			world.block(Vector3(x, 0.12, z), Vector3(0.48, 0.24, 0.48), "96978b").material_override = concrete
			world.block(Vector3(x, height / 2, z), Vector3(0.085, height, 0.22), "45564e").material_override = steel
			for dz in [-0.11, 0.11]:
				world.block(Vector3(x, height / 2, z + dz), Vector3(0.22, height, 0.035), "45564e").material_override = steel
		var beam = world.block(Vector3(-12, 3.5, z), Vector3(6.5, 0.19, 0.14), "45564e")
		beam.rotation.z = -atan(0.55 / 6.0)
		beam.material_override = steel
	var roof = world.block(Vector3(-12, 3.67, 65), Vector3(7.0, 0.065, 11.6), "45564e")
	roof.rotation.z = -atan(0.55 / 6.0)
	roof.material_override = roof_finish
	# Secondary purlins, eaves and drain give the roof a readable underside
	# and cast structural shadows; everything stays above the walking volume.
	for x in [-14.2, -12.8, -11.4, -10.0]:
		world.block(Vector3(x, 3.54 - (x + 12) * 0.55 / 6, 65),
			Vector3(0.09, 0.16, 11.4), "45564e").material_override = steel
	for z in [59.25, 70.75]:
		var fascia = world.block(Vector3(-12, 3.64, z), Vector3(7.0, 0.22, 0.075), "45564e")
		fascia.rotation.z = -atan(0.55 / 6.0)
		fascia.material_override = steel
	# Open gutter profile on the low eave; the downpipe hugs an existing post.
	for offset in [-0.10, 0.10]:
		world.block(Vector3(-8.5 + offset, 3.30, 65), Vector3(0.025, 0.15, 11.7), "45564e").material_override = steel
	world.block(Vector3(-8.5, 3.23, 65), Vector3(0.22, 0.025, 11.7), "45564e").material_override = steel
	world.block(Vector3(-8.91, 1.61, 60), Vector3(0.075, 3.18, 0.075), "45564e").material_override = steel
	world.block(Vector3(-8.70, 3.17, 60), Vector3(0.49, 0.075, 0.075), "45564e").material_override = steel
	for x in [-15.4, -8.6]:
		world.block(Vector3(x, 3.67 - (x + 12) * 0.55 / 6, 65), Vector3(0.12, 0.15, 11.6), "45564e").material_override = steel
	world.block(Vector3(-15.1, 0.65, 65), Vector3(0.25, 1.3, 9.5), "72583f").material_override = brick
	world.block(Vector3(-15.1, 1.33, 65), Vector3(0.38, 0.09, 9.7), "96978b").material_override = concrete
	# A sheltered work wall, with daylight openings above the bench.
	for z in [61.7, 65.0, 68.3]:
		world.block(Vector3(-15.1, 1.88, z), Vector3(0.12, 1.0, 3.2), "45564e").material_override = steel
		world.block(Vector3(-15.1, 3.40, z), Vector3(0.12, 0.50, 3.2), "45564e").material_override = steel
		for edge in [-1.58, 1.58]:
			world.block(Vector3(-15.1, 2.76, z + edge), Vector3(0.16, 0.80, 0.10), "45564e").material_override = steel
		for rib in range(16):
			world.block(Vector3(-15.01, 1.88, z - 1.50 + rib * 0.20),
				Vector3(0.025, 0.98, 0.025), "45564e", false).material_override = steel
	world.block(Vector3(-12, 3.28, 70.83), Vector3(4.7, 0.56, 0.10), "34463f").material_override = steel
	var sign := Label3D.new()
	sign.text = "04  /  FIELD SERVICE"
	sign.font_size = 96
	sign.pixel_size = 0.0034
	sign.position = Vector3(-12, 3.28, 70.90)
	sign.modulate = Color("eee0ba")
	sign.outline_size = 0
	sign.shaded = true
	world.add_child(sign)
	# Work furniture stays against the wall, leaving the central drive-through clear.
	world.block(Vector3(-14.25, 0.94, 66), Vector3(1.1, 0.10, 4.0), "69746c").material_override = steel
	world.block(Vector3(-14.25, 0.30, 66), Vector3(0.95, 0.07, 3.8), "69746c").material_override = steel
	for z in [64.15, 67.85]:
		for x in [-14.68, -13.82]:
			world.block(Vector3(x, 0.46, z), Vector3(0.07, 0.92, 0.07), "45564e").material_override = steel
	var supply: Node3D = vegetation_scene("res://assets/realism/supply_crate.glb").instantiate()
	supply.position = Vector3(-14.2, 1.0, 65.5)
	supply.scale = Vector3.ONE * 0.48
	world.add_child(supply)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("fff0d3")
	glow.emission_enabled = true
	glow.emission = Color("ffe2b7")
	glow.emission_energy_multiplier = 0.7
	for z in [62.5, 67.5]:
		world.block(Vector3(-14.2, 3.38, z), Vector3(0.18, 0.08, 1.2), "45564e", false).material_override = steel
		world.block(Vector3(-14.2, 3.33, z), Vector3(0.14, 0.025, 1.1), "fff0d3", false).material_override = glow
		var task := SpotLight3D.new()
		task.position = Vector3(-14.2, 3.28, z)
		task.rotation_degrees.x = -90
		task.light_color = Color("ffe6c5")
		task.light_energy = 1.8
		task.spot_range = 4.5
		task.spot_angle = 62
		task.shadow_enabled = true
		world.add_child(task)
	# Broken lengths along the outer apron suggest a maintained walking edge.
	# Keep both building mouths free of kerbs.
	for z in [61.5, 63.8, 66.1, 68.4]:
		world.block(Vector3(-8.30, 0.07, z), Vector3(0.18, 0.14, 2.20), "96978b").material_override = concrete
	var verge_random := RandomNumberGenerator.new()
	verge_random.seed = 175
	for centre in [Vector3(-10.3, 0.025, 75.5), Vector3(-12.5, 0.025, 79.8),
			Vector3(10.6, 0.025, 80.5), Vector3(12.0, 0.025, 74.0)]:
		for i in range(42):
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 4 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			var angle := verge_random.randf() * TAU
			var radius := sqrt(verge_random.randf())
			plant.position = centre + Vector3(cos(angle) * radius * 1.25, 0, sin(angle) * radius * 2.3)
			plant.scale = Vector3.ONE * verge_random.randf_range(1.1, 2.3)
			plant.rotation.y = angle
			world.add_child(plant)
	# Broad, staggered crowns break up the road vista without forming a hedge.
	var random := RandomNumberGenerator.new()
	random.seed = 172
	for spec in [Vector3(-18, 0.95, 75), Vector3(-23, 1.2, 68), Vector3(-20, 0.55, 80), Vector3(17, 0.85, 73), Vector3(22, 1.15, 65), Vector3(20, 0.48, 78)]:
		var fir: Node3D = load("res://assets/realism/fir_full.glb").instantiate()
		fir.position = Vector3(spec.x, 0.02, spec.z)
		var crown_width := random.randf_range(0.85, 1.55)
		fir.scale = Vector3(crown_width, random.randf_range(0.83, 1.16), crown_width) * spec.y
		fir.rotation.y = random.randf() * TAU
		world.add_child(fir)
		configure_fir_lod(world, fir)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.175 * spec.y
		cylinder.height = 5 * spec.y
		shape.shape = cylinder
		body.position = fir.position + Vector3(0, cylinder.height / 2, 0)
		body.add_child(shape)
		world.add_child(body)
		world.ground_obstacles.append(Rect2(spec.x - cylinder.radius, spec.z - cylinder.radius, cylinder.radius * 2, cylinder.radius * 2))
		for i in range(55):
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 3 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			var angle := random.randf() * TAU
			var radius := sqrt(random.randf()) * 2.8
			plant.position = fir.position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
			plant.position.y = verge_height(Vector2(plant.position.x, plant.position.z)) + 0.025
			plant.rotation.y = angle
			plant.scale = Vector3.ONE * random.randf_range(0.8, 1.7)
			world.add_child(plant)

static func roadside_waiting_shelter(world) -> void:
	# Walk-in roadside stop: open west facade, pitched roof and slatted windbreak.
	# Footings sit flush with the walkable apron; no invisible entrance threshold.
	var steel := ShaderMaterial.new()
	steel.shader = preload("res://shaders/shelter_structural_steel.gdshader")
	var sheet := ShaderMaterial.new()
	sheet.shader = preload("res://shaders/canopy_sheet.gdshader")
	world.block(Vector3(16, 0.025, 84), Vector3(5.4, 0.05, 7), "8b897e", false)
	for x in [14.0, 18.0]:
		for z in [81.2, 86.8]:
			world.block(Vector3(x, 1.4, z), Vector3(0.12, 2.8, 0.12), "525952").material_override = steel
		world.block(Vector3(x, 2.76, 84), Vector3(0.14, 0.16, 6.5), "525952").material_override = steel
	# Ridge runs east-west: two roof planes read clearly from the default approach.
	for side in [-1.0, 1.0]:
		var roof = world.block(Vector3(16, 3.08, 84 + side * 1.7), Vector3(5.1, 0.07, 3.54), "777d72")
		roof.rotation.x = side * 0.24
		roof.material_override = sheet
		var fascia = world.block(Vector3(16, 2.69, 84 + side * 3.42), Vector3(5.15, 0.20, 0.075), "454c47")
		fascia.material_override = steel
	world.block(Vector3(16, 3.51, 84), Vector3(5.2, 0.09, 0.22), "61675d").material_override = steel
	# Opaque lower windbreak with separated upper slats; collision matches openings.
	world.block(Vector3(18, 0.55, 84), Vector3(0.12, 1.1, 5.5), "736b55")
	for i in range(22):
		world.block(Vector3(18, 1.78, 81.35 + i * 0.25), Vector3(0.10, 1.32, 0.16), "82745c")
	for z in [82.0, 86.0]:
		world.block(Vector3(17.25, 0.24, z), Vector3(0.55, 0.48, 0.10), "454b45").material_override = steel
	for x in [17.0, 17.25, 17.5]:
		world.block(Vector3(x, 0.51, 84), Vector3(0.22, 0.09, 4.6), "8b795c")
	world.block(Vector3(17.7, 0.91, 84), Vector3(0.08, 0.35, 4.6), "807057")
	world.block(Vector3(13.94, 2.40, 84), Vector3(0.08, 0.42, 3.7), "303e38")
	var sign := Label3D.new()
	sign.text = "VALLEY / 04"
	sign.font_size = 80
	sign.pixel_size = 0.0035
	sign.position = Vector3(13.89, 2.40, 84)
	sign.rotation.y = -PI / 2
	sign.modulate = Color("e3d8b7")
	sign.shaded = true
	world.add_child(sign)
	# Irregular low colonies join the foreground verge into continuous meadow.
	# Keep the road, approach (x < 14,z 81..87) and shelter apron clear.
	var random := RandomNumberGenerator.new()
	random.seed = 176
	for center in [Vector3(-12, 0, 94), Vector3(-16, 0, 88), Vector3(-20, 0, 96), Vector3(12, 0, 96), Vector3(19, 0, 94), Vector3(22, 0, 85)]:
		for i in range(55):
			var angle := random.randf() * TAU
			var radius := sqrt(random.randf())
			var at: Vector3 = center + Vector3(cos(angle) * radius * 2.4, 0, sin(angle) * radius * 3.2)
			at.y = verge_height(Vector2(at.x, at.z)) + 0.018
			var plant: Node3D = load("res://assets/realism/" + ("grass_broadleaf.glb" if i % 5 == 0 else "grass_fine.glb")).instantiate()
			plant.position = at
			plant.scale = Vector3.ONE * random.randf_range(0.8, 1.6)
			plant.rotation.y = random.randf() * TAU
			world.add_child(plant)


static func repair_shelter_services(world) -> void:
	# Exposed rainwater collection connects the curved shell to the ground.
	# Both pipes stay outside the masonry jambs and the clear vehicle aisle.
	for side in [-1.0, 1.0]:
		var gutter_x: float = 15.5 + side * 3.48
		var gutter = world.block(Vector3(gutter_x, 1.91, 29.5), Vector3(0.22, 0.16, 7.18), "52615a", false)
		gutter.name = "RepairEavesRainwaterGutter"
		world.block(Vector3(gutter_x, 2.005, 29.5), Vector3(0.15, 0.012, 7.10), "252f2b", false)
		var outlet_x: float = gutter_x + side * 0.12
		workyard_round_fitting(world, Vector3(gutter_x, 1.87, 33.04), Vector3(outlet_x, 1.57, 33.25), 0.085, "59665e")
		workyard_round_fitting(world, Vector3(outlet_x, 1.57, 33.25), Vector3(outlet_x, 0.24, 33.25), 0.085, "59665e")
		workyard_round_fitting(world, Vector3(outlet_x, 0.24, 33.25), Vector3(outlet_x, 0.13, 33.52), 0.085, "59665e")
		for clamp_y in [0.48, 1.36]:
			workyard_round_fitting(world, Vector3(outlet_x, clamp_y - 0.035, 33.25), Vector3(outlet_x, clamp_y + 0.035, 33.25), 0.105, "35423c")
	# Raised rolling shutter: a readable industrial opening with real slat
	# relief. The 2.85m headroom leaves the vehicle aisle and actor clear.
	var shutter_finish := ShaderMaterial.new()
	shutter_finish.shader = load("res://shaders/service_shutter.gdshader")
	var curtain = world.block(Vector3(15.5, 3.25, 33.12), Vector3(3.48, 0.80, 0.075), "81867c")
	curtain.name = "RepairRaisedShutter"
	curtain.material_override = shutter_finish
	for row in range(10):
		var slat = world.block(Vector3(15.5, 2.88 + row * 0.08, 33.175), Vector3(3.48, 0.025, 0.028), "747a70", false)
		slat.material_override = shutter_finish
	world.block(Vector3(15.5, 2.855, 33.16), Vector3(3.55, 0.065, 0.13), "38423e")
	for x in [13.70, 17.30]:
		world.block(Vector3(x, 1.83, 33.24), Vector3(0.085, 3.66, 0.15), "4b5751")
	workyard_round_fitting(world, Vector3(13.65, 3.83, 33.07), Vector3(17.35, 3.83, 33.07), 0.20, "7a8178")
	# A shallow upper hood shades the coil instead of an unbroken box fascia.
	# Folded rain hood gives the facade depth above the door clearance.
	world.block(Vector3(15.5, 4.06, 33.44), Vector3(4.10, 0.065, 1.25), "4b5751", false)
	world.block(Vector3(15.5, 3.98, 34.04), Vector3(4.10, 0.17, 0.055), "384941", false)
	for hood_x in [13.55, 17.45]:
		world.block(Vector3(hood_x, 3.99, 33.46), Vector3(0.055, 0.16, 1.17), "384941", false)
	world.block(Vector3(17.62, 1.42, 33.29), Vector3(0.16, 0.27, 0.10), "727a73", false)
	world.block(Vector3(17.62, 1.48, 33.35), Vector3(0.055, 0.055, 0.025), "925241", false)
	# External extraction stack and weather hood give the workshop a working
	# roof silhouette. All fittings stay beyond the vehicle aisle.
	workyard_round_fitting(world, Vector3(12.35, 2.65, 32.2), Vector3(11.45, 2.65, 32.2), 0.22, "7b8581")
	workyard_round_fitting(world, Vector3(11.45, 2.65, 32.2), Vector3(11.45, 6.25, 32.2), 0.22, "7b8581")
	for y in [3.0, 4.1, 5.3, 6.1]:
		workyard_round_fitting(world, Vector3(11.45, y - 0.04, 32.2), Vector3(11.45, y + 0.04, 32.2), 0.255, "4c5d58")
	for y in [3.0, 4.1]:
		world.block(Vector3(11.88, y, 32.2), Vector3(0.9, 0.06, 0.08), "435650")
	var hood := MeshInstance3D.new()
	var hood_mesh := CylinderMesh.new()
	hood_mesh.top_radius = 0.10
	hood_mesh.bottom_radius = 0.46
	hood_mesh.height = 0.25
	if OS.has_feature("android"):
		hood_mesh.rings = 0
	hood.mesh = hood_mesh
	hood.material_override = world.mat("657571")
	hood.position = Vector3(11.45, 6.53, 32.2)
	hood.name = "RepairExtractionRainHood"
	world.add_child(hood)
	for dx in [-0.17, 0.17]:
		world.block(Vector3(11.45 + dx, 6.30, 32.2), Vector3(0.025, 0.25, 0.035), "435650", false)
	# Roof extraction units are built by repair_shelter_roof_vents.
	# Small overhead service crane supported by the side frames, with the
	# parked trolley outside the through aisle. Lowest hook stays above heads.
	for x in [13.3, 17.7]:
		for y in [3.36, 3.58]:
			world.block(Vector3(x, y, 29.5), Vector3(0.20, 0.035, 5.0), "596a63")
		world.block(Vector3(x, 3.47, 29.5), Vector3(0.035, 0.22, 5.0), "596a63")
		for z in [27.15, 29.5, 31.85]:
			world.block(Vector3(x, 3.78, z), Vector3(0.07, 0.40, 0.09), "596a63")
	for y in [3.61, 3.89]:
		world.block(Vector3(15.5, y, 30.8), Vector3(4.6, 0.045, 0.24), "a28a4e")
	world.block(Vector3(15.5, 3.75, 30.8), Vector3(4.6, 0.28, 0.045), "917743")
	var trolley = world.block(Vector3(16.9, 3.46, 30.8), Vector3(0.48, 0.27, 0.38), "516665")
	trolley.name = "RepairShelterCraneTrolley"
	for x in [16.83, 16.97]:
		workyard_round_fitting(world, Vector3(x, 3.34, 30.8), Vector3(x, 2.82, 30.8), 0.012, "414b49")
	for step in range(10):
		var a := float(step) * PI / 10.0
		var b := float(step + 1) * PI / 10.0
		workyard_round_fitting(world, Vector3(16.9 + cos(a)*0.09, 2.82-sin(a)*0.09, 30.8), Vector3(16.9 + cos(b)*0.09, 2.82-sin(b)*0.09, 30.8), 0.023, "616860")
	# Shielded workshop battens direct broad soft light toward work surfaces.
	# Keeping light below the fixture avoids bleaching the rear wall and roof.
	var diffuser := StandardMaterial3D.new()
	diffuser.albedo_color = Color("f3f0e5")
	diffuser.emission_enabled = true
	diffuser.emission = Color("fff0d5")
	diffuser.emission_energy_multiplier = 0.65
	for fixture in [Vector3(16.65, 3.3, 30.8), Vector3(12.1, 2.9, 32.0), Vector3(18.9, 2.9, 32.0)]:
		var housing = world.block(fixture, Vector3(0.20, 0.12, 1.25), "414b49", false)
		housing.name = "RepairEntranceBattenHousing"
		var lens := MeshInstance3D.new()
		var lens_mesh := BoxMesh.new()
		lens_mesh.size = Vector3(0.16, 0.025, 1.12)
		lens.mesh = lens_mesh
		lens.material_override = diffuser
		lens.position = fixture - Vector3(0, 0.075, 0)
		world.add_child(lens)
		for offset in [-0.38, 0.38]:
			var light := SpotLight3D.new()
			light.name = "RepairBattenSoftSource"
			light.rotation_degrees.x = -90
			light.position = fixture + Vector3(0, -0.14, offset)
			light.light_color = Color("fff1db")
			light.light_energy = 0.38
			light.light_size = 0.32
			light.spot_range = 4.1
			light.spot_angle = 68.0
			light.spot_angle_attenuation = 0.55
			light.spot_attenuation = 1.2
			light.shadow_enabled = true
			world.add_child(light)
	# Uneven low colonies soften the apron-to-earth transition without
	# occupying the entrance or creating another continuous hedge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 304019
	# Low rooted colonies follow the damp exterior footings. Keep the
	# doorway and usable interior clear; these plants have no colliders.
	for side in [-1.0, 1.0]:
		for colony_z in [26.4, 28.1, 31.9, 34.4]:
			for blade in range(12):
				var footing_grass: Node3D = load("res://assets/realism/grass_broadleaf.glb" if blade % 4 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
				footing_grass.name = "ShelterFootingVegetation"
				footing_grass.position = Vector3(15.5 + side * rng.randf_range(3.65, 4.25),
					0.02, colony_z + rng.randf_range(-0.45, 0.45))
				footing_grass.rotation.y = rng.randf() * TAU
				var footing_spread := rng.randf_range(0.30, 0.65)
				footing_grass.scale = Vector3(footing_spread, rng.randf_range(0.15, 0.34), footing_spread)
				world.add_child(footing_grass)
	# Restore the existing verge distribution when changing footing plants.
	rng.seed = 304019
	for side in [-1.0, 1.0]:
		for i in range(85):
			var z := rng.randf_range(32.8, 38.4)
			if sin(z * 3.1 + side) < -0.30:
				continue
			var grass: Node3D = load("res://assets/realism/grass_broadleaf.glb" if i % 5 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
			grass.position = Vector3(15.5 + side * rng.randf_range(3.75, 4.85), 0.015, z)
			grass.rotation.y = rng.randf() * TAU
			var spread := rng.randf_range(0.55, 0.95)
			grass.scale = Vector3(spread, rng.randf_range(0.28, 0.65), spread)
			world.add_child(grass)


	# Unequal shrub islands provide a middle vegetation layer at the unused
	# shoulders. Their broadleaf skirts stay outside the six-metre approach.
	# Tapered fine-grass colonies at two scales break the flat shoulder
	# silhouette. Keep all centres outside the tested access corridor.
	var meadow_grass: PackedScene = load("res://assets/realism/grass_fine.glb")
	# Broadleaf ground cover replaces the tall twig hedge at the approach.
	for pocket in [Vector3(10.0,0,37.8), Vector3(10.4,0,42.8),
		Vector3(21.1,0,39.5), Vector3(22.2,0,44.8), Vector3(23.6,0,48.4)]:
		var colony_count := rng.randi_range(32, 78)
		var colony_length := rng.randf_range(1.4, 2.8)
		for i in range(colony_count):
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf())
			# Uneven, elongated colonies with open soil between tufts; no
			# equally sized circular shrub beds along the access lane.
			if radius > 0.45 and sin(angle * 3.0 + pocket.z) > 0.35:
				continue
			var at: Vector3 = pocket + Vector3(cos(angle)*radius*1.25,0,sin(angle)*radius*colony_length)
			at.y = maxf(0.048, verge_height(Vector2(at.x, at.z)))
			var plant: Node3D = (load("res://assets/realism/grass_broadleaf.glb") if i % 7 == 0 else meadow_grass).instantiate()
			plant.name = "RepairShoulderMeadow"
			plant.position = at
			plant.rotation.y = rng.randf() * TAU
			var spread := rng.randf_range(0.6,1.2)
			var height := rng.randf_range(0.40,0.95) * (1.0-radius*0.66)
			plant.scale = Vector3(spread,height,spread)
			world.add_child(plant)
	for pocket in [Vector3(5.8, 0, 35.5), Vector3(23.8, 0, 36.4), Vector3(25.6, 0, 45.8), Vector3(7.6, 0, 41.0), Vector3(24.8, 0, 47.8)]:
		var shrub_count := rng.randi_range(2, 5)
		for i in range(shrub_count):
			var at: Vector3 = pocket + Vector3(rng.randf_range(-1.1, 1.1), 0, rng.randf_range(-1.4, 1.4))
			at.y = verge_height(Vector2(at.x, at.z)) + 0.02
			var shrub: Node3D = vegetation_scene("res://assets/realism/verge_fine_shrub.glb").instantiate()
			shrub.position = at
			shrub.rotation.y = rng.randf() * TAU
			var spread := rng.randf_range(0.70, 1.35)
			shrub.scale = Vector3(spread, rng.randf_range(0.38, 0.75), spread)
			world.add_child(shrub)
		for i in range(rng.randi_range(18, 42)):
			var at: Vector3 = pocket + Vector3(rng.randf_range(-1.7, 1.7), 0, rng.randf_range(-1.9, 1.9))
			at.y = verge_height(Vector2(at.x, at.z)) + 0.015
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb").instantiate()
			plant.position = at
			plant.rotation.y = rng.randf() * TAU
			var grass_width := rng.randf_range(0.45, 1.1)
			plant.scale = Vector3(grass_width, rng.randf_range(0.20, 0.65), grass_width)
			world.add_child(plant)

static func service_lane_verges(world) -> void:
	service_yard_recovery(world)
	# Shallow deposits share the surrounding world-space soil, eliminating
	# orange UV-textured ribbons. Keep the 3.4 m centre clear and walkable.
	var finish := meadow_surface()
	var rng := RandomNumberGenerator.new()
	rng.seed = 199031
	var stone_mesh := SphereMesh.new()
	stone_mesh.radial_segments = 5
	# Centimetre-scale loose aggregate needs only one latitude ring on mobile.
	# Match the old three-band sphere's maximum horizontal extent.
	stone_mesh.rings = 1 if OS.has_feature("android") else 2
	stone_mesh.radius = sin(PI / 3.0) if OS.has_feature("android") else 1.0
	stone_mesh.height = 2.0
	var stones := MultiMesh.new()
	stones.transform_format = MultiMesh.TRANSFORM_3D
	stones.use_colors = true
	stones.mesh = stone_mesh
	stones.instance_count = 1800
	var stone_index := 0
	for side in [-1.0, 1.0]:
		var strip := SurfaceTool.new()
		strip.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rows: Array = []
		for row in range(51):
			var t := float(row) / 50.0
			var center := Vector3(15.5, 0, 37).lerp(Vector3(16, 0, 46), minf(t / 0.6, 1.0))
			var tangent := Vector3(0.5, 0, 9).normalized()
			if t > 0.6:
				center = Vector3(16, 0, 46).lerp(Vector3(9, 0, 52), (t - 0.6) / 0.4)
				tangent = Vector3(-7, 0, 6).normalized()
			tangent = Vector3(0.5, 0, 9).normalized().lerp(Vector3(-7, 0, 6).normalized(), smoothstep(0.52, 0.68, t)).normalized()
			var normal: Vector3 = Vector3(tangent.z, 0, -tangent.x) * side
			# Asymmetric deposition islands, with long eroded gaps at each bank.
			var deposit := smoothstep(-0.15, 0.65, sin(t * 25.0 + side * 2.1) + 0.30 * sin(t * 53.0))
			var width := (0.31 + 0.16 * sin(t * 24.0 + side)) * lerpf(0.15, 1.0, deposit)
			var offset := 2.28 + 0.19 * sin(t * 19.0 + side)
			var fade := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.88, 1.0, t))
			var erosion := smoothstep(-0.5, 0.7, sin(t * 43.0 + side))
			fade *= deposit
			var crest := (0.012 + 0.020 * erosion) * fade
			var points: Array[Vector3] = []
			for column in range(5):
				var u := float(column) / 4.0
				var pos: Vector3 = center + normal * (offset + (u - 0.5) * width * 2.0)
				pos.y = -0.02 + sin(u * PI) * (crest + 0.018 * fade)
				points.append(pos)
			rows.append(points)
			if row > 0:
				for column in range(4):
					var triangle := [Vector2i(row-1,column), Vector2i(row,column), Vector2i(row,column+1), Vector2i(row-1,column), Vector2i(row,column+1), Vector2i(row-1,column+1)]
					if side > 0:
						triangle.reverse()
					for pair in triangle:
						var v: Vector3 = rows[pair.x][pair.y]
						strip.set_uv(Vector2(v.x, v.z) * 1.8)
						strip.add_vertex(v)
			# Low overlapping colonies follow the outside of the wheel-worn lane.
			# Density tapers at both ends, leaving the entrance and 3.4m aisle clear.
			if row > 3 and row < 47:
				for tuft in range(12):
					# Break the hedge-like strip into colonies and taper height
					# toward the worn edge rather than ending a tall wall.
					var lateral := rng.randf_range(1.70, 3.80)
					var colony_density := 0.30 + 0.48 * sin(t * 23.0 + side * 1.9) + 0.28 * sin(t * 57.0 - side)
					if rng.randf() > colony_density * smoothstep(1.65, 2.9, lateral):
						continue
					var grass: Node3D = load("res://assets/realism/grass_broadleaf.glb" if tuft % 9 == 0 else "res://assets/realism/grass_fine.glb").instantiate()
					grass.position = center + normal * lateral + tangent * rng.randf_range(-0.40, 0.40)
					var spread := rng.randf_range(0.65, 1.20)
					grass.scale = Vector3(spread, rng.randf_range(0.12, 0.34) * lerpf(0.3, 1.0, smoothstep(1.7, 3.4, lateral)), spread)
					grass.rotation.y = rng.randf() * TAU
					world.add_child(grass)
			if row < 50:
				for item in range(16):
					var lateral := rng.randf_range(-0.45, 1.35)
					var pos: Vector3 = center + normal * (offset + lateral) + tangent * rng.randf_range(-0.38, 0.38)
					var size := rng.randf_range(0.016, 0.052)
					pos.y = maxf(0.006, -0.02 + sin(clampf((lateral / width + 1.0) * 0.5, 0.0, 1.0) * PI) * (crest + 0.018 * fade)) + size * 0.15
					var basis := Basis.from_euler(Vector3(rng.randf(), rng.randf()*TAU, rng.randf())).scaled(Vector3(size, size*0.42, size*0.72))
					stones.set_instance_transform(stone_index, Transform3D(basis, pos))
					stones.set_instance_color(stone_index, Color("948975").lerp(Color("514d42"), rng.randf()))
					stone_index += 1
		strip.generate_normals()
		if OS.has_feature("android"):
			# Weld complete attributes after smoothing, retaining the bank's
			# exact lighting/UVs and collision faces while sharing vertices.
			strip.index()
			strip.optimize_indices_for_cache()
		var bank := MeshInstance3D.new()
		bank.name = "ServiceLaneAggregateBank"
		bank.mesh = strip.commit()
		bank.material_override = finish
		world.add_child(bank)
		bank.create_trimesh_collision()
	stones.visible_instance_count = stone_index
	var detail := MultiMeshInstance3D.new()
	detail.name = "ServiceLaneLooseAggregate"
	detail.multimesh = stones
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color("a9aaa3")
	# Vertex tones supply neutral mineral colour at centimetre scale.
	rock.vertex_color_use_as_albedo = true
	rock.roughness = 0.98
	detail.material_override = rock
	world.add_child(detail)

# Broken gravel and dry growth below the west windows; keep the walking strip clear.
static func service_sill_deposits(world) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 245031
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 2
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = 480
	for i in range(480):
		var z := rng.randf_range(25.5, 39.0)
		var x := 11.3 - absf(rng.randfn(0.0, 0.48))
		var p := Vector2(x, z)
		var size := rng.randf_range(0.035, 0.12)
		var basis := Basis.from_euler(Vector3(rng.randf(), rng.randf()*TAU, rng.randf()))
		basis = basis.scaled(Vector3(size, size*0.35, size*0.8))
		batch.set_instance_transform(i, Transform3D(basis, Vector3(x, verge_height(p)+0.025, z)))
		batch.set_instance_color(i, Color("686456").lerp(Color("aaa18a"), rng.randf()))
		if i % 12 == 0:
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb").instantiate()
			plant.position = Vector3(x, verge_height(p)+0.02, z)
			plant.rotation.y = rng.randf()*TAU
			plant.scale = Vector3.ONE * rng.randf_range(0.3, 0.65)
			world.add_child(plant)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	var deposits := MultiMeshInstance3D.new()
	deposits.name = "WestSillLooseDeposits"
	material.albedo_color = Color("454036")
	deposits.multimesh = batch
	deposits.material_override = material
	world.add_child(deposits)

static func drainage_split_stone(rng: RandomNumberGenerator) -> ArrayMesh:
	# Fractured fieldstone: oblique crowns and unequal buried shoulders.
	# The collision surface follows the visible rock, including broken shoulders.
	var points: Array[Vector3] = []
	var outline: Array[Vector2] = []
	var heights: Array[float] = []
	for k in range(12):
		var angle := TAU * float(k) / 12.0
		var radius := rng.randf_range(0.80, 1.12)
		outline.append(Vector2(cos(angle), sin(angle)) * radius)
		heights.append(rng.randf_range(-0.055, 0.055))
	var crown_offset := Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
	var widths := [0.62, 0.94, 1.0, 0.78, rng.randf_range(0.38, 0.64)]
	var fracture_slope := Vector2(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.35, 0.35))
	var levels := [-0.82, -0.60, 0.12, 0.64, 0.72]
	for ring in range(5):
		for k in range(12):
			var corner: Vector2 = outline[k] * widths[ring] + crown_offset * float(ring) / 4.0
			points.append(Vector3(corner.x, levels[ring] + heights[k] + corner.dot(fracture_slope), corner.y))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for ring in range(4):
		for k in range(12):
			var a := ring * 12 + k
			var b := ring * 12 + (k + 1) % 12
			for idx in [a, b, b + 12, a, b + 12, a + 12]:
				surface.add_vertex(points[idx])
	for k in range(1, 11):
		for idx in [0, k + 1, k, 48, 48 + k, 49 + k]:
				surface.add_vertex(points[idx])
	surface.generate_normals()
	return surface.commit()

static func service_road_drainage(world) -> void:
	# Retain the raised yard with rough local stone. The unretained gaps at
	# z=26, z=34..39, the eroded shoulder at z=41, and beyond z=46 are crossings.
	var rng := RandomNumberGenerator.new()
	rng.seed = 355091
	for span in [Vector2(26, 33), Vector2(39, 46)]:
		for course in range(3):
			var z: float = span.x + (0.37 if course == 1 else 0.0)
			while z < span.y - 0.2:
				if absf(z - 41.0) < 1.2:
					z += 0.55
					continue
				var stone := MeshInstance3D.new()
				stone.name = "RoadDrainRetainingStone"
				stone.set_meta("road_drain_retaining", true)
				stone.mesh = drainage_split_stone(rng)
				stone.position = Vector3(9.24 + course * 0.055 + rng.randf_range(-0.11, 0.11),
					0.005 + course * 0.17 + rng.randf_range(-0.09, 0.08), z)
				stone.rotation = Vector3(rng.randf_range(-0.19, 0.19),
					rng.randf_range(-0.75, 0.75), rng.randf_range(-0.28, 0.28))
				stone.scale = Vector3(rng.randf_range(0.27, 0.43),
					rng.randf_range(0.15, 0.24), rng.randf_range(0.22, 0.40))
				var material := ShaderMaterial.new()
				material.shader = load("res://shaders/drainage_stone.gdshader")
				material.set_shader_parameter("rock_texture", load("res://assets/realism/terrain_rock_albedo.jpg"))
				material.set_shader_parameter("stone_color",
					Color("77746a").lerp(Color("4b5049"), rng.randf()))
				stone.material_override = material
				# Leave a full-width pedestrian opening at the north terminal.
				# Set each upper course back to step the wall into the bank;
				# keep mesh collisions on the retained stones. Consume the same
				# random samples so the rest of the drainage stays in place.
				if span.x == 26 and z < 27.4 + course * 0.45:
					z += stone.scale.z * rng.randf_range(1.65, 2.05)
					stone.free()
					continue
				world.add_child(stone)
				stone.create_trimesh_collision()
				z += stone.scale.z * rng.randf_range(1.65, 2.05)
		# Low plants occupy damp toe pockets, leaving both crossing gaps clear.
		for i in range(45):
			var pocket: float = [0.8, 2.9, 5.9][i % 3]
			var z: float = span.x + pocket + rng.randf_range(-0.38, 0.38)
			if absf(z - 41.0) < 1.35: continue
			var plant: Node3D = load("res://assets/realism/grass_broadleaf.glb").instantiate()
			plant.position = Vector3(rng.randf_range(8.87, 9.12), 0.035, z)
			plant.rotation.y = rng.randf() * TAU
			plant.scale = Vector3(0.42, rng.randf_range(0.28, 0.48), 0.42)
			world.add_child(plant)
		# Exposed gravel toe, kept below step height. Loose fragments have no
		# collision; the retaining stones above use their actual mesh.
		# Bake one short spatial batch per bank. Explicit inverse-transpose
		# normals preserve lighting on the flattened, nonuniform fragments.
		var fragments := MeshInstance3D.new()
		fragments.name = "DrainageGravel%d" % int(span.x)
		var pebble := SphereMesh.new()
		pebble.radius = 1.0
		pebble.height = 2.0
		pebble.radial_segments = 5
		pebble.rings = 2
		var gravel := StandardMaterial3D.new()
		gravel.vertex_color_use_as_albedo = true
		gravel.vertex_color_is_srgb = true
		gravel.roughness = 1.0
		fragments.material_override = gravel
		var source := pebble.get_mesh_arrays()
		var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var source_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		for i in range(230):
			var p := Vector3(rng.randf_range(8.45, 8.98), 0.035,
				rng.randf_range(span.x - 0.2, span.y + 0.2))
			var scale := Vector3(rng.randf_range(0.05, 0.14), 0.035,
				rng.randf_range(0.06, 0.18))
			var color := Color("535149").lerp(Color("827969"), rng.randf())
			var offset := vertices.size()
			for vertex in range(source_vertices.size()):
				vertices.append(source_vertices[vertex] * scale + p)
				normals.append((source_normals[vertex] / scale).normalized())
				colors.append(color)
			for index in source_indices:
				indices.append(offset + index)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var gravel_mesh := ArrayMesh.new()
		gravel_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		fragments.mesh = gravel_mesh
		# Include the bank half-length so a near-end fragment never disappears
		# before its previous individual 10 m mobile cutoff.
		fragments.visibility_range_end = 14.0 if OS.has_feature("android") else 0.0
		world.add_child(fragments)
		# Plants root on the retained side in separated pockets, with a lower
		# roadside edge and occasional woody stems rather than a hedge.
		for i in range(110):
			var z := rng.randf_range(span.x + 0.3, span.y - 0.3)
			if sin(z * 1.6) < 0.3 or absf(z - 41.0) < 1.2: continue
			var p := Vector2(rng.randf_range(9.55, 11.15), z)
			if not service_growth_sample(p): continue
			var woody := i % 17 == 0
			var asset := "verge_fine_shrub" if woody else "grass_fine"
			var plant: Node3D = vegetation_scene("res://assets/realism/%s.glb" % asset).instantiate()
			plant.position = Vector3(p.x, verge_height(p) + 0.015, p.y)
			plant.rotation.y = rng.randf() * TAU
			plant.scale = Vector3(0.65, rng.randf_range(0.38, 0.66) if woody else rng.randf_range(0.25, 0.58), 0.65)
			world.add_child(plant)


	# Separate seeded colonies soften the retained edge without changing the
	# existing stone collision or covering the walkable drainage crossings.
	var edge_rng := RandomNumberGenerator.new()
	edge_rng.seed = 370042
	for colony_z in [26.8, 29.4, 32.0, 39.3, 44.6]:
		for i in range(11):
			var p := Vector2(edge_rng.randf_range(9.38, 10.05),
				colony_z + edge_rng.randf_range(-0.48, 0.48))
			if absf(p.y - 41.0) < 1.4: continue
			var plant: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
			plant.name = "DrainageEdgeGrassColony"
			plant.position = Vector3(p.x, verge_height(p) + 0.015, p.y)
			plant.rotation.y = edge_rng.randf() * TAU
			var width := edge_rng.randf_range(0.48, 0.82)
			plant.scale = Vector3(width, edge_rng.randf_range(0.36, 0.79), width)
			world.add_child(plant)

static func service_yard_recovery(world) -> void:
	service_road_drainage(world)
	service_yard_understory(world)
	service_sill_deposits(world)
	# Deposits spread beyond the narrow bank into the worn southern yard.
	# Small embedded stones are cosmetic; no invisible obstacles in the lane.
	var rng := RandomNumberGenerator.new()
	rng.seed = 213045
	var patches := FastNoiseLite.new()
	patches.seed = 213
	patches.frequency = 0.48
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	# These flattened 2–6.5cm grains retain their outline and all placements.
	# Extra latitude bands cost ~48k road-view triangles on Android.
	mesh.rings = 1 if OS.has_feature("android") else 3
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = 2600
	var count := 0
	var plants := 0
	for attempt in range(6500):
		var p := Vector2(rng.randf_range(9.5, 24.0), rng.randf_range(38.5, 56.0))
		var lane := minf(
			p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(15.5, 36), Vector2(16, 46))),
			p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(16, 46), Vector2(9, 52))))
		var loading := p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(16,46), Vector2(27,47)))
		var colony := smoothstep(-0.35, 0.42, patches.get_noise_2dv(p))
		if rng.randf() > colony * 0.78 + 0.12: continue
		if count < batch.instance_count and rng.randf() < 0.55:
			var size := rng.randf_range(0.02, 0.065)
			# Wheels leave fine grit; larger fragments gather in unworn margins.
			size *= lerpf(0.45, 1.0, smoothstep(0.8, 2.1, lane))
			var basis := Basis.from_euler(Vector3(rng.randf()*0.3,rng.randf()*TAU,rng.randf()*0.3))
			basis = basis.scaled(Vector3(size, size*0.32, size*rng.randf_range(0.6,1.25)))
			batch.set_instance_transform(count, Transform3D(basis, Vector3(p.x,verge_height(p)+0.045,p.y)))
			batch.set_instance_color(count, Color("585750").lerp(Color("aaa393"),rng.randf()))
			count += 1
		# Broken, low colonies soften the abrupt strip without hiding the ruts.
		var center_recovery := lane < 0.48 and p.y > 40.5 and loading > 1.65
		var margin_recovery := lane > 1.60 and loading > 1.65
		if (margin_recovery or center_recovery) and service_growth_sample(p) and colony > 0.24 and plants < 960 and rng.randf() < 0.78:
			var grass: Node3D = load("res://assets/realism/grass_fine.glb").instantiate()
			grass.position = Vector3(p.x,verge_height(p)+0.02,p.y)
			grass.rotation.y = rng.randf()*TAU
			var spread := rng.randf_range(0.8,1.55)
			# Mostly cropped grass with sparse taller seed clumps; avoid a uniform lawn.
			var height := rng.randf_range(0.55,1.02)
			if colony > 0.58 and rng.randf() < 0.18:
				height = rng.randf_range(0.65,1.10)
			spread *= rng.randf_range(0.65,1.15)
			if center_recovery:
				spread *= 0.65
				height *= 0.75
			grass.scale = Vector3(spread,height,spread)
			world.add_child(grass)
			plants += 1
	batch.visible_instance_count = count
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.albedo_color = Color("6c6554")
	surface.roughness = 0.97
	var stones := MultiMeshInstance3D.new()
	stones.name = "ServiceYardRecoveryAggregate"
	stones.multimesh = batch
	stones.material_override = surface
	world.add_child(stones)

# Shared by all overlapping approach vegetation layers. Broad drainage scars
# must remain open in every layer; independent random masks refill each other.
static func service_growth(point: Vector2) -> float:
	if point.y < 34.0 or point.y > 55.0 or point.x < 8.0 or point.x > 27.0:
		return 1.0
	var growth := 1.0
	for scar in [Vector4(10.9, 39.2, 2.3, 0.95), Vector4(11.4, 44.3, 2.4, 1.2),
		Vector4(21.4, 40.5, 3.2, 1.05), Vector4(23.1, 44.0, 2.7, 0.85), Vector4(21.8, 51.5, 2.4, 0.85)]:
		var q := (point - Vector2(scar.x, scar.y)) / Vector2(scar.z, scar.w)
		q.y += sin(point.x * 1.7) * 0.14
		growth = minf(growth, smoothstep(0.95, 1.65, q.length()))
	return growth

static func service_growth_sample(point: Vector2) -> bool:
	var sample_value := fposmod(sin(point.dot(Vector2(12.9898, 78.233))) * 43758.5453, 1.0)
	return sample_value < service_growth(point)

static func service_yard_understory(world) -> void:
	service_shelter_edge_groves(world)
	service_yard_groundcover(world)
	service_yard_scrub_islands(world)
	service_road_shoulder_colonies(world)
	# Unequal colonies follow unused shoulders, leaving both the repair lane
	# and the east loading spur clear. Broad leaves form a low skirt beneath
	# upright fine-leaf stems, rather than another evenly spaced grass strip.
	var rng := RandomNumberGenerator.new()
	rng.seed = 240071
	var colonies := [Vector4(10.7,39.5,1.05,1.8), Vector4(11.3,44.2,1.2,1.4),
		Vector4(21.0,40.4,2.3,2.8), Vector4(24.1,43.1,2.0,1.7),
		Vector4(22.2,51.1,1.8,1.2), Vector4(17.8,53.1,1.4,1.6)]
	# Taller stems occur in only two unused shoulder pockets. Low grasses
	# feather their edges; unequal sizes avoid another repeated hedge row.
	for pocket in [Vector3(20.8,0,38.1),Vector3(23.2,0,42.8)]:
		for stem_index in range(5):
			var stem: Node3D = vegetation_scene("res://assets/realism/verge_fine_shrub.glb").instantiate()
			var p := Vector2(pocket.x,pocket.z) + Vector2(rng.randf_range(-0.65,0.65),rng.randf_range(-0.9,0.9))
			stem.position = Vector3(p.x,verge_height(p)+0.025,p.y)
			stem.rotation.y = rng.randf()*TAU
			var spread := rng.randf_range(0.43,0.72)
			stem.scale = Vector3(spread,rng.randf_range(0.60,0.95),spread)
			world.add_child(stem)
	for colony_index in range(colonies.size()):
		var colony: Vector4 = colonies[colony_index]
		for i in range(58):
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf())
			var p := Vector2(colony.x, colony.y) + Vector2(cos(angle)*colony.z, sin(angle)*colony.w)*radius
			if not service_growth_sample(p): continue
			var lane := minf(
				p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(15.5,36), Vector2(16,46))),
				p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(16,46), Vector2(9,52))))
			var loading := p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(16,46), Vector2(27,47)))
			if lane < 2.65 or loading < 2.35: continue
			# Sparse crowns above continuous low groundcover keep the shoulder
			# readable from eye height instead of closing into a hedge.
			var upright := i < 4 and radius < 0.60
			var asset := "verge_fine_shrub" if upright else ("grass_broadleaf" if i % 3 == 0 else "grass_fine")
			var plant: Node3D = vegetation_scene("res://assets/realism/%s.glb" % asset).instantiate()
			plant.name = "YardUnderstory_%d_%d" % [colony_index,i]
			plant.position = Vector3(p.x,verge_height(p)+0.025,p.y)
			plant.rotation.y = rng.randf()*TAU
			var spread := rng.randf_range(0.65,1.1)
			var height := rng.randf_range(0.55,0.85) if upright else rng.randf_range(0.22,0.48)
			if asset == "grass_broadleaf":
				spread *= 0.48
				height *= 0.65
			height *= lerpf(1.0,0.40,radius)
			# Short growth against the access edge opens sightlines to the apron.
			height *= lerpf(0.55,1.0,smoothstep(2.65,4.0,lane))
			plant.scale = Vector3(spread,height * lerpf(0.25, 1.0, service_growth(p)),spread)
			world.add_child(plant)

static func service_shelter_edge_groves(world) -> void:
	service_shoulder_thickets(world)
	# Three unequal crowns anchor the building to its unused outer shoulders.
	# Real trunks cast shade and collide; the front access and west canopy
	# walkway remain clear. Understory falls away irregularly at each edge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 345071
	var birch = vegetation_scene("res://assets/realism/verge_birch.glb")
	var shrub = vegetation_scene("res://assets/realism/verge_fine_shrub.glb")
	var grass = preload("res://assets/realism/grass_fine.glb")
	for spec in [Vector4(7.7, 25.2, 1.04, 0.3),
		Vector4(27.8, 19.0, 1.18, 2.1), Vector4(7.4, 34.8, 0.84, 4.5)]:
		var ground := verge_height(Vector2(spec.x, spec.y))
		var tree: Node3D = birch.instantiate()
		tree.name = "ShelterShoulderBirch_%s_%s" % [spec.x, spec.y]
		tree.position = Vector3(spec.x, ground, spec.y)
		tree.rotation.y = spec.w
		tree.scale = Vector3(spec.z * 1.26, spec.z, spec.z * 1.10)
		world.add_child(tree)
		var body := StaticBody3D.new()
		body.name = "ShelterShoulderTrunk_%s_%s" % [spec.x, spec.y]
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.16 * spec.z * 1.26
		cylinder.height = 5.0 * spec.z
		shape.shape = cylinder
		body.position = tree.position + Vector3(0, cylinder.height * 0.5, 0)
		body.add_child(shape)
		world.add_child(body)
		world.ground_obstacles.append(Rect2(Vector2(spec.x, spec.y) - Vector2.ONE * cylinder.radius,
			Vector2.ONE * cylinder.radius * 2.0))
		for index in range(100):
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf())
			var point := Vector2(spec.x, spec.y) + Vector2(cos(angle) * 2.0, sin(angle) * 2.8) * radius
			var colony := sin(point.x * 1.8 + point.y * 0.8) * cos(point.y * 1.3)
			if colony > 0.45 and radius > 0.35:
				continue
			var woody := index < 12 and radius < 0.70 and colony < -0.05
			var plant: Node3D = (shrub if woody else grass).instantiate()
			plant.position = Vector3(point.x, verge_height(point) + 0.025, point.y)
			plant.rotation.y = rng.randf() * TAU
			var spread := rng.randf_range(0.85, 1.30) if woody else rng.randf_range(0.45, 0.85)
			var height := rng.randf_range(0.85, 1.40) if woody else rng.randf_range(0.24, 0.55)
			plant.scale = Vector3(spread, height * lerpf(1.0, 0.35, radius), spread)
			world.add_child(plant)

static func service_road_shoulder_colonies(world) -> void:
	# Low irregular broadleaf skirts join the road shoulder to existing scrub.
	# Keep the apron crossing and the tested service/loading lanes open.
	var rng := RandomNumberGenerator.new()
	rng.seed = 321071
	var broad = preload("res://assets/realism/grass_broadleaf.glb")
	var fine = preload("res://assets/realism/grass_fine.glb")
	for pocket in [Vector4(10.8, 41.6, 1.6, 3.8), Vector4(-11.9, 47.0, 2.1, 4.1), Vector4(22.4, 42.0, 3.5, 2.8), Vector4(11.0, 36.7, 1.3, 3.2), Vector4(20.4, 37.8, 1.7, 3.2), Vector4(11.2, 46.0, 1.5, 2.4)]:
		for index in range(125):
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf())
			var point := Vector2(pocket.x, pocket.y) + Vector2(cos(angle) * pocket.z, sin(angle) * pocket.w) * radius
			if not service_growth_sample(point): continue
			var lane := minf(point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(15.5,36), Vector2(16,46))), point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(16,46), Vector2(9,52))))
			var loading := point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(16,46), Vector2(27,47)))
			if lane < 2.8 or loading < 2.6 or absf(point.x) < 9.8:
				continue
			# Sparse fine shoots extend beyond broadleaf colonies instead of
			# ending every patch at a uniform elliptical rim.
			var edge_break := sin(point.x * 2.1 + point.y) * cos(point.y * 1.3)
			if radius > 0.65 and edge_break > 0.12:
				continue
			var plant: Node3D = (broad if radius < 0.62 and index % 4 == 0 else fine).instantiate()
			plant.position = Vector3(point.x, verge_height(point) + 0.018, point.y)
			plant.rotation.y = rng.randf() * TAU
			var spread := rng.randf_range(0.46, 0.94)
			plant.scale = Vector3(spread, rng.randf_range(0.18, 0.45) * lerpf(1.0, 0.28, radius), spread)
			world.add_child(plant)

static func service_yard_scrub_islands(world) -> void:
	# Broad unused pockets give the approach a spatial hierarchy: open vehicle
	# lanes, low skirts, then irregular woody crowns. Never plant in doorways.
	var rng := RandomNumberGenerator.new()
	rng.seed = 307041
	var shrub = vegetation_scene("res://assets/realism/verge_fine_shrub.glb")
	var grass = load("res://assets/realism/grass_fine.glb")
	for pocket in [Vector4(10.0,40.5,1.8,2.5), Vector4(22.5,40.5,2.7,3.1),
		Vector4(23.0,51.7,2.6,1.7)]:
		for i in range(95):
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf())
			var p := Vector2(pocket.x,pocket.y) + Vector2(cos(angle)*pocket.z,sin(angle)*pocket.w)*radius
			if not service_growth_sample(p): continue
			var lane := minf(p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(15.5,36),Vector2(16,46))),
				p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(16,46),Vector2(9,52))))
			var loading := p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(16,46),Vector2(27,47)))
			if lane < 3.0 or loading < 2.7 or p.x < 8.6: continue
			# Break the former tall oval hedge into loose, low colonies.
			var gap := sin(p.x * 2.3 + p.y * 0.8) * cos(p.y * 1.7 - p.x * 0.6)
			if gap > 0.32: continue
			var woody := i < 6 and radius < 0.7
			var plant: Node3D = (shrub if woody else grass).instantiate()
			plant.name = "ServiceScrubIsland_%d" % i
			plant.position = Vector3(p.x,verge_height(p)+0.02,p.y)
			plant.rotation.y = rng.randf()*TAU
			var spread := rng.randf_range(0.65,1.05) if woody else rng.randf_range(0.65,1.2)
			var height := rng.randf_range(0.60,1.05) if woody else rng.randf_range(0.25,0.55)
			height *= lerpf(1.0,0.55,radius)
			plant.scale = Vector3(spread,height * lerpf(0.25, 1.0, service_growth(p)),spread)
			world.add_child(plant)

static func service_yard_groundcover(world) -> void:
	# A low, broken transition between bare wheel paths and tall colonies.
	# Deterministic meandering edges avoid a row of isolated identical tufts.
	var rng := RandomNumberGenerator.new()
	rng.seed = 242082
	var field := FastNoiseLite.new()
	field.seed = 242
	field.frequency = 0.48
	var grass_scene = load("res://assets/realism/grass_fine.glb")
	var leaf_scene = load("res://assets/realism/grass_broadleaf.glb")
	for i in range(2600):
		var p := Vector2(rng.randf_range(8.5, 24.0), rng.randf_range(34.8, 54.0))
		if not service_growth_sample(p): continue
		var lane := minf(
			p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(15.5,35.9), Vector2(15.5,44))),
			p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(15.5,44), Vector2(8.2,49.2))))
		var loading := p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(16,46), Vector2(27,47)))
		# Follow the rendered apron, including its bend. Short pioneer grass
		# overlaps the eroded shoulder; the wheel corridor remains clear.
		var edge := 2.95 + field.get_noise_2dv(p) * 0.48
		if lane < edge or lane > edge + 2.4 or loading < 2.15: continue
		if p.y < 38.0 and p.x > 12.0 and p.x < 19.0: continue
		if rng.randf() > 0.82 + field.get_noise_2dv(p * 2.2): continue
		var broad := rng.randf() < 0.24
		var plant: Node3D = (leaf_scene if broad else grass_scene).instantiate()
		plant.name = "ServiceGroundcover_%d" % i
		plant.position = Vector3(p.x, verge_height(p) + 0.018, p.y)
		plant.rotation.y = rng.randf() * TAU
		var spread := rng.randf_range(0.85, 1.55)
		var height := rng.randf_range(0.24, 0.52)
		height *= lerpf(0.35, 1.0, smoothstep(edge, edge + 1.2, lane))
		if broad:
			spread *= 0.52
		plant.scale = Vector3(spread, height * lerpf(0.25, 1.0, service_growth(p)), spread)
		world.add_child(plant)

# Closed annular extrusion. Smooth radial normals retain curved highlights,
# while the front/back faces keep the sharp rolled-section edges.
static func curved_steel_band(world: Node3D, origin: Vector3, inner: float, outer: float, depth: float, finish: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(64):
		var a := PI * float(segment) / 64.0
		var b := PI * float(segment + 1) / 64.0
		var ra := Vector3(cos(a), sin(a), 0)
		var rb := Vector3(cos(b), sin(b), 0)
		for face in range(4):
			var points: Array[Vector3]
			var normals: Array[Vector3]
			var front := Vector3(0, 0, depth * 0.5)
			if face < 2:
				var radius: float = outer if face == 0 else inner
				var sign_normal: float = 1.0 if face == 0 else -1.0
				points = [ra * radius - front, rb * radius - front, rb * radius + front, ra * radius + front]
				normals = [ra * sign_normal, rb * sign_normal, rb * sign_normal, ra * sign_normal]
			else:
				var offset := front if face == 2 else -front
				points = [ra * inner + offset, rb * inner + offset, rb * outer + offset, ra * outer + offset]
				normals = [offset.normalized(), offset.normalized(), offset.normalized(), offset.normalized()]
			# Godot's front faces use clockwise winding.
			var order := [0, 1, 2, 0, 2, 3]
			if (points[1] - points[0]).cross(points[2] - points[0]).dot(normals[0]) > 0:
				order = [0, 2, 1, 0, 3, 2]
			for index in order:
				surface.set_normal(normals[index])
				surface.set_uv(Vector2(points[index].x, points[index].y))
				surface.add_vertex(points[index])
	if OS.has_feature("android"):
		# Share identical position/normal/UV vertices; retain the arch's hard edges.
		surface.index()
		surface.optimize_indices_for_cache()
	var beam := MeshInstance3D.new()
	beam.name = "ContinuousSteelArch"
	beam.mesh = surface.commit()
	# This generated triangle surface has no imported LODs or local-space
	# deformation. Android can bake it with the other static steel sections.
	beam.set_meta("mobile_bake_static_surface", true)
	beam.material_override = finish
	beam.position = origin
	world.add_child(beam)
	beam.create_trimesh_collision()

static func service_shoulder_thickets(world) -> void:
	# Unequal overlapping crowns occupy unused soil, with graded grass skirts.
	# Growth mask and lane distances preserve entrance, loading and z=41 crossing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 358091
	var shrub = vegetation_scene("res://assets/realism/verge_fine_shrub.glb")
	var broad = preload("res://assets/realism/grass_broadleaf.glb")
	for pocket in [Vector4(10.7, 32.0, 1.2, 2.3), Vector4(23.1, 39.0, 2.4, 3.2), Vector4(24.5, 51.8, 3.3, 2.4), Vector4(-18.0, 50.5, 3.5, 2.0), Vector4(5.0, 29.0, 3.5, 4.5), Vector4(24.0, 27.0, 3.0, 4.0), Vector4(-20.0, 31.0, 4.0, 3.0)]:
		for index in range(85):
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf())
			var point := Vector2(pocket.x, pocket.y) + Vector2(cos(angle)*pocket.z, sin(angle)*pocket.w)*radius
			if not service_growth_sample(point): continue
			if absf(point.y - 41.0) < 1.4: continue
			var lane := point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(15.5,36), Vector2(16,46)))
			var loading := point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(16,46), Vector2(27,47)))
			if lane < 3.2 or loading < 3.0: continue
			# Continuous soil openings separate crowns and reveal the wall foot.
			var opening := sin(point.x * 1.31 + sin(point.y * 0.65)) * cos(point.y * 1.12)
			if opening > 0.30: continue
			var woody := index < 10 and radius < 0.70
			var plant: Node3D = (shrub if woody else broad).instantiate()
			plant.name = "ServiceShoulderThicket"
			plant.position = Vector3(point.x, verge_height(point)+0.015, point.y)
			plant.rotation.y = rng.randf()*TAU
			var spread := rng.randf_range(0.8, 1.5) if woody else rng.randf_range(0.35, 0.75)
			var height := rng.randf_range(0.65, 1.25) if woody else rng.randf_range(0.18, 0.44)
			plant.scale = Vector3(spread, height * (1.0-radius*0.3), spread*rng.randf_range(0.7,1.1))
			world.add_child(plant)
