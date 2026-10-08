extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func point(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func run() -> void:
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	var actor = game.actors[game.local_id]
	var records: Array = []
	for weapon in range(3):
		actor.reload_left = 0.0
		actor.switch_weapon(weapon)
		actor.ammo -= 1
		actor.reload_weapon()
		var count := int(ceil(actor.RELOAD[weapon]*60))+2
		for frame in range(count):
			await physics_frame
			actor.simulate(1.0/60.0)
			actor.render_frame(1.0/60.0, false, true, false)
			var fp = actor.first_person
			var sk: Skeleton3D = fp.skeleton
			var shoulder := sk.find_bone("UpperArm.L")
			var elbow := sk.find_bone("Forearm.L")
			var wrist := sk.find_bone("Hand.L")
			var s := sk.get_bone_global_pose(shoulder).origin
			var e := sk.get_bone_global_pose(elbow).origin
			var w := sk.get_bone_global_pose(wrist).origin
			records.append({"weapon":weapon,"frame":frame,"progress":1.0-actor.reload_left/actor.RELOAD[weapon],
				"shoulder":point(s),"elbow":point(e),"wrist":point(w),
				"shoulder_shift_m":s.distance_to(sk.get_bone_global_rest(shoulder).origin),
				"upper_length_m":s.distance_to(e),"lower_length_m":e.distance_to(w),
				"contact_error_m":fp.reload_contact_error})
	var file := FileAccess.open(output.path_join("reload-reach.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"records":records,"scope":"60Hz simulated transforms; not a rendered motion acceptance"},"\t"))
	print("RELOAD_REACH_CAPTURE_PASS frames=",records.size())
	quit()
