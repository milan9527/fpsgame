extends SceneTree

var movement_sections: Dictionary = {}

func record_movement(section: String, started: int) -> void:
	assert(started > 0 and started <= Time.get_ticks_usec())
	movement_sections[section] = movement_sections.get(section, 0) + 1

class BlockedActor extends "res://scripts/actor.gd":
	var standing_queries := 0

	func can_stand() -> bool:
		standing_queries += 1
		return false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := BlockedActor.new()
	root.add_child(actor)
	await physics_frame
	actor.set_stance(true)
	actor.crouch = false
	actor.simulate(1.0 / 60.0)
	assert(actor.crouched and actor.standing_queries == 1,
		"Authority queries a blocked standing attempt once per tick")
	actor.standing_queries = 0
	actor.simulate(1.0 / 60.0, record_movement)
	assert(actor.crouched and actor.standing_queries == 1,
		"Profiling preserves the single blocked standing query")
	assert(movement_sections == {"actor_stance": 1, "actor_lean": 1, "actor_slide": 1},
		"Each movement stage is measured once")
	actor.alive = false
	actor.simulate(1.0 / 60.0, record_movement)
	assert(movement_sections.actor_slide == 1, "Dead actors never enter slide profiling")
	actor.alive = true
	print("ACTOR_MOVEMENT_PROFILE_PASS stages=3 blocked_stance=ok dead=ok")
	actor.standing_queries = 0
	actor.move_step(1.0 / 60.0)
	assert(actor.crouched and actor.standing_queries == 1,
		"Prediction still independently checks standing clearance")
	actor.set_stance(false)
	actor.downed = true
	actor.simulate(1.0 / 60.0)
	assert(actor.crouched, "Authority lowers downed actors before movement")
	actor.set_stance(false)
	actor.move_step(1.0 / 60.0)
	assert(actor.crouched, "Prediction lowers downed actors before movement")
	var live_actor = load("res://scripts/actor.gd").new()
	root.add_child(live_actor)
	live_actor.position = Vector3(10, 0, 0)
	live_actor.set_stance(true)
	var ceiling := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 0.2, 2)
	collider.shape = box
	ceiling.add_child(collider)
	root.add_child(ceiling)
	ceiling.position = Vector3(10, 1.6, 0)
	await physics_frame
	await physics_frame
	assert(not live_actor.can_stand(), "Live ceiling blocks standing")
	ceiling.position.x += 5
	await physics_frame
	await physics_frame
	assert(live_actor.can_stand(), "Reused query observes a moved ceiling")
	live_actor.position.x += 5
	await physics_frame
	await physics_frame
	assert(not live_actor.can_stand(), "Reused query follows actor movement")
	print("STANCE_LIVE_QUERY_PASS ceiling_move=ok actor_move=ok")
	ceiling.queue_free()
	live_actor.queue_free()
	print("ACTOR_STANCE_TICK_PASS authority=1_query prediction=1_query downed=ok")
	actor.queue_free()
	await process_frame
	quit()
