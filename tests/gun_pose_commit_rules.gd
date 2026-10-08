extends SceneTree

class ObservedGun extends Node3D:
	var changes := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fp = load("res://scripts/first_person.gd").new()
	var gun := ObservedGun.new()
	var legacy := ObservedGun.new()
	root.add_child(gun)
	root.add_child(legacy)
	gun.set_notify_local_transform(true)
	legacy.set_notify_local_transform(true)
	var child := Node3D.new()
	child.position = Vector3(0.15, -0.1, -0.3)
	gun.add_child(child)
	var reference_child := Node3D.new()
	reference_child.position = child.position
	legacy.add_child(reference_child)
	for tick in range(6000):
		var t := tick / 60.0
		var location := Vector3(-0.2, 0.1, -0.5)
		var angles := Vector3.ZERO
		match (tick / 1000) as int:
			1: location.y += sin(t) * 0.014 # Walking bob.
			2: angles.x = sin(t) * 0.045 # Recoil.
			3: # Reload rotates and translates the weapon.
				location += Vector3(-0.08, 0.12, -0.06) * sin(t)
				angles = Vector3(-0.1, 0.35, -0.35) * sin(t)
			4: location.x += (tick % 1000) * 0.00000001 # Tiny aim changes.
			5: angles = Vector3(-1.35, 0, 0.1) # Settled wall pose.
		fp.commit_gun_pose(gun, location, angles)
		legacy.position = location
		legacy.rotation = angles
		assert(gun.position == legacy.position)
		assert(gun.rotation == legacy.rotation)
		assert(gun.transform == legacy.transform)
		assert(child.global_transform == reference_child.global_transform)
	var before := gun.changes
	for tick in range(120):
		fp.commit_gun_pose(gun, gun.position, gun.rotation)
	assert(gun.changes == before, "Settled pose must not dirty the hierarchy")
	assert(gun.changes < legacy.changes)
	print("PASS gun pose: 6000 exact local/child transforms; changes=", gun.changes,
		" legacy=", legacy.changes, "; 120 settled frames=0 changes")
	gun.free()
	legacy.free()
	quit()
