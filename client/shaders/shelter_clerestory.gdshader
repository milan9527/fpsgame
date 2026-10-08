shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Glazing reveals the roof behind it. Local bounce is authored separately;
// transparency does not imply physically simulated daylight transmission.
void fragment() {
	vec2 p = UV;
	float window = step(abs(p.x), 2.25) * step(3.48, p.y) * step(p.y, 4.52);
	float mullion = 1.0 - smoothstep(0.025, 0.045, abs(mod(p.x + 0.375, 0.75) - 0.375));
	float frame = max(mullion, 1.0 - smoothstep(0.025, 0.06, min(abs(p.y-3.48), abs(p.y-4.52))));
	float streak = sin(p.x*71.0 + sin(p.x*19.0)*2.0)*0.5+0.5;
	float grime = (1.0-smoothstep(3.48,3.82,p.y))*0.35 + streak*0.10;
	vec3 glass = mix(vec3(0.24,0.34,0.34),vec3(0.43,0.52,0.49),smoothstep(3.48,4.52,p.y));
	float pane = window*(1.0-frame);
	float seam = 1.0-smoothstep(0.012,0.024,abs(mod(p.x,0.38)-0.19));
	vec3 steel = vec3(0.15,0.22,0.20)*(1.0-seam*0.28);
	ALBEDO = mix(steel,glass*(1.0-grime),pane);
	ROUGHNESS = mix(0.78,0.30+grime,pane);
	METALLIC = 0.15*(1.0-pane);
	SPECULAR = mix(0.3,0.65,pane);
	ALPHA = mix(1.0, 0.32 + grime * 0.45, pane);
}
