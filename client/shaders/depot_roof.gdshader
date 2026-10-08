shader_type spatial;
varying vec3 sheet_position;
void vertex() {
	sheet_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Pressed sheet ribs follow the existing 29 cm roof seams.
	float phase = sheet_position.x * 6.283185 / 0.29;
	float visibility = 1.0-smoothstep(0.8,3.0,fwidth(phase));
	float rib = pow(0.5+0.5*cos(phase),6.0)*visibility;
	float panel = floor(sheet_position.x/0.87);
	float tone = sin(panel*17.3)*0.035;
	float runoff = sin(sheet_position.x*53.0+sin(sheet_position.z*0.9))*0.018;
	ALBEDO = vec3(0.245,0.30,0.29)*(1.0+tone+runoff-rib*0.22);
	ROUGHNESS = 0.76;
	SPECULAR = 0.25;
	// Shallow corrugation on upper and lower sheet faces only.
	float face = smoothstep(0.6,0.95,abs((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).y));
	NORMAL = normalize(NORMAL+mat3(VIEW_MATRIX)*vec3(sin(phase)*0.16*visibility*face,0,0));
}
