extends SceneTree

# Tests the production method extracted verbatim without starting the full game.
const OUT = "/home/ec2-user/project/fpsgame/artifacts/android-perf-20260927-supply-query/"
class Eye:
	extends Node3D
	func eye_position() -> Vector3:
		return position + Vector3.UP * 0.35

func original(actor, item: Dictionary, space: PhysicsDirectSpaceState3D) -> bool:
	if actor.position.distance_to(item.p) >= 2.8:
		return false
	var query := PhysicsRayQueryParameters3D.create(actor.eye_position(), item.p + Vector3.UP * 0.35, 5)
	query.hit_from_inside = true
	return space.intersect_ray(query).is_empty()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(OUT + "subject.gd")
	assert(script.reload() == OK)
	var subject = script.new()
	root.add_child(subject)
	var actor := Eye.new()
	var other := Eye.new()
	subject.add_child(actor)
	subject.add_child(other)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = Vector3(1, 0.35, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2, 1)
	shape.shape = box
	wall.add_child(shape)
	subject.add_child(wall)
	await physics_frame
	await physics_frame
	var cases := [
		["blocked", Vector3.ZERO, Vector3(2, 0, 0), false],
		["clear", Vector3.ZERO, Vector3(0, 0, 2), true],
		["inside", Vector3(1, 0, 0), Vector3(2, 0, 0), false],
		["range_boundary", Vector3.ZERO, Vector3(0, 0, 2.8), false],
		["outside_range", Vector3.ZERO, Vector3(0, 0, 3), false],
		["other_side", Vector3(2, 0, 0), Vector3(2, 0, 2), true],
	]
	var identity: int = subject.supply_query.get_instance_id()
	var results: Array = []
	for layer in [1, 4, 2]:
		wall.collision_layer = layer
		await physics_frame
		await physics_frame
		for iteration in 10:
			for entry in cases:
				var current = actor if iteration % 2 == 0 else other
				current.position = entry[1]
				var item := {"p": entry[2]}
				var expected: bool = entry[3]
				if layer == 2 and entry[0] in ["blocked", "inside"]:
					expected = true
				var before := original(current, item, subject.get_world_3d().direct_space_state)
				# Vector3 stores float32: preserve the original comparison at
				# the nominal 2.8 boundary instead of assuming exact equality.
				if entry[0] == "range_boundary":
					expected = current.position.distance_to(item.p) < 2.8
				var after: bool = subject.supply_accessible(current, item)
				assert(before == expected and after == before, str(entry[0], " layer=", layer))
				assert(subject.supply_query.get_instance_id() == identity)
				results.append({"case": entry[0], "layer": layer, "iteration": iteration, "accessible": after})
	FileAccess.open(OUT + "results.json", FileAccess.WRITE).store_string(JSON.stringify({"passed": true, "cases": results}, "\t"))
	print("SUPPLY_QUERY_REUSE_PASS cases=", results.size())
	subject.queue_free()
	await process_frame
	quit()
