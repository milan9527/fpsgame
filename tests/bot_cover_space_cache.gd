extends SceneTree

class WorldProbe:
	extends RefCounted
	var world: World3D
	var lookups := 0
	func get_world_3d() -> World3D:
		lookups += 1
		return world
	func navigation_point(at: Vector3) -> Vector3:
		return at

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50, 10, 1)
	collision.shape = box
	wall.add_child(collision)
	stage.add_child(wall)
	wall.position = Vector3(0, 2, -15)
	await physics_frame
	await physics_frame
	var world := WorldProbe.new()
	world.world = stage.get_world_3d()
	var cover = load("res://scripts/bot_cover.gd").new()
	var threat := Vector3(0, 0, -30)
	for iteration in range(3):
		var before := world.lookups
		var candidates: Array = cover.find_candidates({"position": Vector3.ZERO}, world, threat, Vector2.ZERO, 30)
		assert(candidates.size() == 6)
		assert(world.lookups - before == 1, "Six covered candidates share one space lookup")
		assert(not cover.search_space_cache_enabled and cover.search_space == null)
		for candidate in candidates:
			assert(cover.protected(world, candidate.p, threat))
		assert(world.lookups - before == 7, "Standalone probes resolve their current world")
	var before := world.lookups
	assert(cover.find_candidates({"position": Vector3.ZERO}, world, threat, Vector2.ZERO, 2).is_empty())
	assert(world.lookups == before, "Empty shortlist needs no physics space")
	assert(not cover.search_space_cache_enabled and cover.search_space == null)
	print("BOT_COVER_SPACE_CACHE_PASS searches=3 lookups_per_search=1 standalone_probes=18 empty_lookups=0")
	stage.queue_free()
	await process_frame
	quit()
