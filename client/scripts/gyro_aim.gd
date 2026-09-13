extends RefCounted
## Godot Android already rotates these rad/s readings into screen coordinates.
enum Mode { OFF, ADS, ALWAYS }
var mode := Mode.OFF
var sensitivity := 1.0
var invert_x := false
var invert_y := false
var filtered := Vector2.ZERO
var initialized := false

func reset() -> void:
	filtered = Vector2.ZERO
	initialized = false

func step(rate: Vector3, dt: float, active: bool, aiming: bool) -> Vector2:
	if not active or mode == Mode.OFF or (mode == Mode.ADS and not aiming) or not rate.is_finite() or not is_finite(dt) or dt <= 0 or dt > 0.1:
		reset()
		return Vector2.ZERO
	var input := Vector2(rate.y, rate.x).limit_length(8.0)
	# Small sensor noise must not drift the camera when the device is still.
	input.x = 0.0 if absf(input.x) < 0.004 else input.x
	input.y = 0.0 if absf(input.y) < 0.004 else input.y
	filtered = filtered.lerp(input, 1.0 - exp(-35.0 * dt)) if initialized else input
	initialized = true
	var gain := clampf(sensitivity, 0.1, 4.0) if is_finite(sensitivity) else 1.0
	return filtered * dt * gain * Vector2(-1 if invert_x else 1, -1 if invert_y else 1)
