shader_type spatial;
render_mode cull_disabled;

// Aged, diffusing glass-reinforced roof sheet, UV measured in metres.
// Opaque diffusion avoids transparency sorting against the curved steel roof.
void fragment() {
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	float ribs = 0.5 + 0.5 * cos(UV.y * 31.4159);
	float dirt = 0.5 + 0.5 * sin(UV.x * 3.7 + sin(UV.y * 19.0));
	float fibers = sin(UV.x * 155.0 + sin(UV.y * 211.0)) * 0.018;
	vec3 resin = mix(vec3(0.39, 0.46, 0.40), vec3(0.62, 0.67, 0.55), ribs * 0.45);
	ALBEDO = resin * (0.91 + dirt * 0.09) + fibers;
	ROUGHNESS = 0.66;
	SPECULAR = 0.3;
	// Small transmitted skylight term on the underside, never a bright lamp.
	EMISSION = FRONT_FACING ? vec3(0.0) : resin * 0.10;
}
