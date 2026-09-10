extends RefCounted

const VERSION := 2
const MAX_BYTES := 16384
var root_path: String
var last_error := ""
var id_pattern := RegEx.new()

func _init(location := "user://local_results") -> void:
	root_path = ProjectSettings.globalize_path(location)
	id_pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

func integer(value, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

func valid_record(record) -> bool:
	if not record is Dictionary or record.size() not in [7, 9]:
		return false
	for key in ["id", "finished_at", "status", "rank", "kills", "seconds", "map"]:
		if not record.has(key):
			return false
	if record.size() == 9:
		if not record.has("mode") or not record.has("team_id") or record.mode not in ["solo", "duo"]:
			return false
		if not integer(record.team_id, 1, 8) if record.mode == "duo" else not integer(record.team_id, 0, 0):
			return false
	if not record.id is String or id_pattern.search(record.id) == null:
		return false
	if record.status not in ["completed", "abandoned"] or record.map != "ash_valley":
		return false
	if not integer(record.finished_at, 0, 4102444800) or not integer(record.kills, 0, 15) or not integer(record.seconds, 0, 3600):
		return false
	return integer(record.rank, 1, 8 if record.get("mode", "solo") == "duo" else 16) if record.status == "completed" else integer(record.rank, 0, 0)

func read_copy(path: String, expected_id: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"state": "missing"}
	if file.get_length() > MAX_BYTES:
		return {"state": "corrupt"}
	var envelope = JSON.parse_string(file.get_as_text())
	if not envelope is Dictionary or not envelope.has("version"):
		return {"state": "corrupt"}
	if integer(envelope.version, VERSION + 1, 1000000):
		return {"state": "newer"}
	if not integer(envelope.version, 1, VERSION) or not envelope.get("payload") is String or not envelope.get("sha256") is String:
		return {"state": "corrupt"}
	if envelope.payload.sha256_text() != envelope.sha256:
		return {"state": "corrupt"}
	var record = JSON.parse_string(envelope.payload)
	if not valid_record(record) or record.id != expected_id:
		return {"state": "corrupt"}
	if (int(envelope.version) == 1 and record.size() != 7) or (int(envelope.version) == 2 and record.size() != 9):
		return {"state": "corrupt"}
	return {"state": "ok", "record": record}

func read_record(id: String) -> Dictionary:
	var location := root_path.path_join("records").path_join(id)
	var primary := read_copy(location.path_join("result.json"), id)
	if primary.state in ["ok", "newer"]:
		primary["recovered"] = false
		return primary
	var backup := read_copy(location.path_join("backup.json"), id)
	backup["recovered"] = backup.state == "ok"
	return backup

func write_copy(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	var success := file.get_error() == OK
	file.close()
	return success

func same_record(a: Dictionary, b: Dictionary) -> bool:
	if a.get("mode", "solo") != b.get("mode", "solo") or int(a.get("team_id", 0)) != int(b.get("team_id", 0)):
		return false
	for key in ["id", "status", "map"]:
		if a[key] != b[key]:
			return false
	for key in ["finished_at", "rank", "kills", "seconds"]:
		if int(a[key]) != int(b[key]):
			return false
	return true

func discard_candidate(path: String) -> void:
	for file in ["result.json", "backup.json"]:
		if FileAccess.file_exists(path.path_join(file)):
			DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)

func store(record: Dictionary) -> bool:
	last_error = ""
	if not valid_record(record):
		last_error = "Invalid local result."
		return false
	if FileAccess.file_exists(root_path):
		last_error = "Local results path is a file, not a folder."
		return false
	var destination := root_path.path_join("records").path_join(record.id)
	if DirAccess.dir_exists_absolute(destination):
		var previous := read_record(record.id)
		if previous.state == "ok" and same_record(previous.record, record):
			return true
		last_error = "An existing operation cannot be overwritten."
		return false
	var nonce := Crypto.new().generate_random_bytes(12).hex_encode()
	var candidate := root_path.path_join("pending").path_join(nonce)
	if DirAccess.make_dir_recursive_absolute(root_path.path_join("records")) != OK or DirAccess.make_dir_recursive_absolute(candidate) != OK:
		last_error = "Cannot create local results folder."
		return false
	var payload := JSON.stringify(record)
	var contents := JSON.stringify({"version": VERSION if record.has("mode") else 1, "payload": payload, "sha256": payload.sha256_text()})
	if not write_copy(candidate.path_join("result.json"), contents) or not write_copy(candidate.path_join("backup.json"), contents):
		discard_candidate(candidate)
		last_error = "Cannot write local result. Check available disk space and permissions."
		return false
	# Publish a complete, non-empty directory atomically. Existing immutable
	# directories cannot be replaced by another writer on the same filesystem.
	var error := DirAccess.rename_absolute(candidate, destination)
	if error == OK:
		return true
	discard_candidate(candidate)
	var existing := read_record(record.id)
	if existing.state == "ok" and same_record(existing.record, record):
		return true
	last_error = "Cannot publish local result; existing results were preserved."
	return false

func summary() -> Dictionary:
	var result := {"records": [], "completed": 0, "abandoned": 0, "wins": 0, "kills": 0, "seconds": 0, "recovered": 0, "unreadable": 0, "newer": 0, "read_error": "", "modes": {"solo": {"completed": 0, "abandoned": 0, "wins": 0, "kills": 0}, "duo": {"completed": 0, "abandoned": 0, "wins": 0, "kills": 0}}}
	var records_path := root_path.path_join("records")
	if FileAccess.file_exists(root_path) or FileAccess.file_exists(records_path):
		result.read_error = "Local results folder is unavailable."
		return result
	if not DirAccess.dir_exists_absolute(records_path):
		return result
	var directory := DirAccess.open(records_path)
	if directory == null:
		result.read_error = "Cannot read local results. Check folder permissions."
		return result
	for id in directory.get_directories():
		if id_pattern.search(id) == null:
			continue
		var entry := read_record(id)
		if entry.state != "ok":
			result["newer" if entry.state == "newer" else "unreadable"] += 1
			continue
		var record: Dictionary = entry.record
		var mode_stats: Dictionary = result.modes[record.get("mode", "solo")]
		mode_stats[record.status] += 1
		mode_stats.kills += int(record.kills)
		result.records.append(record)
		result[record.status] += 1
		result.kills += int(record.kills)
		result.seconds += int(record.seconds)
		if record.status == "completed" and int(record.rank) == 1:
			result.wins += 1
			mode_stats.wins += 1
		if entry.recovered:
			result.recovered += 1
	result.records.sort_custom(func(a, b): return a.finished_at > b.finished_at if a.finished_at != b.finished_at else a.id < b.id)
	return result
