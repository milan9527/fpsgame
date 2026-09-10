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
	game.sound.volume = 0
	game.elapsed = 10
	var actor = game.actors[1]
	actor.position = Vector3(0, 0.02, 20)
	actor.reserve = 295
	actor.medkits = 0
	game.loot = {7: {"p": Vector3(0, 0.1, 18.3), "kind": 0, "amount": 37.0}, 8: {"p": Vector3(0.4, 0.1, 18.3), "kind": 1, "amount": 3.0}, 9: {"p": Vector3(80, 0.1, 80), "kind": 3}}
	await physics_frame
	await physics_frame
	var key := InputEventAction.new()
	key.action = "inventory"
	key.pressed = true
	game._unhandled_input(key)
	assert(game.ui.inventory.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not paused)
	game._process(0.016)
	assert(game.ui.inventory.rows.size() == 2 and not game.ui.inventory.rows.has(9))
	Input.action_press("forward")
	Input.action_press("fire")
	Input.action_press("aim")
	var cmd: Dictionary = game.local_command(actor)
	assert(cmd.x == 0 and cmd.z == 0 and not cmd.fire and not cmd.ads and not game.has_actions(cmd))
	var start: float = game.elapsed
	game._physics_process(0.1)
	assert(game.elapsed > start, "Inventory does not pause offline combat")
	game.ui.inventory.rows[8].pressed.emit()
	assert(actor.medkits == 3 and not game.loot.has(8), "Selected medicine is taken instead of nearer ammo")
	game._process(0.016)
	assert(not game.ui.inventory.rows.has(8))
	game.ui.inventory.rows[7].pressed.emit()
	assert(actor.reserve == 300 and game.loot[7].amount == 32)
	game._process(0.016)
	assert(game.ui.inventory.rows[7].disabled)
	game.ui.inventory.weapons[2].pressed.emit()
	assert(actor.weapon == 2 and actor.ammo == 5)
	actor.ammo = 1
	game._process(0.016)
	game.ui.inventory.reload_button.pressed.emit()
	assert(actor.reload_left > 0)
	actor.simulate(4)
	assert(actor.ammo == 5 and actor.reserve == 296)
	actor.health = 50
	game._process(0.016)
	game.ui.inventory.heal_button.pressed.emit()
	assert(actor.heal_left > 0 and actor.medkits == 3)
	actor.simulate(4)
	assert(actor.health == 100 and actor.medkits == 2)
	Input.action_release("forward")
	if "--capture-inventory" in OS.get_cmdline_user_args():
		game._process(0.016)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/inventory.png")
	key.action = "pause"
	game._unhandled_input(key)
	assert(not game.ui.inventory.visible and not game.ui.pause_panel.visible and not paused)
	cmd = game.local_command(actor)
	assert(not cmd.fire and not cmd.ads, "Close click cannot become a shot or ADS")
	Input.action_release("fire")
	Input.action_release("aim")
	game.local_command(actor)
	Input.action_press("fire")
	assert(game.local_command(actor).fire, "Fresh press restores fire")
	Input.action_release("fire")
	game.ui.set_inventory(true)
	game.ui.set_pause(true)
	assert(paused and not game.ui.inventory.visible)
	game.ui.set_pause(false)
	game.ui.set_inventory(true)
	game.damage(actor, 10000, 0, true)
	game._process(0.016)
	assert(not game.ui.inventory.visible)
	game.ui.set_inventory(true)
	game.leave()
	assert(not game.ui.inventory.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("INVENTORY_RULES_PASS selected_pickup=ok partial=ok stock=ok equipment=ok reload=ok heal=ok neutral=ok close_click=ok pause=ok death=ok leave=ok")
	game.queue_free()
	await process_frame
	quit()
