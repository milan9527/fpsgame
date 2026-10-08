extends SceneTree

class Target:
	extends RefCounted
	var point := Vector3.ZERO
	func aim_position() -> Vector3:
		return point

func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var start := source.find("\t\t\tvar blast_offset:", source.find("func detonate_grenade("))
	var finish := source.find("\n\t\t\tif amount > 0:", start)
	assert(start >= 0 and finish > start)
	var body := source.substr(start, finish - start).replace("\t\t\t", "\t")
	body = body.replace("continue", "return 0.0")
	var script := GDScript.new()
	script.source_code = """extends RefCounted
const Grenade = preload("res://scripts/grenade.gd")
var exposure := 1.0
var queries := 0
func explosion_exposure(_origin, _actor) -> float:
	queries += 1
	return exposure
func evaluate(origin: Vector3, actor) -> float:
""" + body + "\n\treturn amount\n"
	assert(script.reload() == OK)
	var subject = script.new()
	var actor := Target.new()
	var grenade = load("res://scripts/grenade.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 665
	var cases := 0
	for exposure in [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]:
		subject.exposure = exposure
		for i in range(10003):
			actor.point = Vector3(rng.randf_range(-20, 20), rng.randf_range(-20, 20), rng.randf_range(-20, 20))
			if i < 3:
				actor.point = Vector3([8.999999, 9.0, 9.000001][i], 0, 0)
			var distance := actor.point.distance_to(Vector3.ZERO)
			var expected: float = 0.0 if distance >= grenade.RADIUS else grenade.MAX_DAMAGE * (1 - distance / grenade.RADIUS) * exposure
			subject.queries = 0
			assert(subject.evaluate(Vector3.ZERO, actor) == expected, str(actor.point))
			assert(subject.queries == (0 if distance >= grenade.RADIUS else 1))
			cases += 1
	print("GRENADE_DISTANCE_REJECTION_PASS cases=", cases)
	quit()
