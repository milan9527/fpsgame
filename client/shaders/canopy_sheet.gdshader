shader_type spatial;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	// Metre-scale standing seams and subtle runoff, not oversized rust noise.
	float joint_distance = abs(mod(local_position.x + 3.4, 0.68) - 0.34);
	float seam = 1.0 - smoothstep(0.008, 0.018 + fwidth(local_position.x), joint_distance);
	float runoff = sin(local_position.x * 39.0 + sin(local_position.x * 9.0)) * 0.025;
	float edge = smoothstep(0.78, 1.2, abs(local_position.z));
	// The outer layer is weathered enamel, so bare-metal reflectance must
	// not bleach the entire roof under the afternoon sky.
	ALBEDO = vec3(0.10, 0.16, 0.135) * (1.0 - seam * 0.30 - edge * 0.17 + runoff);
	ROUGHNESS = 0.88 + edge * 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.18;
}
