shader_type spatial;
varying vec3 position_world;
float grain(vec2 p) {
	vec2 i = floor(p), f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(fract(sin(dot(i,vec2(127.1,311.7)))*43758.5453),
		fract(sin(dot(i+vec2(1,0),vec2(127.1,311.7)))*43758.5453),f.x),
		mix(fract(sin(dot(i+vec2(0,1),vec2(127.1,311.7)))*43758.5453),
		fract(sin(dot(i+vec2(1,1),vec2(127.1,311.7)))*43758.5453),f.x),f.y);
}
void vertex() {
	position_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = vec2(position_world.x + position_world.z * 0.71, position_world.y);
	float fading = grain(p * vec2(2.2, 0.6));
	// Metre-scale runoff and foot corrosion; filter chips below the pixel footprint.
	float base_rust = 1.0 - smoothstep(0.10, 0.48, position_world.y);
	// Evaluate derivatives before branching so neighbouring fragments share
	// the original filtering, including across the visibility boundary.
	float footprint = max(fwidth(p.x), fwidth(p.y));
	float chip_visibility = 1.0 - smoothstep(0.018, 0.055, footprint);
	float paint_visibility = 1.0 - smoothstep(0.003, 0.012, footprint);
	// Above the foot corrosion band, runoff has exactly zero weight.
	float runoff = 0.0;
	if (base_rust > 0.0) {
		runoff = grain(p * vec2(12.0, 0.9));
	}
	float patch = 0.0;
	float chip = 0.0;
	if (chip_visibility > 0.0) {
		patch = smoothstep(0.62, 0.84, grain(p * vec2(3.1, 1.2)));
		if (patch > 0.0) {
			chip = smoothstep(0.56, 0.77, grain(p * vec2(14.0, 8.0)));
		}
	}
	float rust = clamp(base_rust * (0.55 + runoff * 0.35)
		+ patch * chip * chip_visibility * 0.38, 0.0, 1.0);
	// Shader albedo is linear: these values keep painted framing visibly
	// darker than the sunlit sheet metal rather than washed-out mint green.
	ALBEDO = mix(mix(vec3(0.043,0.075,0.058), vec3(0.063,0.100,0.076), fading),
		vec3(0.12,0.047,0.018), rust);
	// Small paint texture changes the highlight, not metre-wide dark blobs.
	float paint_detail = 0.5;
	if (paint_visibility > 0.0) {
		paint_detail = mix(0.5, grain(p * 95.0), paint_visibility);
	}
	ALBEDO *= 0.96 + paint_detail * 0.08;
	ROUGHNESS = mix(0.62 + paint_detail*0.10, 0.96, rust);
	METALLIC = 0.03 * (1.0-rust);
	SPECULAR = 0.28;
}
