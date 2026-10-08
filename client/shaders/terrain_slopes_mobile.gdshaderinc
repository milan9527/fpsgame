
uniform sampler2D ground_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap, repeat_enable;
uniform vec4 ground_tint : source_color = vec4(0.48, 0.48, 0.48, 1.0);
uniform vec4 rock_tint : source_color = vec4(0.49, 0.48, 0.44, 1.0);
// Enabled only for static chunks whose complete normal cone is covered.
#ifdef TERRAIN_COVERED_STATIC
const bool covered_only = true;
#else
uniform bool covered_only = false;
#endif
varying vec3 rock_position;
varying vec3 terrain_normal;
varying vec4 ground_coordinates;

void vertex() {
	// Linear texture coordinates interpolate exactly like world position.
	// Prepare the common scale per vertex instead of per covered pixel.
	rock_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.16;
	// Both ground texture coordinates are affine in world position.
	ground_coordinates = vec4(rock_position.xz * (0.011 / 0.16),
		rock_position.xz * (0.12 / 0.16));
	// Covered chunks never use this varying in the fragment stage. Keep the
	// general path for slopes and the MSAA fallback selected by the loader.
	terrain_normal = vec3(0.0, 1.0, 0.0);
	if (!covered_only) {
		terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	}
}

void fragment() {
	vec3 n = terrain_normal;
	// Scanned textures provide variation without per-pixel procedural geology.
	vec3 patch = texture(ground_map, ground_coordinates.xy).rgb;
	float variation = clamp(dot(patch, vec3(1.1)), 0.0, 1.0);
	vec2 soil_uv = ground_coordinates.zw;
	vec2 soil_dx = dFdx(soil_uv);
	vec2 soil_dy = dFdy(soil_uv);
	float exposed = 0.0;
	vec3 rock = vec3(0.0);
	if (!covered_only) {
		// Variation adds at most 0.075 to incline: |normalized(n).y| >=
		// 0.845 guarantees zero rock coverage. Use a conservative 0.846 bound
		// without normalizing, then retain the original calculation on slopes.
		// Most baked terrain is flat; its normal is otherwise unused below.
		if (n.y * n.y < (0.846 * 0.846) * dot(n, n)) {
			// Only incline needs a unit normal. Triplanar weights below are
			// homogeneous (n^4 / sum(n^4)), so retain the interpolated vector.
			float incline = 1.0 - abs(n.y) * inversesqrt(dot(n, n));
			exposed = smoothstep(0.23, 0.62, incline + (variation - 0.5) * 0.15);
		}
		// Covered slopes contribute no rock. Keep derivatives outside the varying
		// branch so exposed edges retain the original mip selection.
		vec3 rock_dx = dFdx(rock_position);
		vec3 rock_dy = dFdy(rock_position);
		if (exposed > 0.0) {
			vec3 weights = n * n;
			weights *= weights;
			float weight_sum = max(dot(weights, vec3(1.0)), 0.0001);
			// Axis-aligned slopes have zero contribution from one or two
			// projections. Keep every positive weight, including tiny values;
			// explicit gradients above remain valid across these branches.
			if (weights.x > 0.0) {
				rock += textureGrad(rock_map, rock_position.zy, rock_dx.zy, rock_dy.zy).rgb * weights.x;
			}
			if (weights.y > 0.0) {
				rock += textureGrad(rock_map, rock_position.xz, rock_dx.xz, rock_dy.xz).rgb * weights.y;
			}
			if (weights.z > 0.0) {
				rock += textureGrad(rock_map, rock_position.xy, rock_dx.xy, rock_dy.xy).rgb * weights.z;
			}
			// Covered pixels have no rock contribution. Keep its brightness
			// modulation with the existing exposed-only texture work. Normalize
			// the accumulated projections once, combining the common divisor
			// with brightness instead of dividing all three axis weights.
			rock *= rock_tint.rgb * (mix(0.78, 1.12, variation) / weight_sum);
		}
	}
	// Fully exposed rock has no soil contribution. Explicit gradients preserve
	// ground mip selection across the varying coverage boundary.
	vec3 covered = vec3(0.0);
	if (exposed < 1.0) {
		vec3 soil = textureGrad(ground_map, soil_uv, soil_dx, soil_dy).rgb * ground_tint.rgb;
		vec3 vegetation = mix(vec3(0.032, 0.060, 0.021), vec3(0.105, 0.105, 0.047), variation);
		float detail = clamp(dot(soil, vec3(1.0)), 0.55, 1.3);
		covered = vegetation * detail;
		// Dark patches have exactly zero soil blend. Their broad, low-frequency
		// regions can skip the cubic weight and RGB blend together.
		if (variation > 0.65) {
			covered = mix(covered, soil, smoothstep(0.65, 0.95, variation) * 0.4);
		}
	}
	ALBEDO = mix(covered, rock, exposed);
	ROUGHNESS = 0.94;
	SPECULAR = 0.25;
}
