shader_type spatial;
render_mode diffuse_burley;

varying vec3 local_position;
varying vec3 local_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	// Coordinates remain in metres, so grain does not stretch with box UVs.
	vec2 p = local_position.xz;
	float bend = noise(p * vec2(1.3, 5.0)) * 1.5;
	float broad = noise(vec2(p.x * 0.8, p.y * 32.0 + bend));
	float wear = noise(p * vec2(4.0, 8.0));
	// Fade subpixel fibres instead of allowing them to sparkle at distance.
	float grain_visibility = 1.0 - smoothstep(0.35, 1.2, fwidth(p.y) * 390.0);
	float pore_visibility = 1.0 - smoothstep(0.35, 1.2, fwidth(p.y) * 750.0);
	// Fully faded fibres contribute constants; avoid their high-frequency noise.
	float grain = 0.5;
	float pores = 0.0;
	if (grain_visibility > 0.0) {
		grain = mix(0.5, noise(vec2(p.x * 4.0, p.y * 390.0 + bend)), grain_visibility);
	}
	if (pore_visibility > 0.0) {
		pores = smoothstep(0.72, 0.94, noise(p * vec2(12.0, 750.0))) * pore_visibility;
	}
	vec3 wood = mix(vec3(0.29, 0.26, 0.20), vec3(0.37, 0.33, 0.25), broad);
	wood *= 0.96 + grain * 0.06 - pores * 0.07;
	// Three joined boards age differently; joints themselves are real geometry.
	float board = floor((p.y + 0.425) / 0.2833);
	wood *= mix(0.89, 1.06, hash(vec2(board, 17.0)));
	float top = smoothstep(0.6, 0.95, local_normal.y);
	// Old lubricant has soaked around the vise, not uniformly over the bench.
	float oil = (1.0 - smoothstep(0.14, 0.48,
		length((p - vec2(-0.92, 0.17)) * vec2(0.8, 1.4))
		+ (noise(p * 23.0) - 0.5) * 0.09)) * top;
	float ring_distance = abs(length((p - vec2(0.58, -0.05))
		* vec2(1.0, 1.08)) - 0.052);
	float ring = (1.0 - smoothstep(0.002, 0.006 + fwidth(ring_distance),
		ring_distance)) * smoothstep(0.25, 0.6, noise(p * 55.0)) * top;
	// Short knife/scoring marks cross the fibres in the central work area.
	float cuts = 0.0;
	for (int i = 0; i < 18; i++) {
		vec2 seed = vec2(float(i), 41.0);
		vec2 centre = vec2(hash(seed) * 1.15 - 0.38,
			hash(seed + 3.0) * 0.54 - 0.27);
		vec2 q = p - centre;
		float slope = mix(-0.65, 0.65, hash(seed + 7.0));
		float distance_to_cut = abs(q.y - slope * q.x);
		float width = max(0.0007, fwidth(distance_to_cut));
		cuts += (1.0 - smoothstep(0.0, width, distance_to_cut))
			* (0.0007 / width)
			* (1.0 - smoothstep(0.015, 0.065, abs(q.x)));
	}
	float edge_wear = smoothstep(0.35, 0.425, p.y)
		* smoothstep(0.25, 0.75, wear) * top;
	wood = mix(wood, vec3(0.39, 0.35, 0.28), edge_wear * 0.5);
	wood *= 1.0 - oil * 0.38 - ring * 0.24;
	wood = mix(wood, vec3(0.20, 0.17, 0.12), clamp(cuts, 0.0, 1.0) * top * 0.3);
	ALBEDO = wood;
	ROUGHNESS = clamp(0.84 + grain * 0.09 - oil * 0.22 - edge_wear * 0.14, 0.5, 0.96);
	SPECULAR = 0.25;
}
