extends SceneTree
func _initialize() -> void:
	var actors := {}
	var Actor = load("res://scripts/actor.gd")
	for id in [101, 201, 102, 202, -1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12]:
		var actor = Actor.new()
		actor.actor_id = id
		actor.is_bot = id < 0
		actors[id] = actor
	var rules = load("res://scripts/team_rules.gd").new()
	rules.configure(actors, "duo", {101: "party-a", 102: "party-a", 201: "party-b", 202: "party-b"})
	assert(rules.friendly(101, 102) and rules.friendly(201, 202))
	assert(not rules.friendly(101, 201) and rules.members.size() == 8)
	# Missing invited partner is filled by a bot, while complete parties remain intact.
	rules.configure(actors, "duo", {101: "party-a", 201: "party-b", 202: "party-b"})
	assert(rules.friendly(101, -1) and rules.friendly(201, 202))
	assert(not rules.friendly(101, 102))
	for pair in rules.members.values():
		assert(pair.size() == 2)
	var partial := {}
	for id in actors:
		actors[id].is_bot = false
		partial[id] = "incomplete-" + str(id)
	rules.configure(actors, "duo", partial)
	assert(rules.members.size() == 8, "A lobby full of incomplete parties still forms valid pairs")
	for pair in rules.members.values():
		assert(pair.size() == 2)
	rules.configure(actors, "solo", {101: "party-a", 102: "party-a"})
	assert(rules.members.is_empty() and not rules.friendly(101, 102))
	for actor in actors.values():
		actor.free()
	print("PARTY_TEAM_RULES_PASS interleaved_arrival=ok complete_parties=preserved absent_partner=bot solo=unchanged")
	quit()
