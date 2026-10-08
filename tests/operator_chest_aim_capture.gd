extends SceneTree

# Supplement the full carbine four-pose review with sampled reload contacts.
# Per-tick simulation is preserved; these sampled images are not a motion audit.
var game
var actor
var output: String
var records := []
var review_camera: Camera3D
var focused := false
var third_only := false

func _initialize() -> void:
	call_deferred("run")

func advance(frames: int, third: bool) -> void:
	for frame in range(frames):
		await physics_frame
		actor.simulate(1.0 / 60.0)
		actor.render_frame(1.0 / 60.0, false, not third, false)

func capture(label: String) -> void:
	for frame in range(4):
		await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
	var cam := root.get_camera_3d()
	records.append({"name": label, "weapon": actor.weapon,
		"pitch": actor.pitch, "crouched": actor.crouched, "reload_left": actor.reload_left,
		"ammo": actor.ammo, "actor_position": [actor.position.x, actor.position.y, actor.position.z],
		"camera_position": [cam.global_position.x, cam.global_position.y, cam.global_position.z],
		"camera_rotation": [cam.global_rotation.x, cam.global_rotation.y, cam.global_rotation.z]})
	var file := FileAccess.open(output.path_join("contact-review.partial.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": false, "samples": records}, "\t"))
	file.close()
	print("CONTACT_CAPTURE_SAVED ", label)

func run() -> void:
	RenderingServer.render_loop_enabled = false
	output = OS.get_environment("CAPTURE_ARTIFACT_DIR")
	focused = OS.get_environment("CONTACT_CAPTURE_SCOPE") == "other-weapons-and-third"
	third_only = OS.get_environment("CONTACT_CAPTURE_SCOPE") == "third-only"
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	RenderingServer.render_loop_enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	actor = game.actors[game.local_id]
	actor.aiming = false
	actor.reload_left = 0
	actor.switch_weapon(0)
	await advance(60, false)
	actor.position = Vector3(0, 0.3, 68)
	actor.velocity = Vector3.ZERO
	actor.local_view = false
	actor.body_mesh.visible = true
	game.ui.hide()
	review_camera = Camera3D.new()
	game.add_child(review_camera)
	review_camera.fov = 42
	review_camera.make_current()
	for crouch in [false, true]:
		actor.crouch = crouch
		actor.set_stance(crouch)
		for angle in [-0.65, 0.0, 0.65]:
			actor.pitch = angle
			actor.aiming = true
			await advance(40, true)
			review_camera.position = actor.position + Vector3(2.2, 1.3, -2.6)
			review_camera.look_at(actor.position + Vector3(0, 1.05, 0), Vector3.UP)
			await capture("%s-pitch-%s" % ["crouch" if crouch else "stand", str(angle)])
	var file := FileAccess.open(output.path_join("contact-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": true, "samples": records,
		"scope": "Six static third-person aim pitch samples. Not a continuous motion review.",
		"simulation_step": 1.0 / 60.0}, "\t"))
	file.close()
	print("WEAPON_CONTACT_REVIEW_PASS")
	quit()
