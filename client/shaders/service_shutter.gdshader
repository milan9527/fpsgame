shader_type spatial;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float streak = sin(world_position.x * 47.0 + sin(world_position.x * 13.0));
	float stain = smoothstep(0.2, 0.95, streak) * (0.5 + 0.5 * sin(world_position.y * 4.0));
	float joint = pow(0.5 + 0.5 * cos(world_position.y * 78.5398), 12.0);
	joint *= 1.0 - smoothstep(0.015, 0.07, fwidth(world_position.y));
	vec3 finish = mix(vec3(0.39, 0.43, 0.40), vec3(0.52, 0.53, 0.46),
		0.5 + 0.5 * sin(world_position.x * 1.7 + world_position.y));
	ALBEDO = finish * (1.0 - stain * 0.18 - joint * 0.23);
	ROUGHNESS = 0.72 + stain * 0.16;
	METALLIC = 0.24;
}
