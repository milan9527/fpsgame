shader_type spatial;
render_mode cull_disabled;

uniform sampler2D gravel : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 half_extent = vec2(2.7, 5.5);
varying vec3 local_position;
varying vec3 world_position;

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
	local_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = abs(local_position.xz) - half_extent;
	float edge = length(max(q, vec2(0))) + min(max(q.x, q.y), 0.0);
	// Preserve texture derivatives across the coverage branch. These bounds
	// imply exactly zero original alpha for every possible noise value.
	vec2 ground_dx = dFdx(world_position.xz);
	vec2 ground_dy = dFdy(world_position.xz);
	if (edge < -0.30 || edge > 0.88 ||
		abs(local_position.z - 3.5) < 0.49 ||
		abs(local_position.z + 0.5) < 0.44) {
		discard;
	}
	// Deposits collect beside the slab, interrupted by the cross-yard traffic
	// routes. Metre-scale gaps and variable widths avoid an outlined rectangle.
	float deposit = noise(world_position.xz * 0.72);
	float gaps = smoothstep(0.36, 0.58, deposit);
	// Empty metre-scale patches need no fine breakup noise. Keep the same
	// smoothstep result for every fragment with nonzero coverage.
	if (gaps == 0.0) {
		discard;
	}
	float breakup = noise(world_position.xz * 6.0);
	float width = mix(0.08, 0.78, smoothstep(0.35, 0.8, deposit));
	float band = smoothstep(-0.22, -0.04, edge + breakup * 0.07);
	float fade = 1.0 - smoothstep(width * 0.25, width, edge + (breakup - 0.5) * 0.18);
	float traffic = smoothstep(0.5, 1.15, abs(local_position.z - 3.5))
		* smoothstep(0.45, 0.95, abs(local_position.z + 0.5));
	float coverage = band * fade * gaps * traffic;
	// Noise also creates empty patches inside the conservative bounds above.
	// Exact zero contributes no color; retain every partially covered fragment.
	if (coverage == 0.0) {
		discard;
	}
	vec3 stone = textureGrad(gravel, world_position.xz * 2.5, ground_dx * 2.5, ground_dy * 2.5).rgb;
	float soil_weight = smoothstep(0.0, 0.65, edge) * 0.8;
	ALBEDO = stone * vec3(0.48, 0.49, 0.46);
	// The inner deposit has exactly zero soil contribution. Keep explicit
	// gradients from before all branches so outer-edge mip selection is stable.
	if (soil_weight > 0.0) {
		vec3 dirt = textureGrad(soil, world_position.xz * 1.8, ground_dx * 1.8, ground_dy * 1.8).rgb;
		dirt = mix(vec3(dot(dirt, vec3(0.2126, 0.7152, 0.0722))), dirt, 0.28);
		ALBEDO = mix(ALBEDO, dirt * 0.62, soil_weight);
	}
	ROUGHNESS = 0.97;
	ALPHA = coverage;
}
