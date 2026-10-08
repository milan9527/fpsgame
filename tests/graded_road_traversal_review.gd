extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var results := []
	var passed := true
	for east_west in [false, true]:
		# Cover the restored frontage shoulder as well as the remote road.
		# z=26 remains an investigation route: do not assume the grove is clear.
		# Preserve blocking collider identities alongside traversal failures.
		for along in ([85.0] if east_west else [26.0, 35.0, 49.0, 58.0, 85.0]):
			for side in [-1.0, 1.0]:
				for direction in [-1.0, 1.0]:
					var across: float = side * (8.0 - (1.0 if east_west else 0.0))
					var center := Vector2(along, across) if east_west else Vector2(across, along)
					var travel := Vector2(0, direction) if east_west else Vector2(direction, 0)
					var start := center - travel * 3.2
					actor.position = Vector3(start.x, 0.5, start.y)
					actor.velocity = Vector3.ZERO
					actor.yaw = 0
					actor.move_input = Vector2.ZERO
					for frame in range(30):
						await physics_frame
						actor.move_step(1.0 / 60.0)
					var highest := 0.0
					var distance := 0.0
					var blockers := {}
					actor.move_input = travel
					for frame in range(180):
						await physics_frame
						actor.move_step(1.0 / 60.0)
						for collision_index in range(actor.get_slide_collision_count()):
							var collision = actor.get_slide_collision(collision_index)
							if absf(collision.get_normal().y) < 0.7:
								var collider = collision.get_collider()
								if is_instance_valid(collider):
									var detail := {"position": str(collider.global_position),
										"contact": str(collision.get_position()), "normal": str(collision.get_normal())}
									var parent = collider.get_parent()
									if parent is MeshInstance3D:
										detail["mesh_bounds"] = str(parent.get_aabb())
										detail["mesh_transform"] = str(parent.global_transform)
									blockers[str(collider.get_path())] = detail
						highest = maxf(highest, actor.position.y)
						distance = (Vector2(actor.position.x, actor.position.z) - start).dot(travel)
						if distance > 6.4:
							break
					# The recovered drainage bank now rises up to 0.82 m.
					# Access mouths remain nearly level; elsewhere verify that
					# the actor walks over the bank without snagging or launching.
					# Only actual road mouths must remain flat. The former
					# z=26 opening and mirrored west z=49 opening are banks.
					var access: bool = not east_west and (along == 35.0 or (along == 49.0 and side > 0.0))
					var height_limit := 0.16 if access else 0.90
					var ok: bool = distance > 6.4 and highest < height_limit and actor.position.y < height_limit
					passed = passed and ok
					results.append({"east_west": east_west, "along": along, "side": side,
						"direction": direction, "start": str(start), "end": str(actor.position),
						"highest": highest, "distance": distance, "passed": ok,
						"blocking_colliders": blockers})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("graded-road-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "results": results}, "\t"))
	file.close()
	print("GRADED_ROAD_TRAVERSAL_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
