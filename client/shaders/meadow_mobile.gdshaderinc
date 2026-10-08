// Mobile surfaces share world-space textures across road and terrain seams.
// Photographic detail replaces nested procedural noise in the fragment shader.
uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D colony_map : filter_linear, repeat_disable;
// Explicit gradients keep mip selection valid inside the road-edge branch.
void mobile_meadow_filtered(vec3 p, vec2 dx, vec2 dy, out vec3 color, out vec3 relief) {
	// Fade subpixel ground relief using its world-space pixel footprint. This
	// follows resolution and viewing angle, preserving close surface detail.
	// Beyond the fade, avoid normal-map reads altogether.
	float footprint_squared = max(dot(dx, dx), dot(dy, dy));
	// Only the transition needs a square root and interpolation; the close
	// and distant regions have constant weights.
	float relief_weight = 0.0;
	if (footprint_squared < 0.4 * 0.4) {
		relief_weight = 1.0;
		if (footprint_squared > 0.15 * 0.15) {
			relief_weight = 1.0 - smoothstep(0.15, 0.4, sqrt(footprint_squared));
		}
	}
	vec2 cover = textureGrad(colony_map, (p.xz + vec2(109.0)) / 218.0, dx / 218.0, dy / 218.0).rg;
	float mineral = 1.0 - smoothstep(0.49,0.67,cover.g);
	// Skip only zero-weight layers; retain both throughout the transition.
	// Gradients come from outside all branches, including the road blend.
	vec3 earth_color = vec3(0.0);
	vec3 earth_relief = vec3(0.5, 0.5, 1.0);
	if (mineral < 1.0) {
		vec3 earth = textureGrad(soil, p.xz * 0.24, dx * 0.24, dy * 0.24).rgb;
		float patch = textureGrad(soil, p.xz * 0.018, dx * 0.018, dy * 0.018).r;
		float vegetation = smoothstep(0.15, 0.75, cover.r);
		vec3 tint = mix(vec3(0.48,0.43,0.32),vec3(0.28,0.34,0.17),vegetation);
		earth_color = earth * tint * mix(0.85,1.15,patch);
		if (relief_weight > 0.0) {
			earth_relief = textureGrad(soil_normal,p.xz * 0.24,dx * 0.24,dy * 0.24).rgb;
		}
	}
	vec3 stone_color = vec3(0.0);
	vec3 stone_relief = vec3(0.5, 0.5, 1.0);
	if (mineral > 0.0) {
		stone_color = textureGrad(gravel,p.xz * 0.55,dx * 0.55,dy * 0.55).rgb * vec3(0.48,0.45,0.38);
		if (relief_weight > 0.0) {
			stone_relief = textureGrad(gravel_normal,p.xz * 0.55,dx * 0.55,dy * 0.55).rgb;
		}
	}
	color = mix(earth_color,stone_color,mineral);
	// Both layers use the same neutral normal and fade. Apply the fade once
	// after blending, and bypass both blends when the normal maps are skipped.
	relief = vec3(0.5, 0.5, 1.0);
	if (relief_weight > 0.0) {
		relief = mix(relief, mix(earth_relief,stone_relief,mineral), relief_weight);
	}
}
void mobile_meadow(vec3 p, out vec3 color, out vec3 relief) {
	mobile_meadow_filtered(p, dFdx(p.xz), dFdy(p.xz), color, relief);
}
