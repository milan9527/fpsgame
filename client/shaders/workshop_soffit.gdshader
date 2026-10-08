shader_type spatial;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	// Folded galvanised lining: metre-scale bays, filtered raised ribs.
	float phase = local_position.x * 2.0;
	float edge = min(fract(phase), 1.0 - fract(phase));
	float rib = 1.0 - smoothstep(0.012, 0.025 + fwidth(phase), edge);
	float stain = sin(local_position.z * 1.8 + sin(local_position.x * 0.7)) * 0.035;
	ALBEDO = vec3(0.32, 0.355, 0.33) * (1.0 - rib * 0.35 + stain);
	METALLIC = 0.18;
	ROUGHNESS = 0.84;
	SPECULAR = 0.28;
}
