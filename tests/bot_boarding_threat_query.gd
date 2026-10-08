extends SceneTree

class Seats:
	func occupant(_index): return null
	func can_enter(_actor, _index): return true

class Car extends StaticBody3D:
	var speed := 0.0
	var health := 600.0
	var seats := Seats.new()

class Actor extends RefCounted:
	var health := 100.0
	var alive := true
	var downed := false
	var actor_id := 1
	func is_seated(): return false

class Teams:
	func friendly(_first, _second): return true

class Game extends Node3D:
	var match_mode := "duo"
	var grenades := {}
	var actors := {}
	var teams := Teams.new()

class Grenade extends Node3D:
	var kind := 0
	var fuse := 1.0

func _initialize():
	call_deferred("run")

func run():
	var game := Game.new()
	root.add_child(game)
	var car := Car.new()
	game.add_child(car)
	var actor := Actor.new()
	game.actors[2] = Actor.new()
	var grenade := Grenade.new()
	game.add_child(grenade)
	grenade.position = Vector3(0, 0, -4)
	game.grenades[1] = grenade
	var driver = load("res://scripts/bot_driver.gd").new()
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 4, 0.5)
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = Vector3(0, 0, -2)
	await physics_frame
	await physics_frame
	assert(driver.wait_for_teammate(game, actor, car), "Occluded frag must permit boarding")
	assert(not driver.boarding_departed)
	wall.position.x = 50
	await physics_frame
	await physics_frame
	assert(not driver.wait_for_teammate(game, actor, car), "Newly exposed frag must end boarding")
	assert(driver.boarding_departed)
	var second_car := Car.new()
	game.add_child(second_car)
	second_car.position = Vector3(20, 0, 0)
	grenade.position = Vector3(20, 0, -4)
	driver.boarding_departed = false
	assert(not driver.wait_for_teammate(game, actor, second_car))
	assert(driver.boarding_threat_ray.exclude == [second_car.get_rid()])
	assert(driver.boarding_threat_ray.to == second_car.global_position + Vector3.UP * 0.9)
	driver.boarding_departed = false
	grenade.kind = 1
	assert(driver.wait_for_teammate(game, actor, second_car), "Non-frag must not interrupt")
	assert(driver.boarding_threat_ray != load("res://scripts/bot_driver.gd").new().boarding_threat_ray)
	print("BOT_BOARDING_THREAT_QUERY_PASS occlusion=ok live_refresh=ok car_refresh=ok non_frag=ok")
	game.queue_free()
	await process_frame
	quit()
