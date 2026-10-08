shader_type spatial;
varying vec3 local_position;
varying vec3 world_position;
float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise21(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x),
		mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x), f.y);
}
void vertex() {
	local_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Triplanar weather coordinates keep runoff visible on both dished heads.
	float end_weight = smoothstep(1.9, 2.25, abs(world_position.x + 23.0));
	vec2 shell = vec2(mix(world_position.x, world_position.z, end_weight), world_position.y);
	float grain = noise21(shell * 95.0);
	float streak = noise21(shell * vec2(17.0, 0.9) + vec2(noise21(shell * 3.0) * 0.4));
	float seam = 1.0 - smoothstep(0.025, 0.09, abs(abs(world_position.x + 23.0) - 1.65));
	float lower = 1.0 - smoothstep(0.7, 2.8, world_position.y);
	float weather = smoothstep(0.50, 0.75, streak) * (0.18 + lower * 0.7);
	float faded = noise21(shell * 1.8) * 0.65 + noise21(shell * 6.0) * 0.35;
	vec3 paint = mix(vec3(0.19, 0.225, 0.17), vec3(0.34, 0.36, 0.27), faded);
	float chip_weight = max(seam, lower * 0.22);
	float chips = 0.0;
	// Skip four noise hashes where chips cannot change the final paint color.
	// Preserve the original detail everywhere its contribution is visible.
	if (chip_weight > 0.0 && weather + seam * 0.32 < 0.8) {
		chips = smoothstep(0.6, 0.76, noise21(shell * 38.0)) * chip_weight;
	}
	ALBEDO = mix(paint, vec3(0.13, 0.073, 0.032), clamp(weather + seam * 0.32 + chips, 0.0, 0.8));
	ROUGHNESS = 0.64 + grain * 0.23;
	METALLIC = 0.05;
	SPECULAR = 0.36;
}
