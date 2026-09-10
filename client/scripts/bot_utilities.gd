extends RefCounted
# Recomputed tactical decisions; inventory and timed actor actions remain authoritative.
var cooldown := 0.0
var think_left := 0.0
var smoke_hold := 0.0
var smoke_threat := Vector3.ZERO

func update(game, actor, dt: float, solid_cover: bool, evacuating: bool) -> void:
	cooldown = maxf(0, cooldown - dt)
	think_left -= dt
	smoke_hold = maxf(0, smoke_hold - dt)
	if evacuating or not actor.alive:
		smoke_hold = 0
		return
	if smoke_hold > 0:
		if actor.health >= 65:
			smoke_hold = 0
			return
		actor.move_input = Vector2.ZERO
		actor.shooting = false
		actor.crouch = true
		if game.smoke_blocks(actor.eye_position(), smoke_threat + Vector3.UP * 1.6):
			actor.heal()
		return
	if think_left > 0:
		return
	think_left = 0.8 + float(absi(actor.actor_id) % 5) * 0.08
	if cooldown > 0 or game.elapsed < 8 or actor.reload_left > 0 or actor.heal_left > 0 or actor.throw_left > 0:
		return
	if actor.smokes > 0 and actor.medkits > 0 and actor.health < 55 and actor.bot_memory_left > 0 and not solid_cover:
		if game.smoke_blocks(actor.eye_position(), actor.bot_last_seen + Vector3.UP * 1.6):
			return
		var delta: Vector3 = actor.bot_last_seen - actor.position
		var saved_yaw: float = actor.yaw
		var saved_pitch: float = actor.pitch
		actor.yaw = atan2(-delta.x, -delta.z)
		# Place the same physical smoke grenade near the bot's feet.
		actor.pitch = -1.2
		var thrown: bool = game.throw_grenade(actor, 1)
		actor.yaw = saved_yaw
		actor.pitch = saved_pitch
		if thrown:
			cooldown = 18
			smoke_hold = 8
			smoke_threat = actor.bot_last_seen
			actor.move_input = Vector2.ZERO
			actor.shooting = false
			actor.crouch = true
		return
	if actor.grenades > 0 and actor.shooting and game.actors.has(actor.target_id):
		var distance: float = actor.position.distance_to(actor.bot_last_seen)
		if distance > 23 and distance < 32:
			var saved_pitch: float = actor.pitch
			actor.pitch = 0.25
			if game.throw_grenade(actor):
				cooldown = 12
			actor.pitch = saved_pitch
