shader_type spatial;
render_mode cull_disabled;

varying vec3 world_position;
varying vec3 panel_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	panel_position = VERTEX;
}

void fragment() {
	vec2 p = world_position.zy;
	float streak = noise(p * vec2(22.0, 0.8));
	float bloom = noise(p * vec2(1.4, 3.0));
	float fine = noise(p * 190.0);
	// Rain follows the short vertical face; damp splash accumulates on the
	// bottom courses, while exposed folded edges lose paint locally.
	float damp_weight = 1.0 - smoothstep(0.35, 1.25, world_position.y);
	float damp = 0.0;
	if (damp_weight > 0.0) {
		damp = damp_weight * (0.55 + 0.45 * noise(p * vec2(4.0, 1.8)));
	}
	float fold = smoothstep(0.073, 0.112, abs(panel_position.y));
	float chipped = 0.0;
	if (fold > 0.0) {
		chipped = fold * smoothstep(0.53, 0.77, noise(p * vec2(45.0, 16.0)));
	}
	float runoff = smoothstep(0.58, 0.82, streak);
	vec3 paint = mix(vec3(0.027, 0.047, 0.036), vec3(0.063, 0.092, 0.068),
		0.3 * streak + 0.7 * bloom);
	paint *= 1.0 - damp * 0.38 - runoff * 0.18;
	paint = mix(paint, vec3(0.075, 0.041, 0.019), chipped * 0.65);
	ALBEDO = paint * (0.97 + fine * 0.06);
	ROUGHNESS = 0.88 + bloom * 0.10;
	SPECULAR = 0.18;
	METALLIC = 0.0;
}
