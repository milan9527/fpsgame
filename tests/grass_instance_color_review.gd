extends "grass_root_shader_review.gd"

var captures := 0

# Compare real grass with white instance modulation against the implicit
# renderer default, including vertex color, custom variation and frozen wind.
func capture(material: ShaderMaterial, code: String, time: float) -> Image:
	var patch: MultiMeshInstance3D = root.find_children("*", "MultiMeshInstance3D", true, false)[0]
	var original := patch.multimesh
	var replacement := MultiMesh.new()
	replacement.transform_format = MultiMesh.TRANSFORM_3D
	replacement.use_colors = captures % 2 == 0
	replacement.use_custom_data = true
	replacement.mesh = original.mesh
	replacement.instance_count = original.instance_count
	for i in range(original.instance_count):
		replacement.set_instance_transform(i, original.get_instance_transform(i))
		replacement.set_instance_custom_data(i, original.get_instance_custom_data(i))
		if replacement.use_colors:
			replacement.set_instance_color(i, Color.WHITE)
	patch.multimesh = replacement
	captures += 1
	return await super.capture(material, code, time)
