extends SceneTree

const Visuals = preload("res://scripts/world_visuals.gd")

func _initialize() -> void:
	call_deferred("run")

func require(condition: bool, message: String) -> bool:
	if not condition:
		printerr("DETAIL_BATCH_FAIL: ", message)
		quit(1)
	return condition

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Use Xvfb and gl_compatibility for MultiMesh transform checks")
		quit(2)
		return
	RenderingServer.render_loop_enabled = false
	# Cached scenes preserve generated names without advancing the runtime
	# name counter. Reproduce that input through a PackedScene, not name=.
	var scene_text := "[gd_scene format=3]\n[node name=\"World\" type=\"Node3D\"]\n"
	for index in range(1, 513):
		scene_text += "[node name=\"@MultiMeshInstance3D@%d\" type=\"MultiMeshInstance3D\" parent=\".\"]\n" % index
	var path := "user://detail_batch_identity_fixture.tscn"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(scene_text)
	file.close()
	var packed := load(path) as PackedScene
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	var cached := world.get_children()
	var paths: Array[NodePath] = []
	for node in cached:
		paths.append(world.get_path_to(node))
	var material := StandardMaterial3D.new()
	var expected: Array[Transform3D] = []
	for index in range(128):
		var detail := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2, 0.5, 3)
		detail.mesh = mesh
		detail.material_override = material
		detail.transform = Transform3D(Basis(Vector3.UP, index * 0.13), Vector3((index / 2) * 20 + index % 2, 1, 0))
		detail.set_meta("visual_batch", "fixture")
		world.add_child(detail)
		expected.append(Transform3D(detail.basis * Basis.from_scale(mesh.size), detail.position))
	Visuals.batch_details(world)
	var children := world.get_children()
	for index in range(cached.size()):
		if not require(cached[index] in children, "Cached child missing from traversal: %s" % paths[index]):
			return
		if not require(world.get_node_or_null(paths[index]) == cached[index], "Cached path changed"):
			return
	var details := 0
	var shared_mesh: Mesh
	for node in children:
		if node in cached:
			continue
		if not require(node is MultiMeshInstance3D, "Unexpected replacement type"):
			return
		if not require(node.material_override == material, "Material changed"):
			return
		if not require(node.multimesh.instance_count == 2, "Cell population changed"):
			return
		if shared_mesh == null:
			shared_mesh = node.multimesh.mesh
		if not require(node.multimesh.mesh == shared_mesh, "Unit box geometry duplicated across cells"):
			return
		for instance_index in range(2):
			var actual: Transform3D = node.transform * node.multimesh.get_instance_transform(instance_index)
			var cell := roundi((actual.origin.x - instance_index) / 20.0)
			var index := cell * 2 + instance_index
			if not require(index >= 0 and index < expected.size(), "Unexpected cell"):
				return
			if not require(actual.is_equal_approx(expected[index]), "Box transform changed"):
				return
		details += 1
	if not require(details == 64 and children.size() == 576, "Population changed"):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("DETAIL_BATCH_IDENTITY_PASS cached=512 details=128 cells=64 shared_box_meshes=1 paths/transforms/material preserved")
	quit()
