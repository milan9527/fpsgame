extends SceneTree

const Replica = preload("res://scripts/vehicle_replica.gd")

class Observed extends Node3D:
	var changes := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

class EmptySeats extends RefCounted:
	func occupant(_index: int):
		return null

class Car extends Observed:
	var wheel_rigs: Array = []
	var seats := EmptySeats.new()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var car := Car.new()
	root.add_child(car)
	car.set_notify_local_transform(true)
	for index in range(4):
		var roll := Observed.new()
		var turn := Observed.new()
		car.add_child(turn)
		turn.add_child(roll)
		roll.set_notify_local_transform(true)
		turn.set_notify_local_transform(true)
		car.wheel_rigs.append({"roll": roll, "turn": turn, "front": index < 2})
	var game := {"vehicle_fleet": {"vehicles": {1: car}}}
	var replica := Replica.new()
	replica.targets = {1: {"p": Vector3.ZERO, "yaw": 0.0,
		"wheels": [0.0, 0.0, 0.0, 0.0], "steering": 0.0}}
	for frame in range(300):
		replica.render(game, 1.0 / 60.0)
	assert(car.changes == 0)
	for wheel in car.wheel_rigs:
		assert(wheel.roll.changes == 0 and wheel.turn.changes == 0)
	# Preserve fractional interpolation and immediate steering, including the
	# rear-wheel reset if a previous state gave it a nonzero turn.
	car.wheel_rigs[3].turn.rotation.y = 0.2
	replica.targets[1] = {"p": Vector3(2, 0, 0), "yaw": 1.0,
		"wheels": [1.0, 1.0, 1.0, 1.0], "steering": 0.3}
	replica.render(game, 0.025)
	assert(car.position.is_equal_approx(Vector3(1, 0, 0)))
	assert(is_equal_approx(car.rotation.y, 0.5))
	for wheel in car.wheel_rigs:
		assert(is_equal_approx(wheel.roll.rotation.x, 0.5))
		assert(is_equal_approx(wheel.turn.rotation.y, -0.3 if wheel.front else 0.0))
	var before := car.transform
	replica.render(game, -1)
	replica.render(game, NAN)
	assert(car.transform == before)
	# Exact comparison follows even small authority corrections.
	replica.targets[1].p = car.position + Vector3(0.00001, 0, 0)
	replica.render(game, 0.05)
	assert(car.position == replica.targets[1].p)
	car.queue_free()
	await process_frame
	print("VEHICLE_REPLICA_TRANSFORM_PASS idle_300_frames=zero_notifications interpolation=ok steering=ok rear_reset=ok invalid_dt=ok small_correction=ok")
	quit()
