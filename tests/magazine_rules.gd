extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.elapsed = 10
	game.sound.volume = 0
	var actor = game.actors[1]
	for other in game.actors.values():
		other.position = Vector3(100, 0.02, 70 + other.actor_id)
	actor.position = Vector3(0, 0.02, 20)
	actor.grounded = true
	await physics_frame
	assert(actor.magazines == PackedInt32Array([30, 8, 5]) and actor.total_ammunition() == 163)
	game.shoot(actor)
	assert(actor.magazines == PackedInt32Array([29, 8, 5]) and actor.total_ammunition() == 162)
	actor.switch_weapon(1)
	assert(actor.ammo == 8 and actor.reserve == 120 and actor.fire_left == 0.5)
	game.shoot(actor)
	assert(actor.ammo == 8, "Weapon raising delay still gates fire")
	actor.fire_left = 0
	game.shoot(actor)
	assert(actor.ammo == 7 and actor.magazines[0] == 29)
	actor.switch_weapon(0)
	assert(actor.ammo == 29 and actor.reserve == 120, "Returning to a weapon does not refill it")
	var total: int = actor.total_ammunition()
	actor.reload_weapon()
	actor.simulate(0.5)
	assert(actor.ammo == 29 and actor.reserve == 120, "Reload transfers no ammunition early")
	actor.switch_weapon(2)
	assert(actor.weapon == 0, "Cannot redirect a pending reload to another magazine")
	actor.simulate(2)
	assert(actor.magazines == PackedInt32Array([30, 7, 5]) and actor.reserve == 119)
	assert(actor.total_ammunition() == total)
	actor.ammo = 0
	total = actor.total_ammunition()
	for i in range(4):
		actor.switch_weapon(1)
		assert(actor.ammo == 7)
		actor.switch_weapon(2)
		assert(actor.ammo == 5)
		actor.switch_weapon(0)
		assert(actor.ammo == 0 and actor.total_ammunition() == total, "Cycling cannot refill an empty magazine")
	actor.reserve = 2
	actor.reload_weapon()
	actor.simulate(3)
	assert(actor.ammo == 2 and actor.reserve == 0 and actor.magazines[1] == 7)
	game.ui.update_hud(actor, 16, "live", 250, 110, [], "")
	assert("AR 02" in game.ui.loadout_label.text and "SG 07" in game.ui.loadout_label.text)
	if "--capture-magazines" in OS.get_cmdline_user_args():
		actor.render_frame(0.016, false, true, false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/magazine-hud.png")
	actor.ammo = 0
	game.ui.update_hud(actor, 16, "live", 250, 110, [], "")
	assert("NO RESERVE" in game.ui.prompt.text)
	actor.reserve = 10
	game.ui.update_hud(actor, 16, "live", 250, 110, [], "")
	assert("EMPTY MAGAZINE" in game.ui.prompt.text)
	var state: Dictionary = actor.pack()
	var replica = game.actors[-1]
	replica.unpack(state, false)
	assert(replica.magazines == actor.magazines and replica.ammo == actor.ammo)
	replica.ammo = 3
	assert(actor.ammo == 0 and state.mags[0] == 0, "Snapshot and actor arrays do not alias")
	actor.reload_weapon()
	actor.apply_damage(10000)
	actor.simulate(10)
	assert(actor.ammo == 0 and actor.reserve == 10, "Death cannot complete a reload")
	print("MAGAZINE_RULES_PASS independent=ok firing=ok raise_delay=ok no_switch_reload=ok empty_cycle=ok timed_reload=ok partial_reload=ok conservation=ok snapshot=ok hud=ok death=ok")
	game.queue_free()
	await process_frame
	quit()
