extends SceneTree

const OUT = "/home/ec2-user/project/fpsgame/artifacts/android-perf-20260927-explosion-query/"
class Target:
	extends Node3D
	func aim_position() -> Vector3:
		return position + Vector3.UP
	func eye_position() -> Vector3:
		return position + Vector3.UP * 1.7

func original(origin: Vector3, actor, space: PhysicsDirectSpaceState3D) -> float:
	var visible := 0.0
	for point in [actor.position + Vector3.UP * 0.25, actor.aim_position(), actor.eye_position()]:
		var ray := PhysicsRayQueryParameters3D.create(origin, point, 5)
		if space.intersect_ray(ray).is_empty():
			visible += 1
	return visible / 3.0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(OUT + "subject.gd")
	assert(script.reload() == OK)
	var subject = script.new()
	root.add_child(subject)
	var actor := Target.new()
	subject.add_child(actor)
	actor.position = Vector3(2, 0, 0)
	var wall := StaticBody3D.new()
	wall.position = Vector3(1, 0.3, 0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 0.6, 2)
	collision.shape = box
	wall.add_child(collision)
	subject.add_child(wall)
	var results: Array = []
	for height in [0.6, 1.2, 4.0]:
		box.size.y = height
		wall.position.y = height / 2
		for layer in [1, 4, 2]:
			wall.collision_layer = layer
			await physics_frame
			await physics_frame
			for iteration in 10:
				for origin in [Vector3.ZERO, Vector3(1, 0.3, 0), Vector3(2, 0, 2)]:
					var before := original(origin, actor, subject.get_world_3d().direct_space_state)
					var after: float = subject.explosion_exposure(origin, actor)
					assert(before == after, str(height, "/", layer, "/", origin))
					if layer == 2 or origin == Vector3(2, 0, 2):
						assert(after == 1.0)
					if origin == Vector3.ZERO and layer != 2:
						var expected := 1.0 / 3.0 if height == 0.6 else 0.0
						assert(after == expected, str("expected ", expected, " got ", after))
					results.append({"height": height, "layer": layer, "origin": str(origin), "exposure": after})
	FileAccess.open(OUT + "results.json", FileAccess.WRITE).store_string(JSON.stringify({"passed": true, "cases": results}, "\t"))
	print("EXPLOSION_QUERY_REUSE_PASS cases=", results.size())
	subject.queue_free()
	await process_frame
	quit()
