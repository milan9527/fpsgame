shader_type spatial;
render_mode diffuse_burley;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Recesses in a backed steel panel, at a physical 50 mm pitch.
	vec2 p = local_position.xy;
	vec2 cell = fract(p / 0.05 + 0.5) - 0.5;
	float radius = length(cell);
	float aa = max(length(fwidth(p / 0.05)), 0.015);
	float hole = 1.0 - smoothstep(0.075 - aa, 0.075 + aa, radius);
	float border = 1.0 - smoothstep(0.095 - aa, 0.095 + aa, radius);
	float interior = (1.0 - smoothstep(1.20, 1.22, abs(p.x)))
		* (1.0 - smoothstep(0.475, 0.495, abs(p.y)));
	float resolved = 1.0 - smoothstep(0.35, 0.8, aa);
	hole *= interior * resolved;
	border *= interior * resolved;
	vec3 paint = vec3(0.17, 0.20, 0.185);
	paint = mix(paint, vec3(0.26, 0.28, 0.26), border * 0.5);
	ALBEDO = mix(paint, vec3(0.023, 0.028, 0.025), hole);
	METALLIC = 0.35 * (1.0 - hole);
	ROUGHNESS = mix(0.66, 0.94, hole);
}
