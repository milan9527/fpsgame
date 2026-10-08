shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// A transparent ocular surface, not a second camera or a second ballistic dot.
// Leave the center open so the HUD's authoritative aiming point remains readable.
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float aa = max(fwidth(p.x), fwidth(p.y));
	float edge = smoothstep(0.70, 0.99, r);
	float horizontal = 1.0 - smoothstep(0.003, 0.003 + aa, abs(p.y));
	float vertical = 1.0 - smoothstep(0.003, 0.003 + aa, abs(p.x));
	float open_center = smoothstep(0.12, 0.14, r);
	float lines = max(horizontal, vertical) * open_center;
	float ticks = 0.0;
	for (int i = 1; i <= 4; i++) {
		float interval = float(i) * 0.16;
		float tick = 1.0 - smoothstep(0.003, 0.003 + aa, abs(abs(p.x) - interval));
		ticks = max(ticks, tick * (1.0 - smoothstep(0.025, 0.025 + aa, abs(p.y))));
		float drop_tick = 1.0 - smoothstep(0.003, 0.003 + aa, abs(p.y - interval));
		ticks = max(ticks, drop_tick * (1.0 - smoothstep(0.04, 0.04 + aa, abs(p.x))));
	}
	float etching = max(lines, ticks);
	float coating = 0.035 + 0.10 * pow(r, 3.0);
	ALBEDO = mix(vec3(0.12, 0.23, 0.27), vec3(0.012, 0.018, 0.019), max(edge, etching));
	ALPHA = max(coating + edge * 0.72, etching * 0.85);
}
