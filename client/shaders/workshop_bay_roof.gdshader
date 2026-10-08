shader_type spatial;
varying vec3 sheet_position;
float weather_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(fract(sin(dot(i, vec2(127.1,311.7))) * 43758.5453),
		fract(sin(dot(i+vec2(1,0),vec2(127.1,311.7))) * 43758.5453), f.x),
		mix(fract(sin(dot(i+vec2(0,1),vec2(127.1,311.7))) * 43758.5453),
		fract(sin(dot(i+vec2(1,1),vec2(127.1,311.7))) * 43758.5453), f.x), f.y);
}
void vertex() {
	sheet_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float phase = (sheet_position.z - 26.3) * 6.283185 / 0.20;
	float visibility = 1.0 - smoothstep(0.8, 3.0, fwidth(phase));
	float rib = pow(0.5 + 0.5 * cos(phase), 6.0) * visibility;
	float panel = floor((sheet_position.z - 26.3) / 0.6);
	float tone = sin(panel * 17.3) * 0.07;
	float streak = sin(sheet_position.z * 63.0 + sin(sheet_position.x * 0.7)) * 0.025 * visibility;
	float eave = smoothstep(-27.0, -25.9, sheet_position.x);
	ALBEDO = mix(vec3(0.13, 0.17, 0.155), vec3(0.105, 0.12, 0.10), eave * 0.35)
		* (1.0 + tone + streak - rib * 0.24);
	// Broad oxidation follows downslope ribs; exposed laps collect moisture.
	vec2 p = sheet_position.xz;
	float lap = 1.0 - smoothstep(0.018, 0.095, abs(fract((p.y-26.3)/0.6)-0.5)*0.6);
	float mottling = weather_noise(p * vec2(0.65, 2.8));
	float oxidation = smoothstep(0.48, 0.78, mottling + lap * 0.19 + eave * 0.12);
	ALBEDO = mix(ALBEDO, vec3(0.19, 0.105, 0.054), oxidation * 0.67);
	ALBEDO *= 0.88 + weather_noise(p * vec2(0.32, 1.3)) * 0.24;
	// Sheltered galvanized underside retains a lighter zinc finish.
	float underside = smoothstep(0.55, 0.9, -(INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	vec3 zinc = vec3(0.32, 0.35, 0.34) * (0.94 + tone + streak - rib * 0.18);
	ALBEDO = mix(ALBEDO, zinc * (1.0 - oxidation * 0.12), underside);
	ROUGHNESS = mix(0.90, 0.98, oxidation);
	SPECULAR = 0.08;
	float face = smoothstep(0.6, 0.95, abs((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y));
	NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * vec3(0, 0, sin(phase) * 0.17 * visibility * face));
}
