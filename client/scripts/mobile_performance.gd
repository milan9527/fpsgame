extends Node

const BlastDiagnostics = preload("res://scripts/blast_effect.gd")
## Android defaults. Visual-only changes leave world geometry and collision intact.

static var baseline_running := false

static func strip_collapsed_static_triangles(arrays: Array) -> int:
	# Primitive pole/cap seams can submit triangles with coincident corners.
	# Exact equality only: retain narrow faces and distinct normal/UV seams.
	# These static baked materials do not displace vertices in their shaders.
	if arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_INDEX].is_empty():
		return 0
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	var found_collapsed := false
	var kept_count := 0
	for offset in range(0, indices.size(), 3):
		var a := indices[offset]
		var b := indices[offset + 1]
		var c := indices[offset + 2]
		if vertices[a] == vertices[b] or vertices[b] == vertices[c] or vertices[c] == vertices[a]:
			if not found_collapsed:
				# Most static primitives need no filtering. Copy the prefix only
				# when removal is necessary, avoiding a full temporary index buffer.
				kept = indices.slice(0, offset)
				# Reserve once; repeated append calls otherwise grow the packed
				# buffer for every surviving corner during world preparation.
				kept.resize(indices.size())
				kept_count = offset
				found_collapsed = true
			continue
		if found_collapsed:
			kept[kept_count] = a
			kept[kept_count + 1] = b
			kept[kept_count + 2] = c
			kept_count += 3
	# Empty indices mean an unindexed surface in Godot. Leave entirely
	# collapsed surfaces alone instead of accidentally submitting new faces.
	if kept_count == 0 or kept_count == indices.size():
		return 0
	kept.resize(kept_count)
	var removed := (indices.size() - kept.size()) / 3
	arrays[Mesh.ARRAY_INDEX] = kept
	return removed

class DistanceEntry:
	var node: Node3D
	var center: Vector3
	var begin_squared: float
	var end_squared: float
	var grass_roots := Rect2()
	var grass_roots_end := Vector2.ZERO
	var grass_min_x := 0.0
	var grass_max_x := 0.0
	var grass_min_z := 0.0
	var grass_max_z := 0.0
	var grass_fade_squared := 0.0
	var grass_root_points := PackedVector2Array()
	var grass_root_groups: Array[PackedInt32Array] = []
	# Store min X/Z and max X/Z together for one lookup in the hot search.
	var grass_group_bounds: Array[Vector4] = []
	var grass_near_root := 0
	var grass_near_point := Vector2.ZERO
	var grass_last_hit := false
	var grass_empty_center := Vector2.ZERO
	var grass_empty_radius_squared := 0.0
	var grass_search_lower_bound := INF
	var grass_search_nearest_squared := INF

	func _init(target: Node3D, position: Vector3, begin: float, end: float) -> void:
		node = target
		center = position
		begin_squared = begin * begin
		end_squared = INF if end == 0.0 else end * end
		if target is MultiMeshInstance3D and target.get_meta("mobile_animated_grass_fade", false):
			var instances: MultiMesh = target.multimesh
			# These world grass batches are static. Bound root positions rather
			# than render AABBs, which include blade geometry and shader margins.
			var world_transform := target.global_transform
			var root_count := instances.instance_count
			# Only enabled slots can produce fragments. Unused capacity must
			# not keep a distant or empty static batch in the render list.
			if instances.visible_instance_count >= 0:
				root_count = mini(root_count, instances.visible_instance_count)
			# Shader fade ends at 24 m. Allow another 2 m for the
			# incremental visibility scan while the player is moving.
			grass_fade_squared = 26.0 * 26.0
			grass_root_points.resize(root_count)
			for i in range(root_count):
				var root: Vector3 = world_transform * instances.get_instance_transform(i).origin
				var point := Vector2(root.x, root.z)
				grass_root_points[i] = point
				if i == 0:
					grass_roots = Rect2(point, Vector2.ZERO)
				else:
					grass_roots = grass_roots.expand(point)
			if root_count > 0:
				grass_near_point = grass_root_points[0]
				# Large sparse batches need exact root tests after the rectangle
				# test. Static 8 m groups bound that search without changing any
				# render instances or the nearest-root empty-disk certificate.
				if grass_root_points.size() >= 64:
					var groups := {}
					var cell_size := 8.0
					# Coarsen sparse batches rather than abandoning bounds and
					# scanning every root. This only changes the search index;
					# exact root distances still decide visibility.
					for attempt in range(8):
						# Cell sizes are powers of two; the exact reciprocal is
						# shared by all roots instead of dividing twice per root.
						var inverse_cell_size := 1.0 / cell_size
						groups.clear()
						for i in range(grass_root_points.size()):
							var point := grass_root_points[i]
							var key := Vector2i(floori(point.x * inverse_cell_size), floori(point.y * inverse_cell_size))
							if not groups.has(key):
								groups[key] = PackedInt32Array()
								# Occupied cells can only increase. Once this
								# grid is too sparse, skip its remaining roots
								# and allocations; retry with larger cells.
								if groups.size() * 4 > grass_root_points.size():
									break
							groups[key].append(i)
						if groups.size() * 4 <= grass_root_points.size():
							break
						cell_size *= 2.0
					# A compact batch gains nothing from another bounds check.
					# Sparse groups cost more bounds checks than the original scan.
					if groups.size() > 1 and groups.size() * 4 <= grass_root_points.size():
						for key in groups:
							var indices: PackedInt32Array = groups[key]
							var bounds := Rect2(grass_root_points[indices[0]], Vector2.ZERO)
							for index in indices:
								bounds = bounds.expand(grass_root_points[index])
							grass_root_groups.append(indices)
							grass_group_bounds.append(Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y))
				grass_roots_end = grass_roots.end
				grass_min_x = grass_roots.position.x
				grass_max_x = grass_roots_end.x
				grass_min_z = grass_roots.position.y
				grass_max_z = grass_roots_end.y

	func grass_in_range(camera_position: Vector3) -> bool:
		return grass_in_range_xz(Vector2(camera_position.x, camera_position.z))

	func grass_in_range_xz(camera_xz: Vector2) -> bool:
		if grass_fade_squared == 0.0:
			return true
		if grass_root_points.is_empty():
			return false
		# Moving within a visible patch usually retains the previous root.
		# A root hit also proves rectangle intersection, so skip its clamps.
		# Only try this before the bounds for previously visible batches:
		# distant batches retain their cheap axis rejection.
		var nearest_squared := -1.0
		if grass_last_hit:
			nearest_squared = camera_xz.distance_squared_to(grass_near_point)
			if nearest_squared <= grass_fade_squared:
				return true
			grass_last_hit = false
		# Clamp directly to cached static root bounds: avoid unpacking Rect2
		# and Vector2 values and two nested max calls for each axis.
		var x := camera_xz.x - clampf(camera_xz.x, grass_min_x, grass_max_x)
		var x_squared := x * x
		# Reject distant batches on the first axis before evaluating the second.
		# The rectangle is static, so its end need not be rebuilt during scans.
		if x_squared > grass_fade_squared:
			return false
		# Retain the cheap distant-axis rejection above. A prior exact miss
		# certifies an empty disk independently of the rectangle, so a cache
		# hit can skip the remaining axis clamp and distance calculation.
		if grass_empty_radius_squared > 0.0 and camera_xz.distance_squared_to(grass_empty_center) < grass_empty_radius_squared:
			return false
		var z := camera_xz.y - clampf(camera_xz.y, grass_min_z, grass_max_z)
		if x_squared + z * z > grass_fade_squared:
			return false
		# A sparse/rotated cell's rectangle can intersect the fade radius even
		# when every blade has collapsed. Test actual roots before submitting
		# the batch. Nearby frames usually reuse the same successful root.
		# Crossing out of the previous hit already measured this root.
		# Keep that exact distance for the nearest-root search below.
		if nearest_squared < 0.0:
			nearest_squared = camera_xz.distance_squared_to(grass_near_point)
			if nearest_squared <= grass_fade_squared:
				grass_last_hit = true
				return true
		var nearest_index := grass_near_root
		if not grass_root_groups.is_empty():
			nearest_index = grouped_nearest_root(camera_xz, nearest_squared, true)
			nearest_squared = grass_search_nearest_squared
			if nearest_squared <= grass_fade_squared:
				grass_near_root = nearest_index
				grass_near_point = grass_root_points[nearest_index]
				grass_last_hit = true
				return true
			# Unvisited groups contribute conservative bounds, not an assumed
			# nearest root. This keeps the empty-disk cache safe.
			nearest_squared = minf(nearest_squared, grass_search_lower_bound)
		else:
			for i in range(grass_root_points.size()):
				# As in the grouped search, one repeated seed distance avoids
				# a script branch for every root in a flat batch.
				var distance_squared := camera_xz.distance_squared_to(grass_root_points[i])
				if distance_squared <= grass_fade_squared:
					grass_near_root = i
					grass_near_point = grass_root_points[i]
					grass_last_hit = true
					return true
				if distance_squared < nearest_squared:
					nearest_squared = distance_squared
					nearest_index = i
		# On approach from an empty region, try the nearest inspected root
		# first next time.
		grass_near_root = nearest_index
		grass_near_point = grass_root_points[nearest_index]
		grass_empty_center = camera_xz
		# Shrink the mathematical radius to absorb floating-point roundoff.
		var empty_radius := maxf(sqrt(nearest_squared) - 26.0 - 0.001, 0.0)
		grass_empty_radius_squared = empty_radius * empty_radius
		return false

	func grouped_nearest_root(camera: Vector2, nearest_squared: float, visibility_only := false) -> int:
		var nearest_index := grass_near_root
		grass_search_lower_bound = nearest_squared
		# Share tolerance thresholds across groups; only a closer root changes
		# the nearest bound. Keep the original floating-point margin.
		var nearest_limit := nearest_squared + 0.01
		var fade_limit := grass_fade_squared + 0.01
		for group in range(grass_root_groups.size()):
			var bounds := grass_group_bounds[group]
			var dx := camera.x - clampf(camera.x, bounds.x, bounds.z)
			var dx_squared := dx * dx
			if dx_squared > nearest_limit:
				continue
			# The X distance alone proves this group cannot contain a
			# visible root. Retain that conservative lower bound for the
			# empty-disk certificate without computing the Z clamp.
			if visibility_only and dx_squared > fade_limit:
				grass_search_lower_bound = minf(grass_search_lower_bound, maxf(dx_squared - 0.01, 0.0))
				continue
			var dz := camera.y - clampf(camera.y, bounds.y, bounds.w)
			var bound_squared := dx_squared + dz * dz
			# Visibility needs any root within the fade radius, not the exact
			# closest distant root. Skip outside groups and keep their lower
			# bounds to conservatively size the cached empty disk.
			if visibility_only and bound_squared > fade_limit:
				grass_search_lower_bound = minf(grass_search_lower_bound, maxf(bound_squared - 0.01, 0.0))
				continue
			# Retain a small numerical margin when comparing the lower bound.
			if bound_squared > nearest_limit:
				continue
			for index in grass_root_groups[group]:
				# Measuring the seed at most once again avoids a script
				# branch for every root in every intersecting group.
				var squared := camera.distance_squared_to(grass_root_points[index])
				if squared <= grass_fade_squared:
					grass_search_nearest_squared = squared
					return index
				if squared < nearest_squared:
					nearest_squared = squared
					nearest_limit = squared + 0.01
					nearest_index = index
		# Return the already measured distance alongside the index without
		# allocating a result container or measuring the same root again.
		grass_search_nearest_squared = nearest_squared
		return nearest_index

var frame_times: Array[float] = []
var sample_seconds := 0.0
var route_sample_seconds := 0.0
var route_sample_interval := 0.2 if "--profile-game" in OS.get_cmdline_user_args() else 1.0
var last_frame_usec := 0
var cull_seconds := 0.0
var distance_nodes: Array[DistanceEntry] = []
var process_peak_ms := 0.0
var physics_peak_ms := 0.0
var cull_peak_ms := 0.0
var resolution_sample_count := 0
var resolution_slow_count := 0
var resolution_fast_count := 0
var resolution_seconds := 0.0
var resolution_recovery_seconds := 0.0
var resolution_warmup := false
var resolution_resume_pending := false
var cull_cursor := 0
var cull_pass_position := Vector3.ZERO
var cull_pass_stable := false
var cull_settled := false
var cull_settled_position := Vector3.ZERO
var cull_settled_count := -1
var loot_cull_cursor := 0
var loot_cull_keys: Array = []
var loot_cull_seconds := 0.0
var render_started_usec := 0
var render_peak_ms := 0.0
var render_stalls: Array[Dictionary] = []
var render_stalls_omitted := 0

func render_begin() -> void:
	render_started_usec = Time.get_ticks_usec()

func render_end() -> void:
	if render_started_usec != 0:
		# CPU wall time for rendering, including driver waits; not GPU time.
		var ended_usec := Time.get_ticks_usec()
		var wall_ms := (ended_usec - render_started_usec) / 1000.0
		render_peak_ms = maxf(render_peak_ms, wall_ms)
		record_render_stall(wall_ms, ended_usec)
		render_started_usec = 0

func record_render_stall(wall_ms: float, ended_usec: int) -> void:
	if wall_ms <= 50.0:
		return
	# Bound allocations during sustained overload. Print with the existing
	# five-second diagnostics, outside the measured render callback.
	if render_stalls.size() >= 8:
		render_stalls_omitted += 1
		return
	var camera := get_viewport().get_camera_3d()
	var sample := {
		"end_ticks_usec": ended_usec,
		# Preserve the callback timestamp, rather than reconstructing it from
		# rounded milliseconds. Counters help correlate native profiler frames;
		# they are not SurfaceFlinger presentation IDs or FPS measurements.
		"begin_ticks_usec": render_started_usec,
		"engine_frames_drawn": Engine.get_frames_drawn(),
		"engine_process_frames": Engine.get_process_frames(),
		"render_wall_ms": wall_ms,
		"blast": BlastDiagnostics.diagnostic_snapshot(),
		# Godot 4.4.1 updates this before frame_post_draw (milliseconds).
		# Scene/canvas preparation only; excludes particles, probes, viewport
		# rendering and buffer swap. Neither GPU nor presentation time.
		"scene_prepare_cpu_ms": RenderingServer.get_frame_setup_time_cpu(),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"scale": get_viewport().scaling_3d_scale,
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
	}
	if camera != null:
		var position := camera.global_position
		var forward := -camera.global_basis.z
		sample["camera_position"] = [position.x, position.y, position.z]
		sample["camera_forward"] = [forward.x, forward.y, forward.z]
		sample["camera_fov"] = camera.fov
	# Capture the state of this frame, rather than the gameplay state at the
	# later five-second flush. A death can switch cameras between those times.
	# Read scalars only, after the measured interval, and retain the same cap.
	var game = get_parent()
	if game != null and game.get("actors") is Dictionary:
		var local = game.actors.get(game.local_id)
		sample["phase"] = game.phase
		sample["local_alive"] = local.alive if local != null else false
		sample["local_downed"] = local.downed if local != null else false
		sample["spectator_active"] = game.spectator.active
		sample["spectator_target"] = game.spectator.target_id
		sample["spectator_camera"] = camera != null and camera == game.spectator.camera
		sample["loot_count"] = game.loot.size()
	render_stalls.append(sample)

func flush_render_stalls() -> void:
	# Android logcat truncates the multi-sample JSON. Keep each bounded
	# event on its own line, outside the measured render callback.
	# Engine wall time only; these are never presentation/acceptance data.
	if not render_stalls.is_empty():
		# Pair clocks at flush time, not logcat delivery time. Consumers can
		# estimate event epoch from end_ticks_usec; retain both tick bounds
		# to expose clock-read uncertainty. Wall-clock adjustments remain possible.
		var ticks_before := Time.get_ticks_usec()
		var epoch_seconds := Time.get_unix_time_from_system()
		var ticks_after := Time.get_ticks_usec()
		print("ANDROID_RENDER_CLOCK ", JSON.stringify({
			"ticks_before_usec": ticks_before,
			"epoch_seconds": epoch_seconds,
			"ticks_after_usec": ticks_after,
		}))
	for sample in render_stalls:
		print("ANDROID_RENDER_STALL ", JSON.stringify(sample))
	if render_stalls_omitted > 0:
		print("ANDROID_RENDER_STALLS_OMITTED ", render_stalls_omitted)
	render_stalls.clear()
	render_stalls_omitted = 0

func set_resolution_warmup(active: bool) -> void:
	resolution_warmup = active
	resolution_resume_pending = not active
	reset_resolution_window()
	resolution_recovery_seconds = 0.0

func adapt_resolution(elapsed: float) -> void:
	if baseline_running or resolution_warmup:
		return
	if resolution_resume_pending:
		# The first process interval can still span the last warmup draw.
		# Skip only adaptive sampling; diagnostics retain the full interval.
		resolution_resume_pending = false
		return
	# Separate from diagnostics: never discard stalls from the FPS/p95 report.
	# A percentile avoids resizing the framebuffer for one isolated load.
	resolution_sample_count += 1
	if elapsed > 1.0 / 58.0:
		resolution_slow_count += 1
	if elapsed < 1.0 / 59.5:
		resolution_fast_count += 1
	resolution_seconds += elapsed
	if resolution_seconds < 2.0:
		return
	# Only threshold comparisons are needed for the original sorted 80th
	# percentile. Count samples on either side instead of allocating/sorting.
	var percentile_rank := mini(resolution_sample_count - 1,
		int(resolution_sample_count * 0.8))
	var viewport := get_viewport()
	var scale := viewport.scaling_3d_scale
	# Reduce GPU load when sustained delivery misses the 58 FPS target.
	# Keep the existing quality floor; only recover with near-60 FPS
	# headroom for eight seconds to avoid repeated scale oscillation.
	if resolution_sample_count - resolution_slow_count <= percentile_rank:
		scale = maxf(0.45, scale - 0.05)
		resolution_recovery_seconds = 0.0
	elif resolution_fast_count > percentile_rank:
		resolution_recovery_seconds += resolution_seconds
		if resolution_recovery_seconds >= 8.0:
			scale = minf(0.65, scale + 0.05)
			resolution_recovery_seconds = 0.0
	else:
		resolution_recovery_seconds = 0.0
	if not is_equal_approx(scale, viewport.scaling_3d_scale):
		viewport.scaling_3d_scale = scale
		print("ANDROID_RESOLUTION scale=", snappedf(scale, 0.01))
	reset_resolution_window()

func reset_resolution_window() -> void:
	resolution_sample_count = 0
	resolution_slow_count = 0
	resolution_fast_count = 0
	resolution_seconds = 0.0

static func configure_loot_detail(proxy: MeshInstance3D, distance_squared: float) -> void:
	# Dynamic loot is created after static-world registration. Keep its coloured
	# pickup silhouette at long range, but render the detailed case only nearby.
	# These paths are constant across every drop and scan. NodePath literals
	# avoid converting and parsing Strings in this recurring update.
	var shell := proxy.get_node_or_null(^"SupplyCaseVisual")
	if shell == null:
		return
	var detailed := distance_squared < 24.0 * 24.0
	var detail_changed: bool = shell.visible != detailed
	if detail_changed:
		shell.visible = detailed
	var layers := 0 if detailed else 1
	if proxy.layers != layers:
		proxy.layers = layers
	# Category changes create attachments with the shell's current visibility
	# (world.update_supply_attachment). Only a distance transition needs to look up
	# and resynchronise that child during recurring scans.
	if not detail_changed:
		return
	var attachment := proxy.get_node_or_null(^"ForegripDisplay")
	if attachment != null and attachment.visible != detailed:
		attachment.visible = detailed

static func detail_distance(diameter: float) -> float:
	if diameter < 0.5:
		return 10.0
	if diameter < 3.0:
		return 18.0
	if diameter < 12.0:
		return 40.0
	if diameter < 40.0:
		return 160.0
	return 0.0

func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(render_begin)
	RenderingServer.frame_post_draw.connect(render_end)
	var world = get_parent().world
	register_distance_nodes(world)

func register_distance_nodes(world: Node3D) -> void:
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree():
			continue
		if node is MultiMeshInstance3D and node.multimesh == null:
			continue
		if node is MeshInstance3D and node.mesh == null:
			continue
		if node.get_meta("mobile_background_grove", false):
			continue
		# get_meta's default is evaluated eagerly. Partitioned batches already
		# have world bounds: avoid redundant renderer AABB queries/transforms
		# while registering the world before gameplay.
		var distance_bounds: AABB
		if node.has_meta("mobile_distance_bounds"):
			distance_bounds = node.get_meta("mobile_distance_bounds")
		else:
			distance_bounds = node.global_transform * node.get_aabb()
		var begin: float = node.visibility_range_begin
		var end: float = node.visibility_range_end
		if end == 0.0:
			var diameter := distance_bounds.size.length()
			# Small facade props need not submit thousands of surfaces across the
			# entire valley. Large terrain/building shells retain their silhouette.
			end = detail_distance(diameter)
		# Explicit culling also works with the Android compatibility renderer.
		if begin > 0.0 or end > 0.0:
			distance_nodes.append(DistanceEntry.new(node,
				distance_bounds.get_center(), begin, end))
			node.visibility_range_begin = 0.0
			node.visibility_range_end = 0.0

static func warm_world(camera: Camera3D, profile: Node = null) -> void:
	# Draw ground-level material variants before accepting input. The aerial
	# lobby alone never renders many nearby surfaces on GLES drivers.
	var original := camera.transform
	var original_fov := camera.fov
	# Match the player's un-aimed view. The lobby defaults to 75 degrees,
	# leaving edge geometry out of each warm draw that gameplay sees at 85.
	camera.fov = maxf(original_fov, 85.0)
	var started := Time.get_ticks_msec()
	# Include the roadside approach as well as the road center. Short-range
	# vegetation and facade resources there can remain culled from the first
	# two locations, leaving their first draw on the player's movement path.
	# Keep the three established views. r384's fourth approach point added
	# ~1.1s of startup work without demonstrating a gameplay improvement on
	# device; do not grow this list for every observed stall location.
	for position in [Vector3(0, 2.6, 90), Vector3(2, 1.6, 61),
			Vector3(14, 1.65, 49)]:
		camera.position = position
		# A fixed delay does not guarantee that a sliced visibility scan has
		# reached the new position. Settle it before warming nearby resources.
		if profile != null:
			profile.cull_cursor = 0
			while true:
				profile.update_distance_visibility(camera.global_position, Time.get_ticks_usec())
				if profile.cull_cursor == 0:
					break
				await camera.get_tree().process_frame
		for heading in range(8):
			camera.rotation = Vector3(0, heading * TAU / 8.0, 0)
			# Warm each view by completed draws, not a fixed dwell time that
			# repeatedly renders the same scene on fast frames. Two draws let
			# the changed camera reach rendering and submit the warmed view.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
	camera.transform = original
	camera.fov = original_fov
	if profile != null:
		profile.cull_cursor = 0
		while true:
			profile.update_distance_visibility(camera.global_position, Time.get_ticks_usec())
			if profile.cull_cursor == 0:
				break
			await camera.get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("ANDROID_STARTUP: ground views warmed ms=", Time.get_ticks_msec() - started)

static func baseline_ground_family(material: Material) -> String:
	if not material is ShaderMaterial or material.shader == null:
		return ""
	# Baked scenes can embed shaders without retaining their source paths.
	for name in ["meadow_ground", "meadow_ground_mobile", "terrain_slopes",
			"terrain_slopes_mobile", "road_surface", "road_surface_mobile", "service_ground"]:
		var shader := load("res://shaders/%s.gdshader" % name) as Shader
		if material.shader == shader or material.shader.code == shader.code:
			if name.begins_with("meadow"):
				return "meadow"
			if name.begins_with("terrain"):
				return "terrain"
			if name.begins_with("road"):
				return "road"
			return "service"
	return ""

static func baseline_material_kind(material: Material) -> String:
	if not material is ShaderMaterial or material.shader == null:
		return "standard"
	if baseline_ground_family(material) != "":
		return "ground"
	return "custom"

static func baseline_materials(node: GeometryInstance3D, mesh: Mesh) -> Array[Material]:
	if node.material_override != null:
		return [node.material_override]
	var materials: Array[Material] = []
	for i in range(mesh.get_surface_count()):
		materials.append(node.get_active_material(i) if node is MeshInstance3D else mesh.surface_get_material(i))
	return materials

static func profile_ground_materials(root: Node) -> Dictionary:
	# Gameplay diagnostic only. Keep geometry, visibility, physics and mixed
	# meshes unchanged; never edit shared materials or mesh surface resources.
	var report := {"diagnostic_only": true, "replaced": 0, "skipped_mixed": 0}
	var flat := StandardMaterial3D.new()
	flat.albedo_color = Color(0.4, 0.5, 0.3)
	flat.roughness = 1.0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		var mesh: Mesh
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
		if mesh == null:
			continue
		var materials := baseline_materials(node, mesh)
		var ground_count := 0
		for material in materials:
			if baseline_ground_family(material) != "":
				ground_count += 1
		if ground_count == 0:
			continue
		if ground_count != materials.size():
			report.skipped_mixed += 1
			continue
		node.material_override = flat
		report.replaced += 1
	return report

static func profile_render_baseline(camera: Camera3D) -> void:
	# Diagnostic APKs compare shader substitution with geometry exclusion.
	# Exclusion changes only render layers; physics and gameplay stay active.
	baseline_running = true
	var viewport := camera.get_viewport()
	var original_scale := viewport.scaling_3d_scale
	viewport.scaling_3d_scale = 0.65
	var original_mask := camera.cull_mask
	var original_transform := camera.global_transform
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.albedo_color = Color(0.4, 0.5, 0.3)
	var records: Array[Dictionary] = []
	for node in camera.get_tree().current_scene.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
		if mesh == null:
			continue
		var custom := false
		var ground := false
		var families: Array[String] = []
		# This experiment substitutes whole geometry instances. Mixed-material
		# instances belong to ground if any active surface renders ground.
		for material in baseline_materials(node, mesh):
			var kind := baseline_material_kind(material)
			custom = custom or kind != "standard"
			ground = ground or kind == "ground"
			var family := baseline_ground_family(material)
			if family != "" and not family in families:
				families.append(family)
		records.append({"node": node, "material": node.material_override, "layers": node.layers, "custom": custom, "ground": ground, "families": families})
	# Match ground-level review locations instead of measuring the aerial menu.
	# This isolates static rendering cost; it is not a combat FPS acceptance run.
	var views := [
		{"name": "spawn", "position": Vector3(17, 1.65, 50), "target": Vector3(-1, 2.2, 66)},
		{"name": "road", "position": Vector3(2, 1.6, 61), "target": Vector3(0, 3.2, -85)},
	]
	var cases := [
		{"mode": "original", "scale": 0.65},
		{"mode": "original", "scale": 0.55},
		{"mode": "original", "scale": 0.45},
		{"mode": "flat_ground", "scale": 0.65},
		{"mode": "flat_meadow", "scale": 0.65},
		{"mode": "flat_terrain", "scale": 0.65},
		{"mode": "flat_road", "scale": 0.65},
		{"mode": "flat_service", "scale": 0.65},
		{"mode": "flat_other_custom", "scale": 0.65},
		{"mode": "flat_custom", "scale": 0.65},
		{"mode": "hide_ground", "scale": 0.65},
		{"mode": "hide_instanced_other", "scale": 0.65},
		{"mode": "hide_individual_other", "scale": 0.65},
		{"mode": "hide_other", "scale": 0.65},
		{"mode": "hide_all", "scale": 0.65},
		{"mode": "original", "scale": 0.65},
	]
	for view in views:
		camera.global_position = view.position
		camera.look_at(view.target)
		for case in cases:
			viewport.scaling_3d_scale = case.scale
			var mode: String = case.mode
			for record in records:
				var node = record.node
				node.material_override = record.material
				node.layers = record.layers
				if (mode == "flat_custom" and record.custom) or (mode == "flat_ground" and record.ground) or (mode == "flat_other_custom" and record.custom and not record.ground):
					node.material_override = flat
				if mode.begins_with("flat_") and mode.trim_prefix("flat_") in record.families:
					node.material_override = flat
				if mode == "hide_all" or (mode == "hide_ground" and record.ground) or (mode == "hide_other" and not record.ground):
					node.layers = 0
				# Separate batched vegetation/details from individual meshes.
				# Both partitions exclude ground and retain original materials.
				if not record.ground:
					if mode == "hide_instanced_other" and node is MultiMeshInstance3D:
						node.layers = 0
					if mode == "hide_individual_other" and node is MeshInstance3D:
						node.layers = 0
			# Let incremental distance culling and shader compilation settle.
			await camera.get_tree().create_timer(1.0).timeout
			var samples: Array[float] = []
			var started := Time.get_ticks_usec()
			var previous := started
			while Time.get_ticks_usec() - started < 3000000:
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				samples.append((now - previous) / 1000.0)
				previous = now
			samples.sort()
			print("ANDROID_BASELINE mode=", mode,
				" view=", view.name,
				" fps=", snappedf(samples.size() * 1000000.0 / (previous - started), 0.1),
				" p95_ms=", snappedf(samples[int(samples.size() * 0.95)], 0.1),
				" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				" scale=", viewport.scaling_3d_scale)
	# Restore explicitly so adding/reordering diagnostic cases cannot leak a
	# substituted material or camera pose into the playable session.
	for record in records:
		record.node.material_override = record.material
		record.node.layers = record.layers
	camera.global_transform = original_transform
	camera.cull_mask = original_mask
	viewport.scaling_3d_scale = original_scale
	baseline_running = false
	print("ANDROID_BASELINE_COMPLETE")

static func warm_combat(camera: Camera3D) -> void:
	# Allocate shared smoke textures and meshes during loading, before the first
	# grenade. This does not start particles or change their simulation.
	preload("res://scripts/blast_effect.gd")._ensure_resources()
	preload("res://scripts/grenade.gd").warm_resources()
	# Keep these resources alive after drawing them: freeing the last instance
	# can discard driver allocations and repeat the work when combat starts.
	var original := camera.transform
	var stage := Node3D.new()
	stage.name = "CombatRenderWarmup"
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	camera.get_parent().add_child(stage)
	stage.position = Vector3(0, 1000, 0)
	var visuals = preload("res://scripts/world_visuals.gd")
	var started := Time.get_ticks_msec()
	# Recovered driver sources identify roof glazing (r1024), workbench wood
	# and pegboard (r1083), facade glass and jamb (r1100) as first-view compiles.
	# Ground views can miss these
	# behind cover, so draw their cached gameplay shaders during loading.
	for entry in [
		["WorkshopRoofGlazing", "workshop_roof_glazing_mobile"],
		["WorkbenchWood", "workbench_wood"],
		["WorkshopPegboard", "workshop_pegboard"],
		["WorkshopGlass", "workshop_glass"],
		["WorkshopJamb", "workshop_jamb"],
	]:
		var surface := MeshInstance3D.new()
		surface.name = entry[0]
		surface.mesh = BoxMesh.new()
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/%s.gdshader" % entry[1])
		surface.material_override = material
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(surface)
		camera.global_position = surface.global_position + Vector3(0, 0, 3)
		camera.look_at(surface.global_position)
		await camera.get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		surface.visible = false
	# r1113 driver sources contain double-sided emission, red roughness and
	# no normal map, matching the imported workshop task diffuser. Draw the
	# actual mesh/material independently so the surrounding tools cannot
	# occlude this small surface during loading.
	var tools_scene := load("res://assets/realism/workshop_tools.glb") as PackedScene
	var tools_model := tools_scene.instantiate()
	var source := tools_model.find_child("Task light diffuser", true, false) as MeshInstance3D
	var diffuser := MeshInstance3D.new()
	diffuser.name = "WorkshopTaskDiffuser"
	diffuser.mesh = source.mesh
	diffuser.material_override = source.get_active_material(0)
	diffuser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(diffuser)
	tools_model.free()
	var diffuser_center := diffuser.global_transform * diffuser.get_aabb().get_center()
	var diffuser_distance := maxf(diffuser.get_aabb().size.length() * 1.2, 0.1)
	for direction in [Vector3(0.3, 0.2, 1), Vector3(-0.3, -0.2, -1)]:
		camera.global_position = diffuser_center + direction * diffuser_distance
		camera.look_at(diffuser_center)
		await camera.get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	diffuser.visible = false
	for asset in ["operator_mobile", "first_person_mobile", "carbine", "shotgun", "marksman",
			"carbine_mobile", "shotgun_mobile", "marksman_mobile",
			"foregrip", "grenade", "smoke_grenade", "buggy"]:
		var scene := load("res://assets/%s.glb" % asset) as PackedScene
		var model := scene.instantiate() as Node3D
		stage.add_child(model)
		visuals.military_materials(model)
		if asset.trim_suffix("_mobile") in ["carbine", "shotgun", "marksman"]:
			visuals.weapon_finish(model)
		var bounds := AABB()
		var has_bounds := false
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_bounds: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
			has_bounds = true
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if has_bounds:
			var center := bounds.get_center()
			var distance := maxf(bounds.size.length() * 1.2, 0.5)
			for side in [-1.0, 1.0]:
				camera.global_position = center + Vector3(distance * 0.3, distance * 0.2, distance * side)
				camera.look_at(center)
				await camera.get_tree().process_frame
				await RenderingServer.frame_post_draw
		model.visible = false
	# The scope is created procedurally, so drawing the imported marksman
	# model alone does not warm its shader. Use the actual gameplay resources.
	var scope := preload("res://scripts/first_person.gd").create_scope_lens()
	stage.add_child(scope)
	camera.global_position = scope.global_position + Vector3(0, 0, 0.2)
	camera.look_at(scope.global_position)
	await camera.get_tree().process_frame
	await RenderingServer.frame_post_draw
	scope.visible = false
	# First shots also need the procedural muzzle mesh uploaded. Share the
	# actual actor resources and draw them before returning to the lobby.
	var muzzle := preload("res://scripts/muzzle_flash.gd").create()
	stage.add_child(muzzle)
	muzzle.visible = true
	camera.global_position = muzzle.global_position + Vector3(0.1, 0, 0.3)
	camera.look_at(muzzle.global_position)
	await camera.get_tree().process_frame
	await RenderingServer.frame_post_draw
	muzzle.visible = false
	# A muzzle flash does not exercise the line primitive used by tracers.
	# Draw and retain the same resources that shot_fx uses during gameplay.
	var tracer := preload("res://scripts/tracer_effect.gd").create()
	stage.add_child(tracer)
	camera.global_position = tracer.global_position + Vector3(0.5, 0, 0.5)
	camera.look_at(tracer.global_position + Vector3(0, 0, 0.5))
	await camera.get_tree().process_frame
	await RenderingServer.frame_post_draw
	tracer.visible = false
	# The grenade model does not draw its depth-reading volume shader.
	# Exercise the actual cloud resources before the first combat detonation.
	var smoke := preload("res://scripts/smoke_effect.gd").create()
	stage.add_child(smoke)
	smoke.material_override.set_shader_parameter("radius", 1.0)
	smoke.material_override.set_shader_parameter("density", 1.0)
	smoke.material_override.set_shader_parameter("age", 2.0)
	camera.global_position = smoke.global_position + Vector3(0, 0, 3)
	camera.look_at(smoke.global_position)
	await camera.get_tree().process_frame
	await RenderingServer.frame_post_draw
	smoke.visible = false
	# Allocation alone does not exercise the particle rendering variant.
	# Draw the gameplay configuration during loading without explosion timers,
	# damage, or desktop-only lights, then retain its rendering resources.
	var blast_particles := preload("res://scripts/blast_effect.gd").create_particles()
	for particles in blast_particles:
		particles.process_mode = Node.PROCESS_MODE_ALWAYS
		particles.preprocess = 0.1
		stage.add_child(particles)
	camera.global_position = stage.global_position + Vector3(0, 0, 3)
	camera.look_at(stage.global_position)
	for frame in range(2):
		await camera.get_tree().process_frame
		await RenderingServer.frame_post_draw
	for particles in blast_particles:
		particles.emitting = false
		particles.visible = false
		particles.process_mode = Node.PROCESS_MODE_DISABLED
	stage.visible = false
	camera.transform = original
	await RenderingServer.frame_post_draw
	print("ANDROID_STARTUP: combat models warmed ms=", Time.get_ticks_msec() - started)

static func configure_window(window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_size = Vector2i(1440, 900)
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.msaa_3d = Viewport.MSAA_DISABLED
	# Keep touch/UI coordinates stable while reducing the 3D framebuffer.
	window.scaling_3d_scale = 0.65
	# Imported meshes retain their authored silhouette at close range, while
	# selecting simpler index buffers earlier on the small mobile framebuffer.
	window.mesh_lod_threshold = 4.0
	Engine.max_fps = 60

static func configure_world(world: Node) -> Dictionary:
	var before := 0
	var after := 0
	var mobile_grass_materials := {}
	var short_grass_materials := {}
	var short_grass_shaders := {}
	var short_grass_meshes := {}
	var gravel_meshes := {}
	for sun in world.find_children("*", "DirectionalLight3D", true, false):
		sun.shadow_enabled = false
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 45.0
		sun.directional_shadow_blend_splits = false
	# Compatibility renders additional passes for local lights. Daylight already
	# lights the level; decorative lamps must not multiply every foliage draw.
	for light in world.find_children("*", "Light3D", true, false):
		if not light is DirectionalLight3D:
			light.visible = false
	for geometry in world.find_children("*", "GeometryInstance3D", true, false):
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var litter_materials := {}
	for cell in world.find_children("GroundLitterCell*", "MultiMeshInstance3D", true, false):
		if cell.material_override != null:
			litter_materials[cell.material_override] = true
	for node in world.find_children("*", "MultiMeshInstance3D", true, false):
		if node.name in ["ServiceYardRecoveryAggregate", "ServiceLaneLooseAggregate", "RepairApronDrainageRubble", "RepairAccessEmbeddedGravel",
			"RepairApronSurfaceAggregate", "WestSillLooseDeposits", "CanopyDrainAggregate",
			"RepairShelterSplashStones"]:
			var source_mesh: Mesh = node.multimesh.mesh if node.multimesh != null else null
			if source_mesh is SphereMesh or source_mesh is ArrayMesh:
				if not gravel_meshes.has(source_mesh):
					gravel_meshes[source_mesh] = compact_gravel_mesh(source_mesh)
				# Other batches may share the original MultiMesh resource.
				node.multimesh = compact_gravel_instances(node.multimesh)
				node.multimesh.mesh = gravel_meshes[source_mesh]
		# Older packed scenes rename sibling cells, but share their material.
		# Each cell is 12 m wide:
		# a 26 m center cutoff keeps its nearest details beyond 17 m visible,
		# without drawing subpixel pebbles and leaves out to 42 m.
		if node.get_meta("mobile_ground_litter", false) or litter_materials.has(node.material_override):
			node.visibility_range_end = 26.0
			# Ground litter shares a small sphere across many cells. Remove its
			# zero-area pole triangles once, retaining every pebble and leaf.
			if node.multimesh != null and node.multimesh.mesh is SphereMesh:
				var litter_mesh: Mesh = node.multimesh.mesh
				if not gravel_meshes.has(litter_mesh):
					gravel_meshes[litter_mesh] = compact_gravel_mesh(litter_mesh)
				node.multimesh = node.multimesh.duplicate()
				node.multimesh.mesh = gravel_meshes[litter_mesh]
		var material = node.material_override
		if material == null and node.multimesh != null and node.multimesh.mesh != null:
			material = node.multimesh.mesh.surface_get_material(0)
		if not material is ShaderMaterial or material.shader == null:
			continue
		# Packed scenes can embed shaders and replace their original resource path.
		var shader_code: String = material.shader.code
		var animated_grass: bool = node.get_meta("mobile_grass", false) or ("tuft_variation" in shader_code and "colony_hash" in shader_code)
		var static_grass := "leaf_normal" in shader_code and "sky_normal" in shader_code
		if not animated_grass and not static_grass:
			continue
		var original: MultiMesh = node.multimesh
		if original == null or original.instance_count == 0:
			continue
		# Procedural patches can reserve more slots than they populate. Respect
		# the populated prefix instead of making unused transforms visible again.
		var active_count := original.instance_count if original.visible_instance_count < 0 else mini(original.instance_count, original.visible_instance_count)
		before += active_count
		var reduced := MultiMesh.new()
		reduced.transform_format = original.transform_format
		reduced.use_colors = original.use_colors
		reduced.use_custom_data = original.use_custom_data
		reduced.mesh = original.mesh
		reduced.instance_count = ceili(active_count / 16.0)
		# Read the source buffer once and submit the selected records together.
		# Preserve the exact transform/color/custom-data bits and existing 1/16
		# selection without thousands of individual RenderingServer calls.
		var stride := 12 if original.transform_format == MultiMesh.TRANSFORM_3D else 8
		if original.use_colors:
			stride += 4
		if original.use_custom_data:
			stride += 4
		var source_buffer := original.buffer
		var reduced_buffer := PackedFloat32Array()
		reduced_buffer.resize(reduced.instance_count * stride)
		for i in range(reduced.instance_count):
			var source_offset := mini(i * 16, active_count - 1) * stride
			for component in range(stride):
				reduced_buffer[i * stride + component] = source_buffer[source_offset + component]
		if not reduced_buffer.is_empty():
			reduced.buffer = reduced_buffer
		node.multimesh = reduced
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 30.0
		if animated_grass:
			node.set_meta("mobile_animated_grass_fade", true)
			# Decide from actual local vertices, not instance scale or a custom
			# bounding box: blade_height is captured before wind and transforms.
			if not short_grass_meshes.has(original.mesh):
				short_grass_meshes[original.mesh] = grass_can_skip_dry_tips(original.mesh)
			var short_grass: bool = short_grass_meshes[original.mesh] and "#ifndef SHORT_GRASS" in shader_code
			var materials: Dictionary = short_grass_materials if short_grass else mobile_grass_materials
			# Cells sharing a source material use identical fade uniforms. Retain
			# sharing within each height class, including mixed-mesh sources.
			if not materials.has(material):
				var mobile_material: ShaderMaterial = material.duplicate()
				if short_grass:
					# Distinct source materials can share a shader while keeping
					# their own uniforms. Reuse its specialized rendering resource.
					if not short_grass_shaders.has(material.shader):
						var short_shader := Shader.new()
						short_shader.code = "#define SHORT_GRASS\n" + shader_code
						short_grass_shaders[material.shader] = short_shader
					mobile_material.shader = short_grass_shaders[material.shader]
				mobile_material.set_shader_parameter("fade_begin", 16.0)
				mobile_material.set_shader_parameter("fade_end", 24.0)
				materials[material] = mobile_material
			node.material_override = materials[material]
		after += reduced.instance_count
	return {"grass_before": before, "grass_after": after,
		"batched_instances": batch_static_meshes(world),
		"access_gravel_cells": split_access_gravel(world),
		"background_grove_cells": split_background_groves(world)}

static func grass_can_skip_dry_tips(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() == 0:
		return false
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			return false
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			return false
		for vertex in vertices:
			# Strict comparison also rejects NaN and preserves the exact edge.
			if not vertex.y <= 0.16:
				return false
	return true

static func compact_gravel_instances(source: MultiMesh) -> MultiMesh:
	var compact: MultiMesh = source.duplicate()
	# These static gravel batches never populate their reserved slots later.
	# Keep the visible prefix and its attributes without uploading spare slots.
	var active := source.visible_instance_count
	if active < 0 or active >= source.instance_count:
		return compact
	var buffer := source.buffer
	var stride := buffer.size() / source.instance_count
	# Preserve the original culling bounds and distance-range center.
	compact.custom_aabb = source.get_aabb()
	compact.instance_count = active
	if active > 0:
		compact.buffer = buffer.slice(0, active * stride)
	compact.visible_instance_count = -1
	return compact

static func compact_gravel_sphere(source: SphereMesh) -> ArrayMesh:
	return compact_gravel_mesh(source)

static func compact_gravel_mesh(source: Mesh) -> ArrayMesh:
	# Only whitelisted single-surface gravel and ground-litter spheres use this path.
	# Flat-shaded deformed stones also retain the primitive pole triangles.
	# Primitive sphere pole quads contain triangles with coincident corners.
	# Keep the original vertex attributes and every nondegenerate triangle;
	# centimetre gravel needs no vertex displacement or sphere-specific API.
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(vertices.size())
		for i in range(vertices.size()):
			indices[i] = i
	var compact := PackedInt32Array()
	var tolerance_squared := pow(source.get_aabb().size.length() * 0.000001, 2)
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		if a.distance_squared_to(b) <= tolerance_squared or b.distance_squared_to(c) <= tolerance_squared or c.distance_squared_to(a) <= tolerance_squared:
			continue
		compact.append(indices[i])
		compact.append(indices[i + 1])
		compact.append(indices[i + 2])
	# Discard vertices orphaned by pole trimming and pack referenced vertices
	# in first-use order. Do not weld the UV seam or distinct pole normals.
	var remap := {}
	var identical_vertices := {}
	var referenced := PackedInt32Array()
	for i in range(compact.size()):
		var original := compact[i]
		if not remap.has(original):
			# Flat-shaded builders deindex every corner. Share only byte-equal
			# attributes: a hard normal or UV seam must remain separate.
			var key := []
			for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
				if arrays[attribute] == null:
					continue
				var stride := 4 if attribute == Mesh.ARRAY_TANGENT else 1
				for component in range(stride):
					key.append(arrays[attribute][original * stride + component])
			if not identical_vertices.has(key):
				identical_vertices[key] = referenced.size()
				referenced.append(original)
			remap[original] = identical_vertices[key]
		compact[i] = remap[original]
	for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arrays[attribute] == null:
			continue
		var original = arrays[attribute]
		var packed = original.duplicate()
		var stride := 4 if attribute == Mesh.ARRAY_TANGENT else 1
		packed.resize(referenced.size() * stride)
		for i in range(referenced.size()):
			for component in range(stride):
				packed[i * stride + component] = original[referenced[i] * stride + component]
		arrays[attribute] = packed
	arrays[Mesh.ARRAY_INDEX] = compact
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Reuse recently transformed corners within each tiny instanced stone.
	# Only copy the reordered indices: retain the exact packed attributes and
	# avoid another GPU normal/tangent encode/decode round trip.
	var optimizer := SurfaceTool.new()
	optimizer.create_from(mesh, 0)
	optimizer.optimize_indices_for_cache()
	arrays[Mesh.ARRAY_INDEX] = optimizer.commit_to_arrays()[Mesh.ARRAY_INDEX]
	# Cache optimization changes first-use order. Match vertex storage to the
	# final index stream for sequential fetches across every instanced stone.
	preload("res://scripts/terrain_mesh_lod.gd").reorder_vertex_fetch(arrays, {}, false)
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, source.surface_get_material(0))
	return mesh

static func split_access_gravel(world: Node) -> int:
	# The access apron spans several road views. Coarse cells let the renderer
	# cull off-screen stones without removing geometry or changing materials.
	# 8m cells added seven road-view draws to cull only 4956 triangles.
	# Use 16m cells to bound submission overhead for this compact stone patch.
	var count := 0
	var sources := world.find_children("RepairAccessEmbeddedGravel", "MultiMeshInstance3D", true, false)
	# The recovery patch crosses the same road view; retain every stone while
	# allowing its off-screen half to be culled independently.
	sources.append_array(world.find_children("ServiceYardRecoveryAggregate", "MultiMeshInstance3D", true, false))
	for source in sources:
		var original: MultiMesh = source.multimesh
		if original == null or original.mesh == null or original.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		if original.visible_instance_count >= 0 or source.get_child_count() != 0:
			continue
		if not source.material_override is StandardMaterial3D or source.material_override.next_pass != null or source.material_overlay != null:
			continue
		if source.visibility_range_begin != 0.0 or source.visibility_range_end != 0.0:
			continue
		var groups := {}
		var placements: Array[Transform3D] = []
		placements.resize(original.instance_count)
		for i in range(original.instance_count):
			var placement := original.get_instance_transform(i)
			placements[i] = placement
			var origin := placement.origin
			var key := Vector2i(floori(origin.x / 16.0), floori(origin.z / 16.0))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(i)
		if groups.size() <= 1:
			continue
		# Preserve complete instance records, uploading each cell once instead
		# of issuing separate rendering-server updates for every attribute.
		var source_buffer := original.buffer
		var stride := 12 + (4 if original.use_colors else 0) + (4 if original.use_custom_data else 0)
		var mesh_bounds := original.mesh.get_aabb()
		var distance_bounds: AABB = source.global_transform * source.get_aabb()
		var batches: Array[MultiMeshInstance3D] = []
		for key in groups:
			# Duplicate before attaching children, retaining all render settings.
			var batch: MultiMeshInstance3D = source.duplicate()
			batch.name = "AccessGravelCell_%s_%s" % [key.x, key.y]
			# Retain the original distance center/threshold; cells only refine frustum culling.
			batch.set_meta("mobile_distance_bounds", distance_bounds)
			batch.transform = Transform3D.IDENTITY
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.use_colors = original.use_colors
			instances.use_custom_data = original.use_custom_data
			instances.mesh = original.mesh
			instances.instance_count = groups[key].size()
			var cell_buffer := PackedFloat32Array()
			cell_buffer.resize(instances.instance_count * stride)
			var bounds := AABB()
			for j in range(instances.instance_count):
				var index: int = groups[key][j]
				for component in range(stride):
					cell_buffer[j * stride + component] = source_buffer[index * stride + component]
				var stone_bounds: AABB = placements[index] * mesh_bounds
				bounds = stone_bounds if j == 0 else bounds.merge(stone_bounds)
			instances.buffer = cell_buffer
			instances.custom_aabb = bounds
			batch.multimesh = instances
			batch.custom_aabb = bounds
			batches.append(batch)
		source.multimesh = null
		for batch in batches:
			source.add_child(batch)
			count += 1
	return count

static func _background_grove_radius(mesh: QuadMesh, placement: Transform3D, tight_billboard: bool) -> float:
	var scales_squared := Vector3(placement.basis.x.length_squared(),
		placement.basis.y.length_squared(), placement.basis.z.length_squared())
	# The known keep-scale billboard rotates orthogonal axes in the shader.
	# Its largest axis scale bounds every rotated corner; summing all three
	# scales unnecessarily expands the culling sphere by up to sqrt(3).
	if tight_billboard:
		return mesh.size.length() * 0.5 * sqrt(maxf(scales_squared.x, maxf(scales_squared.y, scales_squared.z)))
	return mesh.size.length() * 0.5 * sqrt(scales_squared.x + scales_squared.y + scales_squared.z)

static func split_background_groves(world: Node) -> int:
	# A valley-wide MultiMesh submits every tree even when most are behind the
	# camera. Preserve every instance, using coarse cells for frustum culling.
	var count := 0
	for grove in world.find_children("BackgroundGroves", "MultiMeshInstance3D", true, false):
		var original: MultiMesh = grove.multimesh
		if original == null or not original.mesh is QuadMesh or grove.get_meta("mobile_background_grove", false):
			continue
		var material = grove.material_override
		if material == null:
			material = original.mesh.material
		var tight_billboard: bool = material is StandardMaterial3D \
			and material.billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y \
			and material.billboard_keep_scale and grove.material_overlay == null \
			and not material.grow \
			and original.mesh.center_offset == Vector3.ZERO \
			and grove.global_basis.is_equal_approx(Basis.IDENTITY)
		var groups := {}
		var visible_count := original.instance_count if original.visible_instance_count < 0 else original.visible_instance_count
		for i in range(visible_count):
			var origin := original.get_instance_transform(i).origin
			var key := Vector2i(floori(origin.x / 128.0), floori(origin.z / 128.0))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(i)
		for key in groups:
			var batch: MultiMeshInstance3D = grove.duplicate()
			batch.name = "BackgroundGroveCell_%s_%s" % [key.x, key.y]
			batch.set_meta("mobile_background_grove", true)
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.use_colors = original.use_colors
			instances.use_custom_data = original.use_custom_data
			instances.mesh = original.mesh
			instances.instance_count = groups[key].size()
			var bounds := AABB()
			for j in range(instances.instance_count):
				var index: int = groups[key][j]
				var placement := original.get_instance_transform(index)
				instances.set_instance_transform(j, placement)
				if instances.use_colors:
					instances.set_instance_color(j, original.get_instance_color(index))
				if instances.use_custom_data:
					instances.set_instance_custom_data(j, original.get_instance_custom_data(index))
				# Fixed-Y billboards rotate in the shader. A sphere enclosing all
				# orientations avoids clipping crowns at cell/frustum boundaries.
				var diagonal := Basis.from_scale(Vector3(placement.basis.x.x, placement.basis.y.y, placement.basis.z.z))
				var radius := _background_grove_radius(original.mesh, placement,
					tight_billboard and placement.basis.is_equal_approx(diagonal))
				var tree_bounds := AABB(placement.origin - Vector3.ONE * radius, Vector3.ONE * radius * 2.0)
				bounds = tree_bounds if j == 0 else bounds.merge(tree_bounds)
			instances.custom_aabb = bounds
			batch.multimesh = instances
			batch.custom_aabb = bounds
			grove.get_parent().add_child(batch)
			count += 1
		# Keep the source node in place; configure_world can be called again.
		grove.multimesh = null
	return count

static func optimize_static_surface(source: Mesh) -> ArrayMesh:
	var primitive := SurfaceTool.new()
	primitive.create_from(source, 0)
	# Procedural triangle surfaces can be unindexed. Build an attribute-aware
	# index first so cache optimization and orphan removal have a valid stream.
	var source_indices = source.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	if source_indices == null or source_indices.is_empty():
		primitive.index()
	primitive.optimize_indices_for_cache()
	var arrays := primitive.commit_to_arrays()
	strip_collapsed_static_triangles(arrays)
	preload("res://scripts/terrain_mesh_lod.gd").reorder_vertex_fetch(arrays, {}, false)
	var optimized := ArrayMesh.new()
	optimized.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	optimized.surface_set_material(0, source.surface_get_material(0))
	# Singleton nodes retain their original culling center and bounds too.
	optimized.custom_aabb = source.get_aabb()
	return optimized

static func batch_static_meshes(world: Node3D) -> int:
	# Called before actors and loot exist. Keep original nodes and their collision
	# children; only transfer eligible static render surfaces to spatial batches.
	var groups := {}
	var material_keys := {}
	var optimized_primitives := {}
	var dense_meshes := {}
	var world_inverse := world.global_transform.affine_inverse()
	for node in world.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or not node.is_visible_in_tree() or node.skin != null:
			continue
		if node.get_script() != null or node.material_overlay != null:
			continue
		# A simple far cutoff can be retained on a spatial batch. Near LOD
		# transitions and fading depend on each individual instance's distance.
		if node.visibility_range_begin != 0.0 or node.visibility_range_end_margin != 0.0 or node.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED:
			continue
		if not node.visibility_parent.is_empty() or node.custom_aabb != AABB():
			continue
		var eligible := true
		var instance_only := false
		var bake_geometry: bool = node.mesh is PrimitiveMesh or (
			node.mesh is ArrayMesh and node.get_meta("mobile_bake_static_surface", false)
			and node.mesh.get_surface_count() == 1
			and node.mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES)
		var parent = node.get_parent()
		while parent != world and parent != null:
			if parent.get_script() != null or parent is PhysicsBody3D and not parent is StaticBody3D:
				eligible = false
			parent = parent.get_parent()
		for surface in range(node.mesh.get_surface_count()):
			if node.get_surface_override_material(surface) != null:
				eligible = false
			var material = node.material_override
			if material == null:
				material = node.mesh.surface_get_material(surface)
			if material is ShaderMaterial:
				# These static opaque shaders can retain local coordinates and normals
				# through MultiMesh transforms, but must not bake vertices together.
				var instance_shader: bool = material.shader in [
					preload("res://shaders/precast_concrete.gdshader"),
					preload("res://shaders/warehouse_concrete.gdshader"),
					preload("res://shaders/workshop_masonry.gdshader"),
				]
				var bake_shader: bool = material.shader == preload("res://shaders/shelter_structural_steel.gdshader") and bake_geometry
				if (not instance_shader and not bake_shader) or material.next_pass != null:
					eligible = false
				instance_only = instance_only or instance_shader
			elif material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				eligible = false
		if not eligible:
			continue
		var bounds: AABB = node.global_transform * node.get_aabb()
		var diameter := bounds.size.length()
		var distance := detail_distance(diameter)
		if node.visibility_range_end > 0.0:
			distance = node.visibility_range_end
		var mesh_key := str(node.mesh.get_instance_id())
		# Imported ArrayMesh surfaces may carry generated LODs. SurfaceTool
		# rebuilding discards those levels; only explicitly tagged procedural
		# triangle surfaces may opt into baking alongside primitives.
		var merge_surface: bool = not instance_only and node.mesh.get_surface_count() == 1 and bake_geometry
		# SurfaceTool transforms normals with the vertex basis. Restrict merging
		# to positive uniform scale without shear to preserve lighting.
		var bake_basis: Basis = (world_inverse * node.global_transform).basis
		var scale_squared := Vector3(bake_basis.x.length_squared(), bake_basis.y.length_squared(), bake_basis.z.length_squared())
		var positive_basis := bake_basis.determinant() > 0.0
		var normalized_basis := bake_basis.orthonormalized() if positive_basis else Basis.IDENTITY
		merge_surface = merge_surface and positive_basis \
			and is_equal_approx(scale_squared.x, scale_squared.y) \
			and is_equal_approx(scale_squared.x, scale_squared.z) \
			and bake_basis.x.normalized().is_equal_approx(normalized_basis.x) \
			and bake_basis.y.normalized().is_equal_approx(normalized_basis.y) \
			and bake_basis.z.normalized().is_equal_approx(normalized_basis.z)
		# Only baked primitives/opted-in surfaces share the wider material batch.
		# Near surfaces use 32m cells to reduce submissions in full-scene
		# Android-branch OpenGL replays; distant surfaces retain 128m cells.
		# Keep imported meshes in tighter instance cells
		# to limit offscreen geometry submitted
		# when any part of a group enters the frustum or visibility range.
		var cell_size := (128.0 if distance >= 160.0 else 32.0) if merge_surface else 16.0
		# Dense imported meshes make large cells expensive when only one
		# instance is on screen. Keep cheap details in their existing batches.
		if not merge_surface and node.mesh is ArrayMesh:
			if not dense_meshes.has(node.mesh):
				var element_count := 0
				for surface in range(node.mesh.get_surface_count()):
					if node.mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
						var index_count: int = node.mesh.surface_get_array_index_len(surface)
						element_count += index_count if index_count > 0 else node.mesh.surface_get_array_len(surface)
				dense_meshes[node.mesh] = element_count >= 9000
			if dense_meshes[node.mesh]:
				cell_size = 8.0
		var cell := Vector3i(((world_inverse * bounds.get_center()) / cell_size).floor())
		var effective_material = node.material_override
		if effective_material == null:
			effective_material = node.mesh.surface_get_material(0)
		if merge_surface:
			# Generated details often duplicate an identical opaque material. Compare
			# all stored rendering properties; resource identity alone prevents batching.
			if not material_keys.has(effective_material):
				var properties := {}
				if effective_material != null:
					for property in effective_material.get_property_list():
						if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["resource_name", "resource_path", "resource_local_to_scene", "script"]:
							properties[property.name] = effective_material.get(property.name)
				material_keys[effective_material] = (effective_material.get_class() if effective_material != null else "") + var_to_str(properties)
		if merge_surface:
			mesh_key = "surface-material:" + material_keys[effective_material]
		var key := "%s|%s|%s|%s|%s|%s|%s" % [cell, mesh_key,
			null if merge_surface else node.material_override, node.layers, distance, node.gi_mode,
			node.ignore_occlusion_culling]
		if not groups.has(key):
			groups[key] = {"nodes": [], "distance": distance, "merge": merge_surface, "material": effective_material,
				"optimize": true}
		# Reordering local primitive vertices is also safe for instance-only
		# shaders and nonuniform transforms. Require every member to opt in:
		# imported surfaces can share a group while carrying generated LODs.
		groups[key].optimize = groups[key].optimize and bake_geometry and node.mesh.get_surface_count() == 1
		groups[key].nodes.append(node)
	var count := 0
	for group in groups.values():
		if group.nodes.size() < 2:
			# Unique cell/material groups still benefit from the same lossless
			# triangle trimming and cache/fetch layout as merged primitives.
			if group.optimize:
				var singleton: MeshInstance3D = group.nodes[0]
				if not optimized_primitives.has(singleton.mesh):
					optimized_primitives[singleton.mesh] = optimize_static_surface(singleton.mesh)
				singleton.mesh = optimized_primitives[singleton.mesh]
			continue
		var first: MeshInstance3D = group.nodes[0]
		if group.merge:
			# Static primitive props share materials but have different shapes. Merge
			# their surfaces per cell instead of submitting one draw per size.
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for original in group.nodes:
				# Optimize each shared primitive once, preserving constituent
				# submission order when surfaces overlap. There are no shared
				# vertices between constituents for a cross-object reorder to reuse.
				if not optimized_primitives.has(original.mesh):
					optimized_primitives[original.mesh] = optimize_static_surface(original.mesh)
				surface.append_from(optimized_primitives[original.mesh], 0, world_inverse * original.global_transform)
			var combined := MeshInstance3D.new()
			combined.name = "MobileFacadeBatch"
			combined.mesh = surface.commit()
			combined.mesh.surface_set_material(0, group.material)
			combined.material_override = group.material
			combined.layers = first.layers
			combined.gi_mode = first.gi_mode
			combined.ignore_occlusion_culling = first.ignore_occlusion_culling
			combined.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			combined.visibility_range_end = group.distance
			world.add_child(combined)
			if group.distance > 0.0:
				# A merged surface is culled around its combined center. Retaining
				# the original radius alone can remove a nearby constituent early.
				# Enclose every original cutoff sphere; this runs only at setup.
				var center: Vector3 = (combined.global_transform * combined.get_aabb()).get_center()
				var padding := 0.0
				for original in group.nodes:
					var original_center: Vector3 = (original.global_transform * original.get_aabb()).get_center()
					padding = maxf(padding, center.distance_to(original_center))
				combined.visibility_range_end += padding
			for original in group.nodes:
				original.mesh = null
			count += group.nodes.size()
			continue
		var batch := MultiMeshInstance3D.new()
		batch.name = "MobileStaticBatch"
		batch.material_override = first.material_override
		batch.layers = first.layers
		batch.gi_mode = first.gi_mode
		batch.ignore_occlusion_culling = first.ignore_occlusion_culling
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = group.distance
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = first.mesh
		if group.optimize:
			if not optimized_primitives.has(first.mesh):
				optimized_primitives[first.mesh] = optimize_static_surface(first.mesh)
			instances.mesh = optimized_primitives[first.mesh]
		instances.instance_count = group.nodes.size()
		var transform_data := PackedFloat32Array()
		transform_data.resize(group.nodes.size() * 12)
		var batch_bounds := AABB()
		var original_centers: Array[Vector3] = []
		for i in range(group.nodes.size()):
			var original: MeshInstance3D = group.nodes[i]
			var local_transform: Transform3D = world_inverse * original.global_transform
			var local_bounds: AABB = local_transform * original.get_aabb()
			batch_bounds = local_bounds if i == 0 else batch_bounds.merge(local_bounds)
			if group.distance > 0.0:
				original_centers.append((original.global_transform * original.get_aabb()).get_center())
			# Upload the static batch once instead of crossing into the rendering
			# server for each member. MultiMesh stores three row-major vec4 rows.
			var offset := i * 12
			for axis in range(3):
				transform_data[offset + axis * 4] = local_transform.basis.x[axis]
				transform_data[offset + axis * 4 + 1] = local_transform.basis.y[axis]
				transform_data[offset + axis * 4 + 2] = local_transform.basis.z[axis]
				transform_data[offset + axis * 4 + 3] = local_transform.origin[axis]
			original.mesh = null
		instances.buffer = transform_data
		# Static transforms never change: explicit bounds avoid renderer-side
		# instance-bound updates and give distance culling a stable center.
		instances.custom_aabb = batch_bounds
		batch.multimesh = instances
		world.add_child(batch)
		if group.distance > 0.0:
			var center: Vector3 = (batch.global_transform * batch_bounds).get_center()
			var padding := 0.0
			for original_center in original_centers:
				padding = maxf(padding, center.distance_to(original_center))
			batch.visibility_range_end += padding
		count += group.nodes.size()
	return count

func update_loot_detail(camera_position: Vector3, delta: float) -> void:
	loot_cull_seconds -= delta
	if loot_cull_keys.is_empty() and loot_cull_seconds > 0.0:
		return
	# Resolve the current dictionary once per slice, rather than once per drop.
	# Do not retain it across frames: a world reset can replace the dictionary.
	var loot_nodes: Dictionary = get_parent().world.loot_nodes
	if loot_nodes.is_empty():
		# A reset invalidates the entire pending snapshot. Avoid spending
		# subsequent frame slices looking up IDs that no longer exist.
		loot_cull_keys.clear()
		loot_cull_cursor = 0
		loot_cull_seconds = 0.05
		return
	if loot_cull_keys.is_empty():
		# Cache IDs, not nodes: a pickup/reset may free or replace a proxy
		# between frames. New drops join the next scan.
		loot_cull_keys = loot_nodes.keys()
		loot_cull_cursor = 0
	var started := Time.get_ticks_usec()
	var slice_end := mini(loot_cull_cursor + 64, loot_cull_keys.size())
	while loot_cull_cursor < slice_end:
		# Bound each batch once instead of testing a modulo and the full
		# dictionary snapshot size for every drop.
		var batch_end := mini(loot_cull_cursor + 8, slice_end)
		while loot_cull_cursor < batch_end:
			var proxy = loot_nodes.get(loot_cull_keys[loot_cull_cursor])
			loot_cull_cursor += 1
			if is_instance_valid(proxy):
				configure_loot_detail(proxy,
					camera_position.distance_squared_to(proxy.global_position))
		# Retain the 64-entry hard cap and 500 us soft budget, including
		# invalid IDs. No drop waits for a fresh scan while this one runs.
		if Time.get_ticks_usec() - started >= 500:
			break
	if loot_cull_cursor >= loot_cull_keys.size():
		loot_cull_keys.clear()
		loot_cull_cursor = 0
		loot_cull_seconds = 0.05

func static_distance_scan_needed(camera_position: Vector3) -> bool:
	# These entries have fixed world bounds. Rotation alone cannot change their
	# distance visibility; dynamic loot is updated separately every frame.
	return cull_cursor != 0 or baseline_running or not cull_settled \
		or cull_settled_count != distance_nodes.size() \
		or camera_position != cull_settled_position

func update_distance_visibility(camera_position: Vector3, cull_started: int) -> void:
	if cull_cursor == 0:
		cull_pass_position = camera_position
		cull_pass_stable = true
		cull_settled = false
	elif camera_position != cull_pass_position:
		cull_pass_stable = false
	# Check the clock once per small batch, instead of once per world object.
	# The 1 ms soft budget can overrun by at most the remaining 15 entries.
	# Static entries do not change during this synchronous scan. Keep the
	# entry count local instead of querying the array twice per batch.
	var entry_count := distance_nodes.size()
	# All grass batches use the same horizontal camera position this pass.
	var camera_xz := Vector2(camera_position.x, camera_position.z)
	while cull_cursor < entry_count:
		var batch_end := mini(cull_cursor + 16, entry_count)
		while cull_cursor < batch_end:
			var entry: DistanceEntry = distance_nodes[cull_cursor]
			var shown: bool
			if entry.grass_fade_squared > 0.0:
				# Match the shader's horizontal root distance. The older 3D
				# center limit can hide near blades in wide or sloped patches.
				shown = entry.grass_in_range_xz(camera_xz)
			else:
				var distance_squared := camera_position.distance_squared_to(entry.center)
				shown = distance_squared >= entry.begin_squared and distance_squared < entry.end_squared
			if entry.node.visible != shown:
				entry.node.visible = shown
			cull_cursor += 1
		if Time.get_ticks_usec() - cull_started >= 1000:
			break
	if cull_cursor >= entry_count:
		cull_cursor = 0
		cull_seconds = 0.05
		# A pass spanning camera movement has mixed results. Complete another
		# pass at the stopped position before suppressing stationary scans.
		cull_settled = cull_pass_stable and not baseline_running
		cull_settled_position = camera_position
		cull_settled_count = entry_count

func sample_route_state(elapsed: float) -> void:
	# The touch driver needs fresh health/zone state between commands.
	# Profiling touch runs wait for a sample after releasing the look gesture.
	# A full second here leaves the player standing exposed between commands.
	# Keep normal logging at one second, expensive summaries at five seconds,
	# and avoid catch-up bursts after a stall.
	route_sample_seconds += elapsed
	if route_sample_seconds < route_sample_interval:
		return
	route_sample_seconds = 0.0
	if get_parent().has_method("android_route_state"):
		print("ANDROID_ROUTE route_json=", get_parent().android_route_state())

func _process(_delta: float) -> void:
	var cull_started := Time.get_ticks_usec()
	var camera := get_viewport().get_camera_3d()
	# Read the scene transform once; both scans use the same frame position.
	var camera_position := camera.global_position if camera != null else Vector3.ZERO
	cull_seconds -= _delta
	if cull_seconds <= 0.0 or cull_cursor != 0:
		if camera != null and static_distance_scan_needed(camera_position):
			# Spread the measured 4,000+ node scan over frames. A scan continues
			# from its cursor, so distant entries cannot starve when moving.
			update_distance_visibility(camera_position, cull_started)
	# Give dynamic loot its own share so a large static scan cannot starve it.
	if camera != null:
		update_loot_detail(camera_position, _delta)
	cull_peak_ms = maxf(cull_peak_ms, (Time.get_ticks_usec() - cull_started) / 1000.0)
	process_peak_ms = maxf(process_peak_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	physics_peak_ms = maxf(physics_peak_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var now := Time.get_ticks_usec()
	if last_frame_usec == 0:
		last_frame_usec = now
		return
	var elapsed := (now - last_frame_usec) / 1000000.0
	last_frame_usec = now
	adapt_resolution(elapsed)
	sample_route_state(elapsed)
	frame_times.append(elapsed * 1000.0)
	sample_seconds += elapsed
	if sample_seconds < 5.0:
		return
	frame_times.sort()
	print("ANDROID_PERF fps=", snappedf(frame_times.size() / sample_seconds, 0.1),
		" p95_ms=", snappedf(frame_times[mini(frame_times.size() - 1,
			int(frame_times.size() * 0.95))], 0.1),
		" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		" scale=", get_viewport().scaling_3d_scale)
	print("ANDROID_CPU process_peak_ms=", snappedf(process_peak_ms, 0.1),
		" physics_peak_ms=", snappedf(physics_peak_ms, 0.1),
		" cull_peak_ms=", snappedf(cull_peak_ms, 0.1),
		" render_wall_peak_ms=", snappedf(render_peak_ms, 0.1),
		" cull_nodes=", distance_nodes.size())
	if get_parent().has_method("android_gameplay_state"):
		print("ANDROID_GAMEPLAY ", get_parent().android_gameplay_state())
	flush_render_stalls()
	frame_times.clear()
	sample_seconds = 0.0
	process_peak_ms = 0.0
	physics_peak_ms = 0.0
	cull_peak_ms = 0.0
	render_peak_ms = 0.0
