extends Node3D

func _ready() -> void:
	var smoke := CPUParticles3D.new()
	smoke.amount = 26
	smoke.lifetime = 1.6
	smoke.one_shot = true
	smoke.explosiveness = 1
	smoke.direction = Vector3.UP
	smoke.spread = 150
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 4.0
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.3
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var radial := Gradient.new()
	radial.set_color(0, Color(0.24, 0.25, 0.26, 0.75))
	radial.set_color(1, Color(0.3, 0.31, 0.32, 0))
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.gradient = radial
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	material.albedo_texture = texture
	quad.material = material
	smoke.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.8, 0.6, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	smoke.color_ramp = fade
	add_child(smoke)
	var sparks := CPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 0.55
	sparks.one_shot = true
	sparks.explosiveness = 1
	sparks.spread = 180
	sparks.direction = Vector3.UP
	sparks.gravity = Vector3(0, -12, 0)
	sparks.initial_velocity_min = 5
	sparks.initial_velocity_max = 12
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.03
	spark_mesh.height = 0.06
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1, 0.7, 0.2)
	spark_mesh.material = spark_material
	sparks.mesh = spark_mesh
	add_child(sparks)
	var light := OmniLight3D.new()
	light.omni_range = 7
	light.light_color = Color(1, 0.6, 0.25)
	light.light_energy = 3
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.2)
	get_tree().create_timer(1.8, false).timeout.connect(queue_free)
