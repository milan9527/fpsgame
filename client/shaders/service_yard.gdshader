shader_type spatial;
render_mode cull_disabled;

uniform sampler2D concrete : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 half_extent;
uniform vec2 yard_center;
uniform bool parking = true;
varying vec2 local;
varying vec2 world;

float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 k = vec2(127.1, 311.7);
	return mix(mix(fract(sin(dot(i, k)) * 43758.5453),
		fract(sin(dot(i + vec2(1, 0), k)) * 43758.5453), f.x),
		mix(fract(sin(dot(i + vec2(0, 1), k)) * 43758.5453),
		fract(sin(dot(i + vec2(1, 1), k)) * 43758.5453), f.x), f.y);
}

void vertex() {
	local = VERTEX.xz - yard_center;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Rounded worn corners and metre-scale erosion replace the rectangular
	// overlay silhouette. Keep the connector's travelled centre intact.
	float edge;
	float connector_offset = 0.0;
	if (parking) {
		vec2 q = abs(local) - half_extent;
		vec2 corner = q + vec2(2.4);
		edge = length(max(corner, vec2(0.0)))
			+ min(max(corner.x, corner.y), 0.0) - 2.4;
	} else {
		// The access is a pair of travelled gravel tracks, broadening into the
		// loading court; no concrete ribbon or straight transverse end cap.
		float along = clamp((world.x * sign(yard_center.x) - 8.0)
			/ max(half_extent.x * 2.0, 1.0), 0.0, 1.0);
		float bend = sin(along * 3.14159) * 0.8;
		float width = mix(1.65, 3.0, smoothstep(0.25, 1.0, along));
		// Reuse the centreline distance for both silhouette and compacted ruts.
		connector_offset = abs(local.y - bend);
		edge = connector_offset - width;
		edge = max(edge, abs(local.x) - half_extent.x);
	}
	// Erosion adds at most 1.24 m; dirt reaches at most 2.8 m inward
	// plus 0.06 m grain. Below -4.2 m both ramps are saturated for
	// every noise value, so none of these three noise samples contributes.
	float deposits = 0.5;
	if (edge > -4.2) {
		float erosion = (noise(world * 0.31) - 0.48) * 2.0
			+ (noise(world * 1.3) - 0.5) * 0.40;
		edge += erosion;
		deposits = noise(world * 0.53);
	}
	float extension = mix(0.1, 0.6, smoothstep(0.3, 0.82, deposits));
	float deposit_width = mix(0.8, 2.8, deposits * deposits);
	// Noise is in [0, 1]. Deep inside the yard, both edge ramps stay
	// saturated for its entire range; high-frequency grain cannot affect them.
	// Include a small guard beyond the coverage (0.075) and dirt (0.06) offsets.
	float grain = 0.5;
	if (edge > min(extension - 1.276, -deposit_width - 0.061)) {
		grain = noise(world * 17.0);
	}
	// Preserve mip gradients before discarding transparent erosion fragments.
	// Parking fringe fragments need no texture fetches or colour shading.
	// Keep implicit sampling on the connecting road to retain its mip behaviour.
	vec2 gravel_uv = world * 0.8;
	vec2 gravel_dx = dFdx(gravel_uv);
	vec2 gravel_dy = dFdy(gravel_uv);
	vec2 concrete_uv = world * 0.42;
	vec2 concrete_dx = dFdx(concrete_uv);
	vec2 concrete_dy = dFdy(concrete_uv);
	// Interior parking fragments have zero dirt for every grain value.
	// Evaluate gradients before branching so edge pixels retain mip selection.
	vec2 soil_uv = world * 0.5;
	vec2 soil_dx = dFdx(soil_uv);
	vec2 soil_dy = dFdy(soil_uv);
	float coverage = 1.0 - smoothstep(extension - 1.2, extension, edge + (grain - 0.5) * 0.15);
	if (parking && coverage <= 0.0) {
		discard;
	}
	vec3 stones;
	if (parking) {
		stones = textureGrad(gravel, gravel_uv, gravel_dx, gravel_dy).rgb * vec3(0.43, 0.43, 0.40);
	} else {
		stones = texture(gravel, gravel_uv).rgb * vec3(0.43, 0.43, 0.40);
	}
	vec3 earth = vec3(0.0);
	if (!parking) {
		earth = texture(soil, soil_uv).rgb * 0.52;
	} else if (edge > -deposit_width - 0.061) {
		earth = textureGrad(soil, soil_uv, soil_dx, soil_dy).rgb * 0.52;
	}
	vec3 cement = vec3(0.0);
	if (parking) {
		cement = textureGrad(concrete, concrete_uv, concrete_dx, concrete_dy).rgb * 0.44;
	}
	if (coverage <= 0.0) {
		discard;
	}
	// Loading lanes cross the connecting driveway, then turn along the facade.
	// Paired broad tyre paths interrupt edge deposits and the parking paint.
	float curve = 8.4 + 0.65 * sin(local.x * 0.18);
	float lane = abs(abs(local.y) - curve);
	float tracks = 1.0 - smoothstep(0.13, 0.36, abs(lane - 0.78));
	// Procedural wear has no contribution outside the tyre paths.
	if (tracks > 0.0) {
		tracks *= 0.65 + 0.35 * noise(vec2(world.x * 0.4, world.y * 7.0));
	}
	float traffic = 1.0 - smoothstep(1.2, 2.1, lane);
	float dirt = smoothstep(-deposit_width, 0.28, edge + (grain - 0.5) * 0.12)
		* (1.0 - traffic * 0.65);
	// Quiet concrete patches and compacted aggregate have different scales.
	vec3 base;
	if (parking) {
		base = mix(cement, stones, 0.12 + traffic * 0.24);
	} else {
		float rut = abs(connector_offset - 0.85);
		float compacted = 1.0 - smoothstep(0.22, 0.62, rut);
		base = mix(earth, stones, 0.38 + compacted * 0.40);
		base *= mix(1.0, 0.76, compacted);
	}
	base *= mix(0.88, 1.08, noise(world * 0.18));
	base = mix(base, base * 0.72, tracks * 0.65);
	base = mix(base, mix(stones, earth, 0.7), dirt);
	if (parking) {
		float x = abs(local.x);
		float stripe_distance = min(abs(x - 2.8), min(abs(x - 5.8), abs(x - 8.8)));
		float paint = (1.0 - smoothstep(0.022, 0.044, stripe_distance))
			* (1.0 - smoothstep(2.12, 2.2, abs(abs(local.y) - 9.5)));
		// Most fragments are outside the narrow parking stripes.
		if (paint > 0.0) {
			float wear = smoothstep(0.25, 0.6, noise(world * 24.0));
			paint *= wear * (1.0 - tracks * 0.9) * (1.0 - dirt);
			base = mix(base, vec3(0.48, 0.47, 0.31), paint * 0.72);
		}
	}
	ALBEDO = base;
	ROUGHNESS = 0.96;
	SPECULAR = 0.18;
	// Broken outer silhouette, never a constant-width brown border.
	ALPHA = coverage;
}
