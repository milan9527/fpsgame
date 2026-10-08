extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var visuals = load("res://scripts/world_visuals.gd")
	var checked := 0
	var baked_normals := 0
	for weapon in ["carbine", "shotgun", "marksman"]:
		var model = load("res://assets/%s.glb" % weapon).instantiate()
		var found := {}
		visuals.weapon_finish(model)
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var source = mesh.mesh.surface_get_material(surface)
				var finish = mesh.get_surface_override_material(surface)
				if finish == null:
					continue
				var key: String = source.resource_name
				found[key] = true
				assert(finish != source, "Imported shared materials must not be mutated")
				assert(finish.roughness_texture != null and finish.normal_texture != null)
				if source.albedo_texture != null:
					assert(finish.albedo_color == Color.WHITE, "Baked colour must not be darkened by legacy tint")
					assert(finish.albedo_texture == source.albedo_texture)
					assert(not finish.uv1_triplanar and finish.uv1_scale == Vector3.ONE)
					assert(finish.roughness_texture == source.roughness_texture)
					assert(is_equal_approx(finish.roughness, source.roughness))
					if source.normal_enabled and source.normal_texture != null:
						assert(finish.normal_enabled)
						assert(finish.normal_texture == source.normal_texture, "Baked normal grain must survive runtime finishing")
						assert(is_equal_approx(finish.normal_scale, source.normal_scale))
						baked_normals += 1
				if key.begins_with("Shoulder pad /") or key.ends_with("composite"):
					assert(finish.metallic == 0.0, "Stock and rubber cannot inherit metal response")
				elif key.begins_with("Bolt /"):
					assert(finish.metallic > 0.9)
					assert(finish.uv1_scale.y > finish.uv1_scale.x * 10, "Machined grain is directional")
				elif key.begins_with("Graphite /"):
					assert(finish.metallic > 0.5)
				elif key.begins_with("Receiver /") or key.begins_with("Receiver edge /"):
					assert(is_equal_approx(finish.metallic, source.metallic))
					if weapon == "carbine":
						assert(finish.metallic < 0.6, "Coated receiver must not revert to bare metal")
					assert(finish.albedo_color.r > 0.25, "Receiver planes must remain readable")
				elif key.begins_with("Optic /") and source.albedo_texture == null:
					assert(finish.albedo_color != source.albedo_color,
						"Optic aluminium must receive the runtime finish")
				checked += 1
		assert(found.has("Graphite / parkerized steel"))
		if weapon == "carbine":
			assert(found.has("Optic / bead blasted aluminium"))
			assert(found.has("Receiver / anodized aluminium"))
			assert(found.has("Receiver edge / satin anodized aluminium"))
		var has_rubber := false
		for key in found:
			if key.begins_with("Shoulder pad / charcoal rubber"):
				has_rubber = true
		assert(has_rubber, "Each weapon must include its rubber shoulder pad finish")
		assert(found.has("Slate / composite" if weapon == "carbine" else weapon + " composite"),
			"Each imported stock material must receive its finish")
		# Reapplying must reuse cached materials, not allocate per frame.
		var cache_count: int = visuals.weapon_material_cache.size()
		visuals.weapon_finish(model)
		assert(visuals.weapon_material_cache.size() == cache_count)
		model.free()
	assert(baked_normals > 0, "Exercise imported baked normals rather than only procedural fallback")
	print("WEAPON_FINISH_RULES_PASS models=3 surfaces=%d baked_normals=%d coverage=ok dielectric=ok source_isolation=ok cache=ok" % [checked, baked_normals])
	quit()
