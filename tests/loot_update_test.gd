extends SceneTree

var mesh_changes := 0

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	# Keep the world outside the tree to avoid building the entire terrain.
	var world = load("res://scripts/world.gd").new()
	var items := {1: {"p": Vector3(2, 0, 3), "kind": 5}}
	world.show_loot(items)
	var proxy: MeshInstance3D = world.loot_nodes[1]
	var shell = proxy.get_node("SupplyCaseVisual")
	var attachment = proxy.get_node("ForegripDisplay")
	proxy.mesh.changed.connect(func(): mesh_changes += 1)
	var material = proxy.material_override
	for frame in range(120):
		world.show_loot(items)
	assert(mesh_changes == 0, "Unchanged snapshots must not rebuild loot meshes")
	assert(proxy.get_node("SupplyCaseVisual") == shell)
	assert(proxy.get_node("ForegripDisplay") == attachment)
	assert(proxy.material_override == material)
	var mobile = load("res://scripts/mobile_performance.gd")
	mobile.configure_loot_detail(proxy, 40.0 * 40.0)
	assert(not shell.visible and not attachment.visible)
	assert(proxy.layers == 1 and proxy.visible,
		"Distant loot must retain its category-coloured pickup silhouette")
	world.show_loot(items)
	assert(not shell.visible and proxy.layers == 1,
		"Network snapshots must not reset the mobile detail selection")
	mobile.configure_loot_detail(proxy, 5.0 * 5.0)
	assert(shell.visible and attachment.visible and proxy.layers == 0)
	items[1]["p"] = Vector3(4, 0, 7)
	world.show_loot(items)
	assert(proxy.position == Vector3(4, 0.35, 7))
	assert(mesh_changes == 0)
	items[1]["drop_slot"] = 0
	world.show_loot(items)
	assert(proxy.mesh.size == Vector3(0.65, 0.2, 0.65))
	assert(shell.scale == proxy.mesh.size)
	assert(is_equal_approx(attachment.position.y, 0.5))
	world.highlight_supply(1)
	assert(proxy.material_override.emission_enabled)
	assert(is_equal_approx(proxy.material_override.emission_energy_multiplier, 1.2))
	assert(proxy.material_override.emission == proxy.material_override.albedo_color)
	world.highlight_supply(-1)
	assert(proxy.material_override == material)
	assert(material.emission_enabled)
	assert(material.emission_energy_multiplier == 0.0)
	world.highlight_supply(1)
	items[1]["kind"] = 2
	world.show_loot(items)
	assert(proxy.get_node_or_null("ForegripDisplay") == null)
	assert(proxy.material_override == material)
	assert(world.highlighted_supply == -1)
	assert(proxy.material_override.emission_enabled)
	assert(proxy.material_override.emission_energy_multiplier == 0.0)
	# Repeated category changes must recolour every body surface while retaining
	# the hardware materials, scale, and mobile detail visibility.
	var body_surfaces := 0
	mobile.configure_loot_detail(proxy, 40.0 * 40.0)
	var colors := ["e8c77b", "77d7ad", "7bbee8", "d9844e", "c2d6c9", "b5a1dc"]
	for kind in [0, 1, 4, 5, 3, 2]:
		items[1]["kind"] = kind
		world.show_loot(items)
		assert(proxy.material_override == material)
		assert(material.albedo_color == world.mat(colors[kind]).albedo_color)
		assert(material.emission == material.albedo_color)
		assert(material.emission_energy_multiplier == 0.0)
		assert(shell.scale == proxy.mesh.size)
		assert(not shell.visible and proxy.layers == 1)
		if kind == 5:
			var refreshed_attachment = proxy.get_node("ForegripDisplay")
			assert(not refreshed_attachment.visible,
				"New attachments must inherit distant detail before the next LOD update")
			mobile.configure_loot_detail(proxy, 5.0 * 5.0)
			assert(shell.visible and refreshed_attachment.visible and proxy.layers == 0)
			mobile.configure_loot_detail(proxy, 40.0 * 40.0)
			assert(not shell.visible and not refreshed_attachment.visible and proxy.layers == 1)
		for part in shell.find_children("*", "MeshInstance3D", true, false):
			for surface in range(part.mesh.get_surface_count()):
				var source: Material = part.mesh.surface_get_material(surface)
				if source != null and source.resource_name == "Supply body":
					body_surfaces += 1
					assert(part.get_surface_override_material(surface) == proxy.material_override)
				else:
					assert(part.get_surface_override_material(surface) == null)
	assert(body_surfaces > 0, "The real supply model must expose category body surfaces")
	# New network dictionaries must reuse the display, while same-size replacements
	# and changed stack order must still update immediately.
	world.show_loot(items.duplicate(true))
	assert(world.loot_nodes[1] == proxy)
	items[2] = {"p": items[1].p, "kind": 3, "drop_slot": 1}
	world.show_loot(items)
	assert(is_equal_approx(world.loot_nodes[2].position.y, 0.35))
	var other_material = world.loot_nodes[2].material_override
	var other_color: Color = other_material.albedo_color
	assert(other_material != material, "Each pickup needs independent highlight uniforms")
	world.highlight_supply(1)
	items[1]["kind"] = 3
	world.show_loot(items)
	assert(proxy.material_override == material and other_material != material)
	assert(other_material.albedo_color == other_color)
	assert(other_material.emission_energy_multiplier == 0.0)
	assert(material.emission_energy_multiplier == 0.0)
	world.highlight_supply(1)
	assert(is_equal_approx(material.emission_energy_multiplier, 1.2))
	assert(other_material.emission_energy_multiplier == 0.0)
	var reversed := {2: items[2], 1: items[1]}
	world.show_loot(reversed)
	assert(is_equal_approx(world.loot_nodes[2].position.y, 0.15))
	assert(is_equal_approx(proxy.position.y, 0.35))
	reversed.erase(2)
	reversed[3] = {"p": Vector3(8, 0, 9), "kind": 0}
	world.show_loot(reversed)
	assert(not world.loot_nodes.has(2) and world.loot_nodes.has(3))
	assert(is_equal_approx(proxy.position.y, 0.15))
	world.show_loot({})
	assert(world.loot_nodes.is_empty())
	world.free()
	await process_frame
	print("LOOT_UPDATE_PASS stable meshes movement stack attachment category removal")
	quit()
