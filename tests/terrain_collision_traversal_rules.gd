extends SceneTree

# Desktop differential physics probe, never Android presentation evidence.
const Chunks = preload("res://scripts/terrain_collision_chunks.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := "../artifacts/android-terrain-traversal-20260929"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var source: ConcavePolygonShape3D = load("res://assets/android_terrain_collision.res")
	var started := Time.get_ticks_usec()
	var single_tree := "--single-tree" in OS.get_cmdline_user_args()
	var chunks := Chunks.build(source, 16.0, single_tree)
	var control := "--control" in OS.get_cmdline_user_args()
	if control:
		chunks.clear()
		chunks.append(source)
	var build_us := Time.get_ticks_usec() - started
	var space := Node3D.new()
	root.add_child(space)
	for variant in range(2):
		var terrain := StaticBody3D.new()
		terrain.collision_layer = 1 << variant
		terrain.collision_mask = 0
		var shapes: Array[ConcavePolygonShape3D] = []
		if variant == 0:
			shapes.append(source)
		else:
			shapes.assign(chunks)
		for shape in shapes:
			var collision := CollisionShape3D.new()
			collision.shape = shape
			terrain.add_child(collision)
		space.add_child(terrain)
	var pairs := []
	# Cross partition seams in both directions and the yard's fine/coarse
	# triangle boundaries. All pairs use identical capsule dimensions/input.
	for z in [-32.0, -16.0, 0.0, 16.0, 32.0, 48.0]:
		for direction in [Vector3.RIGHT, Vector3.BACK]:
			var actors: Array[CharacterBody3D] = []
			var origin := Vector3(-20, 3, z) if direction == Vector3.RIGHT else Vector3(z, 3, -20)
			for variant in range(2):
				var actor := CharacterBody3D.new()
				actor.collision_layer = 0
				actor.collision_mask = 1 << variant
				var collision := CollisionShape3D.new()
				var capsule := CapsuleShape3D.new()
				capsule.radius = 0.38
				capsule.height = 1.8
				collision.shape = capsule
				collision.position.y = 0.9
				actor.add_child(collision)
				space.add_child(actor)
				actor.position = origin
				actors.append(actor)
			pairs.append({"actors": actors, "direction": direction,
				"position_differences": 0, "floor_differences": 0,
				"normal_differences": 0, "slide_count_differences": 0,
				"slide_normal_differences": 0,
				"max_position_delta": 0.0, "grounded_ticks": [0, 0]})
	await physics_frame
	await physics_frame
	var examples := []
	var timings := [[], []]
	for tick in range(720):
		await physics_frame
		for index in range(pairs.size()):
			var pair: Dictionary = pairs[index]
			for variant in range(2):
				var actor: CharacterBody3D = pair.actors[variant]
				var direction: Vector3 = pair.direction
				# Settle, traverse at normal run speed, reverse, then jump.
				var speed := 0.0 if tick < 60 else (5.0 if tick < 420 else -5.0)
				actor.velocity.x = direction.x * speed
				actor.velocity.z = direction.z * speed
				if actor.is_on_floor():
					actor.velocity.y = 6.0 if tick == 500 else 0.0
				else:
					actor.velocity.y -= 20.0 / 60.0
				started = Time.get_ticks_usec()
				actor.move_and_slide()
				timings[variant].append(Time.get_ticks_usec() - started)
				if actor.is_on_floor():
					pair.grounded_ticks[variant] += 1
			var before: CharacterBody3D = pair.actors[0]
			var after: CharacterBody3D = pair.actors[1]
			var distance := before.position.distance_to(after.position)
			pair.max_position_delta = maxf(pair.max_position_delta, distance)
			if distance > 0.001:
				pair.position_differences += 1
				if examples.size() < 20:
					examples.append({"path": index, "tick": tick, "distance": distance,
						"source": [before.position.x, before.position.y, before.position.z],
						"chunked": [after.position.x, after.position.y, after.position.z]})
			if before.is_on_floor() != after.is_on_floor():
				pair.floor_differences += 1
			if before.get_floor_normal().distance_to(after.get_floor_normal()) > 0.001:
				pair.normal_differences += 1
			if before.get_slide_collision_count() != after.get_slide_collision_count():
				pair.slide_count_differences += 1
			else:
				for collision_index in range(before.get_slide_collision_count()):
					if before.get_slide_collision(collision_index).get_normal().distance_to(
						after.get_slide_collision(collision_index).get_normal()) > 0.001:
						pair.slide_normal_differences += 1
	var paths := []
	var passed := true
	for pair in pairs:
		pair.erase("actors")
		pair.erase("direction")
		paths.append(pair)
		passed = passed and pair.position_differences == 0 and pair.floor_differences == 0 \
			and pair.normal_differences == 0 and pair.slide_count_differences == 0 \
			and pair.slide_normal_differences == 0 \
			and pair.grounded_ticks[0] > 300 and pair.grounded_ticks[1] > 300
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "control": control, "single_tree": single_tree, "paths": paths, "ticks_per_path": 720,
		"examples": examples, "move_and_slide_us": timings, "chunk_build_us": build_us,
		"scope": "Desktop differential terrain-only physics; not Android FPS or acceptance"}))
	file.close()
	print("TERRAIN_TRAVERSAL_", "PASS" if passed else "FAIL", " paths=", paths.size(),
		" ticks=720 build_us=", build_us)
	space.queue_free()
	await process_frame
	quit(0 if passed else 1)
