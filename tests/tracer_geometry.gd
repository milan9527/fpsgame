extends SceneTree

class SilentSound:
	extends Node
	func shot(_origin: Vector3, _kind: int) -> void:
		pass

class TracerGame:
	extends "res://scripts/game.gd"
	func _ready() -> void:
		pass
	func _process(_dt: float) -> void:
		pass
	func _physics_process(_dt: float) -> void:
		pass

class MuzzleActor:
	extends Node3D
	var muzzle := Node3D.new()
	var flash_left := 0.0
	var weapon_kick := 0.0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# No world or audio needed: exercise the production shot effect itself.
	var game = TracerGame.new()
	game.sound = SilentSound.new()
	game.add_child(game.sound)
	root.add_child(game)
	game.running = false
	var origin := Vector3(3, 2, -7)
	var ends := [Vector3(3, 2, 8), Vector3(3, 2, -22),
		Vector3(-20, 11, 4), Vector3(3, 25, -7)]
	var lines: Array[MeshInstance3D] = []
	for endpoint in ends:
		game.shot_fx(999, origin, endpoint, 0)
		var line: MeshInstance3D = game.get_child(game.get_child_count() - 1)
		assert((line.transform * Vector3.ZERO).is_equal_approx(origin))
		assert((line.transform * Vector3.BACK).is_equal_approx(endpoint))
		assert(absf(line.basis.determinant()) > 0.0)
		assert(line.mesh == preload("res://scripts/tracer_effect.gd").shared_mesh)
		assert(line.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		lines.append(line)
	var actor := MuzzleActor.new()
	actor.add_child(actor.muzzle)
	game.add_child(actor)
	actor.muzzle.position = Vector3(1, 4, 2)
	game.local_id = 42
	game.actors[42] = actor
	game.shot_fx(42, origin, ends[0], 0)
	var local_line: MeshInstance3D = game.get_child(game.get_child_count() - 1)
	assert((local_line.transform * Vector3.ZERO).is_equal_approx(actor.muzzle.global_position))
	assert((local_line.transform * Vector3.BACK).is_equal_approx(ends[0]))
	assert(local_line.mesh == lines[0].mesh)
	assert(actor.flash_left > 0 and actor.weapon_kick == 1.0)
	lines.append(local_line)
	var count: int = game.get_child_count()
	game.shot_fx(999, origin, origin, 0)
	assert(game.get_child_count() == count)
	paused = true
	await create_timer(0.12, true).timeout
	for line in lines:
		assert(is_instance_valid(line), "Paused tracers retain their lifetime")
	paused = false
	await create_timer(0.12).timeout
	for line in lines:
		assert(not is_instance_valid(line), "Tracers expire after unpausing")
	game.queue_free()
	await process_frame
	print("TRACER_GEOMETRY_PASS")
	quit()
