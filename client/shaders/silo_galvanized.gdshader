shader_type spatial;

uniform float corrugation_strength = 1.0;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Galvanized sheets have a broad diffuse response even on the shaded
	// side. Oxidation collects at sheet seams and near the wet foundation.
	float sheet = floor(UV.x * 24.0);
	float seam = 1.0 - smoothstep(0.0, 0.075, fract(UV.x * 24.0));
	float mottling = noise(world_position.xz * 5.0 + world_position.y * 2.0);
	float streak = noise(vec2(UV.x * 170.0, world_position.y * 0.22));
	float foot = 1.0 - smoothstep(0.15, 1.7, world_position.y);
	float rust = clamp(seam * smoothstep(0.48, 0.8, streak) * 0.65
		+ foot * smoothstep(0.3, 0.8, streak) * 0.7, 0.0, 0.85);
	vec3 zinc = vec3(0.46, 0.50, 0.47) * (0.88 + 0.16 * mottling
		+ 0.08 * hash(vec2(sheet, 3.0)));
	ALBEDO = mix(zinc, vec3(0.22, 0.105, 0.045), rust);
	METALLIC = mix(0.22, 0.02, rust);
	ROUGHNESS = mix(0.63, 0.94, max(rust, mottling * 0.35));
	// Fine horizontal sheet corrugations; the structural hoops remain geometry.
	float phase = world_position.y * 78.54;
	float footprint = fwidth(phase);
	float wave = cos(phase) * (1.0 - smoothstep(1.0, 3.14, footprint)) * corrugation_strength;
	NORMAL_MAP = normalize(vec3(0.0, wave * 0.24, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.65;
}
