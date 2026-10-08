shader_type spatial;
render_mode cull_disabled;
uniform sampler2D aggregate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_lattice : filter_linear, repeat_enable;
uniform vec2 access_points[17];
uniform vec3 access_projection[16];
varying vec3 world_position;
varying vec3 view_position;
float noise2(vec2 p) {
	vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	// Share the ground material's baked hash lattice. Smooth interpolation
	// preserves continuous weathering without four arithmetic hashes per sample.
	return textureLod(noise_lattice,(i+f+vec2(512.5))/1024.0,0.0).r;
}
float segment_squared(vec2 p,vec2 a,vec2 b) {
	vec2 v=b-a;
	vec2 offset=p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0);
	return dot(offset,offset);
}
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	view_position=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
	vec2 p=world_position.xz;
	// The final cutout always rejects these pixels: road_end is at least 9.
	// Avoid all sixteen path projections outside those fixed bounds.
	if(p.y<35.90 || p.x<9.0){discard;}
	float lane_squared=1000000.0;
	float along=0.0;
	vec2 nearest_offset=vec2(0.0);
	vec2 nearest_direction=vec2(1.0,0.0);
	for(int i=0;i<16;i++){
		vec2 a=access_points[i], v=access_projection[i].xy;
		float t=clamp(dot(p-a,v)*access_projection[i].z,0.0,1.0);
		vec2 offset=p-a-v*t;
		float distance_squared=dot(offset,offset);
		if(distance_squared<lane_squared){
			lane_squared=distance_squared;
			along=(float(i)+t)/16.0;
			nearest_offset=offset;
			nearest_direction=v;
		}
	}
	// half_width <= 3.40, chipped >= 0, shoulder_break >= -0.24.
	// Beyond 3.64 metres the final cutout cannot survive; keep a 0.01m
	// margin and skip width calculations and four noise samples there.
	if(lane_squared>3.65*3.65){discard;}
	// Resolve length and side once after choosing the nearest path segment.
	float lane=sqrt(lane_squared);
	float signed_lane=dot(nearest_offset,
		normalize(vec2(-nearest_direction.y,nearest_direction.x)));
	// Narrow service throat opens into a vehicle turning bell at the road.
	// Unequal shoulders follow the swept turn instead of a constant-width strip.
	float throat=mix(3.15,2.45,smoothstep(0.0,0.30,along));
	float half_width=mix(throat,3.40,smoothstep(0.34,0.86,along));
	half_width-=0.42*sin(along*3.14159265)*smoothstep(-0.3,0.6,signed_lane);
	float edge_lane=lane+(3.40-half_width);
	float chipped=noise2(p*7.0)*0.10+noise2(p*1.9)*0.18;
	float shoulder_break = (noise2(p * 1.4) - 0.5) * 0.48;
	// The mouth overlaps the asphalt shoulder; a two-metre irregular
	// aggregate transition replaces the clipped edge at the road boundary.
	float curing_noise = noise2(p * 0.85);
	float road_end = 9.0 + curing_noise * 0.45;
	if(edge_lane+chipped+shoulder_break>3.40 || p.x<road_end){discard;}
	// Blend the last half metre into the actual soil below the apron.
	// Colour-only weathering left a hard silhouette at the mesh cutout.
	float perimeter = edge_lane + chipped + shoulder_break;
	float coverage = (1.0-smoothstep(2.86,3.40,perimeter))
		*smoothstep(road_end,road_end+2.2,p.x);
	// Soil and aggregate invade a chipped edge in islands, not a uniform rim.
	float edge=max(smoothstep(2.35,3.26,perimeter),
		1.0-smoothstep(road_end,road_end+1.45,p.x));
	vec3 stone=texture(aggregate,p*2.6).rgb;
	float stone_luma=dot(stone,vec3(0.2126,0.7152,0.0722));
	stone=mix(vec3(stone_luma),stone,0.14);
	// Continuous in-situ concrete, with broad curing variation rather than
	// independent square pavers. Saw cuts follow the vehicle approach.
	float pour_tone=noise2(p*vec2(0.31,0.17));
	vec3 concrete=vec3(0.165,0.158,0.143)*mix(0.88,1.09,pour_tone);
	float gravel_noise = noise2(p * 24.0);
	concrete*=0.89+curing_noise*0.15+gravel_noise*0.07;
	// Saw cuts describe the pour boundaries below. Curing varies continuously;
	// a full-width dark rectangular pour reads as a floating platform.
	float dry_margin = smoothstep(1.5, 2.7, lane) * noise2(p * vec2(0.7, 0.3));
	concrete = mix(concrete, vec3(0.29, 0.258, 0.209), dry_margin * 0.25);
	// Irregular deposits extend from the planted verge onto the forecourt.
	// Metre-scale lobes remain visible under the canopy shadows; the centre
	// swept by tyres stays cleaner instead of tinting the entire slab.
	float soil_front=edge_lane+(noise2(p*vec2(0.85,0.48))-0.5)*1.8;
	float soil_fingers=smoothstep(1.15,2.70,soil_front);
	float soil_noise = noise2(p * 1.7);
	float settled_soil=soil_fingers*mix(0.38,0.9,soil_noise);
	concrete=mix(concrete,vec3(0.115,0.097,0.067),settled_soil*0.65);
	float runoff=noise2(p*vec2(2.8,0.27)+vec2(7.0,23.0));
	float wash=smoothstep(0.48,0.77,runoff)*smoothstep(0.65,2.1,lane);
	concrete*=1.0-wash*0.16;
	// Tracked soil spreads out from the service threshold and fades onto
	// the approach slab; metre-scale deposits survive a normal game camera.
	float threshold_zone = (1.0 - smoothstep(36.2, 40.2, p.y));
	float tire_track = 1.0 - smoothstep(0.15, 0.46, abs(abs(p.x - 15.5) - 1.03));
	float tracked_soil = threshold_zone * tire_track * (0.40 + noise2(p * vec2(5.0, 1.6)) * 0.60);
	concrete = mix(concrete, vec3(0.12, 0.106, 0.076), tracked_soil * 0.65);
	// Exposed aggregate and broad drying marks break the poured surface.
	float wear=smoothstep(0.30,0.76,noise2(p*0.72+vec2(19.0,7.0)));
	concrete=mix(concrete,stone*0.60,0.06+wear*0.08);
	// Worn cement skin exposes connected sandy islands, rather than evenly
	// distributed black grain. Decimetre shapes survive the gameplay view.
	float scoured = smoothstep(0.42,0.70,noise2(p*2.1)+noise2(p*6.7)*0.20);
	scoured *= 0.35 + wear*0.65;
	vec3 worn_cement = mix(vec3(0.145,0.137,0.118), stone*0.52,0.24);
	concrete = mix(concrete,worn_cement,scoured*0.55);
	float damp_noise = noise2(p * 1.3);
	float damp=(1.0-smoothstep(0.0,0.95,3.1-lane))*damp_noise;
	concrete*=1.0-damp*0.27;
	// Compare squared distances first; only the closest segment needs a root.
	float cut_distance=sqrt(min(segment_squared(p,vec2(12.0,40.8),vec2(19.0,40.8)),
		segment_squared(p,vec2(12.0,44.0),vec2(19.0,44.0))));
	// Retain transverse construction joints; no unsupported diagonal saw cut.
	float footprint=max(length(fwidth(p)),0.003);
	float joint=(1.0-smoothstep(0.005,0.010+footprint,cut_distance)) * min(1.0,0.016/footprint);
	// Broken aggregate shoulders surround the narrow saw-cut core.
	float joint_lip=1.0-smoothstep(0.010,0.025+footprint,cut_distance);
	float joint_grit=0.0;
	// The explicit-LOD grit sample contributes only inside the joint lip.
	if (joint_lip > 0.0) {
		joint_grit=joint_lip*smoothstep(0.33,0.72,noise2(p*17.0));
	}
	concrete=mix(concrete,stone*0.42,joint_grit*0.26 * min(1.0,0.035/footprint));
	concrete*=1.0-joint*0.48;
	float crack_noise = noise2(p * 3.0);
	float crack_line=abs(p.x-(14.25+sin(p.y*2.3)*0.09+crack_noise*0.17));
	float crack=(1.0-smoothstep(0.003,0.012+footprint,crack_line))*smoothstep(40.0,41.0,p.y)*(1.0-smoothstep(44.0,44.4,p.y));
	crack *= min(1.0,0.009/footprint);
	concrete*=1.0-crack*0.45;
	// Two worn wheel paths follow the same swept turn as the access geometry.
	// Broad rubber/soil bands remain legible from eye height; fine tread fades
	// with pixel footprint instead of becoming a moire pattern in the distance.
	float track_offset = abs(lane - (1.02 + sin(p.y * 0.37) * 0.06));
	float tire = 1.0 - smoothstep(0.17, 0.40, track_offset);
	float traffic = 0.0;
	if (tire > 0.0) {
		traffic = smoothstep(0.28,0.68,noise2(vec2(along*19.0,signed_lane*1.4)));
	}
	float tread = (1.0 - smoothstep(0.10, 0.24, abs(mod(p.y + p.x * 0.22, 0.32) - 0.16)));
	tread *= 1.0 - smoothstep(0.025, 0.09, footprint);
	concrete *= 1.0 - tire * traffic * (0.25 + tread * 0.08);
	// Exposed aggregate and irregular edge loss, with occasional repaired
	// concrete, break the otherwise perfectly uniform apron perimeter.
	float edge_loss = smoothstep(2.30, 3.12, lane + soil_noise * 0.45);
	float spall_noise = noise2(p * 3.2);
	float spall = 0.0;
	if (edge_loss > 0.0) {
		spall = smoothstep(0.49, 0.70, spall_noise + noise2(p * 12.0) * 0.18) * edge_loss;
	}
	concrete = mix(concrete, stone * vec3(0.37, 0.36, 0.32), spall * 0.74);
	vec2 patch_delta = abs(p - vec2(16.5, 43.4));
	float patch_distance = max(patch_delta.x - 0.64, patch_delta.y - 0.89);
	float patch = 0.0;
	// Nonnegative noise can only shrink the repair. Outside its filtered
	// bounds the patch has zero weight; keep footprint derivatives above.
	if (patch_distance < 0.04 + footprint) {
		patch = 1.0 - smoothstep(-0.03, 0.04 + footprint,
			patch_distance + noise2(p * 11.0) * 0.085);
	}
	concrete = mix(concrete, concrete * 0.72 + vec3(0.019, 0.020, 0.018), patch * 0.85);
	// Continue the existing pour across the approach. Drainage is represented
	// by the physical entrance grate, not a synthetic full-width repair strip.
	// A broom finish, rubbed away in the wheel paths, gives nearby concrete
	// a directional physical scale. Filter the grooves before they alias.
	float broom_visibility = 1.0-smoothstep(0.004,0.025,footprint);
	// Explicit-LOD noise is safe inside these branches. Keep screen-space
	// derivatives outside: distant pixels need no already-faded microdetail.
	float broom = 0.0;
	if (broom_visibility > 0.0) {
		broom = sin(p.y*760.0 + crack_noise*2.0);
	}
	float broom_strength = broom_visibility*(1.0-tire*0.8);
	concrete *= 1.0+broom*0.055*broom_strength;
	// Faded vehicle guidance and a stop bar explain the apron at eye level.
	// Paint is embedded in the surface, so it adds no collision or decal flicker.
	float guide_squared=min(segment_squared(p,vec2(13.45,37.1),vec2(13.45,43.0)),
		segment_squared(p,vec2(17.55,37.1),vec2(17.55,43.0)));
	float bar_squared=segment_squared(p,vec2(13.45,37.1),vec2(17.55,37.1));
	float paint=1.0-smoothstep(0.045,0.075+footprint,sqrt(min(guide_squared,bar_squared)));
	// Outside the antialiased marking, both wear samples have zero weight.
	if (paint > 0.0) {
		float missing=smoothstep(0.29,0.62,noise2(p*18.0)+spall_noise*0.23);
		paint*=missing*(0.46+noise2(p*0.9)*0.24)*(1.0-joint);
	}
	concrete=mix(concrete,vec3(0.43,0.32,0.105),paint);
	vec3 shoulder=stone*vec3(0.46,0.48,0.45);
	float roots=smoothstep(2.98,3.36,lane+chipped);
	if (roots > 0.0) {
		roots*=smoothstep(0.46,0.69,noise2(p*1.55+vec2(31.0,7.0)));
	}
	shoulder=mix(shoulder,vec3(0.065,0.084,0.043),roots*0.55);
	// Windblown soil collects in broad irregular tongues from the meadow.
	// Keep the wheel corridor legible, with a continuous dirt-to-gravel fade.
	float deposit=smoothstep(1.65,3.20,lane+noise2(p*0.78)*0.85);
	if (deposit > 0.0) {
		deposit*=smoothstep(0.23,0.73,noise2(p*1.35)+noise2(p*4.8)*0.24);
	}
	vec3 silt=mix(vec3(0.145,0.109,0.068),stone*vec3(0.61,0.49,0.32),0.48);
	concrete=mix(concrete,silt,deposit*0.78);
	shoulder=mix(shoulder,silt,0.50+deposit*0.24);
	// Centimetre aggregate is confined to eroded patches, with larger
	// sandy exposures visible at eye height and grain fading in the distance.
	float exposed=smoothstep(0.40,0.72,noise2(p*2.7)+wear*0.17);
	float aggregate_visibility=1.0-smoothstep(0.025,0.12,footprint);
	float chips=0.0;
	float aggregate_relief=0.0;
	float gravel_relief=0.0;
	if (aggregate_visibility > 0.0) {
		chips=smoothstep(0.52,0.76,noise2(p*37.0));
		aggregate_relief=noise2(p*32.0)*0.0002+deposit*noise2(p*15.0)*0.001;
		gravel_relief=gravel_noise*0.006;
	}
	concrete=mix(concrete,vec3(0.245,0.235,0.215),chips*exposed*0.14*aggregate_visibility);
	concrete*=1.0-(1.0-chips)*exposed*0.05*aggregate_visibility;
	// Fine mineral grains resolve near the player and fade before aliasing.
	float grain_visibility=1.0-smoothstep(0.008,0.035,footprint);
	float mineral=0.0;
	if (grain_visibility > 0.0) {
		mineral=noise2(p*85.0);
	}
	concrete*=1.0+(mineral-0.5)*0.08*grain_visibility;
	// Dirt collects at the two entrance jambs, tapering into the traffic lane.
	float jamb=sqrt(min(segment_squared(p,vec2(13.60,36.0),vec2(13.60,38.6)),segment_squared(p,vec2(17.40,36.0),vec2(17.40,38.6))));
	// Noise is nonnegative, so beyond the dirt radius its weight is zero.
	float jamb_dirt=0.0;
	if (jamb < 0.48) {
		jamb_dirt=1.0-smoothstep(0.04,0.48,jamb+noise2(p*8.0)*0.10);
	}
	concrete=mix(concrete,silt*0.65,jamb_dirt*0.70);
	// Only the workshop threshold is paved. Beyond its broken edge,
	// compacted wheel tracks cross a raised, loose aggregate centre.
	float gravel_mix=smoothstep(38.8,41.2,p.y+(damp_noise-0.5)*1.25);
	float wheel_bed=1.0-smoothstep(0.18,0.55,abs(abs(signed_lane)-1.08));
	vec3 gravel_color=mix(silt,stone*vec3(0.52,0.48,0.39),0.62);
	gravel_color*=0.82+noise2(p*5.0)*0.30;
	gravel_color=mix(gravel_color,silt*0.72,wheel_bed*0.67);
	concrete=mix(concrete,gravel_color,gravel_mix);
	ALBEDO=mix(concrete,shoulder,edge);
	ALPHA=coverage;
	// Interleaved ground meshes need per-pixel depth, not whole-mesh sorting.
	ALPHA_HASH_SCALE=1.0;
	AO=1.0-jamb_dirt*0.28-joint*0.12;
	// Derivative bump in the plane tangent frame: coarse aggregate catches
	// sunlight while the antialiased joint reads as a shallow recessed cut.
	float height=broom*0.00035*broom_strength+chips*exposed*0.0006*aggregate_visibility+aggregate_relief*aggregate_visibility+mineral*0.0002*grain_visibility+wear*0.004-scoured*0.002-joint*0.006-spall*0.012-joint_grit*0.004;
	height=mix(height,gravel_relief*aggregate_visibility*(1.0-wheel_bed*0.7),gravel_mix);
	vec3 dpdx=dFdx(view_position), dpdy=dFdy(view_position);
	vec3 r1=cross(dpdy,NORMAL), r2=cross(NORMAL,dpdx);
	float det=dot(dpdx,r1);
	NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(height)*r1+dFdy(height)*r2));
	ROUGHNESS=mix(mix(0.84-wear*0.08,0.99,gravel_mix),0.99,edge); SPECULAR=0.18;
}
