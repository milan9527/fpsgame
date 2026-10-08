shader_type spatial;
render_mode cull_disabled;

float weather_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	vec4 v = sin(vec4(dot(i,vec2(127.1,311.7)),
		dot(i+vec2(1,0),vec2(127.1,311.7)),
		dot(i+vec2(0,1),vec2(127.1,311.7)),
		dot(i+vec2(1),vec2(127.1,311.7))))*43758.5453;
	v = fract(v);
	return mix(mix(v.x,v.y,f.x),mix(v.z,v.w,f.x),f.y);
}

void fragment() {
	// UVs are in metres along the arch and the length of the shelter.
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	float resolved = 1.0 - smoothstep(0.025, 0.10, fwidth(UV.y));
	// The mesh provides corrugation normals; only subtle trough dirt remains.
	float groove = pow(0.5 - 0.5 * cos((UV.y + 3.5) * 6.283185 / 0.20), 5.0);
	groove = mix(0.246, groove, resolved);
	float footprint = max(fwidth(UV.y), 0.004);
	float joint = (1.0 - smoothstep(0.015, 0.035 + footprint, abs(mod(UV.y + 0.585, 1.17) - 0.585))) * resolved;
	float mottling = sin(UV.x * 3.7 + sin(UV.y * 2.3)) * sin(UV.y * 7.1) * 0.025;
	vec3 paint = vec3(0.23, 0.29, 0.255);
	ALBEDO = paint * (0.92 - groove * 0.17 - joint * 0.23 + mottling);
	// Broad rain-washed panels and narrow oxidised seams remain visible at eye level.
	float panel = floor(UV.y / 1.17);
	float panel_tone = fract(sin(panel * 127.1) * 43758.5453);
	ALBEDO *= mix(0.86, 1.14, panel_tone);
	float seam_wear = 1.0 - smoothstep(0.025, 0.075 + footprint, abs(mod(UV.y + 0.585, 1.17) - 0.585));
	ALBEDO = mix(ALBEDO, vec3(0.19, 0.105, 0.055), seam_wear * 0.12 * resolved);
	// Runoff follows the arch, with a broad faded crown and darker eaves.
	float crown = smoothstep(0.0, 2.8, min(UV.x, 10.367 - UV.x));
	float wash = weather_noise(vec2(UV.y * 0.85, UV.x * 0.35 + 12.0));
	ALBEDO *= mix(0.72, 1.04, crown);
	ALBEDO = mix(ALBEDO, vec3(0.24, 0.19, 0.12), (1.0-crown)*wash*0.24);
	// Rain follows the curved sheet toward the eaves. Uneven mineral wash
	// spans metres, while oxidation stays concentrated at overlaps and edges.
	float runoff = weather_noise(vec2(UV.x * 0.7, UV.y * 9.0))
		* weather_noise(vec2(UV.x * 0.24 + 17.0, UV.y * 2.8));
	float chalk = smoothstep(0.32, 0.72,
		weather_noise(UV * vec2(0.65, 1.4))) * crown;
	ALBEDO = mix(ALBEDO, vec3(0.39, 0.40, 0.34), chalk * 0.58);
	ALBEDO *= 1.0 - runoff * (1.0 - crown * 0.6) * 0.52;
	// Break corrosion into local damaged patches instead of full-height stripes.
	float damage = smoothstep(0.43, 0.72, weather_noise(UV * vec2(1.15, 0.73) + vec2(8.0, 19.0)));
	float oxidation = smoothstep(0.36, 0.67, weather_noise(UV * vec2(3.0, 11.0)))
		* max(seam_wear * damage * 0.72, (1.0-crown) * damage * 0.38);
	ALBEDO = mix(ALBEDO, vec3(0.135, 0.071, 0.033), oxidation);
	// Selected full sheets were replaced: restrained zinc-green panels with
	// broad weathering, retaining corrugation and physical overlap shadows.
	float replacement = step(0.77, panel_tone);
	vec3 zinc = vec3(0.27, 0.31, 0.28) * (0.90 - groove * 0.14 - joint * 0.22);
	zinc *= mix(0.77, 1.03, crown) - runoff * 0.10;
	ALBEDO = mix(ALBEDO, zinc, replacement * 0.46);
	// Exposed paint loss forms interrupted bands below lap seams. The metre
	// scale wash remains visible from the service lane without giant rust dots.
	float bare = smoothstep(0.48, 0.70, weather_noise(vec2(UV.x*1.4,UV.y*5.0)+vec2(31.0,8.0)));
	float edge_loss = (1.0-crown) * bare * (0.28 + damage*0.45);
	ALBEDO = mix(ALBEDO, vec3(0.23,0.135,0.069), edge_loss);
	AO = FRONT_FACING ? 1.0 : 0.72;
	ROUGHNESS = mix(0.86, 0.98, clamp(chalk + oxidation + runoff, 0.0, 1.0));
	METALLIC = replacement * 0.09;
	SPECULAR = 0.23;
}
