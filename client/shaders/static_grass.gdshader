shader_type spatial;
render_mode cull_disabled;

varying flat vec3 sky_normal;

void vertex() {
	// Camera3D's view basis is orthonormal: its up column is already unit
	// length. Avoid a redundant normalization for every static grass vertex.
	// Factor the positive leaf weight out of the final normalization so
	// the fixed blend ratio is computed per vertex instead of per fragment.
	sky_normal = VIEW_MATRIX[1].xyz * (0.82 / (1.0 - 0.82));
}

void fragment() {
	// Thin leaves collect light across the tuft rather than behaving like
	// vertical opaque walls. Keep some blade curvature in the shading.
	vec3 leaf_normal = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = normalize(leaf_normal + sky_normal);
	// The Blender/glTF mesh stores linear vertex reflectance.
	ALBEDO = COLOR.rgb;
	if (OUTPUT_IS_SRGB) {
		// StaticGrassCell uses imported fine/broadleaf colors without instance
		// tint. Their red/green channels stay above the linear sRGB segment;
		// retain the piecewise conversion for blue and interpolate in linear
		// space as before.
		vec3 encoded;
		encoded.rg = 1.055 * pow(ALBEDO.rg, vec2(1.0 / 2.4)) - 0.055;
		// As with animated grass, dark leaf regions only need the linear
		// blue segment. Avoid computing a power that would be discarded.
		if (ALBEDO.b < 0.0031308) {
			encoded.b = 12.92 * ALBEDO.b;
		} else {
			encoded.b = 1.055 * pow(ALBEDO.b, 1.0 / 2.4) - 0.055;
		}
		ALBEDO = encoded;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
