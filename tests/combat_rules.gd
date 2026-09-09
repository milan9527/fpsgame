extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func physics_sync() -> void:
	await physics_frame
	await physics_frame

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.start_solo()
	game.running = false
	game.elapsed = 10
	game.sound.volume = 0
	var player = game.actors[1]
	var target = game.actors[-1]
	# Leave the firing lane free from incidental actors.
	for actor in game.actors.values():
		actor.position = Vector3(105, 1, 100 + actor.actor_id)
	player.position = Vector3(0, 0.02, 20)
	target.position = Vector3(0, 0.02, 10)
	player.yaw = 0
	player.pitch = 0
	player.velocity = Vector3.ZERO
	player.crouch = true
	player.update_stance()
	assert(player.crouched and is_equal_approx(player.body_shape.shape.height, 1.15))
	assert(is_equal_approx(player.head.position.y, 0.98), "Crouch changes camera and collider")
	assert(is_equal_approx(player.body_shape.position.y - player.body_shape.shape.height / 2, 0), "Feet remain fixed")
	var roof = game.world.block(Vector3(0, 1.45, 20), Vector3(4, 0.25, 4), "465a61")
	await physics_sync()
	player.crouch = false
	player.update_stance()
	assert(player.crouched, "Low ceiling prevents standing")
	player.jump_requested = true
	player.simulate(1.0 / 60)
	assert(player.crouched and player.velocity.y <= 0, "Jump cannot force player through roof")
	roof.queue_free()
	await physics_sync()
	player.update_stance()
	assert(not player.crouched, "Player stands after obstacle is removed")
	# A waist-high barricade blocks crouched fire, but leaves standing eyes clear.
	var barricade = game.world.block(Vector3(0, 0.6, 15), Vector3(5, 1.2, 1), "465a61")
	player.crouch = true
	player.update_stance()
	await physics_sync()
	target.health = 100
	target.armor = 0
	player.fire_left = 0
	game.shoot(player)
	assert(target.health == 100, "Crouch bullet starts below cover, not at standing eyes")
	assert(player.recoil > 0, "Server accumulates recoil on accepted shots")
	var first_recoil: float = player.recoil
	var first_ammo: int = player.ammo
	game.shoot(player)
	assert(player.ammo == first_ammo and player.recoil == first_recoil, "Rejected fire adds neither ammo loss nor recoil")
	player.crouch = false
	player.update_stance()
	player.fire_left = 0
	player.recoil = 0
	await physics_sync()
	game.shoot(player)
	assert(target.health < 100, "Standing fire clears barricade")
	assert(game.ui.hit_until > Time.get_ticks_msec(), "Actual server damage generates hit confirmation")
	barricade.queue_free()
	await physics_sync()
	# Head hit threshold must follow the victim's stance, not a fixed world height.
	target.crouch = true
	target.update_stance()
	assert(target.headshot_height() < 1.0)
	target.health = 100
	player.recoil = 0
	player.fire_left = 0
	player.pitch = 0
	player.velocity = Vector3.ZERO
	player.aiming = true
	await physics_sync()
	game.shoot(player)
	assert(target.health == 100, "Standing-height bullet passes over crouched capsule")
	player.recoil = 0
	player.fire_left = 0
	player.pitch = atan2(target.position.y + 1.0 - player.eye_position().y, 10)
	game.shoot(player)
	assert(target.health < 70 and game.ui.hit_text.text == "HEADSHOT", "Physical hit detects crouched head and awards bonus")
	player.aiming = false
	player.recoil = 0
	player.velocity = Vector3.ZERO
	var hip_spread: float = player.shot_spread()
	player.aiming = true
	assert(player.shot_spread() < hip_spread, "ADS reduces authoritative spread")
	var ads_spread: float = player.shot_spread()
	player.velocity.x = 5
	assert(player.shot_spread() > ads_spread, "Movement worsens spread")
	player.recoil = 0.1
	var command: Dictionary = game.local_command(player)
	command.pitch = 0.0
	game.apply_command(player, command)
	assert(player.recoil == 0.1, "Client look input cannot erase server recoil")
	player.shooting = false
	player.simulate(0.5)
	assert(player.recoil < 0.1, "Recoil recovers over simulation time")
	var wire: Dictionary = player.pack()
	var replica = game.actors[-2]
	replica.unpack(wire, false)
	assert(replica.crouched == player.crouched and replica.recoil == player.recoil, "Network state carries stance and recoil")
	game.damage(player, 5, target.actor_id)
	assert(game.ui.damage_until > Time.get_ticks_msec(), "Damage to local actor generates directional feedback")
	game.elapsed = 0
	game.ui.hit_until = 0
	game.damage(target, 5, player.actor_id)
	assert(game.ui.hit_until == 0, "Spawn protection produces no false hit confirmation")
	var capture_path := OS.get_environment("CAPTURE_PATH")
	if not capture_path.is_empty():
		player.crouch = true
		player.update_stance()
		replica.position = Vector3(100, 1, 100)
		player.render_frame(0.016, false, true, true)
		game.ui.update_hud(player, 16, "live", 250, 110, [], "")
		game.ui.combat_feedback(0, 38, true, false, target.position)
		game.ui.combat_feedback(1, 5, false, false, target.position)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_path)
	await create_timer(0.15).timeout
	print("COMBAT_RULES_PASS crouch=ok ceiling=ok cover=ok recoil=ok spread=ok feedback=ok wire=ok")
	quit()
