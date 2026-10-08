extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model = load("res://assets/first_person.glb").instantiate()
	load("res://scripts/world_visuals.gd").military_materials(model)
	var checked := {}
	var triangle_count := 0
	for instance in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(instance.mesh.get_surface_count()):
			var material = instance.get_active_material(surface)
			if material.resource_name not in ["Reinforced gloves", "Glove leather pads", "Field sleeves", "Sleeve abrasion twill"]:
				continue
			assert(material.normal_enabled and material.normal_texture != null,
				"Exported glove microstructure must survive import and runtime overrides")
			assert(material.metallic == 0.0, "Gloves are dielectric")
			if material.resource_name == "Sleeve abrasion twill":
				assert(material.albedo_texture != null and material.roughness_texture != null,
					"Reinforcement dye and cloth roughness must survive the asset export")
			var arrays = instance.mesh.surface_get_arrays(surface)
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			assert(uv.size() == arrays[Mesh.ARRAY_VERTEX].size())
			var nondegenerate := 0
			for i in range(0, indices.size(), 3):
				var a = uv[indices[i + 1]] - uv[indices[i]]
				var b = uv[indices[i + 2]] - uv[indices[i]]
				if absf(a.cross(b)) > 0.0000001:
					nondegenerate += 1
			# Closed digit end caps collapse in UV; the swept finger walls must
			# not. This catches the former missing UVs on every finger/thumb.
			assert(nondegenerate > indices.size() / 3 * 0.95,
				"At least 95% of glove triangles need noncollapsed UVs")
			triangle_count += nondegenerate
			checked[material.resource_name] = true
	assert(checked.size() == 4, "Sleeve reinforcement must retain its distinct twill material")
	model.free()
	print("GLOVE_SURFACE_RULES_PASS materials=4 sleeves_and_reinforcement_included normal_maps=ok dielectric=ok uv_triangles=%d" % triangle_count)
	quit()
