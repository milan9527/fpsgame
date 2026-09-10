extends RefCounted
const Bindings = preload("res://scripts/control_bindings.gd")
var step := 0
var start_position := Vector3.ZERO
var kills := 0
var frag_done := false
var map_opened := false
var map_marked := false
var loaded := 0

func start(game) -> void:
	game.phase = "live"
	game.loot.clear()
	game.events.clear()
	game.actors[1].position = Vector3(0, 0.02, 20)
	game.actors[1].yaw = 0
	game.actors[1].grenades = 0
	game.actors[1].smokes = 0
	start_position = game.actors[1].position
	game.ui.tactical_map.waypoint = null

func record_kill(target) -> void:
	if step == 2 and target.actor_id in [-1, -2, -3]:
		kills += 1
		if target.has_node("TrainingLabel"):
			target.get_node("TrainingLabel").hide()

func record_frag() -> void:
	if step == 6:
		frag_done = true

func update(game) -> void:
	var actor = game.actors[1]
	var advance := false
	match step:
		0:
			advance = Vector2(actor.position.x, actor.position.z).distance_to(Vector2(start_position.x, start_position.z)) >= 5
		1:
			advance = actor.crouched
		2:
			actor.reserve = maxi(actor.reserve, 90)
			advance = kills >= 3
		3:
			advance = actor.reserve > 0
		4:
			actor.reserve = maxi(actor.reserve, 45)
			advance = actor.magazines[0] + actor.magazines[1] + actor.magazines[2] > loaded
		5:
			actor.medkits = maxi(actor.medkits, 1)
			advance = actor.health >= 100
		6:
			if game.grenades.is_empty() and not frag_done:
				actor.grenades = maxi(actor.grenades, 1)
			advance = frag_done
		7:
			if game.grenades.is_empty() and game.smoke_clouds.is_empty():
				actor.smokes = maxi(actor.smokes, 1)
			for cloud in game.smoke_clouds.values():
				advance = advance or cloud.age >= 1.5
		8:
			map_opened = map_opened or game.ui.tactical_map.visible
			map_marked = map_marked or (map_opened and game.ui.tactical_map.waypoint != null)
			advance = map_marked and not game.ui.tactical_map.visible
	if advance:
		step += 1
		enter_step(game)

func enter_step(game) -> void:
	var actor = game.actors[1]
	match step:
		2:
			actor.magazines = PackedInt32Array([30, 8, 5])
			for i in range(3):
				var target = game.spawn_actor(-i - 1, "TARGET %d" % (i + 1), true, Vector3((i - 1) * 4, 0.02, -6 - i * 6))
				target.health = 35
				target.armor = 0
				target.yaw = PI
				var label := Label3D.new()
				label.name = "TrainingLabel"
				label.text = target.display_name
				label.position.y = 2.3
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				target.add_child(label)
		3:
			actor.reserve = 0
			game.loot[game.next_loot_id] = {"p": Vector3(0, 0.1, 16), "kind": 0, "amount": 45.0}
			game.next_loot_id += 1
			game.ui.tactical_map.waypoint = Vector2(0, 16)
		4:
			actor.ammo = mini(actor.ammo, actor.CAPACITY[actor.weapon] - 1)
			loaded = actor.magazines[0] + actor.magazines[1] + actor.magazines[2]
		5:
			actor.health = 40
			actor.medkits = 1
		6:
			actor.grenades = 1
		7:
			game.clear_grenades()
			actor.smokes = 1
		8:
			game.ui.tactical_map.waypoint = null
		9:
			game.phase = "training_complete"
			actor.shooting = false
			actor.move_input = Vector2.ZERO
			game.clear_grenades()

func hint() -> String:
	match step:
		0: return "MOVE\n%s / %s / %s / %s — move five metres along the road." % [Bindings.key_label("forward"), Bindings.key_label("back"), Bindings.key_label("left"), Bindings.key_label("right")]
		1: return "CROUCH\nHold %s to lower your stance." % Bindings.key_label("crouch")
		2: return "TARGET PRACTICE / %d OF 3\nFace down the road. Right mouse to aim, left mouse to fire. %s to reload." % [kills, Bindings.key_label("reload")]
		3: return "COLLECT AMMUNITION\nFollow the waypoint to the supply. Press %s nearby." % Bindings.key_label("loot")
		4: return "RELOAD\nPress %s and wait for the magazine to refill." % Bindings.key_label("reload")
		5: return "HEAL\nPress %s and wait for treatment to finish." % Bindings.key_label("heal")
		6: return "FRAGMENTATION GRENADE\nAim down the road, press %s, and watch the detonation. Training protects you from damage." % Bindings.key_label("throw")
		7: return "SMOKE GRENADE\nPress %s and wait for the smoke screen to develop." % Bindings.key_label("smoke_throw")
		8: return "TACTICAL MAP\nPress %s, left-click to mark a destination, then close the map." % Bindings.key_label("map")
	return "TRAINING COMPLETE\nMovement, weapons, supplies and navigation practised. ESC to return to deployment."
