shader_type spatial;
uniform float exposed_brick_height = 0.0;
uniform float reclaimed_variation = 0.0;
uniform float aged_plinth_render = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
	float horizontal = abs(world_normal.z) > 0.5 ? world_position.x : world_position.z;
	vec2 surface = vec2(horizontal, world_position.y);
	float footprint = max(fwidth(horizontal), fwidth(world_position.y));
	// Once subpixel grain has fully faded, its four noise hashes cannot
	// affect any layer. Keep derivatives outside this fragment branch.
	float grain = 0.5;
	if (footprint < 0.014) {
		grain = mix(0.5, noise(surface * 110.0), 1.0 - smoothstep(0.003, 0.014, footprint));
	}
	// Above the maximum damp height both noises have zero color weight.
	float rising_damp = 0.0;
	float streak = 0.0;
	if (world_position.y < 0.83) {
		rising_damp = 1.0 - smoothstep(0.08, 0.45 + noise(vec2(horizontal * 2.1, 3.0)) * 0.38, world_position.y);
		// The local damp edge can end below 0.83; dry fragments have
		// zero streak weight and need no additional four-hash sample.
		if (rising_damp > 0.0) {
			streak = noise(vec2(horizontal * 8.0, world_position.y * 0.7));
		}
	}
	// Disconnected impact/spall patches leave render extending to the ground.
	// Dampness is independent of missing render: no continuous sawtooth hem.
	// Fully exposed brick above splash height uses neither chip nor lime.
	// Cement can restore a coating at any height, so keep its warp intact.
	vec2 erosion_warp = vec2(0.0);
	if (world_position.y < 0.62 || aged_plinth_render != 0.0
			|| exposed_brick_height < 0.001 || world_position.y > exposed_brick_height) {
		erosion_warp = vec2(noise(surface * 9.7 + 19.0),
			noise(surface * 11.3 - 7.0)) - 0.5;
	}
	// Above splash height spall has zero weight. Cement remnants still use
	// chip at all heights, while the lime layer still uses erosion_warp.
	float chip = 0.0;
	if (world_position.y < 0.62 || aged_plinth_render != 0.0) {
		chip = noise(surface * vec2(17.0, 23.0) + erosion_warp * 1.4);
	}
	float spall = 0.0;
	if (world_position.y < 0.62) {
		float clusters = noise(surface * vec2(2.7, 4.3) + vec2(41.0, 9.0));
		float splash_zone = 1.0 - smoothstep(0.12, 0.62, world_position.y);
		spall = smoothstep(0.61 - footprint, 0.69 + footprint,
			clusters * 0.78 + chip * 0.22) * splash_zone;
	}
	float render_mask = 1.0 - spall;
	// Optional exposed courses on the shelter plinth; other walls retain render.
	render_mask *= mix(1.0, smoothstep(exposed_brick_height, exposed_brick_height + 0.06, world_position.y), step(0.001, exposed_brick_height));
	// Bare brick has zero coating weight. Cement may restore that weight,
	// so retain every coating calculation when its uniform is enabled.
	vec3 lime = vec3(0.0);
	if (render_mask != 0.0 || aged_plinth_render != 0.0) {
		float lime_variation = noise(surface * 1.8 + erosion_warp);
		lime = mix(vec3(0.235, 0.235, 0.202), vec3(0.34, 0.325, 0.278),
			lime_variation);
		lime *= 0.94 + grain * 0.10;
		// Shelter limewash over a washable mineral-green dado. The same coating
		// wraps jambs and side walls; exposed foundation courses remain brick.
		float shelter_finish = step(0.1, exposed_brick_height);
		float dado = 1.0 - smoothstep(1.18, 1.20, world_position.y);
		vec3 coating = mix(vec3(0.46, 0.405, 0.30), vec3(0.13, 0.205, 0.175), dado);
		coating *= 0.88 + lime_variation * 0.18;
		lime = mix(lime, coating, shelter_finish * 0.88);
		// Sparse drainage marks, broken by broad dry areas. Do not bend every
		// narrow streak with high-frequency erosion: it reads as striped wallpaper.
		float drainage = noise(vec2(horizontal * 1.3 + 37.0, world_position.y * 0.35));
		float wet_patch = smoothstep(0.56, 0.79, drainage);
		// Both coatings multiply rain by wet_patch; dry areas need no rain sample.
		float rain = 0.0;
		if (wet_patch > 0.0) {
			rain = noise(vec2(horizontal * 12.7,
				world_position.y * 0.48 + 13.0));
		}
		lime *= 1.0 - smoothstep(0.58, 0.83, rain) * wet_patch * 0.16;
		// Coherent remnants of cement render, with exposed courses around broken
		// edges. World-space mapping keeps the damage continuous across the pier.
		// Uniform branch: ordinary walls do not evaluate the optional cement layer.
		// Keep fractional strengths and all enabled-layer calculations unchanged.
		if (aged_plinth_render != 0.0) {
			float remnant = noise(surface * vec2(1.55, 2.2) + vec2(8.0, 23.0));
			float render_edge = remnant * 0.74 + chip * 0.12
				+ smoothstep(0.18, 0.95, world_position.y) * 0.30;
			float old_render = smoothstep(0.43 - footprint, 0.47 + footprint, render_edge);
			render_mask = mix(render_mask, old_render, aged_plinth_render);
			vec3 cement = mix(vec3(0.18, 0.175, 0.145), vec3(0.28, 0.265, 0.22),
				noise(surface * 2.8 + erosion_warp * 0.4));
			cement *= (0.94 + grain * 0.12) * (1.0 - wet_patch * rain * 0.18);
			lime = mix(lime, cement, aged_plinth_render);
		}
	}
	// Fully covered bricks have zero color weight. The footprint derivatives
	// stay outside this branch; retain bricks wherever render is broken.
	vec3 base = lime;
	vec2 cell = vec2(0.0);
	vec2 edge = vec2(0.0);
	if (render_mask != 1.0) {
		// Covered render uses neither brick color nor mortar relief.
		// Compute the course grid only after the final coating mask is known.
		float row = floor(world_position.y / 0.085);
		vec2 courses = vec2(horizontal / 0.24 + mod(row, 2.0) * 0.5, world_position.y / 0.085);
		cell = fract(courses);
		edge = min(cell, 1.0 - cell) * vec2(0.24, 0.085);
		float erosion = noise(surface * 45.0);
		float brick = smoothstep(0.002 - footprint, 0.006 + footprint,
			min(edge.x, edge.y) + (erosion - 0.5) * 0.003);
		float variation = hash(floor(courses));
		vec3 clay = mix(vec3(0.235, 0.123, 0.074), vec3(0.29, 0.164, 0.103), variation);
		clay *= 0.87 + grain * 0.23;
		// Kiln-fired batches include occasional pale and dark reclaimed bricks.
		clay = mix(clay, mix(vec3(0.105, 0.077, 0.053), vec3(0.40, 0.27, 0.15), variation), reclaimed_variation);
		float salt = smoothstep(0.60, 0.82, noise(surface * 5.0)) * (1.0 - rising_damp) * 0.3;
		base = mix(vec3(0.145, 0.133, 0.109), clay, brick);
		base = mix(base, vec3(0.28, 0.26, 0.21), salt);
		base *= 0.91 + noise(surface * 2.7) * 0.12;
		base = mix(base, lime, render_mask);
	}
	// Soil splash at the footing varies in height and breaks across dry patches.
	float soil_contact = 0.0;
	// Noise stays in [0, 1], so soil cannot reach above 0.36 m.
	// Skip both four-hash samples where the original blend is exactly zero.
	if (world_position.y < 0.36) {
		float soil_height = mix(0.10, 0.36, noise(vec2(horizontal * 2.1, 17.0)));
		soil_contact = 1.0 - smoothstep(0.025, soil_height, world_position.y);
		// Above the local splash height, the dry-patch sample has no color weight.
		if (soil_contact > 0.0) {
			soil_contact *= mix(0.35, 0.80, noise(surface * 7.0));
		}
	}
	base = mix(base, base * vec3(0.55, 0.52, 0.40), soil_contact);
	ALBEDO = mix(base, base * vec3(0.50, 0.57, 0.48), rising_damp * (0.65 + streak * 0.35));
	// Recessed mortar bevels; fade below pixel size to avoid distant glitter.
	// Covered render and fully faded mortar have exactly zero relief.
	// footprint was evaluated unconditionally above, outside divergent flow.
	vec3 normal_relief = vec3(0.0);
	if (render_mask != 1.0 && footprint < 0.025) {
		vec2 bevel = (1.0 - smoothstep(vec2(0.004), vec2(0.011), edge))
			* smoothstep(vec2(0.001), vec2(0.004), edge) * sign(cell - 0.5);
		vec3 horizontal_axis = abs(world_normal.z) > 0.5 ? vec3(1, 0, 0) : vec3(0, 0, 1);
		vec3 relief = horizontal_axis * bevel.x + vec3(0, 1, 0) * bevel.y;
		normal_relief = mat3(VIEW_MATRIX) * relief * 0.65 * (1.0 - render_mask)
			* (1.0 - smoothstep(0.004, 0.025, footprint));
	}
	NORMAL = normalize(NORMAL + normal_relief);
	ROUGHNESS = 0.94;
	SPECULAR = 0.15;
}
