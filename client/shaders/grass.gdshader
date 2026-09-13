shader_type spatial;
render_mode cull_disabled;

uniform float fade_begin = 24.0;
uniform float fade_end = 48.0;
uniform float wind_strength = 0.025;

void vertex() {
	// MODEL_MATRIX includes each MultiMesh instance transform.
	vec3 root_world = MODEL_MATRIX[3].xyz;
	float distance_to_camera = distance(root_world.xz, CAMERA_POSITION_WORLD.xz);
	float visibility = 1.0 - smoothstep(fade_begin, fade_end, distance_to_camera);
	float height = max(VERTEX.y, 0.0);
	float phase = TIME * 1.4 + dot(root_world.xz, vec2(0.17, 0.11));
	VERTEX.x += sin(phase) * wind_strength * height;
	VERTEX.z += cos(phase * 0.73) * wind_strength * height;
	// Collapse to the root instead of alpha blending thousands of grass layers.
	VERTEX *= visibility;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
