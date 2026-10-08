shader_type spatial;
varying vec3 position_world;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(grain(i), grain(i + vec2(1, 0)), f.x),
		mix(grain(i + vec2(0, 1)), grain(i + vec2(1)), f.x), f.y);
}
void vertex() {
	position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Local corrosion at sheet joints and drip edges; the painted face
	// retains its coating instead of becoming a continuous orange stripe.
	vec2 p = position_world.xy;
	float fade = noise(p * vec2(0.72, 1.3) + vec2(8.13, 2.37));
	float rain = smoothstep(0.55, 0.85, noise(p * vec2(38.0, 1.8)));
	float lower_edge = 1.0 - smoothstep(2.915, 2.945, p.y);
	float joint_distance = min(fract(p.x), 1.0 - fract(p.x));
	float joint = 1.0 - smoothstep(0.012, 0.055, joint_distance);
	float chips = smoothstep(0.56, 0.80, noise(p * vec2(29.0, 43.0)));
	float paint_loss = chips * max(joint * 0.85, lower_edge * 0.60);
	// Muted oxide coating separates folded sheet from the green steel frame.
	// Low contrast, metre-scale fading avoids the old square patchwork.
	vec3 paint = mix(vec3(0.13, 0.077, 0.049), vec3(0.17, 0.108, 0.071), fade);
	vec3 oxide = mix(paint, vec3(0.23, 0.105, 0.048), paint_loss);
	oxide *= 1.0 - rain * 0.12 - lower_edge * 0.18;
	ALBEDO = oxide;
	ROUGHNESS = mix(0.78, 0.95, fade);
	METALLIC = 0.10;
	SPECULAR = 0.25;
}
