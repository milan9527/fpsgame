shader_type spatial;
render_mode cull_disabled;

// Box UVs are normalized; wall sheets need metre-scale world coordinates.
varying vec3 position_world;
void vertex() {
	position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = position_world.xy;
	float sheet = floor((p.x - 12.2) / 0.5);
	float variation = fract(sin(sheet * 71.7) * 43758.5453);
	float footprint = max(fwidth(p.x), 0.001);
	float seam_distance = abs(mod(p.x - 12.2 + 0.25, 0.5) - 0.25);
	float seam = 1.0 - smoothstep(0.008, 0.016 + footprint, seam_distance);
	float dado = 1.0 - smoothstep(1.16, 1.19, p.y);
	vec3 finish = mix(vec3(0.43, 0.40, 0.32), vec3(0.105, 0.17, 0.145), dado);
	finish *= mix(0.91, 1.05, variation);
	float runoff = pow(0.5 + 0.5 * sin(p.x * 23.0 + sin(p.x * 8.0)), 5.0);
	float splash = (1.0 - smoothstep(0.12, 0.64, p.y)) * (0.4 + runoff * 0.6);
	finish = mix(finish, vec3(0.125, 0.105, 0.072), splash * 0.6);
	finish *= 1.0 - seam * 0.32 - runoff * 0.055;
	ALBEDO = finish;
	ROUGHNESS = mix(0.79, 0.94, splash);
	METALLIC = 0.0;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
