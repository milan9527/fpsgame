extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sync() -> void:
	await physics_frame
	await physics_frame

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.volume = 0
	game.elapsed = 10
	var actor = game.actors[1]
	for other in game.actors.values():
		other.position = Vector3(105, 0.02, 80 + other.actor_id)
	actor.position = Vector3(0, 0.02, 20)
	actor.yaw = 0
	actor.pitch = 0
	actor.aiming = true
	actor.grounded = true
	var wall = game.world.block(Vector3(0, 1.5, 19.4), Vector3(3, 3, 0.2), "465a61")
	await sync()
	for weapon in range(3):
		actor.switch_weapon(weapon)
		actor.fire_left = 0
		assert(actor.weapon_obstructed(true) and actor.weapon_obstructed(false))
		var ammo: int = actor.ammo
		actor.weapon_blocked = false # An untrusted cosmetic flag cannot permit firing.
		game.shoot(actor)
		assert(actor.ammo == ammo and actor.recoil == 0 and actor.fire_left == 0 and actor.weapon_blocked, "Authority blocks before ammo/recoil/effects")
	actor.yaw = PI / 2
	assert(not actor.weapon_obstructed(true), "Probe rotates with aim")
	actor.yaw = 0
	for frame in range(30):
		actor.render_frame(1.0 / 60, false, true, true)
		game.ui.update_hud(actor, game.alive_count(), "live", 300, 110, [], "")
		await process_frame
	assert(actor.first_person.wall_blend == 1 and actor.first_person.aim_blend == 0)
	assert(actor.gun.rotation.x < -1 and actor.camera.fov > 84)
	assert(not actor.first_person.sight_dot.visible and "MUZZLE BLOCKED" in game.ui.prompt.text)
	assert(actor.muzzle.global_position.z > 19.5, "Lowered long barrel remains on player side of frontal wall")
	if "--capture-obstruction" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/weapon-obstruction.png")
	wall.queue_free()
	await sync()
	wall = game.world.block(Vector3(0, 1.5, 18.98), Vector3(3, 3, 0.1), "465a61")
	await sync()
	actor.weapon = 0
	assert(not actor.weapon_obstructed(true))
	actor.weapon = 2
	assert(actor.weapon_obstructed(true), "Long barrel requires more clearance")
	wall.queue_free()
	await sync()
	wall = game.world.block(Vector3(0, 0.5, 19.4), Vector3(3, 1, 0.2), "465a61")
	await sync()
	assert(not actor.weapon_obstructed(true), "Standing shot clears waist-high cover")
	actor.crouch = true
	actor.update_stance()
	assert(actor.weapon_obstructed(true), "Crouching lowers the same barrel behind cover")
	wall.queue_free()
	await sync()
	actor.crouch = false
	actor.update_stance()
	for frame in range(30):
		actor.render_frame(1.0 / 60, false, true, true)
		await process_frame
	assert(actor.first_person.wall_blend == 0 and actor.first_person.aim_blend == 1)
	var ammo: int = actor.ammo
	game.shoot(actor)
	assert(actor.ammo == ammo - 1 and actor.recoil > 0, "Firing resumes after clearance")
	wall = game.world.block(actor.eye_position(), Vector3(0.2, 0.2, 0.2), "465a61")
	await sync()
	assert(actor.weapon_obstructed(true), "Initial overlap is blocked as well as swept collision")
	print("WEAPON_OBSTRUCTION_RULES_PASS authority=ok ammo=ok rotated=ok lengths=ok crouch=ok overlap=ok low_ready=ok zoom=ok hud=ok recovery=ok")
	game.queue_free()
	await process_frame
	quit()
