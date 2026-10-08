extends SceneTree

# Exercise actual ammunition, spread, armor and damage in the depot doorway.
# A camera/raycast alignment check alone cannot prove shoot() deals damage.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	var android_terrain := OS.get_environment("CAPTURE_ANDROID_TERRAIN") == "1"
	if android_terrain:
		var replacements := 0
		for terrain in game.find_children("ExcavatedTerrain", "MeshInstance3D", true, false):
			var shapes: Array[Node] = terrain.find_children("*", "CollisionShape3D", true, false)
			assert(shapes.size() == 1)
			var cached_shape: Shape3D = load("res://assets/android_terrain_collision.res")
			assert(cached_shape != null)
			shapes[0].shape = cached_shape
			replacements += 1
		assert(replacements == 1)
	game.set_process(false)
	game.set_physics_process(false)
	game.elapsed = 10.0
	var actor = game.actors[game.local_id]
	var target = game.actors[-1]
	for other in game.actors.values():
		other.position = Vector3(1000, 80, other.actor_id * 5)
	var samples := []
	var failed := false
	for weapon in range(3):
		for covered in [false, true]:
			# The open 4 m doorway and adjacent intact wall share the same depth.
			var x := 27.0 if covered else 23.5
			actor.position = Vector3(x, 0.15, 43)
			target.position = Vector3(x, 0.15, 35)
			target.health = 100.0
			target.armor = 50.0
			target.alive = true
			actor.reload_left = 0
			actor.switch_weapon(weapon)
			actor.fire_left = 0
			actor.recoil = 0
			actor.velocity = Vector3.ZERO
			actor.aiming = true
			actor.yaw = 0
			var direction: Vector3 = (target.position + Vector3.UP - actor.eye_position()).normalized()
			actor.pitch = asin(direction.y)
			for frame in range(3):
				await physics_frame
			actor.render_frame(1.0 / 60.0, false, true, true)
			var ammo_before: int = actor.ammo
			seed(130 + weapon)
			game.shoot(actor)
			var damage: float = 150.0 - target.health - target.armor
			var passed: bool = actor.ammo == ammo_before - 1 and (damage == 0.0 if covered else damage > 0.0)
			failed = failed or not passed
			samples.append({"weapon": weapon, "covered": covered,
				"shooter_position": str(actor.position), "target_position": str(target.position),
				"pitch": actor.pitch, "ammo_before": ammo_before, "ammo_after": actor.ammo,
				"health_after": target.health, "armor_after": target.armor,
				"damage": damage, "passed": passed})
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("aim-damage.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": samples, "passed": not failed,
		"cached_android_terrain_collision": android_terrain,
		"scope": "Local authoritative shoot() with seeded spread; not authenticated multiplayer."}, "\t"))
	file.close()
	print("AIM_DAMAGE_", "FAIL" if failed else "PASS", " ", JSON.stringify(samples))
	quit(1 if failed else 0)
