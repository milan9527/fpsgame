extends SceneTree

func _initialize() -> void:
	var controller = load("res://scripts/character_animation.gd").new()
	var player := AnimationPlayer.new()
	var skeleton := Skeleton3D.new()
	root.add_child(player)
	root.add_child(skeleton)
	skeleton.add_bone("Foot.L")
	var animation := Animation.new()
	animation.length = 1.0
	var track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, NodePath("Skeleton3D:Foot.L"))
	animation.position_track_insert_key(track, 0.0, Vector3(0, 2, 0))
	animation.position_track_insert_key(track, 1.0, Vector3(0, 2, 0))
	var library := AnimationLibrary.new()
	library.add_animation("Walk", animation)
	player.add_animation_library("", library)
	controller.player = player
	controller.skeleton = skeleton
	controller.clips = {"Walk": "Walk"}
	controller.gait_tracks = {"Walk": PackedInt32Array([track, 0, Animation.TYPE_POSITION_3D])}
	var passed := true
	controller.reload_gait_weight = 1.0
	for frame in range(12):
		# Base reload animation supplies a fresh pose before each gait blend.
		skeleton.set_bone_pose_position(0, Vector3.ZERO)
		controller.apply_reload_gait(0.0, false, 1.0 / 60.0)
		var expected := maxf(0.0, 1.0 - (frame + 1) * 8.0 / 60.0)
		passed = passed and absf(skeleton.get_bone_pose_position(0).y - 2.0 * expected) < 0.00001
	passed = passed and controller.reload_gait_weight == 0.0
	var idle_pose := Vector3(1, 3, 2)
	skeleton.set_bone_pose_position(0, idle_pose)
	for frame in range(120):
		controller.apply_reload_gait(0.1, false, 1.0 / 60.0)
		passed = passed and skeleton.get_bone_pose_position(0) == idle_pose
	# Below-threshold movement still advances phase, even at zero blend weight.
	passed = passed and absf(controller.gait_phase - 120.0 / 60.0 * 0.1 / 4.5) < 0.00001
	controller.apply_reload_gait(4.5, false, 1.0 / 60.0)
	passed = passed and controller.reload_gait_weight > 0.0
	passed = passed and skeleton.get_bone_pose_position(0) != idle_pose
	# Compare full-weight and fading rotations against the original blend,
	# including opposite quaternion signs and wrapping the animation phase.
	var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(rotation_track, NodePath("Skeleton3D:Foot.L"))
	animation.rotation_track_insert_key(rotation_track, 0.0, Quaternion(Vector3.UP, 0.4))
	animation.rotation_track_insert_key(rotation_track, 1.0, Quaternion(Vector3.RIGHT, 1.2))
	controller.gait_tracks["Walk"] = PackedInt32Array([
		track, 0, Animation.TYPE_POSITION_3D,
		rotation_track, 0, Animation.TYPE_ROTATION_3D])
	for initial_weight in [0.0, 0.5, 1.0]:
		for speed in [0.0, 4.5]:
			for sign_value in [-1.0, 1.0]:
				controller.reload_gait_weight = initial_weight
				controller.gait_phase = 0.999
				var base_rotation: Quaternion = Quaternion(Vector3.FORWARD, 0.7) * sign_value
				skeleton.set_bone_pose_rotation(0, base_rotation)
				skeleton.set_bone_pose_position(0, idle_pose)
				controller.apply_reload_gait(speed, false, 1.0 / 60.0)
				var expected_weight := move_toward(initial_weight, 1.0 if speed > 0.25 else 0.0, 8.0 / 60.0)
				var expected_phase := fposmod(0.999 + speed / 4.5 / 60.0, 1.0)
				var expected_rotation: Quaternion = base_rotation.slerp(
					animation.rotation_track_interpolate(rotation_track, expected_phase), expected_weight)
				var actual_rotation := skeleton.get_bone_pose_rotation(0)
				passed = passed and absf(absf(actual_rotation.dot(expected_rotation)) - 1.0) < 0.00001
				passed = passed and skeleton.get_bone_pose_position(0).is_equal_approx(
					idle_pose.lerp(Vector3(0, 2, 0), expected_weight))
				passed = passed and absf(controller.gait_phase - expected_phase) < 0.00001
	print("RELOAD_GAIT_IDLE_PASS" if passed else "RELOAD_GAIT_IDLE_FAIL")
	player.free()
	skeleton.free()
	quit(0 if passed else 1)
