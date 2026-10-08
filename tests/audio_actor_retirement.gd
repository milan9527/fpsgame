extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sound = load("res://scripts/sound.gd").new()
	root.add_child(sound)
	var camera := Camera3D.new()
	root.add_child(camera)
	var actor = load("res://scripts/actor.gd").new()
	# No movement or terrain queries are needed for roster transitions.
	var actors := {1: actor, 2: actor, 3: actor}
	sound.update_actors(actors, null, camera)
	var retained: RefCounted = sound.actor_states[2]
	actors.erase(1)
	actors.erase(3)
	sound.update_actors(actors, null, camera)
	assert(sound.actor_states.size() == 1)
	assert(is_same(retained, sound.actor_states[2]))
	actors.clear()
	sound.update_actors(actors, null, camera)
	assert(sound.actor_states.is_empty())
	# A returning id starts with a fresh snapshot, not a stale reload edge.
	actor.reload_left = 1.0
	actors[1] = actor
	sound.played_events.clear()
	sound.update_actors(actors, null, camera)
	assert(sound.played_events.is_empty())
	assert(sound.actor_states[1].reload == 1.0)
	actor.reload_left = 0.0
	actor.ammo += 1
	sound.update_actors(actors, null, camera)
	assert(sound.played_events.get("reload_end", 0) == 1)
	actor.grounded = true
	sound.update_actors(actors, null, camera)
	actor.position = Vector3(1, 2, 3)
	actor.grounded = false
	actor.velocity.y = 7
	sound.update_actors(actors, null, camera)
	assert(sound.voices.back().get_meta("effect") == "jump")
	assert(sound.voices.back().global_position.is_equal_approx(actor.position + Vector3.UP * 0.4))
	actor.velocity.y = -6
	sound.update_actors(actors, null, camera)
	actor.grounded = true
	actor.position.y = 0
	sound.update_actors(actors, null, camera)
	assert(sound.voices.back().get_meta("effect") == "land")
	assert(sound.voices.back().global_position.is_equal_approx(actor.position + Vector3.UP * 0.4))
	assert(is_equal_approx(sound.voices.back().get_meta("gain"), 0.5))
	# Fixed-field snapshots must preserve action edges and fractional health.
	sound.played_events.clear()
	actor.heal_left = 2.0
	actor.health = 30.25
	sound.update_actors(actors, null, camera)
	assert(sound.played_events.get("heal_start", 0) == 1)
	actor.heal_left = 0.0
	actor.health = 30.5
	sound.update_actors(actors, null, camera)
	assert(sound.played_events.get("heal_end", 0) == 1)
	actor.throw_left = 1.0
	sound.update_actors(actors, null, camera)
	assert(sound.played_events.get("throw", 0) == 1)
	actor.armor += 0.25
	sound.update_actors(actors, null, camera)
	assert(sound.played_events.get("pickup", 0) == 1)
	actor.ammo += 1
	actor.reserve -= 1
	sound.update_actors(actors, null, camera)
	assert(sound.played_events.get("pickup", 0) == 1)
	assert(sound.played_events.get("throw", 0) == 1)
	# Muted movement still accumulates stride, while stationary corrections,
	# teleports and airborne displacement must reset it without surface rays.
	sound.volume = 0
	actor.grounded = true
	actor.velocity = Vector3(3, 0, 0)
	sound.update_actors(actors, null, camera)
	actor.position.x += 1
	sound.update_actors(actors, null, camera)
	assert(is_equal_approx(sound.actor_states[1].distance, 1.0))
	actor.velocity = Vector3.ZERO
	actor.position.x += 0.1
	sound.update_actors(actors, null, camera)
	assert(sound.actor_states[1].distance == 0.0)
	actor.velocity = Vector3(3, 0, 0)
	actor.position.x += 30
	sound.update_actors(actors, null, camera)
	assert(sound.actor_states[1].distance == 0.0)
	actor.grounded = false
	actor.position.x += 1
	sound.update_actors(actors, null, camera)
	assert(sound.actor_states[1].distance == 0.0)
	sound.reset_round()
	assert(sound.actor_states.is_empty() and sound.retired_actor_ids.is_empty())
	actor.free()
	camera.queue_free()
	sound.queue_free()
	await process_frame
	print("PASS audio actor retirement: departures, retained snapshot, rejoin, reload, heal, throw, fractional armor pickup, ammo transfer, stride, stationary correction, teleport and airborne movement")
	quit()
