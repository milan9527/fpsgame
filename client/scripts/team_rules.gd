extends RefCounted

var mode := "solo"
var assignments: Dictionary = {}
var members: Dictionary = {}
var ranks: Dictionary = {}

func configure(actors: Dictionary, selected_mode: String) -> void:
	mode = selected_mode
	assignments.clear()
	members.clear()
	ranks.clear()
	var index := 0
	for actor in actors.values():
		var team := int(index / 2) + 1 if mode == "duo" else 0
		actor.team_id = team
		assignments[actor.actor_id] = team
		if team > 0:
			if not members.has(team):
				members[team] = []
			members[team].append(actor.actor_id)
		index += 1

func friendly(first: int, second: int) -> bool:
	return mode == "duo" and first != second and assignments.get(first, 0) > 0 and assignments.get(first, 0) == assignments.get(second, 0)

func living(actors: Dictionary) -> Array:
	var teams: Array = []
	for actor in actors.values():
		if actor.alive and actor.team_id > 0 and actor.team_id not in teams:
			teams.append(actor.team_id)
	return teams

func eliminated(actors: Dictionary, participants: Dictionary) -> void:
	var alive_teams := living(actors)
	for team in members:
		if team not in alive_teams and not ranks.has(team):
			ranks[team] = alive_teams.size() + 1
	apply_ranks(actors, participants)

func finish(actors: Dictionary, participants: Dictionary) -> void:
	var standings: Array = []
	for team in living(actors):
		var health := 0.0
		var kills := 0
		for id in members[team]:
			if actors.has(id):
				health += actors[id].health if actors[id].alive else 0
				kills += actors[id].kills
			else:
				kills += int(participants.get(id, {}).get("kills", 0))
		standings.append({"team": team, "health": health, "kills": kills})
	standings.sort_custom(func(a, b): return a.health > b.health if a.health != b.health else (a.kills > b.kills if a.kills != b.kills else a.team < b.team))
	for index in range(standings.size()):
		ranks[standings[index].team] = index + 1
	apply_ranks(actors, participants)

func apply_ranks(actors: Dictionary, participants: Dictionary) -> void:
	for team in ranks:
		for id in members[team]:
			if actors.has(id):
				actors[id].rank = ranks[team]
			if participants.has(id):
				participants[id].rank = ranks[team]

func winner() -> int:
	for team in ranks:
		if ranks[team] == 1:
			return team
	return 0
