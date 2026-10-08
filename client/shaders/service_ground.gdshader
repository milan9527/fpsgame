shader_type spatial;
render_mode cull_disabled;
uniform sampler2D gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Linear lattice data: smooth interpolation retains value-noise contours
// without expanding four arithmetic hashes at every procedural layer.
uniform sampler2D noise_lattice : filter_linear, repeat_enable;
// Linear RGBA: nearest-clod gap, clod shade, signed relief X/Z.
uniform sampler2D fracture_field : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool physical_shoulder = false;
uniform vec2 access_points[17];
// XY segment vector, Z reciprocal squared length, prepared once on the CPU.
uniform vec3 access_projection[16];
varying vec3 world;
float hash(vec2 p) {
	vec3 q=fract(vec3(p.xyx)*0.1031);
	q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return textureLod(noise_lattice,(i+f+vec2(512.5))/1024.0,0.0).r;
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float segment_distance_squared(vec2 p, vec2 a, vec2 b) {
	vec2 ab=b-a;
	vec2 offset=p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0);
	return dot(offset,offset);
}
float segment_distance(vec2 p, vec2 a, vec2 b) {
	return sqrt(segment_distance_squared(p,a,b));
}
void fragment() {
	vec2 p=world.xz;
	// Swept shoulder coverage depends only on vertex alpha and world X.
	// Reject its transparent border before noise sampling and path evaluation.
	float coverage=0.0;
	if (physical_shoulder) {
		coverage=COLOR.a*smoothstep(7.9,10.4,p.x);
		if (coverage<0.015) discard;
	}
	// Road transitions belong to the graded road mesh. Painting another
	// shoulder on this elevated yard plane created a second, pale perimeter.
	float shoulder=0.0;
	// Rounded, eroded work pad: broader broken transitions avoid a rectangular
	// dirt carpet at normal eye height. Keep the central vehicle lane worn.
	vec2 d=abs(p-vec2(16.0,33.3))-vec2(4.8,5.7);
	float boundary=length(max(d,vec2(0.0)))+min(max(d.x,d.y),0.0)-1.1;
	float erosion=(noise(p*0.7)-0.5)*1.7+(noise(p*2.7)-0.5)*0.35;
	float yard=1.0-smoothstep(-0.8,1.5,boundary+erosion);
	// Follow the actual curved vehicle surface. The old two-segment strip
	// ended outside the bend and left an angular island in the meadow.
	// Compare squared distances; only the winning segment needs a square root.
	float lane_squared=1000000.0;
	for (int i=0;i<16;i++) {
		vec2 a=access_points[i], ab=access_projection[i].xy;
		vec2 offset=p-a-ab*clamp(dot(p-a,ab)*access_projection[i].z,0.0,1.0);
		lane_squared=min(lane_squared,dot(offset,offset));
	}
	float lane=sqrt(lane_squared);
	float fill_width=3.4+noise(p*0.31+vec2(8.0,21.0))*1.2;
	float approach=1.0-smoothstep(fill_width,fill_width+1.4,lane+erosion*0.5);
	// The swept bed stops at the asphalt verge instead of painting the lane.
	approach *= smoothstep(7.9,10.4,p.x);
	yard=max(yard,approach);
	if (!physical_shoulder) {
		// These masks only affect plane coverage; swept shoulders already
		// received their coverage from vertex alpha above.
		float n=noise(p*0.85);
		vec2 west=abs(p-vec2(-19.0,34.0))-vec2(4.0,3.6);
		vec2 east=abs(p-vec2(17.0,17.0))-vec2(4.0,3.6);
		float storage=1.0-smoothstep(-0.7,1.3,min(max(west.x,west.y),max(east.x,east.y))+n*0.7);
		// Feathered mineral verge beside the repair bay, tied to its apron edge.
		float bay_edge=segment_distance(p,vec2(-24.0,26.3),vec2(-24.0,41.8));
		float bay_verge=1.0-smoothstep(0.15,1.35,bay_edge+erosion*0.30);
		coverage=max(max(max(shoulder,yard),storage),bay_verge);
		if (coverage<0.015) discard;
	}
	// Two nonparallel sample frames break repetition at a physical fine-grit scale.
	vec2 mineral_uv=mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*p*1.31+vec2(7.3,19.1);
	vec3 stone=mix(texture(gravel,p*1.18).rgb,texture(gravel,mineral_uv).rgb,
		smoothstep(0.25,0.75,noise(p*0.71)));
	// Blend rotated soil samples so the access lane does not repeat one tile.
	vec2 soil_b=mat2(vec2(0.6,0.8),vec2(-0.8,0.6))*p*1.47+vec2(11.3,7.8);
	vec3 dirt=mix(texture(soil,p*1.32).rgb,texture(soil,soil_b).rgb,
		smoothstep(0.25,0.75,noise(p*0.43)));
	// Compress the scan's baked broad shadows; physical clods and aggregate
	// below provide local contrast instead of large blurry dark islands.
	dirt=mix(vec3(0.36),dirt,0.48);
	stone=mix(vec3(0.39),stone,0.72);
	float wander=(noise(p*1.7)-0.5)*0.18+(noise(p*0.4)-0.5)*0.22;
	float tracks=(1.0-smoothstep(0.105,0.19,abs(abs(p.x-15.5)-1.05)+wander))*yard;
	tracks=mix(tracks,1.0-smoothstep(0.105,0.19,abs(lane-1.05)+wander),smoothstep(36.0,38.0,p.y));
	tracks*=yard*mix(0.25,0.85,smoothstep(0.2,0.8,noise(p*0.9)));
	// Preserve luminance without amplifying orange in the source aggregate.
	stone=mix(vec3(dot(stone,vec3(0.2126,0.7152,0.0722))),stone,0.12);
	dirt=mix(vec3(dot(dirt,vec3(0.2126,0.7152,0.0722))),dirt,0.25);
	vec2 warp=vec2(noise(p*0.18+12.0),noise(p*0.21-9.0));
	float deposits=noise(p*0.34+warp*2.0);
	// Uneven drainage leaves broad dark silt pockets between dry aggregates.
	float damp=smoothstep(0.40,0.69,noise(p*0.11+warp*0.4));
	// Vehicle use sorts pale loose chips away from damp compacted wheel paths.
	float chips=smoothstep(0.40,0.64,noise(p*0.65+warp*2.3))*(1.0-tracks*0.85);
	ALBEDO=mix(dirt*vec3(0.52,0.49,0.43),stone*vec3(0.48,0.46,0.41),
		0.15+deposits*0.25)*mix(1.0,0.96,tracks);
	// Drainage changes value subtly: broad high-contrast stains read as
	// blurred camouflage at eye height and overwhelm the aggregate.
	ALBEDO*=mix(vec3(1.06,1.04,1.00),vec3(0.91,0.93,0.89),damp);
	ALBEDO=mix(ALBEDO,stone*vec3(0.64,0.61,0.55),chips*0.23);
	ALBEDO=mix(ALBEDO,dirt*vec3(0.32,0.33,0.28),tracks*(0.06+damp*0.08));
	// Water draining off the apron leaves a broad broken dark band; the
	// compacted approach remains lighter than the quiet perimeter.
	float apron_edge = abs(p.y - 36.2);
	float runoff = 0.0;
	// Noise shifts the band by at most 0.2 m. Outside these bounds
	// either smoothstep makes the contribution exactly zero.
	if (apron_edge < 1.36 && abs(p.x - 15.5) < 3.8) {
		runoff = (1.0 - smoothstep(0.18, 1.15, apron_edge + (noise(p * 2.0) - 0.5) * 0.4))
			* (1.0 - smoothstep(2.7, 3.8, abs(p.x - 15.5)));
	}
	ALBEDO *= 1.0 - runoff * 0.20;
	// Sparse fine leaf litter at the eroded margin; keep the traffic lane bare.
	float margin=(1.0-smoothstep(0.3,0.85,coverage))*(1.0-tracks);
	float litter=0.0;
	if (margin > 0.0) {
		litter=smoothstep(0.52,0.70,noise(p*13.0))*margin;
	}
	ALBEDO=mix(ALBEDO,vec3(0.12,0.105,0.049),litter*0.6);
	// Fine pale aggregate near asphalt, darker earth at the outer verge.
	float aggregate=0.0;
	ALBEDO=mix(ALBEDO,stone*vec3(0.49,0.47,0.41),aggregate*0.65);
	// Metre-scale exposed earth interrupts the uniform gravel apron.
	float earth=smoothstep(0.38,0.65,noise(p*0.24+warp*1.8));
	ALBEDO=mix(ALBEDO,dirt*vec3(0.51,0.48,0.42),earth*0.30*(1.0-aggregate*0.7)*(1.0-tracks));
	// Loose aggregate piles beside the compacted ruts. Keep this layer after
	// the broad soil blend so use marks survive at standing camera height.
	float wheel_distance = mix(abs(abs(p.x-15.5)-1.05),abs(lane-1.05),
		smoothstep(36.0,38.0,p.y));
	// Displaced earth breaks into metre-scale deposits, not painted bright rails.
	float bank_offset = (noise(p * 0.83 + warp) - 0.5) * 0.48;
	float berm = (1.0-smoothstep(0.06,0.28,abs(wheel_distance-0.42+bank_offset)))
		* yard;
	// The bank offset also shapes center growth below; keep it unconditional.
	// Bank breakup and tint use explicit LOD and contribute only inside berms.
	if (berm > 0.0) {
		float bank_breaks = smoothstep(0.46,0.72,noise(p*vec2(1.3,0.65)+warp*2.0));
		berm *= bank_breaks;
		ALBEDO=mix(ALBEDO,mix(dirt*vec3(0.40,0.38,0.33),
			stone*vec3(0.46,0.44,0.39),noise(p*3.7)),berm*0.48);
	}
	ALBEDO=mix(ALBEDO,dirt*vec3(0.30,0.29,0.23),tracks*0.08);
	// Low ground cover merges living verge plants into the soil, with worn
	// wheel paths and the paved shoulder kept exposed.
	float colonization = smoothstep(0.36,0.68,noise(p*0.48+warp*1.7));
	float recovery = smoothstep(1.05,2.3,lane+(noise(p*0.8)-0.5)*1.1)
		* smoothstep(38.0,42.0,p.y) * approach;
	float verge_cover = max(1.0-smoothstep(0.28,0.95,coverage),recovery*0.85)
		* colonization * (1.0-tracks) * (1.0-aggregate);
	// Broken low growth on the unused strip between wheel paths.
	float center_growth=(1.0-smoothstep(0.18,0.70,lane+wander+bank_offset))
		* approach * smoothstep(38.0,43.0,p.y) * colonization;
	verge_cover=max(verge_cover,center_growth*0.8);
	// Colonization describes where plants can grow, not a green paint layer.
	// Resolve small irregular patches with bare earth between them. Filter
	// the threshold by pixel footprint to avoid shimmering in the distance.
	float plant_noise=noise(p*18.0+warp*3.0)*0.65+noise(p*41.0)*0.35;
	float plant_aa=max(fwidth(plant_noise),0.035);
	float plant_threshold=mix(0.76,0.42,verge_cover);
	float plant_patches=smoothstep(plant_threshold-plant_aa,plant_threshold+plant_aa,plant_noise);
	plant_patches*=smoothstep(0.08,0.42,verge_cover);
	// Explicit-LOD noise needs no derivatives; bare pixels need no plant tint.
	if (plant_patches > 0.0) {
		vec3 ground_cover=mix(vec3(0.048,0.063,0.022),vec3(0.105,0.119,0.043),noise(p*23.0));
		ALBEDO=mix(ALBEDO,ground_cover,plant_patches*0.87);
	}
	// Dry crushed aggregate sits outside the compacted paths. A readable
	// grey-brown lane replaces the orange/green low-frequency camouflage.
	float lane_gravel=approach*(1.0-tracks*0.75)*(1.0-plant_patches);
	ALBEDO=mix(ALBEDO,stone*vec3(0.58,0.55,0.46),lane_gravel*0.42);
	// Compacted clods and broken gravel at 15–30 cm scale bridge the
	// broad damp patches and fine texture; suppress beyond pixel resolution.
	float clod_resolution=1.0-smoothstep(0.06,0.22,max(length(dFdx(p)),length(dFdy(p))));
	float exposed=(1.0-plant_patches*0.9)*(1.0-tracks*0.5)*clod_resolution;
	// Keep the footprint unconditional; defer faded clod samples until a
	// loading-aggregate footprint actually needs their shared color.
	float clods=0.0;
	if (exposed > 0.0) {
		clods=noise(p*19.5+vec2(noise(p*2.1),noise(p*2.1+31.0))*1.8);
		float grit=smoothstep(0.52,0.76,clods);
		ALBEDO*=1.0+(clods-0.5)*0.16*exposed;
		ALBEDO=mix(ALBEDO,ALBEDO*vec3(1.25,1.22,1.15),grit*exposed*0.32);
	}
	// Resolve tread only nearby; distant tracks keep their softer silhouette.
	float tread_resolution=1.0-smoothstep(0.035,0.12,fwidth(p.y));
	float tread=(1.0-smoothstep(0.025,0.065,abs(mod(p.y+p.x*0.28,0.31)-0.155)))*tread_resolution;
	float tread_wear=0.0;
	// Keep the footprint above unconditional, then skip invisible lug wear.
	if (tread*tracks > 0.0) {
		tread_wear=smoothstep(0.38,0.72,noise(p*vec2(3.1,0.73)+42.0));
	}
	ALBEDO*=1.0-tracks*(0.025+tread*tread_wear*0.05);
	vec2 relief=texture(gravel_normal,p*1.18).xy*2.0-1.0;
	// Centimetre-scale angular facets have directional lighting, rather than
	// only painted spots. Fade their slope when the footprint becomes coarse.
	vec2 clod_cell=floor(p*23.0);
	vec2 clod_uv=fract(p*23.0)-0.5;
	vec2 clod_jitter=(vec2(hash(clod_cell+5.0),hash(clod_cell-19.0))-0.5)*0.45;
	vec2 clod_local=clod_uv-clod_jitter;
	float facet=max(abs(clod_local.x),abs(clod_local.y)*1.25);
	float facet_aa=max(fwidth(facet),0.025);
	float facet_mask=(1.0-smoothstep(0.21-facet_aa,0.34+facet_aa,facet))
		*clod_resolution*(1.0-plant_patches*0.8);
	ALBEDO*=1.0+(hash(clod_cell+71.0)-0.55)*0.48*facet_mask;
	relief+=normalize(clod_local+vec2(0.001))*facet_mask*0.8;
	float resolved=1.0-smoothstep(0.018,0.10,max(length(dFdx(p)),length(dFdy(p))));
	// Displaced 3–9 cm aggregate resolves in the near lane. Random offsets
	// avoid rows; derivative filtering removes subpixel distant highlights.
	vec2 scattered=p*6.1+vec2(noise(p*1.73),noise(p*1.91+83.0))*2.7;
	vec2 pebble_cell=floor(scattered);
	float pebble_seed=hash(pebble_cell);
	vec2 pebble_uv=fract(scattered)-0.5-
		(vec2(hash(pebble_cell+13.0),hash(pebble_cell-27.0))-0.5)*0.65;
	float pebble_edge=length(pebble_uv*vec2(1.0,1.35))-mix(0.08,0.23,pebble_seed)
		+(noise(p*81.0)-0.5)*0.09;
	float pebble_aa=max(fwidth(pebble_edge),0.035);
	float pebbles=(1.0-smoothstep(-pebble_aa,pebble_aa,pebble_edge))*resolved
		*step(0.38,hash(pebble_cell+49.0))*(1.0-plant_patches)*(1.0-tracks*0.8);
	// Both pebble layers use the same explicit-LOD density. Sample once
	// when either can contribute; keep edge derivatives unconditional.
	float access=smoothstep(36.0,38.0,p.y)*(1.0-smoothstep(53.0,56.0,p.y));
	float pebble_density=0.0;
	if (pebbles > 0.0 || access > 0.0) {
		pebble_density=smoothstep(0.34,0.67,noise(p*1.4+17.0));
	}
	pebbles*=pebble_density;
	ALBEDO=mix(ALBEDO,mix(vec3(0.075,0.071,0.059),vec3(0.16,0.15,0.125),pebble_seed),pebbles*0.55);
	relief+=pebble_uv*pebbles*3.0;
	// A fresh aggregate fan grounds the loading entrance. Its irregular edge
	// follows the apron; traffic compresses two continuous, curved wheel bands.
	float fan=0.0;
	// Breakup is bounded by +/-0.9 m. Outside this padded interval the
	// fan is exactly zero; skip its two explicit-LOD noise samples.
	if (p.y > 34.5 && p.y < 46.5) {
		float fan_width=mix(3.35,1.4,smoothstep(36.0,44.0,p.y));
		float fan_breakup=(noise(p*1.25)-0.5)*1.5+(noise(p*5.4)-0.5)*0.30;
		fan=(1.0-smoothstep(fan_width-0.35,fan_width+0.35,
			abs(p.x-(15.5+clamp(p.y-36.0,0.0,10.0)*0.05))+fan_breakup))
			*smoothstep(35.5,36.5,p.y+fan_breakup)*(1.0-smoothstep(41.5,45.5,p.y+fan_breakup));
	}
	float crumb_bank=0.0;
	if (access > 0.0) {
		crumb_bank=(1.0-smoothstep(0.045,0.15,
			abs(abs(lane-1.05)-0.23)+(noise(p*17.0)-0.5)*0.12))*access;
	}
	vec3 loading_aggregate=vec3(0.0);
	// This shared color contributes at the entrance and beside the tread.
	// Explicit-LOD samples can be skipped where both footprints are zero.
	if (fan > 0.0 || crumb_bank > 0.0) {
		if (exposed <= 0.0) {
			clods=noise(p*19.5+vec2(noise(p*2.1),noise(p*2.1+31.0))*1.8);
		}
		float wheel=1.0-smoothstep(0.10,0.18,abs(lane-1.05)+wander*0.9);
		wheel*=mix(0.32,0.85,noise(vec2(p.x*3.0,p.y*1.2)));
		loading_aggregate=mix(vec3(0.19,0.18,0.15),vec3(0.29,0.28,0.24),
			noise(p*22.5))*mix(0.94,1.04,noise(p*0.9))*mix(0.95,1.05,clods);
		loading_aggregate=mix(loading_aggregate,stone*0.56,0.42);
		loading_aggregate*=1.0+(pebble_seed-0.5)*facet_mask*0.40;
		loading_aggregate=mix(loading_aggregate,vec3(0.105,0.099,0.078)*(0.93+clods*0.14),
			wheel*0.24);
		ALBEDO=mix(ALBEDO,loading_aggregate,fan*(1.0-plant_patches*0.55)*0.72);
		relief+=clod_local*facet_mask*fan*(1.0-wheel)*0.8;
	}
	// Continuous compressed wheel beds read at walking distance. Noise varies
	// their shoulders, not their continuity; runoff follows the lower margin.
	// Outside the access strip these masks are exactly zero. The lattice
	// samples use explicit LOD, so skipping them needs no quad derivatives.
	float compacted=0.0;
	float wash=0.0;
	if (access>0.0) {
		float rut_offset=abs(lane-1.05)+(noise(p*vec2(1.6,0.65))-0.5)*0.12;
		compacted=(1.0-smoothstep(0.105,0.19,rut_offset))*access;
		float wash_offset=abs(lane-2.08+(noise(p*0.7)-0.5)*0.32);
		wash=(1.0-smoothstep(0.045,0.16,wash_offset))*access;
	}
	// Compressed earth retains the scan's granular structure. Long stretched
	// noise previously painted over it as blurry stripes at player eye height.
	// A 21 cm compressed center with a narrow loose shoulder, in world meters.
	// Preserve mineral chips instead of stacking multiple dark rut overlays.
	// The later tire-lug layer also uses this color with an access mask.
	vec3 compact_soil=vec3(0.0);
	if (access>0.0) {
		compact_soil=mix(dirt*vec3(0.53,0.49,0.40),stone*0.48,0.38);
		compact_soil*=mix(0.91,1.06,noise(p*3.8));
		ALBEDO=mix(ALBEDO,compact_soil,compacted*0.52);
	}
	ALBEDO=mix(ALBEDO,vec3(0.068,0.064,0.047),wash*0.16);
	relief*=1.0-compacted*0.42;
	// Worn 24 cm tire lugs follow the two actual lane segments. Their narrow
	// edges fade below pixel size; patchy impressions avoid a painted zipper.
	vec2 lane_axis=normalize(vec2(0.5,10.0));
	float lane_along=dot(p-vec2(15.5,36.0),lane_axis);
	// Selecting the nearer segment only needs squared distances.
	if (segment_distance_squared(p,vec2(16,46),vec2(9,52)) <
		segment_distance_squared(p,vec2(15.5,36),vec2(16,46))) {
		lane_axis=normalize(vec2(-7.0,6.0));
		lane_along=length(vec2(0.5,10.0))+dot(p-vec2(16,46),lane_axis);
	}
	// Normals follow a shallow compressed rut cross-section, in metres.
	// Derive the outward direction from the closest actual lane segment.
	vec2 lane_origin=lane_axis.x>0.0 ? vec2(15.5,36.0) : vec2(16.0,46.0);
	vec2 cross_axis=vec2(lane_axis.y,-lane_axis.x);
	float signed_lane=dot(p-lane_origin,cross_axis);
	float rut_side=lane-1.05;
	float rut_slope=sign(rut_side)*smoothstep(0.06,0.13,abs(rut_side))
		*(1.0-smoothstep(0.16,0.28,abs(rut_side)));
	relief-=cross_axis*sign(signed_lane)*rut_slope*access*0.95;
	float lug_phase=(lane_along+abs(lane-1.05)*0.65)/0.24;
	float lug_wave=sin(lug_phase*6.283185);
	float lug_aa=max(fwidth(lug_phase)*6.283185,0.06);
	float lug=(1.0-smoothstep(0.15-lug_aa,0.55+lug_aa,abs(lug_wave)));
	float print_extent=(1.0-smoothstep(0.10,0.17,abs(lane-1.05)))*access;
	float print_visibility=1.0-smoothstep(0.04,0.12,length(fwidth(p)));
	float print_mask=0.0;
	// Keep footprint derivatives unconditional; explicit-LOD wear noise
	// cannot contribute outside the compressed tread or beyond its fade.
	if (print_extent > 0.0 && print_visibility > 0.0) {
		print_mask=print_extent
			*smoothstep(0.32,0.65,noise(p*vec2(2.8,0.75)+8.0))
			*print_visibility;
	}
	ALBEDO=mix(ALBEDO,compact_soil*0.80,lug*print_mask*0.38);
	relief+=lane_axis*cos(lug_phase*6.283185)*print_mask*0.55;
	// Loose soil accumulates beside the compressed tread, at irregular widths.
	ALBEDO=mix(ALBEDO,loading_aggregate*0.76,crumb_bank*0.40);
	relief+=clod_local*facet_mask*crumb_bank*1.4;
	// Sheltered humus under the west sill joins the shrub roots to the yard.
	float sill_extent=smoothstep(25.0,26.1,p.y)*(1.0-smoothstep(32.0,33.4,p.y));
	float sill_bed=0.0;
	// Outside the sill's length the layer contributes exactly zero.
	// This explicit-LOD noise has no derivative dependency across the branch.
	if (sill_extent > 0.0) {
		sill_bed=(1.0-smoothstep(0.42,1.02,abs(p.x-11.65)+(noise(p*3.1)-0.5)*0.35))
			*smoothstep(25.0,26.1,p.y)*(1.0-smoothstep(32.0,33.4,p.y));
	}
	ALBEDO=mix(ALBEDO,dirt*vec3(0.28,0.25,0.18),sill_bed*0.76);
	// Larger embedded angular aggregate survives the ordinary grazing view.
	// Apply after traffic/soil blends so those layers cannot erase its relief.
	vec2 access_cell=floor(p*8.3);
	vec2 access_uv=fract(p*8.3)-0.5;
	float access_seed=hash(access_cell);
	access_uv-=(vec2(hash(access_cell+13.0),hash(access_cell-27.0))-0.5)*0.4;
	// Rotate and vary embedded pebbles independently; identical aligned
	// diamonds previously made a regular pattern across the approach.
	float pebble_angle=hash(access_cell+71.0)*6.283185;
	vec2 access_pebble_uv=mat2(vec2(cos(pebble_angle),sin(pebble_angle)),
		vec2(-sin(pebble_angle),cos(pebble_angle)))*access_uv;
	access_pebble_uv.x*=mix(0.75,1.65,hash(access_cell-43.0));
	float access_edge=length(access_pebble_uv)
		+noise(access_pebble_uv*12.0+access_cell)*0.045-mix(0.09,0.24,access_seed);
	float access_aa=max(fwidth(access_edge),0.035);
	float access_chips=(1.0-smoothstep(-access_aa,access_aa,access_edge))
		*(1.0-smoothstep(0.06,0.24,max(length(dFdx(p)),length(dFdy(p)))))
		*pebble_density*(1.0-compacted*0.85)
		*(1.0-plant_patches)*access;
	ALBEDO=mix(ALBEDO,stone*mix(0.51,0.72,access_seed),access_chips*0.66);
	relief+=access_uv*access_chips*0.8;
	// Millimetre grit fades with the pixel footprint, leaving the larger
	// soil structure intact in the distance instead of aliasing into sparkle.
	float grit_visibility=1.0-smoothstep(0.012,0.055,
		max(length(dFdx(p)),length(dFdy(p))));
	float surface_grit=0.0;
	// Explicit-LOD noise needs no fragment derivatives inside this branch.
	if (grit_visibility > 0.0) {
		surface_grit=noise(p*67.0)-0.5;
	}
	ALBEDO*=1.0+surface_grit*0.36*grit_visibility;
	// Broken 10–25 cm soil crust remains visible between the scan's
	// coarse colour and individual pebbles at a standing, grazing view.
	// Apply after the access blends, which otherwise erase this scale.
	vec2 crust_warp=vec2(noise(p*2.3+4.0),noise(p*2.7-15.0));
	float crust_visibility=1.0-smoothstep(0.08,0.28,
		max(length(dFdx(p)),length(dFdy(p))));
	float crust_exposed=crust_visibility*(1.0-plant_patches)*(1.0-aggregate*0.65);
	// Skip the two explicit-LOD samples once crust contributes no colour.
	// Keep warp unconditional: the fracture texture below uses implicit LOD.
	if (crust_exposed > 0.0) {
		float crust=noise(p*6.5+crust_warp*2.0)*0.65+noise(p*14.0+crust_warp)*0.35;
		float crust_pores=1.0-smoothstep(0.30,0.45,crust);
		ALBEDO*=1.0+((crust-0.5)*0.48-crust_pores*0.16)*crust_exposed;
	}
	// Fractured compacted earth: uneven polygonal clods with narrow seams,
	// rather than another smooth noise layer over the scanned soil.
	vec2 fracture_p=p*8.0+crust_warp*0.65;
	// Bake neighbour searches; retain world-space warp and footprint fading.
	vec4 fracture_sample=texture(fracture_field,fracture_p/32.0);
	vec2 clod_direction=fracture_sample.ba*2.0-1.0;
	float clod_seed=fracture_sample.g;
	float seam_distance=fracture_sample.r/8.0;
	float seam_aa=max(fwidth(seam_distance),0.001);
	float seams=1.0-smoothstep(0.001-seam_aa,0.004+seam_aa,seam_distance);
	float fracture_visibility=(1.0-smoothstep(0.025,0.085,
		max(length(dFdx(p)),length(dFdy(p)))))*crust_exposed*(1.0-compacted*0.75);
	ALBEDO*=1.0+((clod_seed-0.5)*0.24-seams*0.27)*fracture_visibility;
	relief+=clod_direction*fracture_visibility*0.65;
	NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX)*vec3(relief.x,0.0,relief.y)*0.13*resolved);
	// Broad rooted soil under the shelter verge; leave the travelled apron clear.
	float verge_z = smoothstep(27.0, 30.0, p.y) * (1.0-smoothstep(45.0, 48.0, p.y));
	float rooted = 0.0;
	// The explicit-LOD noise contributes nothing outside the verge length.
	if (verge_z > 0.0) {
		float verge_edge = min(abs(p.x-11.4), abs(p.x-20.2));
		rooted = (1.0-smoothstep(0.55, 1.85, verge_edge + (noise(p*0.8)-0.5)*0.5))*verge_z;
	}
	ALBEDO = mix(ALBEDO, ALBEDO*vec3(0.70,0.74,0.59), rooted*0.65);
	// Broad compressed tyre shoulders remain legible from standing height.
	// Preserve aggregate detail and break the edges with displaced soil.
	float wheel_wear = 0.0;
	if (access > 0.0) {
		float wheel_offset = abs(lane-1.05)+(noise(p*3.4)-0.5)*0.13;
		wheel_wear = (1.0-smoothstep(0.19,0.36,wheel_offset))*access;
		wheel_wear *= mix(0.65,1.0,noise(p*vec2(1.7,0.45)));
	}
	ALBEDO = mix(ALBEDO,ALBEDO*vec3(0.58,0.55,0.49),wheel_wear*0.70);
	ROUGHNESS=mix(mix(0.98,0.92,damp),mix(0.84,0.72,damp),compacted);
	ROUGHNESS=mix(ROUGHNESS,0.79,wheel_wear);
	// Irregular pale aggregate islands and broad damp earth at the edges
	// establish a travelled surface at eye height, without tiling decals.
	float apron_region = (1.0-smoothstep(4.0,7.0,abs(p.x-15.5)))
		* smoothstep(32.0,35.0,p.y)*(1.0-smoothstep(47.0,51.0,p.y));
	// Outside the apron these four explicit-LOD samples contribute zero.
	if (apron_region > 0.0) {
		float aggregate_islands = smoothstep(0.48,0.73,
			noise(p*0.78 + vec2(noise(p*2.3),noise(p*1.7+9.0))*0.8));
		ALBEDO = mix(ALBEDO, ALBEDO*vec3(1.27,1.24,1.17),
			aggregate_islands*apron_region*(1.0-wheel_wear)*0.75);
		float edge_damp = smoothstep(2.4,4.7,abs(p.x-15.5))
			* smoothstep(0.35,0.72,noise(p*vec2(0.8,0.37)+17.0))*apron_region;
		ALBEDO *= 1.0-edge_damp*0.25;
	}
	// Sediment spreads out from the shelter downpipes, connecting the
	// building drainage to the dirt rather than painting a uniform border.
	float pipe_runoff = 0.0;
	// Noise is in [0,1]: runoff is zero for fan >= 1.325. All four
	// supports fit inside x=[10.37,20.63], z=[24.93,33.76].
	// Use a loose bound to skip their explicit-LOD noise and fan math.
	if (p.x > 10.0 && p.x < 21.0 && p.y > 24.0 && p.y < 34.0) {
		float runoff_breakup = (noise(p*9.0)-0.5)*0.25;
		for (int side = 0; side < 2; side++) {
			float pipe_x = side == 0 ? 12.03 : 18.97;
			for (int outlet = 0; outlet < 2; outlet++) {
				float pipe_z = outlet == 0 ? 26.28 : 32.41;
				vec2 delta = p - vec2(pipe_x, pipe_z);
				float outward = delta.x * (side == 0 ? -1.0 : 1.0);
				float fan = length(vec2((outward - 0.40) / 0.95,
					delta.y / (0.22 + max(outward, 0.0) * 0.48)));
				pipe_runoff = max(pipe_runoff, (1.0-smoothstep(0.55,1.2,
					fan+runoff_breakup)));
			}
		}
	}
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.48,0.53,0.43), pipe_runoff * 0.8);
	ROUGHNESS = mix(ROUGHNESS, 0.86, pipe_runoff);
	SPECULAR=0.08;
	ALPHA=coverage;
	// Resolve graded bank/apron intersections before shading the surface.
	ALPHA_HASH_SCALE=1.0;
}
