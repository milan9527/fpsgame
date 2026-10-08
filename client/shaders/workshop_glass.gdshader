shader_type spatial;
render_mode specular_schlick_ggx;

// Opaque, dusty glazing over the existing closed facade: no false opening.
float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
varying vec2 glazing_position;
void vertex() {
	glazing_position = VERTEX.xy;
}
void fragment() {
	vec2 facade_uv = vec2(glazing_position.x / 4.8 + 0.5, 0.5 - glazing_position.y / 1.86);
	vec2 pane_uv = vec2(fract(facade_uv.x * 4.0), fract(facade_uv.y * 2.0));
	float dust = noise(facade_uv * vec2(85.0, 4.0));
	float edge = smoothstep(0.31, 0.5, abs(pane_uv.x - 0.5));
	float lower_dirt = smoothstep(0.72, 1.0, pane_uv.y);
	float pane_age = hash(floor(facade_uv * vec2(4.0, 2.0)) + 7.0);
	float rain = smoothstep(0.48,0.74,noise(facade_uv * vec2(115.0,3.0)))
		* smoothstep(0.18,0.95,pane_uv.y);
	vec3 glazing = mix(vec3(0.025, 0.055, 0.06), vec3(0.07, 0.105, 0.11), 1.0 - facade_uv.y);
	float grime = clamp(dust * 0.2 + edge * 0.28 + lower_dirt * 0.2
		+ rain * 0.22 + pane_age * 0.16, 0.0, 0.78);
	ALBEDO = mix(glazing, vec3(0.09, 0.085, 0.065), grime);
	// Broad sky reflection remains readable beneath the canopy shadow.
	// World-space reflection changes with the player, rather than painting
	// identical bright rectangles onto each pane. Closed facade stays opaque.
	vec3 reflected = normalize(mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL));
	float sky_visibility = smoothstep(-0.08, 0.38, reflected.y);
	vec3 sky = mix(vec3(0.035, 0.055, 0.032), vec3(0.28, 0.44, 0.59), sky_visibility);
	float cloud = smoothstep(0.55, 0.76, noise(reflected.xz * 4.0 + reflected.y * 2.0));
	sky = mix(sky, vec3(0.62, 0.66, 0.66), cloud * sky_visibility * 0.45);
	// Approximate the distant wooded horizon with angular variation; this
	// is an environment approximation, not a screen-space scene reflection.
	float treeline = 0.04 + noise(reflected.xz * 18.0) * 0.11;
	float trees = 1.0 - smoothstep(treeline - 0.025, treeline + 0.025, reflected.y);
	sky = mix(sky, vec3(0.022, 0.042, 0.027), trees * 0.82);
	float fresnel = 0.16 + 0.56 * pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	// Frame occlusion and pane wear interrupt the broad sky response.
	float frame_occlusion = smoothstep(0.0,0.11,pane_uv.x)
		* smoothstep(0.0,0.11,1.0-pane_uv.x)
		* smoothstep(0.0,0.12,pane_uv.y);
	float pane_response = mix(0.38,1.12,pane_age);
	EMISSION = sky * fresnel * (1.0 - grime) * pane_response
		* mix(0.4,1.0,frame_occlusion);
	METALLIC = 0.0;
	ROUGHNESS = 0.16 + grime * 0.55 + pane_age * 0.16;
	SPECULAR = 0.5;
}
