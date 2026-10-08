shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 sheet_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float weather(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	sheet_position = VERTEX;
}

void fragment() {
	// Coordinates are metres, matching the standing seams in the roof mesh.
	vec2 p = sheet_position.xz;
	float panel = floor((p.y + 6.9) / 0.575);
	float coating = weather(p * vec2(0.65, 1.3));
	float fine = weather(p * 19.0);
	float panel_tone = hash21(vec2(panel, 7.0));
	vec3 paint = mix(vec3(0.085, 0.125, 0.13), vec3(0.15, 0.185, 0.18),
		coating * 0.65 + panel_tone * 0.35);
	// Adjacent sheets age differently; occasional replacement sheets retain paint.
	float replacement = step(0.86, panel_tone);
	float bleaching = weather(p * vec2(0.23, 0.55));
	paint = mix(paint, vec3(0.23, 0.255, 0.235), bleaching * 0.42);
	paint = mix(paint, vec3(0.095, 0.15, 0.155), replacement * 0.65);
	float seam_distance = abs(fract((p.y + 6.9) / 0.575) - 0.5);
	float runoff = smoothstep(0.36, 0.49, seam_distance)
		* smoothstep(0.32, 0.78, weather(p * vec2(0.42, 5.0)));
	paint *= 1.0 - runoff * 0.22;
	// Sparse weathering remains subordinate to the painted metal, with no
	// metallic mirror response from the intact coating under the noon sun.
	float oxide = smoothstep(0.69, 0.88, weather(p * vec2(2.3, 0.6)));
	ALBEDO = mix(paint, vec3(0.16, 0.105, 0.067), oxide * 0.24) * (0.96 + fine * 0.08);
	ROUGHNESS = 0.86 + coating * 0.10;
	METALLIC = 0.0;
	SPECULAR = 0.18;
}
