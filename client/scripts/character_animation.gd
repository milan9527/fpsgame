extends RefCounted

var player: AnimationPlayer
var skeleton: Skeleton3D
var clips: Dictionary = {}
var active_clip := ""
var available := false
var gait_phase := 0.0
var reload_gait_weight := 0.0
var reload_exit_left := 0.0
var spine_bone := -1
var spine_override_active := false
var gait_tracks: Dictionary = {}

# Reload owns the torso and hands. Locomotion must still drive the legs when
# the collision body moves, without moving the weapon/contact frame.
func apply_reload_gait(speed: float, crouched: bool, dt: float) -> void:
	var gait := "CrouchWalk" if crouched else ("Run" if speed > 6.0 else "Walk")
	if not clips.has(gait):
		return
	var animation := player.get_animation(clips[gait])
	var nominal_speed := 2.8 if crouched else (8.0 if gait == "Run" else 4.5)
	gait_phase = fposmod(gait_phase + dt * speed / nominal_speed / animation.length, 1.0)
	reload_gait_weight = move_toward(reload_gait_weight, 1.0 if speed > 0.25 else 0.0, dt * 8.0)
	# Keep phase and fade-out progressing, but leave the reload pose untouched
	# once locomotion contributes nothing. Avoid sampling and dirtying leg bones.
	if reload_gait_weight == 0.0:
		return
	var time := gait_phase * animation.length
	var tracks: PackedInt32Array = gait_tracks[gait]
	var full_weight := reload_gait_weight == 1.0
	for index in range(0, tracks.size(), 3):
		var track := tracks[index]
		var bone := tracks[index + 1]
		match tracks[index + 2]:
			Animation.TYPE_POSITION_3D:
				var position := animation.position_track_interpolate(track, time)
				# At full weight the live pose is not an input. Avoid a getter
				# for every animated channel just to conditionally skip a setter.
				if full_weight:
					skeleton.set_bone_pose_position(bone, position)
					continue
				var current_position := skeleton.get_bone_pose_position(bone)
				position = current_position.lerp(position, reload_gait_weight)
				# Imported gait tracks include constant channels. Compare the
				# live pose after torso sampling, so changed poses still apply.
				if current_position != position:
					skeleton.set_bone_pose_position(bone, position)
			Animation.TYPE_ROTATION_3D:
				var rotation := animation.rotation_track_interpolate(track, time)
				if full_weight:
					skeleton.set_bone_pose_rotation(bone, rotation)
					continue
				var current_rotation := skeleton.get_bone_pose_rotation(bone)
				rotation = current_rotation.slerp(rotation, reload_gait_weight)
				if current_rotation != rotation:
					skeleton.set_bone_pose_rotation(bone, rotation)

func setup(model: Node3D) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		return
	player = players[0]
	skeleton = skeletons[0]
	spine_bone = skeleton.find_bone("Spine")
	clips.clear()
	gait_tracks.clear()
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in player.get_animation_list():
		var short_name: String = name.get_slice("/", name.get_slice_count("/") - 1)
		clips[short_name] = name
		var animation := player.get_animation(name)
		animation.loop_mode = Animation.LOOP_NONE if short_name in ["Death", "DownedDeath", "Reload", "CrouchReload"] else Animation.LOOP_LINEAR
		if short_name in ["Walk", "Run", "CrouchWalk"]:
			# Imported clips and bone indices are fixed for this model. Resolve
			# the leg channels once, preserving their original sampling order.
			var tracks := PackedInt32Array()
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				var bone_name := String(path.get_subname(0)) if path.get_subname_count() else ""
				if not (bone_name.begins_with("Thigh.") or bone_name.begins_with("Shin.") or bone_name.begins_with("Foot.")):
					continue
				var bone := skeleton.find_bone(bone_name)
				var type := animation.track_get_type(track)
				if bone >= 0 and type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
					tracks.append_array(PackedInt32Array([track, bone, type]))
			gait_tracks[short_name] = tracks
	available = clips.has("Idle") and clips.has("CrouchIdle") and clips.has("Walk") and clips.has("Death")

func update(actor, dt: float) -> void:
	if not available:
		return
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var desired := "Idle"
	if actor.is_seated():
		desired = "SeatedDowned" if not actor.alive or actor.downed else ("SeatedDriver" if actor.vehicle_seat == 0 else "SeatedPassenger")
	elif not actor.alive:
		desired = "DownedDeath" if active_clip.begins_with("Downed") and clips.has("DownedDeath") else "Death"
	elif actor.downed:
		desired = "DownedCrawl" if speed > 0.1 else "DownedIdle"
	elif actor.crouched:
		desired = "CrouchReload" if actor.reload_left > 0 else ("CrouchWalk" if speed > 0.25 else "CrouchIdle")
	elif not actor.grounded:
		desired = "Jump"
	elif actor.reload_left > 0:
		desired = "Reload"
	elif speed > 6:
		desired = "Run"
	elif speed > 0.25:
		desired = "Walk"
	if not clips.has(desired):
		desired = "CrouchIdle" if actor.crouched else "Idle"
	# Clear our previous aim before sampling. Downed, dead and seated actors
	# stop applying aim, so they only need this reset on the transition.
	if spine_override_active:
		skeleton.set_bone_global_pose_override(spine_bone, Transform3D.IDENTITY, 0.0, true)
		spine_override_active = false
	if active_clip != desired:
		var seat_transition := active_clip.begins_with("Seated") or desired.begins_with("Seated")
		var resume_gait := active_clip.ends_with("Reload") and desired in ["Walk", "Run", "CrouchWalk"]
		active_clip = desired
		# Stance changes must immediately match the collision height; locomotion blends.
		var blend := 0.0 if seat_transition or desired.begins_with("Crouch") or desired.begins_with("Downed") or desired == "Death" else 0.12
		player.play(clips[desired], blend)
		reload_exit_left = blend if resume_gait else 0.0
		if resume_gait:
			player.seek(gait_phase * player.get_animation(clips[desired]).length, true)
		if desired.ends_with("Reload"):
			var length := player.get_animation(clips[desired]).length
			player.seek(length * clampf(1 - actor.reload_left / actor.RELOAD[actor.weapon], 0, 1), true)
	# Commit once: resetting to 1 before applying locomotion/reload speed
	# sends an unused intermediate value to AnimationPlayer every update.
	var playback_speed := 1.0
	if desired == "SeatedDowned" and not actor.alive:
		playback_speed = 0.0
	elif desired == "Walk":
		playback_speed = clampf(speed / 4.5, 0.5, 1.5)
	elif desired == "Run":
		playback_speed = clampf(speed / 8, 0.6, 1.4)
	elif desired == "CrouchWalk":
		playback_speed = clampf(speed / 2.8, 0.5, 1.5)
	elif desired == "DownedCrawl":
		playback_speed = clampf(speed, 0.25, 1.2)
	elif desired.ends_with("Reload"):
		playback_speed = player.get_animation(clips[desired]).length / actor.RELOAD[actor.weapon]
	# Idle, jump and reload often retain the same rate across samples.
	# Still advance every sample, but only notify the player when it changes.
	if player.speed_scale != playback_speed:
		player.speed_scale = playback_speed
	player.advance(dt)
	if desired.ends_with("Reload"):
		apply_reload_gait(speed, actor.crouched, dt)
	else:
		if desired in ["Walk", "Run", "CrouchWalk"]:
			gait_phase = fposmod(player.current_animation_position / player.current_animation_length, 1.0)
		if reload_exit_left > 0.0:
			# The outgoing reload clip has static legs. Keep sampling the
			# resumed gait while AnimationPlayer blends the torso and hands.
			apply_reload_gait(speed, actor.crouched, 0.0)
			reload_exit_left = maxf(0.0, reload_exit_left - dt)
		else:
			reload_gait_weight = 0.0
	# A zero aim angle is the sampled animation pose already. Avoid forcing
	# global bone evaluation and a persistent override for level aim. The
	# reset above still removes the previous override when returning to level.
	var aim_angle: float = (actor.pitch + actor.recoil) * 0.6
	if aim_angle != 0.0 and actor.alive and not actor.downed and not actor.is_seated():
		var spine := spine_bone
		if spine >= 0:
			var pose := skeleton.get_bone_global_pose(spine)
			pose.basis = Basis(Vector3.RIGHT, aim_angle) * pose.basis
			skeleton.set_bone_global_pose_override(spine, pose, 1.0, true)
			spine_override_active = true
