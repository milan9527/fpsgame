shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float radius = 6.0;
uniform float density = 1.0;
uniform float age = 0.0;
varying vec3 world_position;
varying vec3 center;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	center = MODEL_MATRIX[3].xyz;
}
void fragment() {
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = normalize(world_position - camera);
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_distance = length(view_position.xyz / view_position.w);
	vec3 offset = camera - center;
	float b = dot(offset, ray);
	float disc = b * b - dot(offset, offset) + radius * radius;
	if (disc <= 0.0) { discard; }
	float reach = sqrt(disc);
	float entry = max(0.0, -b - reach);
	float exit_distance = min(scene_distance, -b + reach);
	float thickness = max(0.0, exit_distance - entry);
	vec3 point = camera + ray * (entry + thickness * 0.5);
	float swirl = 0.92 + 0.08 * sin(point.x * 2.1 + age) * sin(point.y * 2.7 - age * 0.7) * sin(point.z * 2.3);
	ALBEDO = vec3(0.57, 0.61, 0.60) * swirl;
	float total = 0.0;
	for (int i = 0; i < 8; i++) {
		vec3 sample_point = camera + ray * (entry + thickness * (float(i) + 0.5) / 8.0);
		total += 1.0 - smoothstep(radius * 0.65, radius, length(sample_point - center));
	}
	ALPHA = clamp(1.0 - exp(-total / 8.0 * thickness * density), 0.0, 0.999);
}
