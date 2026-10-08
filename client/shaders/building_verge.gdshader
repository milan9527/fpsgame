shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world_point;
float patch_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 h = fract(sin(vec4(dot(i, vec2(127.1, 311.7)),
		dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7)),
		dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7)),
		dot(i + vec2(1.0), vec2(127.1, 311.7)))) * 43758.5453);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float broken_edge = sin(world_point.y * 1.7) * 0.10 + sin(world_point.x * 2.3 + world_point.y * 0.8) * 0.12;
	broken_edge += (patch_noise(world_point * 0.9) - 0.5) * 0.38;
	float coverage = (1.0 - smoothstep(0.32, 0.97, p.x + broken_edge))
		* (1.0 - smoothstep(0.70, 1.0, p.y));
	vec3 earth = texture(soil, world_point * 0.48).rgb;
	earth = mix(vec3(dot(earth, vec3(0.2126, 0.7152, 0.0722))), earth, 0.3);
	float organic = patch_noise(world_point * 1.6);
	ALBEDO = earth * mix(vec3(0.39, 0.38, 0.31), vec3(0.57, 0.55, 0.43), organic);
	ALPHA = coverage * 0.86;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
