extends SceneTree
class HazardServer:
	extends "res://scripts/game.gd"
	var spawned := false
	var verified := false
	func reset_round() -> void:
		super.reset_round()
		phase_time = 3
	func begin_round() -> void:
		super.begin_round()
		for actor in actors.values():
			actor.position = Vector3(105, 0.02, 105) if actor.is_bot else Vector3(0, 0.02, -30)
		actors[-1].position = Vector3(0, 0.02, 20)
		actors[-1].grenades = 0
		actors[-1].smokes = 0
		actors[-1].armor = 0
		loot.clear()
	func bot_input(actor, dt: float) -> void:
		if actor.actor_id != -1 or elapsed < 9:
			return
		if not spawned:
			spawned = true
			var grenade = Grenade.new()
			grenade.grenade_id = next_grenade_id
			next_grenade_id += 1
			grenade.position = Vector3(0, 0.15, 17)
			add_child(grenade)
			grenades[grenade.grenade_id] = grenade
			actor.navigator.utilities.smoke_hold = 8
		super.bot_input(actor, dt)
		if not verified and grenades.is_empty():
			verified = true
			assert(actor.health == 100 and actor.position.distance_to(Vector3(0, 0.02, 20)) > 6)
			assert(actor.navigator.utilities.smoke_hold == 0)
			print("BOT_HAZARDS_SERVER_PASS blast=detonated health=100 physical_escape=ok")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := HazardServer.new()
	game.name = "Game"
	root.add_child(game)
