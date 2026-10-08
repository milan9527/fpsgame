shader_type spatial;
varying vec3 timber_position;
void vertex() {
	timber_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Grain follows the boards' fall. Filter fine fibres at gameplay distance.
	float across = timber_position.x * 130.0 + sin(timber_position.z * 2.7) * 0.8;
	float grain = sin(across) * (1.0 - smoothstep(0.4, 2.0, fwidth(across)));
	float board = floor((timber_position.x - 12.105) / 0.485);
	float tone = sin(board * 7.13) * 0.035;
	ALBEDO = vec3(0.31, 0.255, 0.185) * (1.0 + grain * 0.07 + tone);
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
