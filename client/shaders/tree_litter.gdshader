shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 point;
void vertex() { point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float edge = length(p) + 0.10 * sin(point.x * 3.1) * sin(point.y * 2.7);
	vec3 earth = texture(soil, point * 0.65).rgb;
	float needle = sin(point.x * 31.0 + point.y * 47.0) * sin(point.y * 29.0);
	ALBEDO = earth * vec3(0.46, 0.35, 0.23) + vec3(0.018, 0.012, 0.004) * needle;
	ALPHA = (1.0 - smoothstep(0.35, 0.95, edge)) * 0.78;
	ROUGHNESS = 1.0;
	SPECULAR = 0.12;
}
