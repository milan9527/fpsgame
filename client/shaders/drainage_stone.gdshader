shader_type spatial;
varying vec3 position_world;
varying vec3 normal_world;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 stone_color : source_color = vec4(0.29, 0.28, 0.24, 1.0);
float mineral_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float grain(vec3 p) {
	vec3 i = floor(p), f = smoothstep(vec3(0.0), vec3(1.0), fract(p));
	float bottom = mix(mix(mineral_hash(i), mineral_hash(i + vec3(1,0,0)), f.x),
		mix(mineral_hash(i + vec3(0,0,1)), mineral_hash(i + vec3(1,0,1)), f.x), f.z);
	float top = mix(mix(mineral_hash(i + vec3(0,1,0)), mineral_hash(i + vec3(1,1,0)), f.x),
		mix(mineral_hash(i + vec3(0,1,1)), mineral_hash(i + vec3(1,1,1)), f.x), f.z);
	return mix(bottom, top, f.y);
}
void vertex() { position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
	float mottling = grain(position_world * 8.0);
	float damp = 1.0 - smoothstep(0.08, 0.43, position_world.y);
	ALBEDO = stone_color.rgb * (0.77 + 0.3 * mottling) * (1.0 - damp * 0.25);
	// Even integer power: preserve triplanar blending without a general pow.
	vec3 weights = normal_world * normal_world;
	weights *= weights;
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 rock = texture(rock_texture, position_world.zy * 2.3).rgb * weights.x
		+ texture(rock_texture, position_world.xz * 2.3).rgb * weights.y
		+ texture(rock_texture, position_world.xy * 2.3).rgb * weights.z;
	float relief = dot(rock, vec3(0.3333));
	ALBEDO *= 0.72 + relief * 1.15;
	// Fine mineral relief affects lighting without a shiny varnish response.
	vec3 surface_normal = NORMAL;
	vec3 dpdx = dFdx(position_world);
	vec3 dpdy = dFdy(position_world);
	// Fade subpixel mineral bumps while retaining the mipmapped stone relief.
	// Compare squared lengths first: one square root, identical fade distances.
	float footprint = sqrt(max(dot(dpdx, dpdx), dot(dpdy, dpdy)));
	float micro_visibility = 1.0 - smoothstep(0.003, 0.012, footprint);
	float detail = relief * 0.007;
	// Avoid eight noise hashes once mineral bumps contribute zero.
	if (micro_visibility > 0.0) {
		detail += grain(position_world * 110.0) * 0.0015 * micro_visibility;
	}
	vec3 view_dx = (VIEW_MATRIX * vec4(dpdx, 0.0)).xyz;
	vec3 view_dy = (VIEW_MATRIX * vec4(dpdy, 0.0)).xyz;
	vec3 r1 = cross(view_dy, surface_normal);
	vec3 r2 = cross(surface_normal, view_dx);
	float determinant = dot(view_dx, r1);
	vec3 gradient = sign(determinant) * (dFdx(detail) * r1 + dFdy(detail) * r2);
	NORMAL = normalize(abs(determinant) * surface_normal - gradient);
	// Earth caught in the low shoulders ties the retaining bank to its soil.
	float earth = 0.0;
	// Grain is nonnegative, so surfaces above this edge cannot collect earth.
	if (position_world.y < 0.22) {
		earth = (1.0 - smoothstep(0.02, 0.22, position_world.y + grain(position_world * 14.0) * 0.12)) * 0.65;
	}
	ALBEDO = mix(ALBEDO, vec3(0.16, 0.135, 0.095), earth);
	ROUGHNESS = 0.96;
	SPECULAR = 0.18;
}
