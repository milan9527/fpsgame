shader_type spatial;
#include "res://shaders/meadow_mobile.gdshaderinc"
varying vec3 ground_position;
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec3 color, relief;
	mobile_meadow(ground_position,color,relief);
	ALBEDO = color;
	vec2 slope = (relief.xy * 2.0 - 1.0) * 0.25;
	// Distant relief is exactly neutral: retain the surface normal directly.
	if (any(notEqual(slope, vec2(0.0)))) {
		vec3 gradient = mat3(VIEW_MATRIX) * vec3(slope.x,0.0,slope.y);
		NORMAL = normalize(NORMAL - gradient + NORMAL * dot(NORMAL,gradient));
	}
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
