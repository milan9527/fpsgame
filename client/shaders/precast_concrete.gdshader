shader_type spatial;
render_mode cull_disabled;

uniform sampler2D concrete_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 cast_position;
varying vec3 cast_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	cast_position = VERTEX;
	cast_normal = NORMAL;
}

void fragment() {
	// Metric triplanar projection also covers the bore and annular end faces.
	// The old diagonal UV projection collapsed parts of the circular surface.
	// Fourth-power triplanar weights use multiplies, avoiding general pow.
	vec3 squared_normal = world_normal * world_normal;
	vec3 weights = squared_normal * squared_normal;
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 p = world_position * 1.5;
	vec3 scan = texture(concrete_texture, p.zy).rgb * weights.x
		+ texture(concrete_texture, p.xz).rgb * weights.y
		+ texture(concrete_texture, p.xy).rgb * weights.z;
	float aggregate = dot(scan, vec3(0.2126, 0.7152, 0.0722));
	float ground_stain = 1.0 - smoothstep(0.12, 0.7, world_position.y);
	// Centimetre aggregate and broad mottling remain independent of mesh UVs.
	float grain = texture(concrete_texture, p.xy * 9.0).r * weights.z
		+ texture(concrete_texture, p.zy * 9.0).r * weights.x
		+ texture(concrete_texture, p.xz * 9.0).r * weights.y;
	float seam = 1.0 - smoothstep(0.012, 0.035, abs(abs(cast_position.z) - 1.52));
	// Rain carries mineral fines down the sides; elongated texture projection
	// gives metre-scale runoff independent of the centimetre aggregate.
	float runoff = texture(concrete_texture, world_position.xz * 1.8 + vec2(world_position.y * 0.09)).r;
	float weather = texture(concrete_texture, world_position.xz * 0.37 + vec2(world_position.y * 0.21)).r;
	float side = 1.0 - smoothstep(0.35, 0.92, abs(world_normal.y));
	float streak = smoothstep(0.32, 0.65, runoff) * side;
	ALBEDO = vec3(0.235, 0.228, 0.205) * (0.64 + 0.70 * aggregate);
	ALBEDO *= (0.88 + 0.24 * grain) * (1.0 - 0.24 * ground_stain);
	ALBEDO *= mix(0.78, 1.10, weather);
	ALBEDO *= vec3(1.0) - vec3(0.21, 0.195, 0.24) * streak;
	ALBEDO *= 1.0 - 0.13 * seam;
	// A real open bore: reduce indirect illumination toward its middle,
	// leaving the annular faces and both openings exposed to the sky.
	float bore = 1.0 - step(0.0, dot(cast_normal.xy, cast_position.xy));
	float bore_depth = 1.0 - smoothstep(0.4, 1.8, abs(cast_position.z));
	AO = 1.0 - bore * bore_depth * 0.72;
	AO_LIGHT_AFFECT = 0.0;
	// Preserve smooth cast curvature; avoid tangent-space normals on a mesh
	// with independent flat annular faces and no generated tangent basis.
	ROUGHNESS = 0.94;
	SPECULAR = 0.2;
}
