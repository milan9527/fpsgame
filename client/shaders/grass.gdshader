shader_type spatial;
render_mode cull_disabled;

uniform float fade_begin = 24.0;
uniform float fade_end = 48.0;
uniform float wind_strength = 0.025;
varying float blade_height;
#ifndef SHORT_GRASS
varying vec3 tip_delta;
#endif
varying flat vec3 sky_normal;

float colony_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float colony_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(colony_hash(i), colony_hash(i + vec2(1, 0)), f.x),
		mix(colony_hash(i + vec2(0, 1)), colony_hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	// MODEL_MATRIX includes each MultiMesh instance transform.
	vec3 root_world = MODEL_MATRIX[3].xyz;
	vec2 camera_offset = root_world.xz - CAMERA_POSITION_WORLD.xz;
	float distance_squared = dot(camera_offset, camera_offset);
	// Only the fade band needs a square root and smoothstep. Nearby roots
	// retain full size; distant roots retain the existing zero-size collapse.
	float visibility;
	if (fade_begin >= 0.0 && fade_end > fade_begin
			&& distance_squared <= fade_begin * fade_begin) {
		visibility = 1.0;
	} else if (fade_end > 0.0 && fade_end > fade_begin
			&& distance_squared >= fade_end * fade_end) {
		visibility = 0.0;
	} else {
		// Reuse the squared distance from the near/far checks in the fade band.
		float distance_to_camera = sqrt(distance_squared);
		visibility = 1.0 - smoothstep(fade_begin, fade_end, distance_to_camera);
	}
	// A patch can remain in view after some roots have fully faded. Those
	// vertices already collapse to zero; skip all their shading preparation.
	if (visibility > 0.0) {
		// Camera-space up and its blend weight are constant across a draw.
		// Prepare the normal blend ratio before shading overlapping pixels.
		// The camera view rotation is orthonormal; its second column is world up.
		// Factor the positive surface weight out of normalize(). This moves
		// three multiplications from every grass pixel to vertex preparation.
		sky_normal = VIEW_MATRIX[1].xyz * (0.82 / (1.0 - 0.82));
		vec2 tuft_variation = INSTANCE_CUSTOM.rg;
#ifndef SHORT_GRASS
		float tip_strength = 0.25 + tuft_variation.x * 0.40;
#endif
		blade_height = max(VERTEX.y, 0.0);
		float colony = smoothstep(0.2, 0.8, colony_noise(root_world.xz * 0.24) * 0.7 + colony_noise(root_world.xz * 0.73) * 0.3);
		float height = blade_height;
		// Ground contacts have zero displacement: avoid four trig evaluations
		// there while retaining the same bending and wind on every raised vertex.
		if (height > 0.0) {
			vec2 bend = fract(sin(vec2(dot(root_world.xz,vec2(12.9898,78.233)),
				dot(root_world.xz,vec2(39.346,11.135))))*43758.5453)*2.0-1.0;
			VERTEX.xz += bend * height * height * 0.65;
			float phase = TIME * 1.4 + dot(root_world.xz, vec2(0.17, 0.11));
			VERTEX.x += sin(phase) * wind_strength * height;
			VERTEX.z += cos(phase * 0.73) * wind_strength * height;
		}
		// Collapse to the root instead of alpha blending thousands of grass layers.
		// Fully sized tufts need no scaling. This condition is shared by all
		// vertices of an instance, like the distance branches above.
		if (visibility < 1.0) {
			VERTEX *= visibility;
		}
		// These colors are constant per instance. Fully faded instances have
		// no fragments, so their color products and normal are unnecessary.
		vec3 colony_tint = mix(vec3(0.79, 0.87, 0.72), vec3(1.22, 1.05, 0.77), colony);
		vec3 instance_tint = colony_tint * tuft_variation.y;
		vec3 base_tint = mix(vec3(0.74, 0.83, 0.62), vec3(1.02, 0.91, 0.65), tuft_variation.x);
#ifndef SHORT_GRASS
		vec3 tip_tint = vec3(1.12, 0.97, 0.70);
#endif
		// Both endpoints share colony/brightness modulation. Apply that
		// product once to the authored color, saving a vec3 multiplication
		// on every visible grass vertex without changing the noise or wind.
		COLOR.rgb *= instance_tint;
		// The scaled color difference is constant per tuft. Prepare it once
		// per vertex instead of subtracting and scaling on overlapping pixels.
		// Instance tint is constant across each triangle, so multiplying the
		// authored color here commutes with interpolation. Reuse COLOR for the
		// base and avoid a separate base-tint varying and fragment product.
#ifndef SHORT_GRASS
		tip_delta = COLOR.rgb * ((tip_tint - base_tint) * tip_strength);
#endif
		COLOR.rgb *= base_tint;
	} else {
		VERTEX = vec3(0.0);
		sky_normal = vec3(0.0, 1.0, 0.0);
		blade_height = 0.0;
		COLOR.rgb = vec3(0.0);
#ifndef SHORT_GRASS
		tip_delta = vec3(0.0);
#endif
	}
}

void fragment() {
	// Resolve both sides in view space: the renderer flips back-face normals
	// after vertex(), which used to point half the upward-bent normals down.
	vec3 surface_normal = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = normalize(surface_normal + sky_normal);
	// Spatially coherent dry colonies, with dark roots and sun-dried tips.
	// The short grass mesh is entirely below the dry-tip band; the other
	// meshes also have coherent root regions. Their tip contribution is
	// exactly zero, so skip the cubic gradient and color addition there.
	ALBEDO = COLOR.rgb;
	// The dry-tip gradient is exactly one above its upper edge. Avoid the
	// cubic and its color multiplication across that coherent leaf region.
#ifndef SHORT_GRASS
	if (blade_height >= 0.48) {
		ALBEDO += tip_delta;
		ALBEDO *= 1.06;
	} else if (blade_height > 0.16) {
		float tip = smoothstep(0.16, 0.48, blade_height);
		ALBEDO += tip_delta * tip;
		// Only this middle band can cross the root gradient's upper edge.
		// Tips and roots already have a known result from the outer branch.
		if (blade_height >= 0.25) {
			ALBEDO *= 1.06;
		} else {
			ALBEDO *= mix(0.72, 1.06, smoothstep(0.0, 0.25, blade_height));
		}
	} else {
#endif
		ALBEDO *= mix(0.72, 1.06, smoothstep(0.0, 0.25, blade_height));
#ifndef SHORT_GRASS
	}
#endif
	// glTF vertex colors store linear reflectance. Compatibility shades in
	// sRGB; match StandardMaterial's conversion instead of darkening it twice.
	if (OUTPUT_IS_SRGB) {
		// The three grass meshes with white instance colors and brightness
		// >= 0.8 have minimum red/green reflectance >= 0.00924/0.01794
		// after all tints. Only blue can enter the linear sRGB segment.
		// Keep conversion after interpolation to preserve blade gradients.
		vec3 encoded;
		encoded.rg = 1.055 * pow(ALBEDO.rg, vec2(1.0 / 2.4)) - 0.055;
		// Dark root/leaf regions use the linear blue segment. Do not evaluate
		// a discarded power there; keep the threshold and transfer unchanged.
		if (ALBEDO.b < 0.0031308) {
			encoded.b = 12.92 * ALBEDO.b;
		} else {
			encoded.b = 1.055 * pow(ALBEDO.b, 1.0 / 2.4) - 0.055;
		}
		ALBEDO = encoded;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
