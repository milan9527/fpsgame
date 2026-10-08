extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var space = world.get_world_3d().direct_space_state
	# The new boundary blocks bodies and shots while its central opening stays clear.
	for height in [0.3, 1.0, 1.8]:
		var fence := PhysicsRayQueryParameters3D.create(
			Vector3(16, height, 21), Vector3(16, height, 23), 1)
		assert(not space.intersect_ray(fence).is_empty(), "Yard fence must be solid")
		var gate := PhysicsRayQueryParameters3D.create(
			Vector3(23.5, height, 21), Vector3(23.5, height, 23), 1)
		assert(space.intersect_ray(gate).is_empty(), "Yard opening must stay clear")
	# An upright player's side lane must stay clear beneath the loading shelter.
	for height in [0.3, 1.0, 1.8]:
		var lane := PhysicsRayQueryParameters3D.create(
			Vector3(23.5, height, 28), Vector3(23.5, height, 40), 1)
		assert(space.intersect_ray(lane).is_empty(), "Loading lane needs standing clearance")
	var overhead := PhysicsRayQueryParameters3D.create(Vector3(24.5, 8, 34), Vector3(24.5, 2, 34), 1)
	var roof: Dictionary = space.intersect_ray(overhead)
	assert(not roof.is_empty(), "Canopy must block overhead shots")
	assert(absf(roof.position.y - 3.31) < 0.03, "Canopy collision should meet its visible surface")
	var post := PhysicsRayQueryParameters3D.create(Vector3(20, 1, 34), Vector3(23, 1, 34), 1)
	assert(not space.intersect_ray(post).is_empty(), "Visible post must stop shots")
	print("DEPOT_CLEARANCE_PASS standing_lane=clear canopy=solid posts=solid")
	quit()
