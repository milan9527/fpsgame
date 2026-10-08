shader_type spatial;
#include "res://shaders/meadow_surface.gdshaderinc"
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 ground_color, ground_normal;
	float ground_roughness;
	sample_meadow(world_position, NORMAL, mat3(VIEW_MATRIX), ground_color, ground_normal, ground_roughness);
	ALBEDO = ground_color;
	NORMAL = ground_normal;
	ROUGHNESS = ground_roughness;
	SPECULAR = 0.12;
}
