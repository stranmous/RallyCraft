extends SceneTree

var _failures := 0


func _initialize() -> void:
	await process_frame
	_test_six_biome_presets_and_coverage()
	await _test_vfx_controller()
	await _test_builder_six_biome_ui()

	await physics_frame
	if _failures > 0:
		printerr("biome_presets_and_vfx_test failed with %d error(s)." % _failures)
		quit(1)
		return
	print("biome_presets_and_vfx_test passed.")
	quit(0)


func _expect(cond: bool, message: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % message)


func _test_six_biome_presets_and_coverage() -> void:
	var seen_sky_top := {}
	var seen_ground_albedo := {}
	for theme_key in TrackDefinition.THEMES:
		var preset := BiomePresets.get_preset(theme_key)
		_expect(str(preset.get("id", "")) == theme_key, "BiomePresets should resolve theme key '%s'." % theme_key)
		seen_sky_top[str(preset.sky_top)] = true
		seen_ground_albedo[str(preset.ground_albedo)] = true
	_expect(seen_sky_top.size() >= 5, "Six biome presets should provide distinct sky palettes (got %d unique)." % seen_sky_top.size())
	_expect(seen_ground_albedo.size() == TrackDefinition.THEMES.size(), "Every biome should have its own distinct ground albedo tint.")

	var test_tracks: Array[TrackDefinition] = []
	test_tracks.append_array(CuratedTrackCatalog.get_curated_tracks())

	var desert_loop := TrackDefinition.create_custom("Sahara Dirt Stage", PackedVector2Array([
		Vector2(-150, -70), Vector2(-40, -135), Vector2(115, -100),
		Vector2(175, 10), Vector2(95, 130), Vector2(-95, 115),
	]))
	desert_loop.track_id = "test_biome_desert"
	desert_loop.surface = "dirt"
	desert_loop.road_width = "wide"
	desert_loop.theme = "desert"
	test_tracks.append(desert_loop)

	var forest_crossing := TrackDefinition.create_custom("Timber Bridge Stage", PackedVector2Array([
		Vector2(-80, -50), Vector2(80, 50), Vector2(150, 75), Vector2(170, 0),
		Vector2(150, -75), Vector2(80, -50), Vector2(-80, 50), Vector2(-150, 75),
		Vector2(-170, 0), Vector2(-150, -75),
	]))
	forest_crossing.track_id = "test_biome_forest_bridge"
	forest_crossing.surface = "dirt"
	forest_crossing.road_width = "standard"
	forest_crossing.theme = "forest"
	test_tracks.append(forest_crossing)

	var used_nature := {}
	var used_trackside := {}

	for track in test_tracks:
		var compiled := TrackCompiler.build_runtime(track)
		_expect(bool(compiled.get("ok", false)), "Track '%s' (%s) must compile." % [track.track_id, track.theme])
		var runtime := compiled.runtime as Node3D
		if runtime.get_node_or_null("StartGantry") != null:
			used_trackside["start_gantry"] = true
		if runtime.get_node_or_null("StartFlag_L") != null:
			used_trackside["flag_checkered"] = true
		if not (compiled.get("boost_pickup_nodes", []) as Array).is_empty():
			used_trackside["boost_pad"] = true

		var layout := BiomePresets.compute_scenery_layout(compiled, track, -0.02)
		var arch_xforms: Array[Transform3D] = layout.get("arch_transforms", [] as Array[Transform3D])
		var ts_batches: Dictionary = layout.get("trackside_batches", {})
		var nat_batches: Dictionary = layout.get("nature_batches", {})

		var container := Node3D.new()
		root.add_child(container)
		var env_root := BiomePresets.apply_race_environment(container, compiled, track, true, false)

		var world_env := env_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
		var sun := env_root.get_node_or_null("SunLight") as DirectionalLight3D
		var ground := env_root.get_node_or_null("PreviewGround") as StaticBody3D
		var ts_group := env_root.get_node_or_null("BiomeTrackside") as Node3D
		var nat_group := env_root.get_node_or_null("BiomeNature") as Node3D

		_expect(world_env != null and world_env.environment != null, "%s: WorldEnvironment must exist." % track.theme)
		_expect(sun != null and not sun.shadow_enabled, "%s: SunLight must exist with shadows disabled for mobile budget." % track.theme)
		_expect(ground != null, "%s: PreviewGround StaticBody3D must exist." % track.theme)
		_expect(ts_group != null and ts_group.get_child_count() > 0, "%s: BiomeTrackside must populate props." % track.theme)
		_expect(nat_group != null and nat_group.get_child_count() > 0, "%s: BiomeNature must populate instanced props." % track.theme)

		_expect(not _has_collision_nodes(ts_group), "%s: BiomeTrackside props must not add runtime physics colliders." % track.theme)
		_expect(not _has_collision_nodes(nat_group), "%s: BiomeNature props must not add runtime physics colliders." % track.theme)

		var half_w := float(TrackCompiler.ROAD_HALF_WIDTHS[track.road_width])
		var min_edge_clearance := half_w + TrackCompiler.CURB_WIDTH + 0.15
		var cl: PackedVector3Array = compiled.centerline

		var mm_trackside_nodes := 0
		var arch_nodes := 0
		for child in ts_group.get_children():
			if child.name.begins_with("CheckpointArch"):
				arch_nodes += 1
				used_trackside["checkpoint_arch"] = true
			elif child is MultiMeshInstance3D:
				mm_trackside_nodes += 1
				var key := child.name.replace("MM_Trackside_", "")
				used_trackside[key] = true
				var expected_xforms: Array = ts_batches.get(key, [])
				var mm := (child as MultiMeshInstance3D).multimesh
				_expect(mm != null and mm.instance_count == expected_xforms.size() and mm.instance_count > 0, "%s: %s MultiMesh count mismatch (%d vs %d)." % [track.theme, child.name, mm.instance_count if mm != null else -1, expected_xforms.size()])

		_expect(arch_nodes == arch_xforms.size(), "%s: Spawned CheckpointArch nodes must match layout (%d vs %d)." % [track.theme, arch_nodes, arch_xforms.size()])
		for key in ts_batches.keys():
			var xforms: Array = ts_batches[key]
			for idx in xforms.size():
				var pos := (xforms[idx] as Transform3D).origin
				var d := _min_xz_dist(pos, cl)
				_expect(d >= min_edge_clearance, "%s: Trackside %s instance #%d overlapped road (dist=%.2f < %.2f)." % [track.theme, key, idx, d, min_edge_clearance])

		var mm_nature_nodes := 0
		var total_nature_instances := 0
		for child in nat_group.get_children():
			_expect(child is MultiMeshInstance3D, "%s: Nature child '%s' must be MultiMeshInstance3D." % [track.theme, child.name])
			if child is MultiMeshInstance3D:
				mm_nature_nodes += 1
				var key := child.name.replace("MM_Nature_", "")
				used_nature[key] = true
				var expected_xforms: Array = nat_batches.get(key, [])
				var mm := (child as MultiMeshInstance3D).multimesh
				_expect(mm != null and mm.instance_count == expected_xforms.size() and mm.instance_count > 0, "%s: %s MultiMesh count mismatch (%d vs %d)." % [track.theme, child.name, mm.instance_count if mm != null else -1, expected_xforms.size()])
				if mm != null:
					total_nature_instances += mm.instance_count

		for key in nat_batches.keys():
			if str(key) == "sky_cloud":
				continue
			var xforms: Array = nat_batches[key]
			for idx in xforms.size():
				var pos := (xforms[idx] as Transform3D).origin
				var d := _min_xz_dist(pos, cl)
				_expect(d >= half_w + BiomePresets.CURB_WIDTH + 2.8, "%s: Nature %s #%d too close to road (dist=%.2f)." % [track.theme, key, idx, d])

		_expect(mm_trackside_nodes <= 10 and mm_nature_nodes <= 16, "%s: MultiMesh batch count exceeded budget (%d trackside, %d nature)." % [track.theme, mm_trackside_nodes, mm_nature_nodes])
		_expect(total_nature_instances >= 50, "%s: Expected rich biome foliage/vista scatter >= 50 instances (got %d)." % [track.theme, total_nature_instances])

		container.free()
		runtime.free()

	for nat_key in AssetRegistry.NATURE_MODELS.keys():
		_expect(used_nature.has(nat_key), "Nature asset not placed by any of the 6 biome presets: %s" % nat_key)
	for ts_key in AssetRegistry.TRACKSIDE_MODELS.keys():
		_expect(used_trackside.has(ts_key), "Trackside asset not placed across biomes/compiler: %s" % ts_key)


func _test_vfx_controller() -> void:
	var car := RallyCar.new()
	var vfx := CarVfxController.new()
	car.add_child(vfx)
	vfx.configure(car, "dirt", "desert", true)
	# Verify safe no-op when called outside the scene tree.
	car._contact_cooldown = 0.5
	vfx._process(0.016)
	car._contact_cooldown = 0.0
	root.add_child(car)
	await process_frame
	var used_vfx := vfx.get_vfx_textures_used()
	for req_key in AssetRegistry.VFX_TEXTURES.keys():
		_expect(used_vfx.has(req_key), "CarVfxController must wire VFX texture: %s" % req_key)

	var dust := vfx.get_node_or_null("DustEmitter") as CPUParticles3D
	var boost := vfx.get_node_or_null("BoostEmitter") as CPUParticles3D
	var spark := vfx.get_node_or_null("SparkEmitter") as CPUParticles3D
	_expect(dust != null and boost != null and spark != null, "All three particle emitters should be constructed.")
	if boost != null:
		car._drive.boost_remaining = 0.8
		vfx._process(0.016)
		_expect(boost.emitting, "BoostEmitter should emit while boost_remaining > 0.")
		car._drive.boost_remaining = 0.0
		vfx._process(0.016)
		_expect(not boost.emitting, "BoostEmitter should stop emitting when boost expires.")
	if spark != null:
		car._contact_cooldown = 0.5
		vfx._process(0.016)
		_expect(spark.one_shot and car._contact_cooldown > 0.1, "SparkEmitter should configure one-shot burst and react cleanly to contact cooldown.")

	car.free()


func _test_builder_six_biome_ui() -> void:
	var main := MainController.new()
	root.add_child(main)
	await process_frame
	var builder := main._show_track_builder()
	for theme_id in TrackDefinition.THEMES:
		var btn := builder.find_child("Theme_%s_Button" % theme_id, true, false) as Button
		_expect(btn != null, "TrackBuilder must expose theme selector button for '%s'." % theme_id)
	var alpine_btn := builder.find_child("Theme_alpine_Button", true, false) as Button
	var canvas := builder.find_child("DrawingCanvas", true, false) as TrackDrawingCanvas
	var save_btn := builder.find_child("SaveTrackButton", true, false) as Button
	if alpine_btn != null and canvas != null and save_btn != null:
		var loop := PackedVector2Array([
			Vector2(140, 140), Vector2(360, 110), Vector2(560, 170),
			Vector2(600, 340), Vector2(500, 480), Vector2(260, 490),
			Vector2(130, 340), Vector2(140, 140),
		])
		var processed := TrackPathProcessor.process_drawing(loop)
		canvas.drawing_processed.emit(processed)
		alpine_btn.pressed.emit()
		var inspect_btn := builder.find_child("InspectPreviewButton", true, false) as Button
		if inspect_btn != null:
			inspect_btn.pressed.emit()
		save_btn.pressed.emit()
		_expect(main._active_track != null and main._active_track.theme == "alpine", "Selecting Alpine in TrackBuilder must assign theme='alpine' to saved track.")
		if main._active_track != null and not main._active_track.track_id.is_empty():
			TrackStore.new().delete_custom_track(main._active_track.track_id)
	builder.free()
	main.free()


func _has_collision_nodes(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _has_collision_nodes(child):
			return true
	return false


func _min_xz_dist(point: Vector3, centerline: PackedVector3Array) -> float:
	var best := INF
	for cp in centerline:
		var dx := point.x - cp.x
		var dz := point.z - cp.z
		best = minf(best, sqrt(dx * dx + dz * dz))
	return best
