extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func geometries(node: Node) -> Array:
	var result: Array = []
	if node is GeometryInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(geometries(child))
	return result

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	var actor = game.actors[1]
	var remote = game.actors[-1]
	var checked := 0
	for weapon in [0, 1, 2, 0]:
		actor.switch_weapon(weapon)
		await process_frame
		for mesh in geometries(actor.gun):
			if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				push_error("Viewmodel shadow caster survives weapon switch: " + str(mesh.name))
				quit(1)
				return
			checked += 1
		for node in [remote.body_mesh, actor.third_person_gun]:
			var casters := 0
			for mesh in geometries(node):
				if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					casters += 1
			if casters == 0:
				push_error("World or remote shadow casting disabled")
				quit(1)
				return
	print("VIEWMODEL_SHADOW_RULES_PASS meshes=%d switches=4 remote_and_world_casters=preserved" % checked)
	game.queue_free()
	await process_frame
	quit()
