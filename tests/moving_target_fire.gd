extends SceneTree

# Real ground movement, camera alignment, authoritative trace and weapon damage.
# Target health is enlarged to keep one moving fixture alive across all weapons.
var samples := []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.local_profile = null
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	game.elapsed = 10.0 # Outside normal spawn protection.
	game.rng.seed = 143
	var actor = game.actors[game.local_id]
	var target = game.actors[-1]
	for other in game.actors.values():
		other.position = Vector3(100, 80, 100)
	actor.position = Vector3(0, 0.3, 68)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2.ZERO
	actor.aiming = true
	target.position = Vector3(-1.5, 0.3, 60)
	target.velocity = Vector3.ZERO
	target.yaw = 0
	target.health = 10000
	target.armor = 0
	var travel := 0.0
	for weapon in range(3):
		actor.switch_weapon(weapon)
		for shot in range(mini(6, actor.CAPACITY[weapon])):
			# Respect the marksman's 1.25-second cooldown and five-round magazine.
			for frame in range(90):
				target.move_input = Vector2(
					-1 if target.position.x > 1.5 else
					(1 if target.position.x < -1.5 else
					(1 if target.move_input.x == 0 else target.move_input.x)), 0)
				await physics_frame
				var previous: Vector3 = target.position
				target.simulate(1.0 / 60.0)
				actor.simulate(1.0 / 60.0)
				travel += target.position.distance_to(previous)
			# Allow the physics server to publish the final moved collider.
			await physics_frame
			var direction: Vector3 = (target.position + Vector3.UP - actor.eye_position()).normalized()
			actor.yaw = atan2(-direction.x, -direction.z)
			actor.pitch = asin(direction.y) - actor.recoil
			actor.render_frame(1.0 / 60.0, false, true, true)
			var camera_ray: Vector3 = -actor.camera.global_basis.z.normalized()
			if not check(camera_ray.distance_to(direction) < 0.0001, "Moving target camera alignment failed"): return
			var hit: Dictionary = game.trace_shot(actor, actor.eye_position(), camera_ray, 0)
			if not check(not hit.is_empty() and hit.collider == target, "Moving target center trace missed"): return
			var before_health: float = target.health
			var before_ammo: int = actor.ammo
			game.shoot(actor)
			if not check(actor.ammo == before_ammo - 1, "Weapon %d shot %d failed to fire (cooldown=%.3f blocked=%s)" % [weapon, shot, actor.fire_left, actor.weapon_blocked]): return
			if not check(target.health < before_health, "Moving target received no weapon damage"): return
			if not check(target.grounded and actor.grounded, "Fixture left actual terrain"): return
			samples.append({"weapon": weapon, "shot": shot, "target_position": str(target.position),
				"target_velocity": str(target.velocity), "damage": before_health - target.health,
				"ammo": actor.ammo, "camera_position": str(actor.camera.global_position),
				"camera_rotation": str(actor.camera.global_rotation)})
	if not check(travel > 50, "Target did not travel far enough"): return
	var directory := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("moving-target-fire.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed": true, "travel_meters": travel,
			"samples": samples, "scope": "Seeded solo test, enlarged target health; no network latency or user aim input."}, "\t"))
		file.close()
	print("MOVING_TARGET_FIRE_PASS shots=%d weapons=3 actual_terrain=true travel=%.2fm" % [samples.size(), travel])
	game.request_quit(0, true)
