extends SceneTree

func _initialize() -> void:
	var expected = JSON.parse_string(OS.get_environment("EXPECTED_CANDIDATE_MANIFEST"))
	var packed = JSON.parse_string(FileAccess.get_file_as_string("res://protocol.json"))
	assert(expected is Dictionary and packed == expected, "Packed compatibility manifest must match candidate metadata")
	assert(ResourceLoader.exists("res://assets/operator.glb"))
	assert(ResourceLoader.exists("res://scripts/team_voice.gd"))
	print("CANDIDATE_MANIFEST_PASS embedded_version=ok operator=ok team_voice=ok")
	quit()
