extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	game.elapsed = 20
	var actor = game.actors[1]
	actor.position = Vector3(0, 0.02, 20)
	actor.health = 30
	actor.medkits = 2
	actor.heal()
	actor.simulate(1)
	assert(actor.heal_left > 0 and actor.health == 30 and actor.medkits == 2)
	var cmd: Dictionary = game.local_command(actor)
	cmd.seq = 100
	cmd.cancel_heal = true
	assert(game.valid_command(cmd))
	assert(not game.has_actions(game.without_actions(cmd)), "Movement cannot cancel treatment")
	assert(not game.receive_actions(actor, "stale", cmd) and actor.heal_left > 0)
	assert(game.receive_actions(actor, game.match_id, cmd))
	assert(actor.heal_left == 0 and actor.health == 30 and actor.medkits == 2)
	assert(not game.receive_actions(actor, game.match_id, cmd), "Replay cannot execute twice")
	actor.sprint = true
	actor.shooting = false
	actor.aiming = false
	actor.move_input = Vector2(0, -1)
	actor.simulate(0.02)
	assert(Vector2(actor.velocity.x, actor.velocity.z).length() > 8)
	cmd.seq = 101
	cmd.cancel_heal = false
	cmd.heal = true
	assert(game.receive_actions(actor, game.match_id, cmd) and actor.heal_left > 0)
	cmd.cancel_heal = true
	assert(not game.valid_command(cmd), "Contradictory start and cancel rejected")
	cmd.heal = false
	actor.simulate(3.6)
	assert(actor.health == 95 and actor.medkits == 1)
	cmd.seq = 102
	assert(game.receive_actions(actor, game.match_id, cmd))
	assert(actor.heal_left == 0 and actor.health == 95 and actor.medkits == 1, "Late cancel cannot start a second kit")
	game.sequence = 102
	game.ui.set_inventory(true)
	game.ui.inventory.refresh(actor, [])
	assert(game.ui.inventory.heal_button.text == "USE MEDKIT")
	game.ui.inventory.heal_button.pressed.emit()
	assert(actor.heal_left > 0)
	game.ui.inventory.refresh(actor, [])
	assert(game.ui.inventory.heal_button.text == "CANCEL MEDKIT" and not game.ui.inventory.heal_button.disabled)
	game.ui.inventory.heal_button.pressed.emit()
	assert(actor.heal_left == 0 and actor.medkits == 1)
	game.ui.set_inventory(false)
	actor.heal()
	Input.action_press("heal")
	var keyboard: Dictionary = game.local_command(actor)
	Input.action_release("heal")
	assert(keyboard.cancel_heal and not keyboard.heal)
	game.apply_actions(actor, keyboard)
	assert(actor.heal_left == 0)
	print("HEAL_CANCEL_RULES_PASS authority=ok replay=ok explicit_intent=ok late_cancel=ok stock=ok sprint=ok inventory=ok keyboard=ok")
	game.request_quit()
