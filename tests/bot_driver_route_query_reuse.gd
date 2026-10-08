extends SceneTree

class Seats:
	var passenger
	func occupant(index: int):
		return passenger if index == 1 else null

class Car extends StaticBody3D:
	const BODY_SIZE := Vector3(2, 1.5, 4)
	var seats := Seats.new()
	var collision_shape := CollisionShape3D.new()
	func _init() -> void:
		collision_shape.shape = BoxShape3D.new()
		collision_shape.shape.size = BODY_SIZE
		collision_shape.position.y = BODY_SIZE.y / 2
		add_child(collision_shape)

func _initialize() -> void:
	call_deferred("run")

func box(parent: Node, size: Vector3, location: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = size
	body.add_child(collision)
	parent.add_child(body)
	body.position = location
	return body

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	box(world, Vector3(160, 1, 160), Vector3(0, -0.5, 0))
	var car := Car.new()
	world.add_child(car)
	var actor := StaticBody3D.new()
	world.add_child(actor)
	var driver = load("res://scripts/bot_driver.gd").new()
	var goal := Vector3(35, 0, -5)
	await physics_frame
	await physics_frame
	var route: PackedVector3Array = driver.turning_route(car, goal, actor)
	assert(not route.is_empty())
	assert(driver.turning_route(car, goal, actor) == route)
	var expected_size: Vector3 = driver.turn_shape.size
	driver.turn_shape.size = Vector3.ONE
	assert(driver.turning_route(car, goal, actor) == route)
	assert(driver.turn_shape.size == expected_size, "A changed hull must be restored before collision queries")
	assert(driver.flat_route(car, Vector3(0, 0, -30), actor))
	var blocker := box(world, Vector3(4, 4, 4), route[route.size() / 2] + Vector3.UP * 2)
	await physics_frame
	await physics_frame
	assert(driver.turning_route(car, goal, actor).is_empty(), "Reuse must query new obstacles")
	car.seats.passenger = blocker
	assert(not driver.turning_route(car, goal, actor).is_empty(), "Current occupant must be excluded")
	car.seats.passenger = null
	assert(driver.turning_route(car, goal, actor).is_empty(), "Departed occupant must block again")
	blocker.position = Vector3(0, 2, -12)
	await physics_frame
	await physics_frame
	assert(not driver.flat_route(car, Vector3(0, 0, -30), actor))
	assert(driver.flat_route(car, Vector3(0, 0, 30), actor), "Opposite sweep must reset motion")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	car.position = Vector3(-20, 0, 10)
	car.rotation.y = 0.2
	var fresh = load("res://scripts/bot_driver.gd").new()
	assert(driver.turning_route(car, goal, actor) == fresh.turning_route(car, goal, actor))
	assert(driver.corridor(car, goal, actor) == fresh.corridor(car, goal, actor))
	assert(driver.turn_query != fresh.turn_query and driver.turn_shape != fresh.turn_shape)
	print("BOT_DRIVER_ROUTE_QUERY_REUSE_PASS live_obstacles=ok occupant_refresh=ok sweep_reset=ok fresh_comparison=ok")
	world.queue_free()
	await process_frame
	quit()
