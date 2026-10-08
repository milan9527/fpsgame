shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float radius = 6.0;
uniform float density = 1.0;
uniform float age = 0.0;
varying vec3 world_position;
varying flat vec3 camera_offset;
varying flat float camera_distance_squared;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 center = MODEL_MATRIX[3].xyz;
	// Constant across the cloud: compute once per vertex rather than for
	// every translucent fragment. Flat interpolation preserves the value.
	camera_offset = INV_VIEW_MATRIX[3].xyz - center;
	camera_distance_squared = dot(camera_offset, camera_offset);
}
void fragment() {
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = normalize(world_position - camera);
	// The camera-to-center vector is uniform over this cloud, including
	// cameras inside it. Reuse the vertex result for all transparent pixels.
	vec3 offset = camera_offset;
	float b = dot(offset, ray);
	float disc = b * b - camera_distance_squared + radius * radius;
	if (disc <= 0.0) { discard; }
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float reach = sqrt(disc);
	float entry = max(0.0, -b - reach);
	// Test opaque occlusion in homogeneous squared distances first, so
	// fragments behind walls need no scene-distance square root or division.
	float scene_squared = dot(view_position.xyz, view_position.xyz);
	float entry_homogeneous = entry * abs(view_position.w);
	if (scene_squared < entry_homogeneous * entry_homogeneous) { discard; }
	float exit_distance = -b + reach;
	// Most visible cloud rays end before opaque geometry. Only reconstruct
	// scene distance when its homogeneous depth actually clips the cloud.
	float exit_homogeneous = max(0.0, exit_distance) * abs(view_position.w);
	if (scene_squared < exit_homogeneous * exit_homogeneous) {
		exit_distance = sqrt(scene_squared) / abs(view_position.w);
	}
	float thickness = max(0.0, exit_distance - entry);
	// Opaque geometry can end the ray before it reaches the cloud. Those
	// pixels contribute zero alpha; skip swirl and all eight density samples.
	if (thickness <= 0.0) { discard; }
	vec3 point = camera + ray * (entry + thickness * 0.5);
	float swirl = 0.92 + 0.08 * sin(point.x * 2.1 + age) * sin(point.y * 2.7 - age * 0.7) * sin(point.z * 2.3);
	ALBEDO = vec3(0.57, 0.61, 0.60) * swirl;
	float total = 0.0;
	// All eight midpoint samples share the same ray origin and spacing.
	vec3 sample_start = offset + ray * (entry + thickness / 16.0);
	vec3 sample_step = ray * (thickness / 8.0);
	// Squared distance along this segment is quadratic in the sample index.
	// Hoist its three dot products instead of reconstructing eight vectors.
	float sample_constant = dot(sample_start, sample_start);
	float sample_linear = 2.0 * dot(sample_start, sample_step);
	float sample_quadratic = dot(sample_step, sample_step);
	float core_radius = radius * 0.65;
	float core_squared = core_radius * core_radius;
	// Squared distance is convex along a ray: if both extreme midpoint
	// samples are in the constant-density core, all eight samples are.
	// This also covers short, opaque-depth-clipped rays inside the cloud.
	float last_sample_squared = sample_constant + 7.0 *
		(sample_linear + 7.0 * sample_quadratic);
	if (max(sample_constant, last_sample_squared) <= core_squared) {
		total = 8.0;
	} else {
		for (int i = 0; i < 8; i++) {
			float sample_index = float(i);
			float sample_squared = sample_constant + sample_index *
				(sample_linear + sample_index * sample_quadratic);
			// Density is exactly one inside the uniform core. Only the shell
			// needs a square root and cubic falloff; retain all eight samples.
			if (sample_squared <= core_squared) {
				total += 1.0;
			} else {
				total += 1.0 - smoothstep(core_radius, radius, sqrt(sample_squared));
			}
		}
	}
	ALPHA = clamp(1.0 - exp(-total / 8.0 * thickness * density), 0.0, 0.999);
}
