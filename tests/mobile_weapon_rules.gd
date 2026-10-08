extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func triangles(model: Node3D) -> int:
	var count := 0
	for child in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(child.mesh.get_surface_count()):
			var arrays: Array = child.mesh.surface_get_arrays(surface)
			count += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return count

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var actor = load("res://scripts/actor.gd").new()
	actor.mobile_animation = true
	scene.add_child(actor)
	actor.set_local()
	for weapon in range(3):
		var path: String = actor.WEAPON_MODELS[weapon]
		var original: Node3D = load(path).instantiate()
		var mobile: Node3D = load(actor.MOBILE_WEAPON_MODELS[weapon]).instantiate()
		scene.add_child(original)
		scene.add_child(mobile)
		assert(triangles(mobile) < triangles(original) * 0.3, "Remote weapon needs a meaningful geometry reduction")
		for anchor in ["Magazine", "MuzzleAnchor", "SightAnchor"]:
			var full_node = original.find_child("*" + anchor + "*", true, false)
			var small_node = mobile.find_child("*" + anchor + "*", true, false)
			assert(full_node != null and small_node != null, "Keep reload and aim attachments")
			assert(full_node.transform.is_equal_approx(small_node.transform), "Keep attachment transforms")
		for full_mesh in original.find_children("*", "MeshInstance3D", true, false):
			var small_mesh = mobile.get_node(original.get_path_to(full_mesh))
			assert(small_mesh is MeshInstance3D)
			assert(full_mesh.mesh.get_aabb().get_center().distance_to(small_mesh.mesh.get_aabb().get_center()) < 0.01)
			assert(full_mesh.mesh.get_aabb().size.distance_to(small_mesh.mesh.get_aabb().size) < 0.025, "Keep weapon silhouette bounds")
			assert(full_mesh.mesh.get_surface_count() == small_mesh.mesh.get_surface_count(), "Keep material regions")
			var mobile_materials := {}
			for surface in range(small_mesh.mesh.get_surface_count()):
				var material = small_mesh.mesh.surface_get_material(surface)
				assert(material != null)
				assert(not mobile_materials.has(material.resource_name), "Material regions must remain distinct")
				mobile_materials[material.resource_name] = material
			for surface in range(full_mesh.mesh.get_surface_count()):
				var full_material = full_mesh.mesh.surface_get_material(surface)
				# Splitting and rejoining material regions changes surface order.
				assert(mobile_materials.has(full_material.resource_name), "Keep each authored material")
				var small_material = mobile_materials[full_material.resource_name]
				if full_material is BaseMaterial3D and full_material.albedo_texture != null:
					assert(small_material.albedo_texture != null, "Keep baked appearance")
					# Imported GPU compression may differ; compare authored PNG pixels.
					var full_image := Image.load_from_file(full_material.albedo_texture.resource_path)
					var small_image := Image.load_from_file(small_material.albedo_texture.resource_path)
					assert(full_image != null and small_image != null)
					assert(full_image.get_size() == small_image.get_size())
					full_image.convert(Image.FORMAT_RGBA8)
					small_image.convert(Image.FORMAT_RGBA8)
					assert(full_image.get_data() == small_image.get_data(), "Keep original baked texture pixels")
		actor.weapon = weapon
		actor.update_weapon_visuals(true)
		assert(actor.third_person_gun.scene_file_path == actor.MOBILE_WEAPON_MODELS[weapon])
		assert(actor.gun_model.scene_file_path == path, "Keep close-up first-person geometry")
		assert(actor.third_person_magazine != null)
		var skeleton: Skeleton3D = actor.character_animation.skeleton
		var bone := skeleton.find_bone("Weapon")
		var rest := skeleton.get_bone_global_rest(bone)
		for clip in ["Idle", "Reload", "CrouchReload"]:
			actor.reload_left = 1.0 if clip.ends_with("Reload") else 0.0
			actor.character_animation.active_clip = clip
			skeleton.set_bone_pose_rotation(bone, Quaternion(Vector3.UP, 0.37))
			actor.update_weapon_attachment()
			var expected := skeleton.get_bone_global_pose(bone) * rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin)
			assert(actor.third_person_gun.transform.is_equal_approx(expected),
				"Cached socket must preserve animated placement after weapon changes")
			if clip.ends_with("Reload"):
				actor.reload_left = 0
				actor.update_weapon_attachment()
				assert(actor.third_person_magazine.transform.is_equal_approx(actor.third_person_magazine_rest),
					"Interrupted reload must restore magazine socket")
		print("MOBILE_WEAPON ", path, " triangles=", triangles(original), " -> ", triangles(mobile))
		original.free()
		mobile.free()
	print("MOBILE_WEAPON_PASS: geometry, attachments, materials, bounds and actor selection")
	quit()
