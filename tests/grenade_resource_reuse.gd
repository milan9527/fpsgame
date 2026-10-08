extends SceneTree

const Grenade = preload("res://scripts/grenade.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Grenade.warm_resources()
	var scenes := Grenade._models.duplicate()
	assert(scenes.size() == 2 and scenes[0] != null and scenes[1] != null)
	for kind in [0, 1]:
		var first := Grenade.new()
		first.kind = kind
		var replica := Grenade.new()
		replica.kind = kind
		replica.authoritative = false
		root.add_child(first)
		root.add_child(replica)
		assert(first.physics_material_override == replica.physics_material_override)
		assert(first.get_child(0) != replica.get_child(0))
		assert(first.get_child(0).shape == replica.get_child(0).shape)
		assert(is_equal_approx(first.get_child(0).shape.radius, 0.12))
		assert(is_equal_approx(first.physics_material_override.bounce, 0.48))
		assert(is_equal_approx(first.physics_material_override.friction, 0.7))
		assert(first.get_child(1) != replica.get_child(1))
		assert(first.get_child(1).scene_file_path == scenes[kind].resource_path)
		assert(first.collision_layer == 8 and first.collision_mask == 5 and not first.freeze)
		assert(replica.collision_layer == 0 and replica.collision_mask == 0 and replica.freeze)
		assert(not first.is_processing() and replica.is_processing())
		replica.target_position = Vector3(10, 0, 0)
		replica._process(0.01)
		assert(replica.position.is_equal_approx(Vector3(2.2, 0, 0)))
		replica.position = Vector3.ZERO
		first.position = Vector3(10, 0, 0)
		assert(replica.position == Vector3.ZERO)
		first.free()
		replica.free()
		Grenade.warm_resources()
		assert(Grenade._models[kind] == scenes[kind])
		var next := Grenade.new()
		next.kind = kind
		root.add_child(next)
		assert(next.get_child(0).shape == Grenade._sphere)
		assert(next.get_child(1).scene_file_path == scenes[kind].resource_path)
		next.free()
	print("GRENADE_RESOURCE_REUSE_PASS: both authored models, retained resources, independent bodies and replicas")
	quit()
