extends "grass_root_shader_review.gd"

const Mobile = preload("res://scripts/mobile_performance.gd")
var captures := 0
var specialized := 0
var reference: Image

func capture(material: ShaderMaterial, code: String, time: float) -> Image:
	var patch: MultiMeshInstance3D = root.find_children("*", "MultiMeshInstance3D", true, false)[0]
	if captures % 2 == 1 and Mobile.grass_can_skip_dry_tips(patch.multimesh.mesh):
		code = "#define SHORT_GRASS\n" + code
		specialized += 1
	captures += 1
	if captures == 54:
		assert(specialized > 0 and specialized < 27)
		print("SHORT_GRASS_SPECIALIZED_CAPTURES ", specialized)
	var image: Image = await super.capture(material, code, time)
	if captures % 2 == 1:
		reference = image
	else:
		var maximum := 0.0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var a := reference.get_pixel(x, y)
				var b := image.get_pixel(x, y)
				maximum = maxf(maximum, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
		print("SHORT_GRASS_PIXEL_DELTA pair=", captures / 2, " max_channel=", maximum)
		if maximum > 0:
			var output := OS.get_environment("GRASS_REVIEW_DIR")
			reference.save_png(output.path_join("difference-%s-before.png" % captures))
			image.save_png(output.path_join("difference-%s-after.png" % captures))
	return image
