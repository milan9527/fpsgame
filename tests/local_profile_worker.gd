extends SceneTree

func _initialize() -> void:
	assert(OS.get_environment("LOCAL_TEST_ROOT") != "")
	var profile = load("res://scripts/local_profile.gd").new(OS.get_environment("LOCAL_TEST_ROOT"))
	var args := OS.get_cmdline_user_args()
	if args[0] == "read":
		print("LOCAL_PROFILE_JSON " + JSON.stringify(profile.summary()))
		quit()
		return
	var record := {"id": args[1], "finished_at": 1800000000, "status": "completed", "rank": 3, "kills": int(args[2]), "seconds": 42, "map": "ash_valley"}
	if profile.store(record):
		print("LOCAL_PROFILE_STORED")
		quit()
	else:
		print("LOCAL_PROFILE_REJECTED " + profile.last_error)
		quit(2)
