extends SceneTree

class ObservedActor extends "res://scripts/actor.gd":
	var changes := 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := ObservedActor.new()
	root.add_child(actor)
	await physics_frame
	actor.set_notify_local_transform(true)
	actor.position = Vector3(12, 3, -27)
	actor.changes = 0
	# Measure the old setters with the same engine and live CharacterBody.
	for i in range(120):
		actor.position.x = clampf(actor.position.x, -115, 115)
		actor.position.z = clampf(actor.position.z, -115, 115)
	var previous_changes := actor.changes
	actor.changes = 0
	for i in range(120):
		actor.enforce_world_bounds()
	assert(actor.changes == 0, "In-bounds movement must not rewrite transforms")
	assert(actor.position == Vector3(12, 3, -27))
	for sample in [Vector3(116, 2, -117), Vector3(-116, 2, 117),
			Vector3(115, -10, -115), Vector3(118, -11, -119)]:
		actor.position = sample
		actor.velocity = Vector3(1, -8, 3)
		actor.grounded = true
		actor.landing_speed = 7
		actor.changes = 0
		actor.enforce_world_bounds()
		var fell: bool = sample.y < -10
		var expected := Vector3(clampf(sample.x, -115, 115),
			4.0 if fell else sample.y, clampf(sample.z, -115, 115))
		assert(actor.position == expected, "Boundary and fall corrections must match")
		assert(actor.changes == (0 if sample == expected else 1),
			"All corrections must use at most one transform write")
		assert(actor.velocity == (Vector3.ZERO if fell else Vector3(1, -8, 3)))
		assert(actor.grounded == not fell)
		assert(actor.landing_speed == (0.0 if fell else 7.0))
	print("ACTOR_WORLD_BOUNDS_PASS old_notifications=%d new_notifications=0 edges=ok fall=ok" % previous_changes)
	actor.queue_free()
	await process_frame
	quit()
