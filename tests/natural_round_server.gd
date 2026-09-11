extends SceneTree

class ObservedServer:
	extends "res://scripts/game.gd"
	var maximum_actors := 0
	var maximum_vehicles := 0
	var bot_driving_frames := 0
	var last_report := -1
	var reported := false

	func _physics_process(dt: float) -> void:
		assert(Engine.time_scale == 1.0 and dt <= 0.05)
		super._physics_process(dt)
		if phase == "live":
			maximum_actors = maxi(maximum_actors, actors.size())
			maximum_vehicles = maxi(maximum_vehicles, vehicle_fleet.vehicles.size())
			for car in vehicle_fleet.vehicles.values():
				if car.driver_id < 0 and absf(car.speed) > 1:
					bot_driving_frames += 1
			if int(elapsed) / 30 != last_report:
				last_report = int(elapsed) / 30
				print("NATURAL_ROUND_PROGRESS elapsed=%.1f alive=%d vehicles=%d bot_driving_frames=%d" % [elapsed, alive_count(), vehicle_fleet.vehicles.size(), bot_driving_frames])
		elif phase == "finished" and not reported:
			reported = true
			assert(maximum_actors == 16 and maximum_vehicles == 4)
			print("NATURAL_ROUND_FINISHED " + JSON.stringify({
				"match_id": match_id, "mode": match_mode, "elapsed": elapsed,
				"actors": maximum_actors, "vehicles": maximum_vehicles,
				"bot_driving_frames": bot_driving_frames, "time_scale": Engine.time_scale
			}))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = ObservedServer.new()
	game.name = "Game"
	root.add_child(game)
