shader_type spatial;
#include "res://shaders/meadow_surface.gdshaderinc"
// Explicit rotated gradients with anisotropic sampling stall the llvmpipe
// first draw. Trilinear mip filtering retains distance filtering on that driver.
uniform sampler2D aggregate : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pavement : source_color, filter_linear_mipmap, repeat_enable;

varying vec2 point;
varying vec3 ground_position;
float hash(vec2 p) {
	vec3 q=fract(vec3(p.xyx)*0.1031);
	q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
// Analytic world-space derivative of the cubic value noise. Screen derivatives
// of a footprint-filtered height would differentiate fwidth itself (undefined).
vec2 noise_gradient(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	vec2 u=f*f*(3.0-2.0*f), du=6.0*f*(1.0-f);
	float a=hash(i), b=hash(i+vec2(1.0,0.0));
	float c=hash(i+vec2(0.0,1.0)), d=hash(i+vec2(1.0));
	return vec2(mix(b-a,d-c,u.y),mix(c-a,d-b,u.x))*du;
}
// Domain-warped variation for local edge weathering.
float weathering(vec2 p) {
	mat2 turn=mat2(vec2(0.8,0.6),vec2(-0.6,0.8));
	vec2 warp=vec2(noise(turn*p*0.17),noise(turn*p*0.17+37.2));
	vec2 q=turn*p+warp*2.8;
	return noise(q*0.73)*0.50+noise(turn*q*1.61+13.7)*0.30
		+noise(turn*turn*q*3.83-8.1)*0.20;
}
// Stochastic triangular footprints have no road-aligned row boundaries.
// Warp only the footprint selection, keeping photographic aggregate undistorted.
// Cubic barycentric weights meet with zero slope on all triangle edges.
vec3 pavement_sample(vec2 uv, vec2 cell, vec2 dx, vec2 dy) {
	vec2 offset=vec2(hash(cell+vec2(19.0,7.0)),hash(cell+vec2(3.0,53.0)));
	float angle=hash(cell+vec2(71.0,23.0))*6.2831853;
	mat2 rotation=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
	// Illumination is baked out before mip generation. Rotating both the
	// sample and gradients preserves mip selection at grazing angles.
	return textureGrad(pavement,rotation*uv+offset,rotation*dx,rotation*dy).rgb;
}
vec3 irregular_pavement(vec2 world) {
	mat2 turn=mat2(vec2(0.8,0.6),vec2(-0.6,0.8));
	vec2 domain=turn*world*0.25;
	domain+=vec2(noise(world*0.11+17.0),noise(world*0.11-31.0))*0.8;
	vec2 skew=vec2(domain.x-domain.y*0.577350269,domain.y*1.154700538);
	vec2 cell=floor(skew), f=fract(skew);
	vec2 a=cell, b=cell+vec2(1.0,0.0), c=cell+vec2(0.0,1.0);
	vec3 weights=vec3(1.0-f.x-f.y,f.x,f.y);
	if (f.x+f.y>1.0) {
		a=cell+vec2(1.0); b=cell+vec2(0.0,1.0); c=cell+vec2(1.0,0.0);
		weights=vec3(f.x+f.y-1.0,1.0-f.x,1.0-f.y);
	}
	weights=weights*weights*(3.0-2.0*weights);
	weights/=dot(weights,vec3(1.0));
	// Compacted asphalt uses fine aggregate, not the shoulder's loose stones.
	// Four times the shoulder density also reaches the photographic mip chain
	// earlier in grazing views, removing oversized bright gravel in the lane.
	vec2 uv=world*2.6;
	vec2 dx=dFdx(uv),dy=dFdy(uv);
	return pavement_sample(uv,a,dx,dy)*weights.x
		+pavement_sample(uv,b,dx,dy)*weights.y
		+pavement_sample(uv,c,dx,dy)*weights.z;
}
// Signed distance to a rounded, irregular maintenance cut in world metres.
float repair_cut(vec2 p, vec2 center, vec2 extent, float skew) {
 vec2 q=p-center;
 q.x+=q.y*skew;
 vec2 d=abs(q)-extent;
 return length(max(d,vec2(0.0)))+min(max(d.x,d.y),0.0)-0.16
  +(noise(p*3.1)-0.5)*0.13;
}
void vertex() {
	ground_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	point=ground_position.xz;
}
void fragment() {
	bool east_west = abs(point.y) < abs(point.x);
	vec2 p=east_west ? point.yx : point;
	// Local stochastic sampling breaks the road-length rows of identical
	// branching cracks without introducing transverse repair rectangles.
	vec3 paving=irregular_pavement(point);
	// Aggregate thresholds and binder values describe linear reflectance.
	// Compatibility samples source_color in sRGB; decode before combining
	// photographed aggregate with the physical binder values below.
	if (OUTPUT_IS_SRGB) {
		paving=mix(paving/12.92,pow((paving+0.055)/1.055,vec3(2.4)),
			step(vec3(0.04045),paving));
	}
	float stone=dot(paving,vec3(0.2126,0.7152,0.0722));
	// Broad worn wheel paths run along each lane and fade at the crossroads.
	float crossing=smoothstep(7.0,12.0,abs(p.y));
	float wheel=1.0-smoothstep(0.35,0.95,abs(abs(abs(p.x)-1.75)-0.72));
	// Gravel washes over the broken asphalt edge and continues onto the
	// meadow mesh in the same world coordinates, hiding the rectangular seam.
	float road_distance=road_surface_distance(point);
	float erosion=road_surface_erosion(point);
	// Both axes share a roughly seven-metre carriageway. The remaining
	// road bed is a low aggregate apron, continuous through the crossroads.
	float margin=road_distance+erosion*0.6;
	// A broken wearing course and exposed sub-base replace a uniformly
	// airbrushed strip. Filter the centimetre-sized islands independently so
	// the transition retains coverage rather than sparkling at a distance.
	float fragment_size=max(length(fwidth(point)),0.001);
	float chips=noise(point*8.0);
	float chip_visibility=1.0-smoothstep(0.025,0.12,fragment_size);
	float broken_margin=margin+(chips-0.5)*0.48*chip_visibility
		+(weathering(point)-0.5)*0.85;
	float edge=smoothstep(-2.6,-1.3,broken_margin);
	float exposed_base=smoothstep(-2.9,-2.45,broken_margin)
		*(1.0-smoothstep(-2.3,-1.7,broken_margin));
	// The wearing course is a continuous binder with embedded aggregate,
	// rather than a gravel photograph used directly as the whole albedo.
	// Only the upper aggregate facets break through; compress their contrast
	// so sunlit chips cannot turn the carriageway into a field of white dots.
	float aging=weathering(point*0.35);
	vec3 binder=mix(vec3(0.038,0.042,0.045),vec3(0.060,0.062,0.061),aging);
	float exposed_grain=smoothstep(0.10,0.23,stone);
	vec3 embedded_stone=mix(vec3(0.071,0.075,0.076),vec3(0.11,0.108,0.098),
		clamp(stone*2.0,0.0,1.0));
	float ravel=smoothstep(-4.0,-2.0,broken_margin);
	vec3 asphalt=mix(binder,embedded_stone,exposed_grain*mix(0.32,0.85,ravel));
	// Preserve pores and hairline cracks below the binder, not bright grit.
	asphalt*=mix(0.72,1.0,smoothstep(0.012,0.065,stone));
	asphalt*=1.0+wheel*crossing*0.18;
	// A wandering longitudinal fatigue crack, interrupted by sound pavement.
	// Periodic transverse joints made asphalt look like stacked concrete slabs.
	float joint=abs(p.x+1.35+(noise(vec2(p.y*0.22,8.0))-0.5)*0.65);
	float joint_aa=max(fwidth(joint),0.008);
	float seam=(1.0-smoothstep(0.008,0.008+joint_aa,joint))
		*min(1.0,0.018/joint_aa)*smoothstep(0.35,0.65,noise(p*0.16))*crossing;
	asphalt*=1.0-seam*0.3;
	// Sparse surveyed repairs replace the repeating lane-cell pattern. Different
	// lengths and oblique ends suggest isolated utility work, not paving tiles.
	float border=repair_cut(p,vec2(-2.9,46.0),vec2(0.48,2.1),0.07);
	border=min(border,repair_cut(p,vec2(3.1,22.0),vec2(0.30,4.2),-0.025));
	border=min(border,repair_cut(p,vec2(-3.3,-31.0),vec2(0.72,1.6),-0.13));
	border=min(border,repair_cut(p,vec2(2.5,-68.0),vec2(0.38,3.3),0.04));
	border=min(border,repair_cut(p,vec2(-2.0,91.0),vec2(0.60,1.2),0.17));
	float repair_aa=max(fwidth(border),0.018);
	float repair=(1.0-smoothstep(-repair_aa,repair_aa,border))*crossing;
	float seal=(1.0-smoothstep(0.03,0.03+repair_aa,abs(border)))*crossing;
	asphalt=mix(asphalt,vec3(0.051,0.057,0.059)*(0.8+stone*0.65),repair*0.42);
	asphalt*=1.0-seal*0.12;
	// One narrow utility trench follows the service-side wheel lane.
	// Opposing near-full-lane patches merged into transverse bars in perspective.
	// The short lateral return terminates at the access mouth, explaining the cut.
	vec2 trench_p=p;
	trench_p.x+=(noise(vec2(p.y*0.32,31.0))-0.5)*0.14;
	float lane_cut=repair_cut(trench_p,vec2(4.1,38.0),vec2(0.36,9.4),0.012);
	lane_cut=min(lane_cut,repair_cut(p,vec2(5.0,47.0),vec2(0.90,0.24),0.18));
	float surf_aa=max(fwidth(lane_cut),0.012);
	float resurfacing=(1.0-smoothstep(-surf_aa,surf_aa,lane_cut))*(east_west ? 0.0 : 1.0);
	vec3 new_asphalt=asphalt*0.84;
	new_asphalt*=1.0+wheel*0.22;
	asphalt=mix(asphalt,new_asphalt,resurfacing*0.72);
	float cut_edge=(1.0-smoothstep(0.012,0.026+surf_aa,abs(lane_cut)))
		*min(1.0,0.026/surf_aa)*(east_west ? 0.0 : 1.0);
	asphalt*=1.0-cut_edge*0.20;
	// Tyres follow a quarter-turn from the access mouth into the northbound
	// lane. A signed radial distance keeps two narrow tracks, rather than
	// painting a rectangular haze across the lane at a fixed world Z.
	vec2 turn_offset=point-vec2(10.0,43.2);
	float turn_radius=length(turn_offset);
	float tyre_distance=abs(abs(turn_radius-6.0)-0.85);
	float track_aa=max(fwidth(tyre_distance),0.015);
	float tracks=1.0-smoothstep(0.12,0.26+track_aa,tyre_distance);
	float turn_angle=atan(turn_offset.y,-turn_offset.x);
	float exit_zone=smoothstep(0.0,0.55,turn_angle)
		*(1.0-smoothstep(1.55,1.85,turn_angle));
	exit_zone*=east_west ? 0.0 : 1.0;
	float tracked_fines=exit_zone*tracks*smoothstep(0.25,0.75,noise(point*vec2(2.0,4.0)));
	asphalt=mix(asphalt,vec3(0.17,0.146,0.109),tracked_fines*0.42);
	// Faded 12cm edge paint, interrupted at the junction. Derivatives retain
	// coverage in the grazing-angle view instead of sparkling thin stripes.
	float paint_distance=abs(abs(p.x)-3.15);
	float aa=max(fwidth(paint_distance),0.008);
	float paint=(1.0-smoothstep(0.06-aa,0.06+aa,paint_distance))*crossing;
	if (!east_west && p.x>0.0) {
		paint*=smoothstep(2.6,3.3,abs(p.y-49.2));
	}
	// Resolve small paint flakes only while the pixel footprint can represent
	// them. Beyond that distance use average coverage, avoiding isolated white
	// speckles along the receding edge.
	float flake_visibility=1.0-smoothstep(0.018,0.075,fragment_size);
	float flakes=mix(0.72,smoothstep(0.24,0.53,noise(point*19.0)),flake_visibility);
	float wear=flakes*mix(0.45,0.8,noise(point*0.9));
	asphalt=mix(asphalt,vec3(0.32,0.31,0.265),paint*wear);
	// Convert only the linear asphalt mixture. Shoulder and shared meadow
	// samples already use the renderer's working colour space.
	if (OUTPUT_IS_SRGB) {
		asphalt=mix(asphalt*12.92,1.055*pow(max(asphalt,vec3(0.0)),vec3(1.0/2.4))-0.055,
			step(vec3(0.0031308),asphalt));
	}
	vec3 shoulder=texture(aggregate,point*0.65).rgb;
	shoulder=mix(vec3(dot(shoulder,vec3(0.2126,0.7152,0.0722))),shoulder,0.18);
	shoulder*=mix(vec3(0.69,0.72,0.70),vec3(1.0),smoothstep(0.28,0.72,noise(point*0.09+vec2(17.0,5.0))));
	shoulder*=vec3(0.48,0.45,0.38)*mix(0.83,1.08,noise(point*0.8));
	// Loose chips collect in islands over the crumbling wearing course.
	// The outer edge still converges exactly to the adjoining terrain sample.
	float loose_chips=smoothstep(0.43,0.66,weathering(point*2.1));
	float shoulder_coverage=clamp(edge+exposed_base*loose_chips*0.62,0.0,1.0);
	ALBEDO=mix(asphalt,shoulder,shoulder_coverage);
	// Millimetre aggregate relief changes reflected light near the player;
	// footprint filtering prevents distant asphalt from shimmering.
	float footprint=max(length(fwidth(point)),0.001);
	float fine_visibility=1.0-smoothstep(0.0038,0.015,footprint);
	float coarse_visibility=1.0-smoothstep(0.011,0.043,footprint);
	vec2 slope=(noise_gradient(point*65.0)*0.035*fine_visibility
		+noise_gradient(point*23.0)*0.025*coarse_visibility)
		*(1.0-edge)*(1.0-wheel*0.4);
	vec3 gradient=(VIEW_MATRIX*vec4(slope.x,0.0,slope.y,0.0)).xyz;
	NORMAL=normalize(NORMAL-gradient+NORMAL*dot(NORMAL,gradient));
	ROUGHNESS=mix(0.91-wheel*0.07,0.86-wheel*0.05,resurfacing);
	ROUGHNESS=mix(ROUGHNESS,0.98,max(edge,tracked_fines));
	// Road and yard share geometry; blend materials in world space.
	// Preserve the excavated profile: material deposition belongs to the
	// actual ditch bottom, not an axis-aligned strip at artificial height zero.
	vec3 ground_color, ground_normal;
	float ground_roughness;
	sample_meadow(ground_position, NORMAL, mat3(VIEW_MATRIX),
		ground_color, ground_normal, ground_roughness);
	// Recover the verge just beyond the usable aggregate shoulder. Access
	// mouths retain a swept mineral bed rather than a road-length mud strip.
	float verge_distance=road_verge_distance(point)+6.0;
	float terrain_join=smoothstep(4.45,6.35,
		verge_distance+erosion*0.65);
	terrain_join*=shoulder_coverage;
	terrain_join=max(terrain_join,smoothstep(105.0,112.5,abs(p.y)));
	terrain_join=max(terrain_join,smoothstep(0.08,0.32,-ground_position.y));
	ALBEDO=mix(ALBEDO,ground_color,terrain_join);
	NORMAL=normalize(mix(NORMAL,ground_normal,terrain_join));
	ROUGHNESS=mix(ROUGHNESS,ground_roughness,terrain_join);
	SPECULAR=mix(0.16,0.12,terrain_join);
}
