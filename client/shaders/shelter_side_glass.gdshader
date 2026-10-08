shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
varying vec2 pane_position;
void vertex() {
	pane_position = VERTEX.zy;
}
void fragment() {
	float bottom = 1.0 - smoothstep(-0.405, -0.24, pane_position.y);
	float edge = smoothstep(0.93, 1.11, abs(pane_position.x));
	float streak = pow(0.5 + 0.5 * sin(pane_position.x * 83.0 + sin(pane_position.x * 29.0)), 8.0);
	float dirt = clamp(bottom * 0.65 + edge * 0.35 + streak * bottom * 0.3, 0.0, 1.0);
	ALBEDO = mix(vec3(0.10, 0.15, 0.14), vec3(0.20, 0.18, 0.13), dirt);
	ROUGHNESS = mix(0.13, 0.68, dirt);
	SPECULAR = 0.35;
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 4.0);
	ALPHA = clamp(0.08 + dirt * 0.48 + fresnel * 0.32, 0.0, 0.85);
}
