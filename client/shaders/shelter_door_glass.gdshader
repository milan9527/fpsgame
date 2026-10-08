shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

varying vec2 pane_position;
void vertex() {
	pane_position = VERTEX.xy;
}
void fragment() {
	vec2 p = pane_position;
	float grime = smoothstep(0.15, 0.95, 0.5 + 0.24 * sin(p.x * 23.0 + sin(p.y * 8.0)) + 0.23 * sin(p.y * 15.0));
	float edge_dirt = smoothstep(0.48, 0.64, abs(p.x));
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 4.0);
	// Embedded safety wire uses derivatives so distant panes do not shimmer.
	vec2 diagonal = vec2(p.x + p.y, p.x - p.y) * 24.0;
	vec2 cell = abs(fract(diagonal + 0.5) - 0.5);
	vec2 aa = max(fwidth(diagonal), vec2(0.001));
	vec2 wires = 1.0 - smoothstep(vec2(0.018), vec2(0.018) + aa, cell);
	float wire = max(wires.x, wires.y) * (1.0 - smoothstep(0.3, 0.8, max(aa.x, aa.y)));
	ALBEDO = mix(mix(vec3(0.19, 0.24, 0.23), vec3(0.31, 0.29, 0.23), grime * 0.3 + edge_dirt * 0.4), vec3(0.07), wire);
	ROUGHNESS = 0.20 + grime * 0.30 + edge_dirt * 0.15;
	SPECULAR = 0.65;
	ALPHA = clamp(0.07 + grime * 0.09 + edge_dirt * 0.28 + fresnel * 0.30 + wire * 0.6, 0.0, 0.8);
}
