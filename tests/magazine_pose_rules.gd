extends SceneTree

class ObservedMagazine extends Node3D:
	var changes := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

# Frozen pre-optimization pose path for differential verification.
class Legacy extends "res://scripts/first_person.gd":
	func update_magazine(desired: String, progress: float) -> void:
		if magazine != null:
			# Withdraw straight from the well, lower to the pouch, then bring a
			# separate magazine back up. The exchange occurs below the view edge.
			magazine.position = magazine_rest
			replacement_magazine.position = magazine_rest
			magazine.rotation = magazine_rest_rotation
			replacement_magazine.rotation = magazine_rest_rotation
			magazine.visible = true
			replacement_magazine.visible = false
			held_magazine = magazine
			if desired == "Reload" and progress > 0.2 and progress < 0.86:
				# Each well needs its own clearance: the long shotgun box must
				# leave the receiver before the wrist turns; the short rifle box
				# should not take the same exaggerated detour.
				var clearance: float = [0.17, 0.21, 0.115][weapon_kind]
				var extracted := Vector3(0, -clearance, 0)
				# Work beside the magwell in the lower-left view, not below the
				# camera. Separate withdrawal from the lateral exchange so the
				# magazine clears the receiver before the wrist turns.
				var exchange := Vector3(-0.19, -clearance - 0.015, -0.035)
				var wrist_turn: Vector3 = [Vector3(0.12, 0.0, -0.32),
					Vector3(0.08, 0.0, -0.22), Vector3(0.18, 0.0, -0.42)][weapon_kind]
				# Removal and return use the same visible workspace. The replacement
				# handoff remains a sampled exchange, not a simulated pouch grab.
				if progress < 0.6:
					if progress < 0.34:
						magazine.position += extracted * smoothstep(0.2, 0.34, progress)
					else:
						var travel := smoothstep(0.34, 0.59, progress)
						magazine.position += extracted.lerp(exchange, travel)
						magazine.rotation += wrist_turn * travel
				else:
					magazine.visible = false
					replacement_magazine.visible = true
					held_magazine = replacement_magazine
					if progress < 0.78:
						var travel := smoothstep(0.61, 0.78, progress)
						replacement_magazine.position += exchange.lerp(extracted, travel)
						replacement_magazine.rotation += wrist_turn * (1.0 - travel)
					else:
						replacement_magazine.position += extracted * (1.0 - smoothstep(0.78, 0.86, progress))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var current = load("res://scripts/first_person.gd").new()
	var legacy := Legacy.new()
	for fp in [current, legacy]:
		fp.magazine = ObservedMagazine.new()
		fp.replacement_magazine = ObservedMagazine.new()
		root.add_child(fp.magazine)
		root.add_child(fp.replacement_magazine)
		fp.magazine.set_notify_local_transform(true)
		fp.replacement_magazine.set_notify_local_transform(true)
		fp.magazine_rest = Vector3(0.12, -0.07, 0.03)
		fp.magazine_rest_rotation = Vector3(0.07, -0.11, 0.05)
	var samples := 0
	for weapon in range(3):
		current.weapon_kind = weapon
		legacy.weapon_kind = weapon
		for desired in ["Reload", "Hold", "Throw", "Heal"]:
			for tick in range(1001):
				var progress := tick / 1000.0
				current.update_magazine(desired, progress)
				legacy.update_magazine(desired, progress)
				for pair in [[current.magazine, legacy.magazine], [current.replacement_magazine, legacy.replacement_magazine]]:
					assert(pair[0].transform.is_equal_approx(pair[1].transform))
					assert(pair[0].visible == pair[1].visible)
				assert((current.held_magazine == current.magazine) == (legacy.held_magazine == legacy.magazine))
				samples += 1
	var optimized_changes: int = current.magazine.changes + current.replacement_magazine.changes
	var legacy_changes: int = legacy.magazine.changes + legacy.replacement_magazine.changes
	assert(optimized_changes < legacy_changes)
	current.magazine.changes = 0
	current.replacement_magazine.changes = 0
	for tick in range(120):
		current.update_magazine("Hold", 0)
	assert(current.magazine.changes + current.replacement_magazine.changes == 0)
	# Live state comparisons must also repair external pose changes.
	current.magazine.position += Vector3.ONE
	current.replacement_magazine.rotation += Vector3.ONE
	current.update_magazine("Hold", 0)
	assert(current.magazine.position == current.magazine_rest)
	assert(current.replacement_magazine.rotation == current.magazine_rest_rotation)
	print("MAGAZINE_POSE_PASS samples=", samples, " notifications=", optimized_changes, " legacy=", legacy_changes, " stable120=0")
	for fp in [current, legacy]:
		fp.magazine.free()
		fp.replacement_magazine.free()
	quit()
