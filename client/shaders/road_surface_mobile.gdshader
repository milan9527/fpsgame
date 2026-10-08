shader_type spatial;
#include "res://shaders/meadow_mobile.gdshaderinc"
uniform sampler2D pavement : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 ground_position;
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = ground_position.xz;
	vec2 dx = dFdx(p);
	vec2 dy = dFdy(p);
	float distance_to_axis = min(abs(p.x),abs(p.y));
	float edge = smoothstep(3.5,5.8,distance_to_axis);
	edge = max(edge,smoothstep(0.08,0.32,-ground_position.y));
	edge = max(edge,smoothstep(105.0,112.5,max(abs(p.x),abs(p.y))));
	float paint_distance = abs(distance_to_axis - 3.15);
	float aa = max(fwidth(paint_distance),0.008);
	// Fully covered shoulders and road ends contribute no pavement. Gradients
	// are computed before either material branch to preserve mip selection.
	vec3 asphalt = vec3(0.0);
	if (edge < 1.0) {
		asphalt = textureGrad(pavement,p * 0.25,dx * 0.25,dy * 0.25).rgb * 0.42;
		// Most pavement lies outside the anti-aliased stripe. Its paint
		// weight is exactly zero: skip both gradients and the color blend.
		// Keep fwidth above the branch, including for distant wide AA bands.
		if (paint_distance < 0.06 + aa) {
			float paint = (1.0-smoothstep(0.06-aa,0.06+aa,paint_distance))
				* smoothstep(5.5,7.0,max(abs(p.x),abs(p.y)));
			asphalt = mix(asphalt,vec3(0.48,0.46,0.38),paint * 0.55);
		}
	}
	// Pure asphalt needs neither meadow textures nor edge/relief blending.
	// Keep all derivatives above this branch for stable boundary mip selection.
	ALBEDO = asphalt;
	ROUGHNESS = 0.9;
	if (edge > 0.0) {
		vec3 earth = vec3(0.0);
		vec3 relief = vec3(0.5,0.5,1.0);
		mobile_meadow_filtered(ground_position,dx,dy,earth,relief);
		ALBEDO = mix(asphalt,earth,edge);
		vec2 slope = (relief.xy * 2.0 - 1.0) * 0.20 * edge;
		// Distant ground has no relief; skip its normal arithmetic.
		if (any(notEqual(slope, vec2(0.0)))) {
			vec3 gradient = mat3(VIEW_MATRIX) * vec3(slope.x,0.0,slope.y);
			NORMAL = normalize(NORMAL-gradient+NORMAL*dot(NORMAL,gradient));
		}
		ROUGHNESS = mix(0.9,0.96,edge);
	}
	SPECULAR = 0.12;
}
