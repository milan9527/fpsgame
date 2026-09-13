extends SceneTree
func _initialize() -> void:
	var saved := preload("res://scripts/remembered_login.gd").read(OS.get_environment("TEST_API_URL"))
	if saved.username != OS.get_environment("TEST_USERNAME") or saved.password != OS.get_environment("TEST_PASSWORD") or saved.password.is_empty():
		push_error("Successful login was not persisted")
		quit(1)
		return
	print("AUTHENTICATED_LOGIN_RESTART_PASS")
	quit()
