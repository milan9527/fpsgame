extends SceneTree

class TestVehicle extends RefCounted:
	var vehicle_id := 7
	var driver_id := 1
	var resets := 0
	func reset_controls() -> void:
		resets += 1

class TestActor extends RefCounted:
	var vehicle_ref: WeakRef
	var actor_id := 1
	func is_seated() -> bool:
		return true

func _initialize() -> void:
	var fleet = load("res://scripts/vehicle_fleet.gd").new()
	var registered := TestVehicle.new()
	var foreign := TestVehicle.new()
	var actor := TestActor.new()
	fleet.vehicles[registered.vehicle_id] = registered
	actor.vehicle_ref = weakref(registered)
	fleet.controls(actor, {}, false)
	assert(registered.resets == 1, "Registered driver receives inactive-round braking")
	actor.vehicle_ref = weakref(foreign)
	fleet.controls(actor, {}, false)
	assert(foreign.resets == 0, "Same ID does not authorize another vehicle object")
	fleet.vehicles.clear()
	actor.vehicle_ref = weakref(registered)
	fleet.controls(actor, {}, false)
	assert(registered.resets == 1, "Removed vehicles reject controls")
	registered = null
	fleet.controls(actor, {}, false)
	print("VEHICLE_CONTROLS_MEMBERSHIP_PASS registered=ok foreign=ok removed=ok expired=ok")
	quit()
