extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.position = Vector3(4, 5, 6)
	camera.current = true
	var original := camera.transform
	await load("res://scripts/mobile_performance.gd").warm_combat(camera)
	assert(camera.transform == original)
	var stage := host.get_node("CombatRenderWarmup")
	assert(not stage.visible and stage.get_child_count() == 24)
	var tools_model = load("res://assets/realism/workshop_tools.glb").instantiate()
	var diffuser_source = tools_model.find_child("Task light diffuser", true, false)
	var diffuser = stage.get_node("WorkshopTaskDiffuser")
	assert(diffuser.mesh == diffuser_source.mesh)
	assert(diffuser.material_override == diffuser_source.get_active_material(0))
	assert(diffuser.material_override.emission_enabled)
	assert(not diffuser.material_override.normal_enabled)
	assert(diffuser.material_override.cull_mode == BaseMaterial3D.CULL_DISABLED)
	assert(diffuser.material_override.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED)
	assert(not diffuser.visible)
	assert(diffuser.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	tools_model.free()
	var glazing := stage.get_node("WorkshopRoofGlazing") as MeshInstance3D
	assert(not glazing.visible)
	assert(glazing.material_override.shader == load("res://shaders/workshop_roof_glazing_mobile.gdshader"))
	assert(glazing.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for entry in [["WorkbenchWood", "workbench_wood"], ["WorkshopPegboard", "workshop_pegboard"],
			["WorkshopGlass", "workshop_glass"], ["WorkshopJamb", "workshop_jamb"]]:
		var surface := stage.get_node(NodePath(entry[0])) as MeshInstance3D
		assert(not surface.visible)
		assert(surface.material_override.shader == load("res://shaders/%s.gdshader" % entry[1]))
		assert(surface.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(stage.find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(stage.process_mode == Node.PROCESS_MODE_DISABLED)
	var blast = load("res://scripts/blast_effect.gd")
	var gameplay_particles = blast.create_particles()
	for index in range(2):
		var particles = gameplay_particles[index]
		var warmed = stage.get_node(NodePath(str(particles.name)))
		assert(warmed.mesh == particles.mesh)
		assert(warmed.amount == particles.amount and warmed.lifetime == particles.lifetime)
		assert(not warmed.visible and not warmed.emitting)
		assert(warmed.process_mode == Node.PROCESS_MODE_DISABLED)
		assert(particles.emitting and particles.preprocess == 0.0)
		particles.free()
	var visuals = load("res://scripts/world_visuals.gd")
	var count: int = visuals.military_material_cache.size()
	var actor = load("res://assets/operator_mobile.glb").instantiate()
	host.add_child(actor)
	visuals.military_materials(actor)
	assert(count > 0 and visuals.military_material_cache.size() == count)
	var gameplay_scope = load("res://scripts/first_person.gd").create_scope_lens()
	var warmed_scope := stage.get_node("ScopeLens") as MeshInstance3D
	assert(gameplay_scope.mesh == warmed_scope.mesh)
	assert(gameplay_scope.material_override == warmed_scope.material_override)
	assert(gameplay_scope.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	gameplay_scope.free()
	var gameplay_muzzle = load("res://scripts/muzzle_flash.gd").create()
	var warmed_muzzle := stage.get_node("MuzzleFlash") as MeshInstance3D
	assert(gameplay_muzzle.mesh == warmed_muzzle.mesh)
	assert(gameplay_muzzle.material_override == warmed_muzzle.material_override)
	assert(not gameplay_muzzle.visible and not warmed_muzzle.visible)
	assert(gameplay_muzzle.mesh.radial_segments == 6)
	assert(is_equal_approx(gameplay_muzzle.mesh.height, 0.12))
	assert(gameplay_muzzle.material_override.albedo_color == Color("ffe7a0"))
	assert(gameplay_muzzle.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var warmed_transform := warmed_muzzle.transform
	gameplay_muzzle.position = Vector3(1, 2, 3)
	gameplay_muzzle.visible = true
	assert(warmed_muzzle.transform == warmed_transform and not warmed_muzzle.visible)
	gameplay_muzzle.free()
	var gameplay_tracer = load("res://scripts/tracer_effect.gd").create()
	var warmed_tracer := stage.get_node("Tracer") as MeshInstance3D
	assert(gameplay_tracer.mesh == warmed_tracer.mesh)
	assert(gameplay_tracer.mesh.surface_get_material(0) == warmed_tracer.mesh.surface_get_material(0))
	assert(gameplay_tracer.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(not warmed_tracer.visible and gameplay_tracer.visible)
	var tracer_transform := warmed_tracer.transform
	gameplay_tracer.position = Vector3(5, 1, -2)
	assert(warmed_tracer.transform == tracer_transform)
	gameplay_tracer.free()
	var gameplay_smoke = load("res://scripts/smoke_effect.gd").create()
	var warmed_smoke := stage.get_node("SmokeCloud") as MeshInstance3D
	assert(gameplay_smoke.mesh == warmed_smoke.mesh)
	assert(gameplay_smoke.material_override != warmed_smoke.material_override)
	assert(gameplay_smoke.material_override.shader == warmed_smoke.material_override.shader)
	assert(gameplay_smoke.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(gameplay_smoke.mesh.radial_segments == 32 and gameplay_smoke.mesh.rings == 16)
	assert(not warmed_smoke.visible)
	gameplay_smoke.material_override.set_shader_parameter("density", 0.25)
	assert(warmed_smoke.material_override.get_shader_parameter("density") == 1.0)
	gameplay_smoke.free()
	var gun := Node3D.new()
	host.add_child(gun)
	var weapon := Node3D.new()
	gun.add_child(weapon)
	var arms = load("res://scripts/first_person.gd").new()
	for kind in [2, 0, 2]:
		arms.bind_weapon(weapon, gun, kind)
		if kind == 2:
			assert(arms.scope_lens.mesh == warmed_scope.mesh)
			assert(arms.scope_lens.material_override == warmed_scope.material_override)
		else:
			assert(arms.scope_lens == null)
		await process_frame
	print("COMBAT_WARMUP_PASS camera restored, twelve models, gameplay scope, muzzle, tracer, smoke and blast particles, no collisions, shared resources, independent instance state, warm particles stopped")
	host.queue_free()
	await process_frame
	quit()
