extends RefCounted

var player: AnimationPlayer
var skeleton: Skeleton3D
var clips: Dictionary = {}
var active_clip := ""
var available := false

func setup(model: Node3D) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		return
	player = players[0]
	skeleton = skeletons[0]
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in player.get_animation_list():
		var short_name: String = name.get_slice("/", name.get_slice_count("/") - 1)
		clips[short_name] = name
		var animation := player.get_animation(name)
		animation.loop_mode = Animation.LOOP_NONE if short_name in ["Death", "DownedDeath", "Reload", "CrouchReload"] else Animation.LOOP_LINEAR
	available = clips.has("Idle") and clips.has("CrouchIdle") and clips.has("Walk") and clips.has("Death")

func update(actor, dt: float) -> void:
	if not available:
		return
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var desired := "Idle"
	if not actor.alive:
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
	skeleton.clear_bones_global_pose_override()
	if active_clip != desired:
		active_clip = desired
		# Stance changes must immediately match the collision height; locomotion blends.
		var blend := 0.0 if desired.begins_with("Crouch") or desired.begins_with("Downed") or desired == "Death" else 0.12
		player.play(clips[desired], blend)
		if desired.ends_with("Reload"):
			var length := player.get_animation(clips[desired]).length
			player.seek(length * clampf(1 - actor.reload_left / actor.RELOAD[actor.weapon], 0, 1), true)
	player.speed_scale = 1.0
	if desired == "Walk":
		player.speed_scale = clampf(speed / 4.5, 0.5, 1.5)
	elif desired == "Run":
		player.speed_scale = clampf(speed / 8, 0.6, 1.4)
	elif desired == "CrouchWalk":
		player.speed_scale = clampf(speed / 2.8, 0.5, 1.5)
	elif desired == "DownedCrawl":
		player.speed_scale = clampf(speed, 0.25, 1.2)
	elif desired.ends_with("Reload"):
		player.speed_scale = player.get_animation(clips[desired]).length / actor.RELOAD[actor.weapon]
	player.advance(dt)
	if actor.alive and not actor.downed:
		var spine := skeleton.find_bone("Spine")
		if spine >= 0:
			var pose := skeleton.get_bone_global_pose(spine)
			pose.basis = Basis(Vector3.RIGHT, (actor.pitch + actor.recoil) * 0.6) * pose.basis
			skeleton.set_bone_global_pose_override(spine, pose, 1.0, true)
