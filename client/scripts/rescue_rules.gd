extends RefCounted

func standing_ally(game, actor) -> bool:
	for other in game.actors.values():
		if game.teams.friendly(actor.actor_id, other.actor_id) and other.alive and not other.downed:
			return true
	return false

func accessible(game, actor, other) -> bool:
	if not actor.alive or actor.downed or not other.alive or not other.downed or actor == other or actor.team_id <= 0 or actor.team_id != other.team_id:
		return false
	if actor.position.distance_to(other.position) > 2.8:
		return false
	var query := PhysicsRayQueryParameters3D.create(actor.position + Vector3.UP * 0.6, other.position + Vector3.UP * 0.6, 1)
	query.hit_from_inside = true
	return game.world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func target(game, actor):
	var best = null
	for other in game.actors.values():
		if accessible(game, actor, other) and (best == null or actor.position.distance_squared_to(other.position) < actor.position.distance_squared_to(best.position)):
			best = other
	return best

func cancel(actor) -> void:
	actor.revive_target = 0
	actor.revive_left = 0

func interrupt(game, actor) -> void:
	cancel(actor)
	for other in game.actors.values():
		if other.revive_target == actor.actor_id:
			cancel(other)

func interact(game, actor) -> bool:
	if actor.revive_target != 0:
		cancel(actor)
		return true
	var other = target(game, actor)
	if other == null:
		return false
	actor.cancel_heal()
	actor.reload_left = 0
	actor.revive_target = other.actor_id
	actor.revive_left = 5.0
	actor.shooting = false
	return true

func update(game, dt: float) -> void:
	if game.match_mode != "duo":
		return
	# Bleeding and team wipe resolve before rescue completion.
	for actor in game.actors.values():
		if actor.alive and actor.downed:
			actor.bleed_left = maxf(0, actor.bleed_left - dt)
			if actor.bleed_left <= 0 or not standing_ally(game, actor):
				game.damage(actor, 10000, actor.knock_attacker, true, false, "BLEED OUT", null, true, true)
	for actor in game.actors.values():
		if actor.revive_target == 0:
			continue
		var other = game.actors.get(actor.revive_target)
		if other == null or not accessible(game, actor, other) or actor.move_input.length() > 0.1 or actor.shooting or actor.jump_requested:
			cancel(actor)
			continue
		actor.revive_left = maxf(0, actor.revive_left - dt)
		if actor.revive_left <= 0:
			other.downed = false
			other.down_health = 0
			other.bleed_left = 0
			other.health = 30
			cancel(actor)
			game.add_event(actor.display_name + "  REVIVED  " + other.display_name)

func bot_rescue(game, actor, dt: float) -> bool:
	if actor.downed:
		actor.move_input = Vector2.ZERO
		actor.shooting = false
		return true
	for other in game.actors.values():
		if not other.alive or not other.downed or not game.teams.friendly(actor.actor_id, other.actor_id):
			continue
		# An imminent frag still takes precedence over approaching a teammate.
		if actor.navigator.hazards.select(game, actor, dt).is_finite():
			cancel(actor)
			return false
		actor.shooting = false
		actor.aiming = false
		actor.sprint = false
		actor.cancel_heal()
		if accessible(game, actor, other):
			actor.move_input = Vector2.ZERO
			if actor.revive_target == 0:
				interact(game, actor)
		else:
			cancel(actor)
			var direction: Vector3 = actor.navigator.steer(actor, game.world, other.position, dt, 0.5)
			actor.move_input = Vector2((Basis(Vector3.UP, -actor.yaw) * direction).x, (Basis(Vector3.UP, -actor.yaw) * direction).z)
		return true
	return false
