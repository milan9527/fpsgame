shader_type spatial;

uniform sampler2D ground_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap, repeat_enable;
uniform vec4 ground_tint : source_color = vec4(0.48, 0.48, 0.48, 1.0);
uniform vec4 rock_tint : source_color = vec4(0.49, 0.48, 0.44, 1.0);

varying vec3 terrain_position;
varying vec3 terrain_normal;

void vertex() {
	terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 triplanar_color(sampler2D map, vec3 position, vec3 weights) {
	// Keep derivatives outside divergent projection branches so mip selection
	// remains continuous at flat shelves and their sloping edges.
	vec3 dx = dFdx(position);
	vec3 dy = dFdy(position);
	vec3 color = vec3(0.0);
	if (weights.x > 0.0) {
		color += textureGrad(map, position.zy, dx.zy, dy.zy).rgb * weights.x;
	}
	if (weights.y > 0.0) {
		color += textureGrad(map, position.xz, dx.xz, dy.xz).rgb * weights.y;
	}
	if (weights.z > 0.0) {
		color += textureGrad(map, position.xy, dx.xy, dy.xy).rgb * weights.z;
	}
	return color;
}

float landscape_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec3 k = vec3(127.1, 311.7, 74.7);
	float a = fract(sin(dot(cell, k.xy)) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), k.xy)) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), k.xy)) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0), k.xy)) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 normal_world = normalize(terrain_normal);
	// Fourth-power projection weights need only two component-wise squares.
	vec3 weights = normal_world * normal_world;
	weights *= weights;
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	float incline = 1.0 - abs(normal_world.y);
	// Evaluate gradients before the slope branch to retain mip selection at edges.
	vec2 patch_uv = terrain_position.xz * 0.011;
	vec2 patch_dx = dFdx(patch_uv);
	vec2 patch_dy = dFdy(patch_uv);
	// Soil pockets survive on shoulders; exposed stone follows broken seams
	// instead of turning every moderately inclined hillside into pale rock.
	float seams = landscape_noise(terrain_position.xz * 0.075
		+ vec2(terrain_position.y * 0.045, 0.0));
	float exposed = 0.0;
	// Noise and the normalized ground image are bounded by 1: on shallow
	// slopes the largest input is 0.06 + 0.11 + 0.102 = 0.272, below 0.28.
	// Broad scan variation only needs sampling where it can expose stone.
	// On steep faces even the minimum input is 0.78 - 0.11 - 0.018
	// = 0.652, above the saturation edge. Preserve later foothill masking.
	if (incline >= 0.78) {
		exposed = 1.0;
	} else if (incline > 0.06) {
		float patch = dot(textureGrad(ground_map, patch_uv, patch_dx, patch_dy).rgb, vec3(0.333333));
		exposed = smoothstep(0.28, 0.65,
			incline + (seams - 0.5) * 0.22 + (patch - 0.15) * 0.12);
	}
	vec3 soil = triplanar_color(ground_map, terrain_position * 0.12, weights) * ground_tint.rgb;
	// Continuous world-space vegetation patches span adjacent ridge meshes.
	// Gentle slopes retain grass/scrub; steep cuts expose the scanned rock.
	float broad = landscape_noise(terrain_position.xz * 0.035);
	float scrub = landscape_noise(terrain_position.xz * 0.11 + vec2(broad * 2.0));
	vec3 vegetation = mix(vec3(0.032, 0.060, 0.021), vec3(0.095, 0.110, 0.043),
		smoothstep(0.25, 0.78, broad));
	vegetation *= mix(0.72, 1.12, scrub);
	float soil_detail = clamp(dot(soil, vec3(0.333333)) * 3.0, 0.55, 1.3);
	vec3 covered = vegetation * soil_detail;
	covered = mix(covered, soil, smoothstep(0.72, 0.95, scrub) * 0.45);
	// Sun-facing dry shoulders and darker drainage pockets create readable
	// land cover at hundreds of metres, without painting regular contour lines.
	float drainage = landscape_noise(terrain_position.xz * 0.019
		+ vec2(seams * 1.7, broad * 1.3));
	float dry_shoulder = smoothstep(0.42, 0.78, drainage)
		* smoothstep(0.05, 0.4, normal_world.x * 0.6 + normal_world.z * 0.8);
	covered = mix(covered, vec3(0.13, 0.115, 0.066) * soil_detail, dry_shoulder * 0.65);
	covered *= mix(0.72, 1.12, smoothstep(0.18, 0.8, drainage));
	// Broken rock outcrops cross the broad shoulders; fine sediment collects
	// below them. World-space masks remain continuous across ridge meshes.
	// Both ledge and sediment weights are zero on these shallow slopes.
	float outcrop = 0.0;
	if (incline > 0.06) {
		outcrop = landscape_noise(terrain_position.xz * 0.047
			+ vec2(seams * 2.4, terrain_position.y * 0.034));
	}
	float broken_ledge = smoothstep(0.46, 0.70, outcrop)
		* smoothstep(0.12, 0.37, incline);
	exposed = max(exposed, broken_ledge * 0.64);
	float sediment = smoothstep(0.34, 0.57, outcrop)
		* (1.0 - smoothstep(0.58, 0.75, outcrop))
		* smoothstep(0.06, 0.22, incline);
	covered = mix(covered, vec3(0.16, 0.142, 0.105) * soil_detail, sediment * 0.72);
	// Broad erosion scars follow slope and elevation, not the fine grass noise.
	// Their scale survives the normal gameplay camera and atmospheric haze.
	float scar_field = landscape_noise(terrain_position.xz * 0.012
		+ vec2(terrain_position.y * 0.018, seams * 0.25));
	float scar = smoothstep(0.51, 0.72, scar_field)
		* smoothstep(0.16, 0.38, incline);
	exposed = max(exposed, scar * 0.76);
	// Steep bed risers expose stone, while shelves keep darker vegetation.
	float bed_face = smoothstep(0.36, 0.64, incline);
	exposed = max(exposed, bed_face * 0.94);
	float dry_grass = smoothstep(0.42, 0.68, scar_field)
		* (1.0 - smoothstep(0.06, 0.24, incline));
	covered = mix(covered, vec3(0.105, 0.105, 0.047) * soil_detail, dry_grass * 0.62);
	// A shared wooded foothill belt joins the billboard groves to their soil.
	// Keep upper escarpments exposed rather than coating the entire mountain.
	float foothill = (1.0 - smoothstep(20.0, 48.0, terrain_position.y))
		* (1.0 - smoothstep(0.14, 0.38, incline));
	covered = mix(covered, vegetation * mix(0.78, 1.05, scrub), foothill * 0.55);
	exposed *= 1.0 - foothill * 0.40;
	// Connected outcrops follow oblique geology rather than horizontal contours.
	float geology = 0.0;
	// Escarpments have no contribution below either slope/elevation cutoff.
	if (incline > 0.18 && terrain_position.y > 12.0) {
		geology = landscape_noise(terrain_position.xz * 0.026
			+ vec2(terrain_position.y * 0.031, -terrain_position.y * 0.017));
	}
	float escarpment = smoothstep(0.46, 0.64, geology)
		* smoothstep(0.18, 0.42, incline) * smoothstep(12.0, 32.0, terrain_position.y);
	exposed = max(exposed, escarpment * 0.90);
	ALBEDO = covered;
	// Derivatives must be evaluated before the varying coverage branch so mip
	// selection stays defined at the boundary between vegetation and exposed rock.
	vec3 rock_uv = terrain_position * 0.16;
	vec3 rock_dx = dFdx(rock_uv);
	vec3 rock_dy = dFdy(rock_uv);
	ROUGHNESS = 0.96;
	SPECULAR = 0.25;
	// Add small surface perturbations to the geometric normal, preserving the
	// smooth terrain slope rather than replacing it with projection-axis normals.
	vec3 detail = vec3(0.0);
	if (exposed > 0.0) {
		// Rock color and its strata/fracture noise have no contribution under full cover.
		// Zero-weight projections contribute no color, roughness or normal detail.
		// Explicit gradients above keep mip selection defined across these branches.
		vec3 rock = vec3(0.0);
		float roughness = 0.0;
		if (weights.x > 0.0) {
			rock += textureGrad(rock_map, rock_uv.zy, rock_dx.zy, rock_dy.zy).rgb * weights.x;
			roughness += textureGrad(rock_roughness, rock_uv.zy, rock_dx.zy, rock_dy.zy).r * weights.x;
			vec2 projected_normal = textureGrad(rock_normal, rock_uv.zy, rock_dx.zy, rock_dy.zy).rg * 2.0 - 1.0;
			detail += vec3(0.0, projected_normal.y, projected_normal.x) * weights.x;
		}
		if (weights.y > 0.0) {
			rock += textureGrad(rock_map, rock_uv.xz, rock_dx.xz, rock_dy.xz).rgb * weights.y;
			roughness += textureGrad(rock_roughness, rock_uv.xz, rock_dx.xz, rock_dy.xz).r * weights.y;
			vec2 projected_normal = textureGrad(rock_normal, rock_uv.xz, rock_dx.xz, rock_dy.xz).rg * 2.0 - 1.0;
			detail += vec3(projected_normal.x, 0.0, projected_normal.y) * weights.y;
		}
		if (weights.z > 0.0) {
			rock += textureGrad(rock_map, rock_uv.xy, rock_dx.xy, rock_dy.xy).rgb * weights.z;
			roughness += textureGrad(rock_roughness, rock_uv.xy, rock_dx.xy, rock_dy.xy).r * weights.z;
			vec2 projected_normal = textureGrad(rock_normal, rock_uv.xy, rock_dx.xy, rock_dy.xy).rg * 2.0 - 1.0;
			detail += vec3(projected_normal.x, projected_normal.y, 0.0) * weights.z;
		}
		rock *= rock_tint.rgb;
		float strata = landscape_noise(vec2(terrain_position.x * 0.018
			+ terrain_position.z * 0.014, terrain_position.y * 0.095 + seams * 0.9));
		rock *= mix(0.65, 1.16, smoothstep(0.2, 0.8, strata));
		vec3 weathered_stone = mix(rock, vec3(0.11, 0.105, 0.088) * soil_detail, 0.55);
		rock = mix(rock, weathered_stone, scar);
		float fracture = landscape_noise(terrain_position.xz * 0.19
			+ vec2(terrain_position.y * 0.13, seams));
		rock *= mix(0.70, 1.08, smoothstep(0.23, 0.74, fracture));
		rock *= mix(0.78, 1.28, smoothstep(0.22, 0.72, strata));
		rock = mix(rock, vec3(0.19, 0.175, 0.142) * mix(0.8, 1.12, fracture), escarpment * 0.65);
		ALBEDO = mix(covered, rock, exposed);
		ROUGHNESS = mix(0.96, clamp(roughness, 0.65, 1.0), exposed);
	}
	// A direction's scale cancels in the final normalization, so normalize
	// only after transforming to view space (also covers non-unit detail).
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world + detail * exposed * 0.22, 0.0)).xyz);
}
