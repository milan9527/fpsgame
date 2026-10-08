extends SceneTree

class Actor extends Node3D:
	var alive := true
	var team_id := 1
	var display_name := "test"
	var yaw := 0.0
	var camera := Camera3D.new()
	var body_mesh := Node3D.new()
	func _init() -> void:
		add_child(camera)
		add_child(body_mesh)
	func eye_height() -> float:
		return 1.6
	func is_seated() -> bool:
		return false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var spectator = load("res://scripts/spectator.gd").new()
	root.add_child(spectator)
	var local := Actor.new()
	local.alive = false
	var first := Actor.new()
	var second := Actor.new()
	var enemy := Actor.new()
	enemy.team_id = 2
	var actors := {9: second, 7: enemy, 3: first, 1: local}
	for actor in actors.values():
		root.add_child(actor)
	# Direct eligibility must agree with the previous sorted-list membership.
	for team in [0, 1, 2, 3]:
		spectator.team_filter = team
		for id in [0, 1, 3, 7, 9, 999]:
			assert(spectator.is_candidate(id, actors) == (id in spectator.candidates(actors)))
	spectator.update_view(actors, 1, "live")
	assert(spectator.target_id == 3)
	for frame in range(120):
		spectator.update_view(actors, 1, "live")
		assert(spectator.target_id == 3)
	spectator.cycle(actors, -1)
	assert(spectator.target_id == 9)
	spectator.cycle(actors, 1)
	assert(spectator.target_id == 3)
	first.alive = false
	spectator.update_view(actors, 1, "live")
	assert(spectator.target_id == 9)
	actors.erase(9)
	spectator.update_view(actors, 1, "live")
	assert(spectator.target_id == 0 and spectator.target_name == "")
	enemy.team_id = 1
	spectator.update_view(actors, 1, "finished")
	assert(spectator.target_id == 7)
	local.alive = true
	spectator.update_view(actors, 1, "live")
	assert(not spectator.active and local.camera.current)
	print("SPECTATOR_TARGET_VALIDITY_PASS eligibility stable cycling death departure team_change respawn")
	quit()
