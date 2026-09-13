extends SceneTree
const Store = preload("res://scripts/remembered_login.gd")
func _initialize() -> void:
	# Run with a fresh XDG_DATA_HOME; never use an actual player's profile.
	if FileAccess.file_exists(Store.DATA) or FileAccess.file_exists(Store.KEY):
		push_error("Test requires an empty profile")
		quit(1)
		return
	var server := "https://test.invalid/api"
	if not check(Store.read(server).password == "", "initially empty"): return
	if not check(Store.remember(server, "test_player", "synthetic-test-password") == OK, "write"): return
	if not check(Store.read(server + "/").username == "test_player", "normalized origin"): return
	if not check(Store.read(server).password == "synthetic-test-password", "read after reopen"): return
	if not check(Store.read("https://another.invalid/api").password == "", "server isolation"): return
	if not check(not FileAccess.get_file_as_bytes(Store.DATA).hex_encode().contains("synthetic-test-password".to_utf8_buffer().hex_encode()), "no plaintext password"): return
	if not check(Store.remember("https://another.invalid/api", "second", "second-test-password") == OK, "second server"): return
	if not check(Store.forget(server) == OK and Store.read(server).password == "", "forget"): return
	if not check(Store.read("https://another.invalid/api").username == "second", "preserve other server"): return
	if not check(Store.forget("https://another.invalid/api") == OK, "cleanup"): return
	print("REMEMBERED_LOGIN_PASS")
	quit()
func check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value
