extends RefCounted
const Actor = preload("res://scripts/actor.gd")
const Zones = preload("res://scripts/zone_rules.gd")
const EXTRA := ["fire_left", "bot_think", "target_id", "bot_destination", "bot_patrol_left", "bot_memory_left", "bot_last_seen", "weapon_kick"]
const MAX_BYTES := 2097152
var path := "user://solo_checkpoint.dat"
var last_error := ""

static func finite_number(value, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high

static func point(value) -> bool:
	return value is Vector3 and value.is_finite() and value.length() < 1000

func validate(data, content: String) -> bool:
	if not data is Dictionary:
		return false
	for key in ["version", "content", "id", "elapsed", "zone_tick", "centers", "rng_seed", "rng_state", "actors", "loot", "grenades", "clouds", "events", "next_loot", "next_grenade", "waypoint"]:
		if not data.has(key):
			return false
	if data.version != 1 or data.content != content or not data.id is String:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
	if pattern.search(data.id) == null or (not finite_number(data.elapsed, 0, 300) or data.elapsed >= 300) or not finite_number(data.zone_tick, 0, 1):
		return false
	if not data.rng_seed is int or not data.rng_state is int or not data.next_loot is int or not data.next_grenade is int:
		return false
	if data.next_loot < 48 or data.next_grenade < 1:
		return false
	if not data.centers is Array or data.centers.size() != 7 or data.centers[0] != Vector2.ZERO:
		return false
	var previous := 110.0
	for i in range(7):
		if not data.centers[i] is Vector2 or not data.centers[i].is_finite():
			return false
		if i > 0:
			if data.centers[i].distance_to(data.centers[i - 1]) + Zones.RADII[i - 1] > previous + 0.001:
				return false
			previous = Zones.RADII[i - 1]
	if not data.actors is Array or data.actors.size() != 16:
		return false
	var prototype = Actor.new()
	var template: Dictionary = prototype.pack()
	var extras := {}
	for field in EXTRA:
		extras[field] = prototype.get(field)
	prototype.free()
	var ids := []
	var humans := 0
	for actor in data.actors:
		if not actor is Dictionary or not actor.get("extra") is Dictionary:
			return false
		for key in template:
			if not actor.has(key) or typeof(actor[key]) != typeof(template[key]):
				return false
			if actor[key] is float and not is_finite(actor[key]):
				return false
		for key in EXTRA:
			if not actor.extra.has(key) or typeof(actor.extra[key]) != typeof(extras[key]):
				return false
			if actor.extra[key] is float and not finite_number(actor.extra[key], -3600 if key == "bot_patrol_left" else 0, 60):
				return false
			if actor.extra[key] is Vector3 and not point(actor.extra[key]):
				return false
		if actor.id in ids or actor.id not in [1, -1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12, -13, -14, -15]:
			return false
		ids.append(actor.id)
		if not actor.b:
			humans += 1
			if actor.id != 1 or not actor.live or actor.r != 0:
				return false
		if actor.k < 0 or actor.k > 15 or actor.r < 0 or actor.r > 16:
			return false
		if not point(actor.p) or not point(actor.vel) or actor.n.length() > 64:
			return false
		if not finite_number(actor.h, 0, 100) or not finite_number(actor.a, 0, 100) or actor.live != (actor.h > 0):
			return false
		if actor.w < 0 or actor.w > 2 or actor.mags.size() != 3 or actor.m != actor.mags[actor.w]:
			return false
		for i in range(3):
			if actor.mags[i] < 0 or actor.mags[i] > Actor.CAPACITY[i]:
				return false
		if not finite_number(actor.s, 0, 300) or not finite_number(actor.med, 0, 5) or not finite_number(actor.frags, 0, 4) or not finite_number(actor.smokes, 0, 3):
			return false
		if not finite_number(actor.y, -PI - 0.01, PI + 0.01) or not finite_number(actor.v, -PI / 2, PI / 2) or not finite_number(actor.lean, -1, 1):
			return false
		if not finite_number(actor.reload, -1, 3.1) or not finite_number(actor.heal, -1, 3.5) or not finite_number(actor.throw, 0, 0.7):
			return false
	if humans != 1 or not data.loot is Dictionary or data.loot.size() > 1024 or not data.grenades is Array or data.grenades.size() > 32 or not data.clouds is Dictionary or data.clouds.size() > 32:
		return false
	for id in data.loot:
		var item = data.loot[id]
		if not id is int or id < 0 or id >= data.next_loot or not item is Dictionary:
			return false
		if not point(item.get("p")) or not item.get("kind") is int or item.kind < 0 or item.kind > 4:
			return false
		if item.has("amount") and not finite_number(item.amount, 0.001, 10000):
			return false
		if item.has("drop_slot") and (not item.drop_slot is int or item.drop_slot < 0 or item.drop_slot > 4):
			return false
	var grenade_ids := []
	for grenade in data.grenades:
		if not grenade is Dictionary or not grenade.get("id") is int or grenade.id < 1 or grenade.id >= data.next_grenade or grenade.id in grenade_ids:
			return false
		grenade_ids.append(grenade.id)
		if grenade.get("kind") not in [0, 1] or grenade.get("owner") not in ids or not finite_number(grenade.get("f"), 0, 2.6):
			return false
		if not point(grenade.get("p")) or not point(grenade.get("linear")) or not point(grenade.get("angular")):
			return false
	for id in data.clouds:
		var cloud = data.clouds[id]
		if not id is int or id < 1 or id >= data.next_grenade or id in grenade_ids or not cloud is Dictionary:
			return false
		if not point(cloud.get("p")) or not finite_number(cloud.get("age"), 0, 20):
			return false
	if not data.events is Array or data.events.size() > 5:
		return false
	for event in data.events:
		if not event is String or event.length() > 1024:
			return false
	return data.waypoint == null or (data.waypoint is Vector2 and data.waypoint.is_finite() and absf(data.waypoint.x) <= 115 and absf(data.waypoint.y) <= 115)

func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func read_copy(file_path: String, content: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var envelope = bytes_to_var(file.get_buffer(file.get_length()))
	if not envelope is Dictionary or not envelope.get("payload") is PackedByteArray or not envelope.get("sha") is String:
		return {}
	if digest(envelope.payload) != envelope.sha:
		return {}
	var data = bytes_to_var(envelope.payload)
	return data if validate(data, content) else {}

func load_state(content: String) -> Dictionary:
	last_error = ""
	var data := read_copy(path, content)
	if not data.is_empty():
		return data
	data = read_copy(path + ".bak", content)
	last_error = "Recovered the previous checkpoint backup." if not data.is_empty() else "No compatible, readable saved operation."
	return data

func write_atomic(file_path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(file_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(file_path + ".tmp", file_path) == OK

func save_state(data: Dictionary, content: String) -> bool:
	if not validate(data, content):
		last_error = "The operation state could not be saved safely."
		return false
	var payload := var_to_bytes(data)
	var envelope := var_to_bytes({"payload": payload, "sha": digest(payload)})
	if envelope.size() > MAX_BYTES:
		last_error = "Saved operation exceeds the supported size."
		return false
	if not read_copy(path, content).is_empty():
		if not write_atomic(path + ".bak", FileAccess.get_file_as_bytes(path)):
			last_error = "Could not preserve the previous checkpoint. Operation remains paused."
			return false
	if not write_atomic(path, envelope):
		last_error = "Could not write checkpoint. Operation remains paused."
		return false
	last_error = ""
	return true
