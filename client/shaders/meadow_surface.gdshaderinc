// Shared terrain evaluation: road shoulders and yards must meet without material seams.
// Keep the shared road/ground evaluation mip-filtered. Anisotropic sampling
// inside the combined road shader is prohibitively expensive on llvmpipe.
uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D colony_map : filter_linear, repeat_disable;
uniform sampler2D noise_lattice : filter_linear, repeat_enable;
uniform bool cached_noise = false;
// Integer-cell hash without large sine products (stable on oblique terrain).
float cell_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float ground_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	// The integer hashes are baked once. Hardware interpolation preserves the
	// same cubic value noise without evaluating four hashes per sample.
	if (cached_noise) {
		return textureLod(noise_lattice, (i + f + vec2(512.5)) / 1024.0, 0.0).r;
	}
	return mix(mix(cell_hash(i),cell_hash(i+vec2(1,0)),f.x),
		mix(cell_hash(i+vec2(0,1)),cell_hash(i+vec2(1,1)),f.x),f.y);
}
float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b-a;
	return length(p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0));
}
float drainage_scar(vec2 p, vec4 scar) {
	vec2 q = (p - scar.xy) / scar.zw;
	q.y += sin(p.x * 1.7) * 0.14;
	return 1.0 - smoothstep(0.70, 1.45, length(q));
}
// A shared network boundary keeps the road mesh and ground's mineral coverage
// continuous, including the swept service entrance.
float road_surface_distance(vec2 p) {
	return min(min(abs(p.x)-6.0,abs(p.y)-6.0),
		segment_distance(p,vec2(5.0,49.2),vec2(12.0,47.7))-2.5);
}
float road_surface_erosion(vec2 p) {
	return (ground_noise(p*0.55)-0.5)*1.4+(ground_noise(p*2.1)-0.5)*0.35;
}
// Metre-scale field encroachment varies the mineral shoulder's width. Keep
// the paved edge fixed; the same boundary serves terrain and road shading.
float road_verge_distance(vec2 p) {
	float distance = road_surface_distance(p);
	float mapped_distance = texture(colony_map, (p+vec2(109.0))/218.0).g*32.0-16.0;
	float within_map = 1.0-smoothstep(107.0,109.0,max(abs(p.x),abs(p.y)));
	float encroachment=(ground_noise(p*0.19+vec2(7.0,19.0))-0.35)*3.8;
	encroachment*=smoothstep(-2.4,-0.5,distance);
	return mix(distance,mapped_distance,within_map)+encroachment;
}
void sample_meadow(vec3 world_position, vec3 surface_normal, mat3 world_to_view,
	out vec3 surface_color, out vec3 relief_normal, out float surface_roughness) {
	vec2 p = world_position.xz;
	// Blend independent orientations in world space: colour and relief share
	// coordinates and weights so the moss scan cannot emboss parallel furrows.
	mat2 turn_b = mat2(vec2(0.6,0.8),vec2(-0.8,0.6));
	mat2 turn_c = mat2(vec2(-0.8,0.6),vec2(-0.6,-0.8));
	vec2 uv_a = p*1.2;
	vec2 uv_b = turn_b*p*1.13+vec2(11.3,7.8);
	vec2 uv_c = turn_c*p*1.27+vec2(3.7,19.2);
	vec3 weights = vec3(ground_noise(p*0.43),ground_noise(p*0.43+17.0),ground_noise(p*0.43+39.0));
	weights = pow(weights+vec3(0.12),vec3(3.0));
	weights /= dot(weights,vec3(1.0));
	vec3 scan = texture(soil,uv_a).rgb*weights.x + texture(soil,uv_b).rgb*weights.y + texture(soil,uv_c).rgb*weights.z;
	// The scanned moss was excessively yellow across bare yards. Preserve
	// its relief and detail while bringing exposed soil toward cool loam.
	float luminance = dot(scan, vec3(0.2126,0.7152,0.0722));
	scan = mix(vec3(luminance),scan,0.32) * vec3(0.91,0.96,0.94);
	float broad = ground_noise(p * 0.065 + ground_noise(p * 0.21) * 1.8);
	float road_distance = road_surface_distance(p);
	float erosion_road = road_surface_erosion(p);
	float edge = road_verge_distance(p) + erosion_road;
	float mapped = texture(colony_map, (p+vec2(109.0))/218.0).r;
	float within_map = 1.0-smoothstep(107.0,109.0,max(abs(p.x),abs(p.y)));
	float meadow = mix(smoothstep(0.36,0.64,broad), mapped, within_map) * smoothstep(-1.4,0.6,edge);
	// The walkable berms use this same world-space surface, without UV seams.
	// Elevation alone must not paint the graded shoulder as a green ribbon.
	// Recovery follows the same world-space colonies as the adjacent field.
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float detail_visibility = 1.0 - smoothstep(0.025, 0.16, footprint);
	// Low ground cover reads as irregular patches at walking distance.
	// Millimetre-scale contrast produced stippling under oblique projection.
	float grain = mix(0.5, ground_noise(p * 3.0), detail_visibility);
	// Metre-scale loam and pale aggregate_weight remain legible beyond normal-map
	// range. Warp the patches to avoid circular ground_noise islands across the yard.
	vec2 soil_warp = vec2(ground_noise(p*0.19+12.0),ground_noise(p*0.23-7.0));
	float deposit = ground_noise(p*0.28+soil_warp*2.4);
	float damp = smoothstep(0.51,0.76,ground_noise(p*0.11+soil_warp));
	vec3 earth = scan * mix(vec3(0.61,0.55,0.45),vec3(0.73,0.67,0.56),
		smoothstep(0.25,0.72,deposit));
	earth *= 1.0-damp*0.14;
	// Exposed loam varies on a 1–4 metre scale as well as at texel scale.
	float dry_silt = smoothstep(0.43,0.65,deposit)*(1.0-damp);
	earth = mix(earth,scan*vec3(0.89,0.78,0.59),dry_silt*0.38);
	float patches = ground_noise(p * 0.37 + vec2(ground_noise(p * 0.13), ground_noise(p * 0.17 + 23.0)) * 3.0);
	// Dry stems and exposed humus should retain tonal detail in open shade.
	// Keep the plant colony mask, but avoid crushing the scanned microdetail
	// into an almost uniform dark olive surface.
	vec3 litter = mix(vec3(0.080,0.084,0.047),vec3(0.145,0.143,0.086),patches);
	// These reflectance constants are linear; source_color textures above
	// already use the renderer's working space. Convert only the constants
	// in Compatibility, as for the neighbouring grass and asphalt.
	if (OUTPUT_IS_SRGB) {
		litter = mix(litter * 12.92,
			1.055 * pow(litter,vec3(1.0/2.4)) - 0.055,
			step(vec3(0.0031308),litter));
	}
	// Scanned litter supplies organic detail instead of a uniform painted bank.
	litter *= mix(0.80,1.40,clamp(luminance * 2.4,0.0,1.0));
	litter *= mix(0.92,1.08,grain);
	// Dense cover owns its colour; photographed soil remains in worn gaps.
	float cover = meadow * 0.92;
	// Exposed elevated flanks break the continuous green carpet into eroded
	// loam and grass. World-scale variation stays stable at walking distance.
	float bank_exposure = smoothstep(0.14,0.65,world_position.y)
		* smoothstep(0.38,0.69,ground_noise(p*0.85+soil_warp*1.8));
	float gaps = max(smoothstep(0.44,0.72,patches) * 0.62, bank_exposure * 0.88);
	surface_color = mix(earth,litter,cover * (1.0-gaps));
	// A low litter transition joins plant colonies to worn soil without
	// covering the access paths or changing their collision surface.
	float colony_fringe = smoothstep(0.16,0.66,meadow)
		* smoothstep(0.30,0.65,patches);
	surface_color = mix(surface_color, litter * 0.85,colony_fringe*0.32);
	float lane = min(segment_distance(p,vec2(-10,50),vec2(-35,48)),
		segment_distance(p,vec2(-35,48),vec2(-42,42)));
	lane = min(lane, min(segment_distance(p,vec2(15.5,36),vec2(16,46)),
		segment_distance(p,vec2(16,46),vec2(9,52))));
	// Loading access joins the existing service lane and warehouse doorway.
	lane = min(lane, min(segment_distance(p,vec2(16,46),vec2(27,47)),
		segment_distance(p,vec2(27,47),vec2(35,42))));
	float erosion = (ground_noise(p*0.7)-0.5)*1.4 + (ground_noise(p*3.1)-0.5)*0.45;
	float apron = 1.0-smoothstep(1.9,3.5,lane + erosion);
	float ruts = 1.0-smoothstep(0.20,0.52,abs(lane-1.25) + (ground_noise(p*5.0)-0.5)*0.16);
	vec3 stone = texture(gravel,p*2.4).rgb;
	stone = mix(vec3(dot(stone,vec3(0.2126,0.7152,0.0722))),stone,0.18);
	// Keep photographed aggregate_weight in the worn surface instead of a solid band.
	float aggregate_weight = apron * mix(0.55,0.95,ground_noise(p*0.9));
	vec3 compacted = mix(scan*vec3(0.57,0.52,0.43),stone*0.53,aggregate_weight);
	// Decimetre soil clods survive mip filtering at ordinary walking views.
	float clods = smoothstep(0.25,0.75,ground_noise(p*5.5+soil_warp));
	compacted *= mix(0.82,1.13,clods);
	compacted *= mix(0.83,1.08,ground_noise(p*0.8)) * (1.0-ruts*0.36);
	float loose_chips = smoothstep(0.38,0.66,ground_noise(p*0.65+soil_warp*2.3))*(1.0-ruts);
	compacted = mix(compacted,stone*vec3(0.83,0.77,0.63),loose_chips*0.72);
	// Centimetre aggregate_weight breaks the blurred loam at eye height; derivative
	// filtering fades stones before they become distant sparkling pixels.
	// 12.5 cm cells yield roughly 3–7 cm chips instead of oversized cobbles.
	vec2 chip_cell = floor(p*8.0);
	vec2 chip_uv = fract(p*8.0)-vec2(0.5);
	float chip_seed = cell_hash(chip_cell);
	chip_uv -= (vec2(cell_hash(chip_cell+13.0),cell_hash(chip_cell-27.0))-0.5)*0.4;
	float chip_edge = max(abs(chip_uv.x)*0.92+abs(chip_uv.y)*0.52,
		abs(chip_uv.y)*1.2+abs(chip_uv.x)*0.25)-mix(0.12,0.29,chip_seed);
	float chip_aa = max(fwidth(chip_edge),0.035);
	float chips = (1.0-smoothstep(-chip_aa,chip_aa,chip_edge))*(1.0-smoothstep(0.025,0.10,footprint))
		*smoothstep(0.34,0.67,ground_noise(p*1.4+17.0));
	compacted = mix(compacted,stone*mix(0.42,0.79,chip_seed),chips*(1.0-ruts*0.75)*0.85);
	float recovery = (1.0-smoothstep(0.25,0.85,lane))*smoothstep(0.34,0.66,ground_noise(p*1.3));
	surface_color = mix(surface_color,compacted,apron*(1.0-recovery*0.65));
	// Match the asphalt's aggregate_weight at the mesh join, then let an irregular
	// loose shoulder break into loam and low grass over the next two metres.
	float shoulder_cover = 1.0-smoothstep(-1.2,0.4,road_verge_distance(p)+erosion_road);
	// Match the road's gravel scale and broad moist deposits at the mesh join.
	vec3 shoulder_scan=texture(gravel,p*0.65).rgb;
	shoulder_scan=mix(vec3(dot(shoulder_scan,vec3(0.2126,0.7152,0.0722))),shoulder_scan,0.18);
	shoulder_scan*=mix(vec3(0.69,0.72,0.70),vec3(1.0),smoothstep(0.28,0.72,ground_noise(p*0.09+vec2(17.0,5.0))));
	vec3 shoulder = shoulder_scan*vec3(0.48,0.45,0.38)*mix(0.83,1.08,ground_noise(p*0.8));
	surface_color = mix(surface_color,shoulder,shoulder_cover);
	// Excavated banks are a different substrate from the flat aggregate
	// shoulder. Height and actual geometric slope localize washed stones,
	// retained silt and plant recovery; raised entrance causeways remain dry.
	float excavation = smoothstep(0.08,0.32,-world_position.y);
	vec3 ground_up = world_to_view * vec3(0.0,1.0,0.0);
	float bank_slope = 1.0-clamp(dot(normalize(surface_normal),ground_up),0.0,1.0);
	float silt_bed = smoothstep(0.62,0.88,-world_position.y)
		*(1.0-smoothstep(0.035,0.16,bank_slope));
	float bank_colonies = smoothstep(0.33,0.67,
		ground_noise(p*0.39+soil_warp*2.0))
		*(1.0-smoothstep(0.10,0.30,bank_slope))*(1.0-silt_bed);
	vec3 washed_bank = mix(earth,stone*vec3(0.66,0.65,0.60),
		smoothstep(0.04,0.24,bank_slope)*0.8);
	washed_bank=mix(washed_bank,litter,bank_colonies*0.86);
	washed_bank=mix(washed_bank,earth*0.64,silt_bed*0.88);
	surface_color=mix(surface_color,washed_bank,excavation);
	// Match the service verge's vegetation gaps with exposed runoff sediment.
	float drainage = max(drainage_scar(p, vec4(10.9,39.2,2.3,0.95)),
		drainage_scar(p, vec4(11.4,44.3,2.4,1.2)));
	drainage = max(drainage, drainage_scar(p, vec4(21.4,40.5,3.2,1.05)));
	drainage = max(drainage, drainage_scar(p, vec4(23.1,44.0,2.7,0.85)));
	drainage = max(drainage, drainage_scar(p, vec4(21.8,51.5,2.4,0.85)));
	float runoff = 1.0-smoothstep(0.06,0.23,abs(sin(p.y*5.0+ground_noise(p*0.43)*4.0)));
	vec3 sediment = mix(scan*vec3(0.65,0.49,0.33),stone*vec3(0.66,0.59,0.46),
		smoothstep(0.3,0.7,deposit));
	sediment *= mix(0.86,1.15,clods);
	sediment *= 1.0-runoff*0.23;
	surface_color = mix(surface_color,sediment,drainage*(1.0-apron)*(1.0-shoulder_cover));
	// Litter beneath the actual western grove; a warped elliptical edge
	// keeps the road and northern pipe clearing free of a rectangular stain.
	vec2 grove_uv = (p-vec2(-21.5,21.5))/vec2(9.0,10.0);
	float grove_litter = (1.0-smoothstep(0.60,1.05,length(grove_uv)+(ground_noise(p*0.7)-0.5)*0.26))
		*(1.0-shoulder_cover)*(1.0-apron);
	vec3 grove_litter_color = scan*vec3(0.48,0.40,0.28)*mix(0.86,1.16,ground_noise(p*7.0));
	surface_color = mix(surface_color,grove_litter_color,grove_litter*0.64);
	// Continue the access yard's decimetre crust into exposed meadow soil.
	vec2 crust_warp=vec2(ground_noise(p*2.3+4.0),ground_noise(p*2.7-15.0));
	float crust=ground_noise(p*6.5+crust_warp*2.0)*0.65+ground_noise(p*14.0+crust_warp)*0.35;
	float crust_visibility=(1.0-smoothstep(0.08,0.28,footprint))
		*(1.0-meadow*0.8)*(1.0-shoulder_cover*0.65);
	float crust_pores=1.0-smoothstep(0.30,0.45,crust);
	surface_color*=1.0+((crust-0.5)*0.48-crust_pores*0.16)*crust_visibility;
	// World-aligned relief also follows sloping berms; geometry stays walkable.
	vec2 soil_relief = (texture(soil_normal,uv_a).xy*2.0-1.0)*weights.x;
	soil_relief += transpose(turn_b)*(texture(soil_normal,uv_b).xy*2.0-1.0)*weights.y;
	soil_relief += transpose(turn_c)*(texture(soil_normal,uv_c).xy*2.0-1.0)*weights.z;
	vec2 relief = mix(soil_relief * mix(0.8,0.32,meadow),
		texture(gravel_normal,p*2.4).xy*2.0-1.0,aggregate_weight);
	relief += chip_uv*chips*apron*(1.0-recovery)*3.0;
	relief_normal = normalize(surface_normal + world_to_view*vec3(relief.x,0.0,relief.y)*mix(0.015, 0.12, detail_visibility));
	// Damp loam is subtly smoother; this is soil, never a mirror puddle.
	surface_roughness = mix(0.98,0.82,damp*(1.0-apron));
}
