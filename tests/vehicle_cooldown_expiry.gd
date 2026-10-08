extends SceneTree

const Fleet = preload("res://scripts/vehicle_fleet.gd")
const Vehicle = preload("res://scripts/vehicle.gd")

class ImpactSink:
	extends RefCounted
	var hits := 0
	func vehicle_impact(_other, _closing, _driver, _vehicle) -> void:
		hits += 1

func _initialize() -> void:
	var fleet = Fleet.new()
	var sink = ImpactSink.new()
	var first = Vehicle.new()
	var second = Vehicle.new()
	first.vehicle_id = 1
	second.vehicle_id = 2
	fleet.on_impact(second, 10.0, 1, sink, first)
	fleet.on_impact(first, 10.0, 2, sink, second)
	assert(sink.hits == 1, "Reversed vehicle pairs share a cooldown")
	# Include restored entries and several expirations on the same tick.
	fleet.pair_cooldowns["3:4"] = 0.5
	fleet.pair_cooldowns["5:6"] = 0.5
	fleet.pair_cooldowns["7:8"] = 2.0
	fleet.step(0.5, true)
	assert(fleet.pair_cooldowns.size() == 2)
	assert(fleet.pair_cooldowns.has("1:2") and fleet.pair_cooldowns.has("7:8"))
	fleet.step(0.5, false)
	assert(not fleet.pair_cooldowns.has("1:2"), "Expires exactly at its deadline even outside live play")
	fleet.on_impact(second, 10.0, 1, sink, first)
	assert(sink.hits == 2, "A new impact is allowed at the deadline")
	fleet.step(1.0, true)
	assert(fleet.pair_cooldowns.is_empty())
	fleet.clear()
	fleet.pair_cooldowns = {"9:10": 0.25}
	fleet.step(0.125, true)
	assert(fleet.pair_cooldowns.size() == 1)
	fleet.step(0.125, true)
	assert(fleet.pair_cooldowns.is_empty(), "Restored cooldowns expire after fleet reset")
	first.free()
	second.free()
	print("vehicle_cooldown_expiry: PASS")
	quit()
