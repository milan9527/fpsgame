shader_type spatial;
varying vec3 world_position;

float hash_patch(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float weather(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_patch(i), hash_patch(i + vec2(1.0, 0.0)), f.x),
		mix(hash_patch(i + vec2(0.0, 1.0)), hash_patch(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Metre-based vertical sheet ribs: BoxMesh UVs previously stretched the
	// roof's horizontal corrugation across each entire parked door.
	float x = world_position.x;
	float y = world_position.y;
	float rib = pow(0.5 + 0.5 * cos(x * 6.283185 / 0.14), 8.0);
	float resolved = 1.0 - smoothstep(0.025, 0.09, fwidth(x));
	rib = mix(0.196, rib, resolved);
	float streak = sin(x * 37.0 + sin(x * 11.0)) * 0.5 + 0.5;
	float dirt = (1.0 - smoothstep(0.1, 0.85 + streak * 0.5, y)) * 0.55;
	// Broad faded upper enamel above a dark, washable lower kick zone.
	float lower = 1.0 - smoothstep(1.00, 1.025, y);
	float fade = 0.5 + 0.5 * sin(x * 2.1 + sin(y * 1.6));
	vec3 enamel = mix(vec3(0.43, 0.425, 0.365), vec3(0.55, 0.53, 0.455), fade);
	vec3 paint = mix(enamel, vec3(0.12, 0.18, 0.165), lower) * (0.93 - rib * 0.20);
	// Rain follows the vertical channels; broad pigment loss stays readable
	// from the yard, while the smaller chips appear only at the entrance.
	float runoff = smoothstep(0.51, 0.78, weather(vec2(x * 19.0, y * 0.65)));
	runoff *= smoothstep(0.6, 2.9, y) * (0.5 + rib * 0.5);
	float worn_band = 1.0 - smoothstep(0.04, 0.24, abs(y - 1.01));
	float patches = weather(vec2(x * 53.0, y * 31.0));
	float chips = smoothstep(0.66, 0.83, patches) * max(worn_band, dirt);
	paint = mix(paint, enamel * 0.62, chips * 0.65);
	paint *= 1.0 - runoff * 0.29;
	float drip = smoothstep(0.63, 0.83, weather(vec2(x * 87.0, y * 0.8)));
	paint *= 1.0 - drip * smoothstep(0.3, 2.4, y) * 0.18;
	float rust = smoothstep(0.67, 0.85, patches) * (worn_band * 0.6 + dirt);
	// Large, irregular enamel failures at the lower sheet edges read at
	// normal approach distance; fine chips alone disappeared in the yard.
	float corrosion_field = weather(vec2(x * 5.1, y * 8.0))
		+ weather(vec2(x * 17.0, y * 21.0)) * 0.22;
	float edge_decay = 1.0 - smoothstep(0.08, 0.65, y);
	float seam_decay = (1.0 - smoothstep(0.015, 0.10, abs(y - 1.01))) * 0.42;
	float peeled = smoothstep(0.49, 0.68, corrosion_field) * max(edge_decay, seam_decay);
	paint = mix(paint, vec3(0.19, 0.105, 0.055), peeled * 0.88);
	float chalk = weather(vec2(x * 3.8, y * 2.6));
	paint *= mix(0.86, 1.08, chalk);
	ALBEDO = mix(mix(paint, vec3(0.10, 0.085, 0.06), dirt),
		vec3(0.22, 0.105, 0.043), rust * 0.6);
	ROUGHNESS = mix(0.76, 0.96, max(dirt, chips));
	SPECULAR = 0.25;
	// World-aligned bump gradients preserve correct shading on both faces
	// of each parked panel without relying on stretched BoxMesh tangents.
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 across_x = cross(dpdy, NORMAL);
	vec3 across_y = cross(NORMAL, dpdx);
	float determinant = dot(dpdx, across_x);
	float height = rib * 0.009;
	vec3 gradient = sign(determinant) * (dFdx(height) * across_x + dFdy(height) * across_y);
	NORMAL = normalize(abs(determinant) * NORMAL - gradient);
}
