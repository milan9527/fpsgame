shader_type spatial;
varying vec3 position_world;
void vertex() { position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Worn safety paint on steel guards. Broad wear survives normal play distance.
	vec3 p = position_world;
	float bands = step(0.50, fract(p.y * 2.0 + p.x * 1.5));
	float grain = sin(p.x * 131.0 + sin(p.y * 73.0)) * sin(p.y * 117.0 + p.z * 83.0);
	float wear = smoothstep(0.35, 0.85, grain) * 0.55;
	vec3 paint = mix(vec3(0.31, 0.20, 0.045), vec3(0.035, 0.042, 0.039), bands);
	float dirt = 1.0 - smoothstep(0.05, 0.48, p.y);
	ALBEDO = mix(mix(paint, vec3(0.13, 0.11, 0.085), wear), vec3(0.07, 0.064, 0.046), dirt * 0.65);
	ROUGHNESS = 0.86;
	METALLIC = wear * 0.3;
}
