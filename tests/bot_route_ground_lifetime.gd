extends SceneTree

const OUTPUT := "../artifacts/android-route-ground-lifetime-20260928/"

class Actor extends Node3D:
	var body_shape := CollisionShape3D.new()
	func _init() -> void:
		body_shape.shape = CapsuleShape3D.new()
		body_shape.shape.height = 1.8
		add_child(body_shape)

class NavWorld extends Node3D:
	var projection_offset := Vector3.ZERO
	func navigation_point(point: Vector3) -> Vector3:
		return point + projection_offset

class Vehicle extends StaticBody3D:
	const BODY_SIZE := Vector3(2, 1.5, 4)
	func _init() -> void:
		collision_layer = 4
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = BODY_SIZE
		shape.position.y = BODY_SIZE.y / 2
		add_child(shape)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var before := GDScript.new()
	before.source_code = FileAccess.get_file_as_string(OUTPUT + "before.gd")
	if before.reload() != OK:
		quit(1)
		return
	var after = load("res://scripts/bot_vehicle_avoidance.gd")
	var world := NavWorld.new()
	root.add_child(world)
	var actor := Actor.new()
	world.add_child(actor)
	actor.position = Vector3(0, 0.02, 7)
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = BoxShape3D.new()
	ground_shape.shape.size = Vector3(60, 0.2, 60)
	ground_shape.position.y = -0.1
	ground.add_child(ground_shape)
	world.add_child(ground)
	var vehicles: Array[Vehicle] = []
	for i in range(4):
		var vehicle := Vehicle.new()
		world.add_child(vehicle)
		vehicles.append(vehicle)
	var cases: Array = []
	var nonempty := 0
	var current = after.new()
	var other = after.new()
	var query_id: int = current.ground_query.get_instance_id()
	if query_id == other.ground_query.get_instance_id():
		push_error("Ground query shared between bots")
		quit(1)
		return
	for count in range(1, 5):
		for i in range(4):
			vehicles[i].position = Vector3(i * 2.8, 0, 0) if i < count else Vector3(25, 0, 25)
			if i < count:
				vehicles[i].add_to_group("vehicles")
			else:
				vehicles[i].remove_from_group("vehicles")
		for angle in [0.0, 0.3, -0.6]:
			vehicles[0].rotation.y = angle
			for variant in range(3):
				ground.collision_layer = 0 if variant == 1 else 1
				world.projection_offset = Vector3(0.5, 0, 0) if variant == 2 else Vector3.ZERO
				await physics_frame
				await physics_frame
				var old = before.new()
				old.build_route(actor, world, vehicles[0], Vector3(0, 0.02, -8))
				current.build_route(actor, world, vehicles[0], Vector3(0, 0.02, -8))
				var equal: bool = old.route == current.route and current.ground_query.get_instance_id() == query_id
				cases.append({"vehicles": count, "angle": angle, "variant": variant, "equal": equal, "waypoints": current.route.size()})
				if not equal:
					push_error("Route differs: " + str(cases.back()))
					quit(1)
					return
				if not current.route.is_empty():
					nonempty += 1
	var result := {"cases": cases, "nonempty_routes": nonempty, "passed": nonempty > 0, "scope": "Headless physics equivalence; not Android FPS acceptance"}
	FileAccess.open(OUTPUT + "results.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("BOT_ROUTE_GROUND_LIFETIME ", cases.size(), " equivalent cases; ", nonempty, " nonempty routes")
	world.queue_free()
	await process_frame
	quit(0 if nonempty > 0 else 1)
