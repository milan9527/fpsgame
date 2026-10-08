shader_type spatial;
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),
		mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
	// Broad limestone slabs, with recessed joints across the side-wall cap.
	float joint_distance = min(fract(wp.z/0.53),1.0-fract(wp.z/0.53))*0.53;
	float joint = smoothstep(0.002,0.006+fwidth(wp.z),joint_distance);
	vec2 surface = abs(wn.y)>0.5 ? wp.xz : vec2(wp.x+wp.z,wp.y);
	// Evaluate derivatives uniformly; filtered pores need no procedural noise.
	float pore_visibility = 1.0-smoothstep(0.003,0.02,length(fwidth(surface)));
	float pores = 0.5;
	if (pore_visibility > 0.0) {
		pores = mix(0.5,noise(surface*95.0),pore_visibility);
	}
	vec3 stone = mix(vec3(0.24,0.225,0.185),vec3(0.37,0.35,0.29),noise(surface*4.0));
	stone *= 0.91+pores*0.18;
	float drip = smoothstep(0.58,0.82,noise(vec2((wp.x+wp.z)*17.0,wp.y*0.6)));
	stone *= 1.0-drip*0.18*(1.0-abs(wn.y));
	ALBEDO = mix(stone*0.48,stone,joint);
	ROUGHNESS = 0.89;
	SPECULAR = 0.18;
}
