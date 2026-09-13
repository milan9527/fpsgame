shader_type spatial;

uniform sampler2D ground_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap, repeat_enable;
uniform vec4 ground_tint : source_color = vec4(0.48, 0.48, 0.48, 1.0);
uniform vec4 rock_tint : source_color = vec4(0.65, 0.65, 0.63, 1.0);

varying vec3 terrain_position;
varying vec3 terrain_normal;

void vertex() {
	terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 triplanar_color(sampler2D map, vec3 position, vec3 weights) {
	return texture(map, position.zy).rgb * weights.x
		+ texture(map, position.xz).rgb * weights.y
		+ texture(map, position.xy).rgb * weights.z;
}

void fragment() {
	vec3 normal_world = normalize(terrain_normal);
	vec3 weights = pow(abs(normal_world), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	// Broad scan variation breaks up a perfectly uniform slope threshold.
	float patch = dot(texture(ground_map, terrain_position.xz * 0.011).rgb, vec3(0.333333));
	float exposed = smoothstep(0.12, 0.42, 1.0 - abs(normal_world.y) + (patch - 0.15) * 0.2);
	vec3 soil = triplanar_color(ground_map, terrain_position * 0.12, weights) * ground_tint.rgb;
	vec3 rock = triplanar_color(rock_map, terrain_position * 0.16, weights) * rock_tint.rgb;
	ALBEDO = mix(soil, rock, exposed);
	ROUGHNESS = mix(0.96, clamp(triplanar_color(rock_roughness, terrain_position * 0.16, weights).r, 0.65, 1.0), exposed);
	SPECULAR = 0.25;
	// Add small surface perturbations to the geometric normal, preserving the
	// smooth terrain slope rather than replacing it with projection-axis normals.
	vec2 nx = texture(rock_normal, terrain_position.zy * 0.16).rg * 2.0 - 1.0;
	vec2 ny = texture(rock_normal, terrain_position.xz * 0.16).rg * 2.0 - 1.0;
	vec2 nz = texture(rock_normal, terrain_position.xy * 0.16).rg * 2.0 - 1.0;
	vec3 detail = vec3(0.0, nx.y, nx.x) * weights.x
		+ vec3(ny.x, 0.0, ny.y) * weights.y
		+ vec3(nz.x, nz.y, 0.0) * weights.z;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(normal_world + detail * exposed * 0.22), 0.0)).xyz);
}
