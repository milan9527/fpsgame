extends RefCounted
## Local encrypted credentials; the random key stays in this app's private data directory.
const DATA := "user://remembered-login.dat"
const KEY := "user://remembered-login.key"

static func origin(endpoint: String) -> String:
	return endpoint.strip_edges().trim_suffix("/")

static func encryption_key(create := false) -> PackedByteArray:
	if FileAccess.file_exists(KEY):
		var existing := FileAccess.get_file_as_bytes(KEY)
		return existing if existing.size() == 32 else PackedByteArray()
	if not create or FileAccess.file_exists(DATA):
		return PackedByteArray()
	var key := Crypto.new().generate_random_bytes(32)
	var file := FileAccess.open(KEY, FileAccess.WRITE)
	if file == null:
		return PackedByteArray()
	file.store_buffer(key)
	file.close()
	FileAccess.set_unix_permissions(KEY, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
	return key

static func load_all() -> ConfigFile:
	var config := ConfigFile.new()
	var key := encryption_key()
	if key.size() == 32 and FileAccess.file_exists(DATA):
		if config.load_encrypted(DATA, key) != OK:
			return ConfigFile.new()
	return config

static func read(endpoint: String) -> Dictionary:
	var config := load_all()
	var section := origin(endpoint).sha256_text()
	return {"username": str(config.get_value(section, "username", "")),
		"password": str(config.get_value(section, "password", ""))}

static func remember(endpoint: String, username: String, password: String) -> Error:
	var key := encryption_key(true)
	if key.size() != 32:
		return ERR_CANT_OPEN
	var config := load_all()
	var section := origin(endpoint).sha256_text()
	config.set_value(section, "username", username)
	config.set_value(section, "password", password)
	var result := config.save_encrypted(DATA, key)
	if result == OK:
		FileAccess.set_unix_permissions(DATA, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
	return result

static func forget(endpoint: String) -> Error:
	var config := load_all()
	var section := origin(endpoint).sha256_text()
	if config.has_section(section):
		config.erase_section(section)
	if config.get_sections().is_empty():
		if FileAccess.file_exists(DATA):
			return DirAccess.remove_absolute(DATA)
		return OK
	return config.save_encrypted(DATA, encryption_key())
