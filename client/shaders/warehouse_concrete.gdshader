shader_type spatial;
render_mode cull_disabled;

uniform vec3 building_origin;
uniform bool slab_joints = false;
uniform bool shelter_apron = false;
uniform bool doorway_apron = false;
uniform bool service_bay = false;
uniform bool depot_apron = false;
varying vec3 world_position;

float concrete_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(concrete_hash(i), concrete_hash(i + vec2(1, 0)), f.x),
		mix(concrete_hash(i + vec2(0, 1)), concrete_hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz - building_origin.xz;
	float cloud = noise(world_position.xz * 0.65);
	// Fade subpixel aggregate rather than letting it sparkle during a walk.
	// Compare squared lengths first: one square root, identical fade distances.
	vec2 footprint_dx = dFdx(world_position.xz);
	vec2 footprint_dy = dFdy(world_position.xz);
	float footprint = sqrt(max(dot(footprint_dx, footprint_dx), dot(footprint_dy, footprint_dy)));
	float fine_visibility = 1.0 - smoothstep(0.008, 0.045, footprint);
	float fine = 0.5;
	// Once filtered out, these procedural samples contribute nothing.
	if (fine_visibility > 0.0) {
		fine = mix(0.5, noise(world_position.xz * 65.0), fine_visibility);
	}
	// Smooth cast concrete: fine aggregate is subtle, dirt follows the doors.
	vec3 base = vec3(0.17, 0.18, 0.17) * (0.94 + cloud * 0.10 + fine * 0.025);
	float entry = smoothstep(2.5, 6.7, abs(p.y)) * (1.0 - smoothstep(1.0, 2.2, abs(p.x)));
	// Masks cover narrow traffic zones; avoid noise outside their support.
	if (entry > 0.0) {
		float dust = entry * (0.25 + 0.75 * noise(world_position.xz * 2.2));
		base = mix(base, vec3(0.23, 0.215, 0.18), dust * 0.42);
	}
	float tracks = (1.0 - smoothstep(0.09, 0.20, abs(abs(p.x) - 0.72)))
		* smoothstep(1.0, 5.8, abs(p.y));
	if (tracks > 0.0) {
		base *= 1.0 - tracks * 0.10 * noise(world_position.xz * 8.0);
	}
	// Restrained curing variation, with swept traffic and dusty wall margins.
	float patch = smoothstep(0.30, 0.72, noise(world_position.xz * 0.37 + noise(world_position.xz * 1.3)));
	base *= mix(0.95, 1.025, patch);
	float margin = smoothstep(5.7, 7.6, abs(p.x));
	base = mix(base, vec3(0.245, 0.23, 0.20), margin * 0.32);
	float swept_mask = 1.0 - smoothstep(1.3, 2.6, abs(p.x));
	if (swept_mask > 0.0) {
		float swept = swept_mask * noise(world_position.xz * 1.7);
		base *= 1.0 - swept * 0.08;
	}
	if (fine_visibility > 0.0) {
		float aggregate = smoothstep(0.64, 0.82, noise(world_position.xz * 110.0));
		base *= 1.0 - aggregate * 0.065 * fine_visibility;
	}
	// Centimetre-scale exposed aggregate survives the entrance camera distance;
	// keep finer pores filtered so movement does not turn them into glitter.
	float grit_visibility = 1.0 - smoothstep(0.035, 0.12, footprint);
	float grit = 0.5;
	if (grit_visibility > 0.0) {
		grit = noise(p * 28.0);
		base *= 1.0 + (grit - 0.5) * (shelter_apron || slab_joints ? 0.16 : 0.28) * grit_visibility;
	}
	if (slab_joints) {
		// Broad worn cement and curing patches replace the repeated gravel look.
		float curing = smoothstep(0.27,0.76,noise(p*0.42+vec2(11.0,3.0)));
		base *= mix(0.91,1.05,curing);
		vec2 slab_id = floor(vec2((p.x + 2.0) / 4.0, (p.y + 3.0) / 6.0));
		// Integer lattice coordinates: value noise reduces to its first hash.
		base *= mix(0.91, 1.07, concrete_hash(slab_id + 41.0));
		// Noise displaces the strip by at most 0.275 m. Outside that
		// support its weight is zero; the inner core is always fully worn.
		float traffic = 0.0;
		if (abs(p.x) < 0.524) {
			traffic = 1.0;
		} else if (abs(p.x) < 2.376) {
			traffic = 1.0-smoothstep(0.8,2.1,abs(p.x+(noise(p*0.6)-0.5)*0.55));
		}
		base = mix(base,vec3(0.155,0.162,0.151),traffic*0.32);
		// Dirt collects against side walls and rear wall panels, not across doors.
		float side_contact = 1.0 - smoothstep(0.0, 0.38, 7.65 - abs(p.x));
		float end_contact = (1.0 - smoothstep(0.0, 0.30, 6.35 - abs(p.y)))
			* smoothstep(1.8, 2.2, abs(p.x));
		float wall_contact = max(side_contact, end_contact);
		// Skip procedural detail only where its spatial weight is exactly zero.
		if (wall_contact > 0.0) {
			base *= 1.0 - wall_contact * (0.22 + noise(p * 9.0) * 0.16);
		}
	}
	if (slab_joints) {
		// Faded aisle paint is part of the slab, with no raised collision strips.
		float paint_edge = abs(abs(p.x) - 1.70);
		float aa = max(fwidth(paint_edge), 0.003);
		float paint = (1.0 - smoothstep(0.045, 0.045 + aa, paint_edge))
			* (1.0 - smoothstep(5.8, 6.1, abs(p.y)));
		// Outside the painted stripe the chip noise contributes exactly zero.
		if (paint > 0.0) {
			float chips = smoothstep(0.24, 0.53, noise(p * 23.0));
			base = mix(base, vec3(0.34, 0.245, 0.065), paint * chips * 0.70);
		}
		// Uneven oil absorption stays in the service bay beside the clear aisle.
		vec2 stain_p = (p - vec2(4.4, -0.8)) / vec2(2.0, 2.8);
		// Noise is nonnegative; reject outside the ellipse before taking a square root.
		if (dot(stain_p, stain_p) < 1.0) {
			float stain_radius = length(stain_p);
			float stain = 1.0 - smoothstep(0.28, 1.0, stain_radius + noise(p*2.7)*0.30);
			base *= 1.0 - stain * 0.40;
		}
		// The sinusoidal offset is bounded by 0.20; beyond 1.25 the mask is zero.
		float wheel = 0.0;
		// The center strip stays outside both tracks even at maximum sway.
		if (abs(p.x) > 0.389 && abs(p.x) < 1.251) {
			wheel = 1.0 - smoothstep(0.10,0.23,abs(abs(p.x + sin(p.y*0.23)*0.20)-0.82));
		}
		if (wheel > 0.0) {
			base *= 1.0 - wheel * noise(p*3.0) * 0.20;
		}
		float along_x = abs(p.x - 4.0 * round(p.x / 4.0));
		float along_z = abs(abs(p.y) - 3.0);
		float distance_to_joint = min(along_x, along_z);
		float pixel_width = max(fwidth(distance_to_joint), 0.002);
		float joint = 1.0 - smoothstep(0.006, 0.006 + pixel_width, distance_to_joint);
		// Pixel coverage and low contrast keep the center seam from becoming
		// a continuous black stripe at grazing camera angles.
		joint *= min(1.0, 0.012 / pixel_width);
		base *= 1.0 - 0.16 * joint;
	}
	if (slab_joints) {
		// Broad wheel wear crosses the ramp and continues through the doorway.
		float travel = smoothstep(2.0, 5.0, abs(p.y));
		// The sinusoidal displacement is at most 0.06 m: outside 1.16 m
		// the track is zero. Keep 1 mm slack at the support boundary.
		if (travel > 0.0 && abs(p.x) < 1.161) {
			float track = 1.0 - smoothstep(0.12, 0.32, abs(abs(p.x + sin(p.y * 0.4) * 0.06) - 0.78));
			if (track > 0.0) {
				base = mix(base, vec3(0.095, 0.09, 0.073), track * travel * (0.30 + noise(p * vec2(7.0, 1.1)) * 0.28));
			}
		}
		// Settled dust at the known cover crate footprint; feather beyond its feet.
		vec2 crate_delta = abs(p - vec2(-4.0, 0.0)) - vec2(0.95, 1.45);
		float contact = 1.0 - smoothstep(0.0, 0.24, max(crate_delta.x, crate_delta.y));
		base *= 1.0 - contact * 0.28;
	}
	if (doorway_apron) {
		float edge = min(1.95 - abs(p.x), 7.65 - abs(p.y));
		float sediment = 0.0;
		// noise is in [0, 1]; past this conservative bound sediment is zero.
		if (edge < 0.676) {
			sediment = 1.0 - smoothstep(0.02, 0.55, edge + (noise(p * 4.0) - 0.5) * 0.25);
		}
		base = mix(base, vec3(0.19, 0.145, 0.085), sediment * 0.68);
		float seam_distance = abs(abs(p.y) - 6.39);
		float aa = max(fwidth(seam_distance), 0.003);
		float seam = (1.0 - smoothstep(0.014, 0.014 + aa, seam_distance)) * min(1.0, 0.028 / aa);
		base *= 1.0 - seam * 0.50;
		base *= mix(0.90, 1.09, noise(p * 2.1));
	}
	float apron_wet = 0.0;
	if (shelter_apron) {
		// Exposed slab: irregular soil ingress follows its actual 6.3 x 10 m edge.
		float edge = min(3.15 - abs(p.x), 5.0 - abs(p.y));
		float dirt = 0.0;
		// Keep all derivative calculations outside this spatially varying branch.
		if (edge < 1.081) {
			dirt = 1.0 - smoothstep(0.03, 0.95, edge + (noise(p * 5.0) - 0.5) * 0.26);
		}
		base = mix(base, vec3(0.145, 0.12, 0.08), dirt * 0.72);
		// Separate pours and worn bay guides read at the normal entrance distance.
		vec2 panel = floor(vec2((p.x + 3.15) / 3.15, (p.y + 5.0) / 3.33));
		// panel is floored, so interpolation and the other three hashes vanish.
		base *= mix(0.95, 1.04, concrete_hash(panel + vec2(17.0, 31.0)));
		float edge_dust = smoothstep(0.4, 2.8, abs(p.x));
		// The central clean strip has no dust contribution.
		if (edge_dust > 0.0) {
			edge_dust *= smoothstep(0.35, 0.72, noise(p * vec2(0.7, 1.3) + vec2(21.0, 4.0)));
		}
		base = mix(base, vec3(0.24, 0.205, 0.145), edge_dust * 0.45);
		float guide = 1.0 - smoothstep(0.045, 0.045 + max(fwidth(p.x), 0.003), abs(abs(p.x) - 1.85));
		guide *= smoothstep(-1.0, 0.0, p.y) * (1.0 - smoothstep(4.3, 4.5, p.y));
		if (guide > 0.0) {
			base = mix(base, vec3(0.40, 0.30, 0.10), guide * smoothstep(0.26, 0.53, noise(p * 32.0)) * 0.76);
		}
		float joint_distance = min(abs(p.x), abs(abs(p.y) - 1.65));
		float aa = max(fwidth(joint_distance), 0.003);
		float joint = (1.0 - smoothstep(0.014, 0.014 + aa, joint_distance))
			* min(1.0, 0.028 / aa);
		// Dust collects beside real pour joints; narrow cut remains antialiased.
		float joint_dust = 1.0 - smoothstep(0.025, 0.14, joint_distance);
		base = mix(base, vec3(0.115, 0.105, 0.081), joint_dust * 0.32);
		base *= 1.0 - joint * 0.26;
		vec2 oil_p = (p - vec2(2.0, -1.5)) / vec2(0.65, 1.25);
		// Noise is nonnegative: outside this radius the stain is exactly zero.
		// Test squared radius so pixels outside the stain need no square root.
		float oil = 0.0;
		if (dot(oil_p, oil_p) < 1.0) {
			oil = 1.0 - smoothstep(0.25, 1.0, length(oil_p) + noise(p * 6.0) * 0.35);
		}
		base *= 1.0 - oil * 0.48;
		float tread = 1.0 - smoothstep(0.10, 0.27, abs(abs(p.x) - 0.87));
		float tread_length = smoothstep(-2.0, 3.0, p.y);
		if (tread > 0.0 && tread_length > 0.0) {
			base = mix(base, vec3(0.13, 0.115, 0.09),
				tread * (0.55 + noise(p * vec2(5.0, 0.7)) * 0.45) * tread_length * 0.68);
		}
		// Tracked soil fans out from each wheel path at the yard threshold.
		// Its broken boundary reads as use rather than another rectangular pour.
		float entrance = smoothstep(1.2, 4.7, p.y);
		float tracked_soil = 0.0;
		// Noise displaces the boundary by at most 0.175 m. Keep a
		// 0.001 m margin and skip both noise fields outside its support.
		if (entrance > 0.0 && abs(abs(p.x) - 0.95) < 0.896) {
			float track_spread = 1.0 - smoothstep(0.25, 0.72,
				abs(abs(p.x) - 0.95) + (noise(p * 3.7) - 0.5) * 0.35);
			if (track_spread > 0.0) {
				tracked_soil = entrance * track_spread
					* smoothstep(0.22, 0.70, noise(p * vec2(7.0, 1.9)));
			}
		}
		base = mix(base, vec3(0.095, 0.073, 0.043), tracked_soil * 0.68);
		// Broad swept sediment and irregular drying fronts stay legible at eye level.
		float sediment_support = smoothstep(0.6, 2.8, abs(p.x));
		float sediment = 0.0;
		if (sediment_support > 0.0) {
			sediment = smoothstep(0.36, 0.73, noise(p * 0.65 + vec2(9.0)))
				* sediment_support;
		}
		base = mix(base, vec3(0.15, 0.135, 0.10), sediment * 0.58);
		// Drying lobes at the two real downpipe outlets (z=35.64),
		// with a dusty pale middle rather than an evenly stained rectangle.
		vec2 outlet = vec2((abs(p.x) - 3.15) * 0.95, (p.y - 4.64) * 0.8);
		if (dot(outlet, outlet) < 1.5625) {
			apron_wet = 1.0 - smoothstep(0.25, 1.25, length(outlet) + noise(p * 3.1) * 0.30);
		}
		base = mix(base, vec3(0.085, 0.094, 0.071), apron_wet * 0.70);
		float dry = smoothstep(0.32, 0.78, noise(p * 0.8 + vec2(3.0, 16.0)));
		base = mix(base, vec3(0.17, 0.165, 0.145), dry * (1.0 - apron_wet) * 0.35);
		// A patched service trench and worn tyre arcs give this working apron
		// a metre-scale history, rather than uniform colour noise.
		vec2 repair_p = p - vec2(0.42, 2.45);
		float repair_edge = max(abs(repair_p.x) - 1.85, abs(repair_p.y) - 0.34);
		// Boundary displacement is at most 0.0225 m; retain a small margin.
		if (repair_edge < 0.048) {
			float repair = 1.0 - smoothstep(-0.025, 0.025,
				repair_edge + (noise(p * 23.0) - 0.5) * 0.045);
			base = mix(base, vec3(0.105, 0.111, 0.105) * (0.90 + noise(p * 36.0) * 0.22), repair * 0.82);
		}
		float arc_support = smoothstep(0.6, 1.4, p.y) * (1.0 - smoothstep(3.8, 4.8, p.y));
		float arc = 0.0;
		// The longitudinal mask is exactly zero outside the tyre-mark strip.
		if (arc_support > 0.0) {
			vec2 arc_p = (p - vec2(-3.6, 0.1)) * vec2(1.0, 0.88);
			float arc_radius_squared = dot(arc_p, arc_p);
			// The arc vanishes outside 3.87..4.23 m; keep a 1 mm margin.
			if (arc_radius_squared > 3.869 * 3.869 && arc_radius_squared < 4.231 * 4.231) {
				float arc_radius = length(arc_p);
				arc = (1.0 - smoothstep(0.08, 0.18, abs(arc_radius - 4.05))) * arc_support;
			}
		}
		if (arc > 0.0) {
			base *= 1.0 - arc * smoothstep(0.24, 0.65, noise(p * vec2(19.0, 5.0))) * 0.32;
		}
	}
	if (service_bay) {
		// Five metre pours with narrow saw cuts, not two metre paving tiles.
		vec2 pour = floor((p + vec2(4.0, 7.5)) / vec2(5.0, 5.3333));
		// Integer lattice coordinates have no noise interpolation; use that corner directly.
		base *= mix(0.94, 1.06, concrete_hash(pour + vec2(19.0, 7.0)));
		vec2 joint_axis = abs(mod(p + vec2(4.0, 7.5) + vec2(2.5, 2.66665), vec2(5.0, 5.3333)) - vec2(2.5, 2.66665));
		float joint_distance = min(joint_axis.x, joint_axis.y);
		float joint_aa = max(fwidth(joint_distance), 0.003);
		float saw_cut = (1.0 - smoothstep(0.008, 0.008 + joint_aa, joint_distance)) * min(1.0, 0.016 / joint_aa);
		base *= 1.0 - saw_cut * 0.42;
		// Swept concrete retains small aggregate; broad cloudy stains no longer
		// dominate the sheltered aisle. Footprint fade prevents distant shimmer.
		base = mix(base, vec3(0.205, 0.211, 0.199), 0.48);
		if (fine_visibility > 0.0) {
			float aggregate = noise(p * 95.0);
			base *= 1.0 + (aggregate - 0.5) * 0.18 * fine_visibility;
		}
		float trowel = noise(p * vec2(2.5, 42.0));
		base *= 0.97 + trowel * 0.06;
		// Actual bench footprints and exposed verge govern wear, not each tile.
		vec2 bench_p = vec2((p.x + 2.9) / 1.15, (abs(p.y) - 4.0) / 1.7);
		float oil = 0.0;
		if (dot(bench_p, bench_p) < 1.21) {
			float bench = length(bench_p);
			oil = 1.0 - smoothstep(0.3, 1.1, bench + noise(p * 4.0) * 0.3);
		}
		base *= 1.0 - oil * 0.48;
		// The [0,1] noise only affects the edge transition, not the
		// clean interior or fully soil-covered exterior. Keep a small margin.
		float ingress = 0.0;
		if (p.x > 4.601) {
			ingress = 1.0;
		} else if (p.x > 1.399) {
			ingress = smoothstep(2.2, 4.6, p.x + noise(p * 1.6) * 0.8);
		}
		base = mix(base, vec3(0.14, 0.115, 0.075), ingress * 0.72);
		float wheel = 0.0;
		// Sine shifts the two tracks by at most 0.5 m. Outside this
		// conservative support interval their smoothstep is exactly one.
		if (p.x > -1.351 && p.x < 1.951) {
			wheel = 1.0 - smoothstep(0.10, 0.29, abs(abs(p.x - 0.3 + sin(p.y * 0.23) * 0.5) - 0.86));
		}
		if (wheel > 0.0) {
			base *= 1.0 - wheel * noise(p * vec2(5.0, 0.7)) * 0.28;
		}
		// A turning vehicle crosses the front of the bay; broken rubber, not painted stripes.
		float turn_support = smoothstep(2.8, 4.0, p.y) * (1.0 - smoothstep(7.0, 8.0, p.y));
		float turn = 0.0;
		if (turn_support > 0.0) {
			vec2 turn_p = (p - vec2(4.2, 2.3)) * vec2(1.0, 0.9);
			float turn_squared = dot(turn_p, turn_p);
			// Both tracks vanish outside radius +/- 0.24. A 0.001 m
			// margin preserves the transition while skipping empty pixels.
			if ((turn_squared > 18.139081 && turn_squared < 22.477081)
					|| (turn_squared > 34.327881 && turn_squared < 40.208281)) {
				float turn_radius = length(turn_p);
				turn = (1.0 - smoothstep(0.10, 0.24, min(abs(turn_radius - 4.5), abs(turn_radius - 6.1)))) * turn_support;
			}
		}
		if (turn > 0.0) {
			base *= 1.0 - turn * smoothstep(0.24, 0.70, noise(p * vec2(14.0, 5.0))) * 0.50;
		}
		// Downpipe at world (-26.04,27): damp fan spreads onto the actual slab.
		vec2 outlet_p = (p - vec2(3.96, -6.5)) * vec2(0.85, 0.65);
		float damp = 0.0;
		if (dot(outlet_p, outlet_p) < 2.4025) {
			float outlet = length(outlet_p);
			damp = 1.0 - smoothstep(0.3, 1.55, outlet + noise(p * 3.5) * 0.35);
		}
		base = mix(base, vec3(0.075, 0.089, 0.064), damp * 0.70);
		float paint_dist = abs(p.x + 1.55);
		float paint = 1.0 - smoothstep(0.045, 0.045 + max(fwidth(paint_dist), 0.003), paint_dist);
		paint *= 1.0 - smoothstep(6.0, 6.5, abs(p.y));
		if (paint > 0.0) {
			base = mix(base, vec3(0.36, 0.26, 0.075), paint * smoothstep(0.28, 0.6, noise(p * 26.0)) * 0.75);
		}
		apron_wet = max(oil * 0.5, damp * 0.75);
		float runoff = (1.0 - smoothstep(0.18, 0.65, abs(p.x - 5.35)))
			* (1.0 - smoothstep(7.2, 7.8, abs(p.y - 0.5)));
		if (runoff > 0.0) {
			base *= 1.0 - runoff * (0.24 + noise(p * 9.0) * 0.18);
		}
		apron_wet = max(apron_wet, runoff * 0.65);
	}
	if (depot_apron) {
		// Actual 5.4 x 11 m loading slab: swept centre, soil only at exposed edges.
		float edge = min(2.7 - abs(p.x), 5.5 - abs(p.y));
		float sediment = 0.0;
		if (edge < 0.571) {
			sediment = 1.0 - smoothstep(0.02, 0.48, edge + (noise(p * 4.0) - 0.5) * 0.18);
		}
		base = mix(base * 1.18, vec3(0.13, 0.112, 0.077), sediment * 0.75);
		// Broad pallet drag marks follow the crates, away from the walking aisle.
		float pallet = (1.0 - smoothstep(0.18, 0.40, abs(p.x - 0.65)))
			* (1.0 - smoothstep(1.6, 2.7, abs(p.y + 2.4)));
		if (pallet > 0.0) {
			base *= 1.0 - pallet * noise(p * vec2(12.0, 0.65)) * 0.28;
		}
		float wall_dust_mask = smoothstep(1.7, 2.65, p.x);
		if (wall_dust_mask > 0.0) {
			float wall_dust = wall_dust_mask * noise(p * 2.5);
			base = mix(base, vec3(0.22, 0.195, 0.145), wall_dust * 0.35);
		}
	}
	// Procedural colours above describe linear surface reflectance. Match
	// StandardMaterial's colour conversion in the Compatibility renderer.
	if (OUTPUT_IS_SRGB) {
		base = mix(base * 12.92,
			1.055 * pow(max(base, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
			step(vec3(0.0031308), base));
	}
	ALBEDO = base;
	vec2 relief = vec2(0.0);
	if (grit_visibility > 0.0) {
		relief = vec2(noise(p * 28.0 + vec2(0.12, 0.0)),
			noise(p * 28.0 + vec2(0.0, 0.12))) - vec2(grit);
	}
	NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * vec3(relief.x, 0.0, relief.y) * (slab_joints || shelter_apron || service_bay ? 0.055 : 0.35) * grit_visibility);
	ROUGHNESS = mix(0.91 + fine * 0.035, 0.72, apron_wet);
	SPECULAR = 0.18;
}
