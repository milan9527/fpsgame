shader_type spatial;
varying vec3 point;
void vertex() { point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float angle = atan(point.x - 46.0, point.z - 31.0);
	float streak = pow(0.5 + 0.5 * sin(angle * 53.0 + sin(angle * 17.0)), 5.0);
	float grime = (1.0 - smoothstep(0.25, 1.5, point.y)) * 0.48;
	float runoff = streak * (0.12 + 0.16 * smoothstep(2.0, 4.2, point.y));
	vec3 paint = vec3(0.14, 0.20, 0.17);
	ALBEDO = mix(paint, vec3(0.075, 0.065, 0.043), grime + runoff);
	ROUGHNESS = 0.87;
	SPECULAR = 0.22;
}
