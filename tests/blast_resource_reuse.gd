extends SceneTree

const Blast = preload("res://scripts/blast_effect.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Blast._ensure_resources()
	var warmed_smoke := Blast._smoke_mesh
	var warmed_sparks := Blast._spark_mesh
	assert(warmed_smoke != null and warmed_sparks != null)
	Blast._ensure_resources()
	assert(Blast._smoke_mesh == warmed_smoke)
	var warm_particles := Blast.create_particles()
	for particles in warm_particles:
		particles.free()
	assert(Blast.created_count == 0 and Blast.active_count == 0)
	var first := Blast.new()
	var second := Blast.new()
	root.add_child(first)
	root.add_child(second)
	assert(Blast.created_count == 2 and Blast.active_count == 2)
	var snapshot := Blast.diagnostic_snapshot()
	assert(snapshot.last_ready_begin_usec > 0)
	assert(snapshot.last_ready_end_usec >= snapshot.last_ready_begin_usec)
	var smoke := first.get_child(0) as CPUParticles3D
	var sparks := first.get_child(1) as CPUParticles3D
	assert(smoke.mesh == warmed_smoke and sparks.mesh == warmed_sparks)
	var other_smoke := second.get_child(0) as CPUParticles3D
	assert(smoke != other_smoke)
	assert(smoke.mesh == other_smoke.mesh)
	assert(smoke.color_ramp == other_smoke.color_ramp)
	assert(sparks.mesh == second.get_child(1).mesh)
	assert(smoke.amount == 26 and smoke.lifetime == 1.6)
	assert(sparks.amount == 24 and sparks.lifetime == 0.55)
	assert(smoke.mesh.material.albedo_texture.width == 64)
	assert(smoke.mesh.material.albedo_texture.gradient.get_color(1).a == 0)
	smoke.emitting = false
	assert(other_smoke.emitting)
	first.queue_free()
	await process_frame
	assert(is_instance_valid(second))
	assert(Blast.active_count == 1)
	assert(other_smoke.mesh != null)
	var third := Blast.new()
	root.add_child(third)
	assert(Blast.created_count == 3 and Blast.active_count == 2)
	assert(snapshot.created_count == 2 and snapshot.active_count == 2)
	assert(third.get_child(0).mesh == other_smoke.mesh)
	await create_timer(2.0).timeout
	assert(not is_instance_valid(second))
	assert(not is_instance_valid(third))
	assert(Blast.active_count == 0)
	print("BLAST_RESOURCE_REUSE_PASS: shared resources, independent simulation, timed cleanup")
	quit()
