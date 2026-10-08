shader_type spatial;
// Frosted daylight panels need no per-light/shadow shader variants on Android.
// Keep the opaque, two-sided core and the same world-space fluting and dirt.
render_mode unshaded, cull_disabled;
varying vec3 pane_position;
void vertex() {
	pane_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float phase = pane_position.z * 6.283185 / 0.10;
	float visibility = 1.0 - smoothstep(0.8, 3.0, fwidth(phase));
	float flute = (0.5 + 0.5 * cos(phase)) * visibility;
	float edge = smoothstep(-28.0, -26.0, pane_position.x);
	float dust = 0.5 + 0.5 * sin(pane_position.x * 3.7 + sin(pane_position.z * 2.3));
	vec3 core = mix(vec3(0.48, 0.53, 0.47), vec3(0.28, 0.27, 0.20), edge * 0.45 + dust * 0.12);
	core *= 0.90 + flute * 0.10;
	vec3 daylight = vec3(0.32, 0.36, 0.29) * (0.72 - edge * 0.30 - dust * 0.12);
	ALBEDO = core * 0.5 + daylight;
}
