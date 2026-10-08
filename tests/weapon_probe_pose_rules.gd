extends SceneTree

class ProbeActor extends "res://scripts/actor.gd":
	var segments: Array = []
	var blocked_segment := 0

	func weapon_segment_blocked(from: Vector3, to: Vector3, _space: PhysicsDirectSpaceState3D) -> bool:
		segments.append([from, to])
		return segments.size() == blocked_segment

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := ProbeActor.new()
	root.add_child(actor)
	await physics_frame
	actor.position = Vector3(12, 3, -9)
	var cases := 0
	for lowered in [false, true]:
		actor.set_stance(lowered)
		for yaw in [-PI, -0.7, 0.0, 1.2, PI]:
			actor.yaw = yaw
			for lean in [-1.0, -0.001, 0.0, 0.001, 1.0]:
				actor.lean = lean
				for pitch in [-1.5, 0.0, 1.5]:
					actor.pitch = pitch
					actor.recoil = 0.12
					for weapon in range(3):
						actor.weapon = weapon
						for ads in [false, true]:
							var yaw_basis := Basis(Vector3.UP, yaw)
							var roll := Basis(Vector3.BACK, -lean * actor.LEAN_ANGLE)
							var facing := yaw_basis * Basis(Vector3.RIGHT, clampf(pitch + actor.recoil, -1.5, 1.5)) * roll
							var pivot := Vector3.UP * 0.38
							var eye := actor.position + yaw_basis * (pivot + roll * (Vector3.UP * actor.eye_height() - pivot))
							var offset := Vector3(0, -actor.OPTIC_HEIGHTS[weapon], -0.40) if ads else Vector3(0.26, -0.24, -0.48)
							var mount := eye + facing * offset
							var tip: Vector3 = mount + facing * actor.BARREL_ENDS[weapon]
							actor.blocked_segment = 0
							actor.segments.clear()
							assert(not actor.weapon_obstructed(ads))
							assert(actor.segments.size() == 2)
							assert(actor.segments[0][0].is_equal_approx(eye))
							assert(actor.segments[0][1].is_equal_approx(mount))
							assert(actor.segments[1][0].is_equal_approx(mount))
							assert(actor.segments[1][1].is_equal_approx(tip))
							for blocked in [1, 2]:
								actor.blocked_segment = blocked
								actor.segments.clear()
								assert(actor.weapon_obstructed(ads))
								assert(actor.segments.size() == blocked)
								assert(actor.segments[0][0].is_equal_approx(eye))
								assert(actor.segments[0][1].is_equal_approx(mount))
								if blocked == 2:
									assert(actor.segments[1][0].is_equal_approx(mount))
									assert(actor.segments[1][1].is_equal_approx(tip))
							cases += 1
	print("WEAPON_PROBE_POSE_RULES_PASS cases=", cases, " obstruction_states=3")
	actor.queue_free()
	await process_frame
	quit()
