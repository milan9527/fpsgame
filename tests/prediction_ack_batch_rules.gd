extends SceneTree

const Actor = preload("res://scripts/actor.gd")

class ReplayActor extends Actor:
	var replayed: Array[int] = []

	func predict_step(cmd: Dictionary, dt: float) -> void:
		replayed.append(int(cmd.seq))
		# Observe that each retained command carries its original time step.
		assert(is_equal_approx(dt, float(cmd.seq) / 10000.0))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := ReplayActor.new()
	root.add_child(actor)
	for count in [0, 1, 30, Actor.PREDICTION_LIMIT]:
		for acknowledged in range(count + 1):
			actor.prediction_history.clear()
			actor.replayed.clear()
			actor.prediction_ack = -1
			for index in range(count):
				var sequence := index + 100
				actor.prediction_history.append({"cmd": {"seq": sequence}, "dt": float(sequence) / 10000.0})
			actor.pending_correction = {"ack": 99 + acknowledged, "p": actor.position, "vel": Vector3.ZERO, "ground": true, "crouched": false}
			actor.reconcile_movement()
			assert(actor.prediction_history.size() == count - acknowledged)
			assert(actor.replayed.size() == count - acknowledged)
			for index in range(count - acknowledged):
				assert(actor.replayed[index] == 100 + acknowledged + index, "Only unacknowledged inputs replay, in order")
				assert(actor.prediction_history[index].cmd.seq == actor.replayed[index])
			# A stale snapshot must neither trim the retained tail nor replay it.
			actor.replayed.clear()
			actor.pending_correction = {"ack": 98 + acknowledged}
			actor.reconcile_movement()
			assert(actor.replayed.is_empty())
			assert(actor.prediction_history.size() == count - acknowledged)
	print("PREDICTION_ACK_BATCH_RULES_PASS empty=ok every_prefix_120=ok replay_order=ok dt=ok stale=ok")
	actor.queue_free()
	await process_frame
	quit()
