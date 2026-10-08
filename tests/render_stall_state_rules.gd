extends SceneTree

class Fixture:
	extends Node
	var actors := {1: {"alive": true, "downed": false}}
	var local_id := 1
	var phase := "playing"
	var spectator := {"active": false, "target_id": 0, "camera": null}
	var loot := {}
	var world := Node3D.new()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Fixture.new()
	root.add_child(game)
	game.add_child(game.world)
	var mobile = load("res://scripts/mobile_performance.gd").new()
	game.add_child(mobile)
	mobile.record_render_stall(50.0, 1)
	assert(mobile.render_stalls.is_empty())
	mobile.record_render_stall(51.0, 2)
	game.actors[1].alive = false
	game.spectator.active = true
	game.spectator.target_id = 7
	game.loot[1] = {}
	mobile.record_render_stall(833.0, 3)
	assert(mobile.render_stalls[0].local_alive)
	assert(not mobile.render_stalls[0].spectator_active)
	assert(mobile.render_stalls[0].loot_count == 0)
	assert(not mobile.render_stalls[1].local_alive)
	assert(mobile.render_stalls[1].spectator_active)
	assert(mobile.render_stalls[1].spectator_target == 7)
	assert(mobile.render_stalls[1].loot_count == 1)
	assert(not mobile.render_stalls[1].spectator_camera)
	game.actors.clear()
	for i in range(10):
		mobile.record_render_stall(60.0, 4 + i)
	assert(mobile.render_stalls.size() == 8)
	assert(mobile.render_stalls_omitted == 4)
	assert(not mobile.render_stalls[2].local_alive)
	assert(not mobile.render_stalls[2].local_downed)
	game.free()
	print("RENDER_STALL_STATE_RULES_PASS snapshot=ok missing_actor=ok cap=ok threshold=ok")
	quit()
