extends SceneTree

var _failures := 0


func _initialize() -> void:
	await process_frame
	_test_registry_paths_and_sizes()
	_test_car_variants_paint_and_ghost()
	_test_trackside_and_nature_bounds()
	await _test_track_compiler_visual_attachments()
	_test_credits_ledger_coverage()

	await physics_frame
	if _failures > 0:
		printerr("asset_import_and_registry_test failed with %d error(s)." % _failures)
		quit(1)
		return
	print("asset_import_and_registry_test passed.")
	quit(0)


func _expect(cond: bool, message: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % message)


func _test_registry_paths_and_sizes() -> void:
	var all_paths := AssetRegistry.get_all_asset_paths()
	_expect(all_paths.size() >= 80, "AssetRegistry should catalog >= 80 assets (got %d)." % all_paths.size())
	for path in all_paths:
		_expect(ResourceLoader.exists(path), "Missing registered asset: %s" % path)

	for surf_key in AssetRegistry.SURFACE_TEXTURES.keys():
		var tex := AssetRegistry.load_surface_texture(surf_key)
		_expect(tex != null, "Surface texture should load: %s" % surf_key)
		if tex != null:
			_expect(tex.get_width() <= 512 and tex.get_height() <= 512, "Surface texture exceeds 512px budget: %s (%dx%d)" % [surf_key, tex.get_width(), tex.get_height()])

	for vfx_key in AssetRegistry.VFX_TEXTURES.keys():
		var tex := AssetRegistry.load_vfx_texture(vfx_key)
		_expect(tex != null, "VFX texture should load: %s" % vfx_key)
		if tex != null:
			_expect(tex.get_width() <= 128 and tex.get_height() <= 128, "VFX texture exceeds 128px budget: %s (%dx%d)" % [vfx_key, tex.get_width(), tex.get_height()])

	for icon_key in AssetRegistry.UI_ICONS.keys():
		var icon := AssetRegistry.load_icon(icon_key)
		_expect(icon != null and icon.get_width() >= 48 and icon.get_height() >= 48, "UI SVG icon should rasterize >=48px for crisp HUD scaling: %s" % icon_key)

	for sfx_key in AssetRegistry.AUDIO_SFX.keys():
		var stream := AssetRegistry.load_audio_stream(sfx_key, false)
		_expect(stream != null, "Audio SFX should load: %s" % sfx_key)

	for music_key in AssetRegistry.AUDIO_MUSIC.keys():
		var stream := AssetRegistry.load_audio_stream(music_key, true)
		_expect(stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop, "Music stream should configure OGG loop: %s" % music_key)

	var eng := AssetRegistry.load_audio_stream("engine_loop", true) as AudioStreamWAV
	_expect(eng != null and eng.loop_mode == AudioStreamWAV.LOOP_FORWARD, "engine_loop WAV should configure forward loop.")
	if eng != null:
		var eng_expected := roundi(eng.get_length() * float(eng.mix_rate))
		_expect(absi(eng.loop_end - eng_expected) <= 2, "engine_loop loop_end=%d should match full decoded sample count %d." % [eng.loop_end, eng_expected])
	var skid := AssetRegistry.load_audio_stream("tire_skid", true) as AudioStreamWAV
	_expect(skid != null and skid.loop_mode == AudioStreamWAV.LOOP_FORWARD, "tire_skid WAV should configure forward loop.")
	if skid != null:
		var skid_expected := roundi(skid.get_length() * float(skid.mix_rate))
		_expect(absi(skid.loop_end - skid_expected) <= 2, "tire_skid loop_end=%d should match full decoded sample count %d." % [skid.loop_end, skid_expected])
	_expect(AssetRegistry.load_audio_stream("nonexistent_audio_key", false) == null, "Unknown audio key should return null cleanly.")

	_test_png_vram_import_settings()


func _test_car_variants_paint_and_ghost() -> void:
	var c0 := AssetRegistry.instantiate_car_visual(0, Color("ff5500"), false)
	var c1 := AssetRegistry.instantiate_car_visual(1, Color("2288ee"), false)
	var c2 := AssetRegistry.instantiate_car_visual(2, Color("33aa55"), false)
	var c_wrap := AssetRegistry.instantiate_car_visual(-1, Color("aa44cc"), false)
	var ghost := AssetRegistry.instantiate_car_visual(0, Color.WHITE, true)

	for pair in [[0, c0], [1, c1], [2, c2], [-1, c_wrap]]:
		var idx: int = pair[0]
		var car: Node3D = pair[1]
		var aabb := _compute_node_aabb(car)
		_expect(aabb.size.x >= 1.3 and aabb.size.x <= 1.9, "Car variant %d width out of range: %.2f" % [idx, aabb.size.x])
		_expect(aabb.size.y >= 0.85 and aabb.size.y <= 1.4, "Car variant %d height out of range: %.2f" % [idx, aabb.size.y])
		_expect(aabb.size.z >= 3.0 and aabb.size.z <= 3.8, "Car variant %d length out of range: %.2f" % [idx, aabb.size.z])
		_expect(absf(aabb.position.y) <= 0.05, "Car variant %d bottom should sit on Y=0 (got %.3f)" % [idx, aabb.position.y])

	# Verify custom color isolation between two rally_coupe cars in SceneTree
	var second_coupe := AssetRegistry.instantiate_car_visual(3, Color("1199dd"), false)
	root.add_child(c0)
	root.add_child(second_coupe)
	var c0_paint := _find_body_paint_color(c0)
	var c3_paint := _find_body_paint_color(second_coupe)
	_expect(c0_paint.is_equal_approx(Color("ff5500")), "First coupe BodyPaint should match requested orange.")
	_expect(c3_paint.is_equal_approx(Color("1199dd")), "Second coupe BodyPaint should match requested blue without overwriting first.")

	var ghost_meshes := AssetRegistry._collect_mesh_instances(ghost)
	_expect(ghost_meshes.size() > 0, "Ghost car visual should contain at least one MeshInstance3D.")
	if not ghost_meshes.is_empty():
		var gm := ghost_meshes[0].material_override as StandardMaterial3D
		_expect(gm != null and gm.albedo_color.a < 0.9 and gm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Ghost car should use unshaded translucent material_override.")

	c0.free()
	second_coupe.free()
	c1.free()
	c2.free()
	c_wrap.free()
	ghost.free()


func _test_trackside_and_nature_bounds() -> void:
	for key in AssetRegistry.TRACKSIDE_MODELS.keys():
		var inst := AssetRegistry.instantiate_trackside(key)
		_expect(inst != null, "Trackside GLB should instantiate: %s" % key)
		if inst != null:
			_validate_mesh_hierarchy(key, inst, false)
			if key == "boost_pad":
				_validate_boost_pad_orientation(inst)
			elif key == "start_gantry":
				_validate_start_gantry_clearance(inst)
			inst.free()

	for key in AssetRegistry.NATURE_MODELS.keys():
		var inst := AssetRegistry.instantiate_nature(key)
		_expect(inst != null, "Nature GLB should instantiate: %s" % key)
		if inst != null:
			_validate_mesh_hierarchy(key, inst, true)
			inst.free()


func _validate_mesh_hierarchy(label: String, node: Node3D, is_nature: bool) -> void:
	var meshes := AssetRegistry._collect_mesh_instances(node)
	_expect(not meshes.is_empty(), "%s must contain at least one MeshInstance3D." % label)
	_expect(not _has_forbidden_runtime_node(node), "%s GLB must not contain embedded CollisionObject3D/CollisionShape3D/AnimationPlayer." % label)
	var aabb := _compute_node_aabb(node)
	_expect(absf(aabb.position.y) <= 0.08, "%s bottom Y should sit cleanly on ground pivot (got %.3f)." % [label, aabb.position.y])
	for mi in meshes:
		_expect(mi.mesh != null, "%s MeshInstance3D has null mesh." % label)
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				_expect(mat != null, "%s surface %d has null material." % [label, s])
				if is_nature and mat is StandardMaterial3D:
					var smat := mat as StandardMaterial3D
					_expect(smat.metallic <= 0.05, "%s surface %d should be non-metallic (got %.2f)." % [label, s, smat.metallic])
					if label == "tree_parkland":
						_expect(smat.resource_name != "_defaultMat", "tree_parkland must not contain stray _defaultMat material.")


func _test_track_compiler_visual_attachments() -> void:
	var spa := CuratedTrackCatalog.get_featured_track()
	var built := TrackCompiler.build_runtime(spa)
	_expect(bool(built.get("ok", false)), "Featured curated track should compile cleanly.")
	var runtime := built.get("runtime") as Node3D
	_expect(runtime != null, "build_runtime should create a runtime Node3D.")
	if runtime == null:
		return
	_expect(runtime.get_node_or_null("StartGantry") != null, "Compiled track runtime should attach StartGantry.")
	_expect(runtime.get_node_or_null("StartFlag_L") != null and runtime.get_node_or_null("StartFlag_R") != null, "Compiled track runtime should attach start flags.")
	var road := runtime.get_node_or_null("Road") as MeshInstance3D
	var curb := runtime.get_node_or_null("Curbs") as MeshInstance3D
	_expect(road != null and road.material_override is StandardMaterial3D and (road.material_override as StandardMaterial3D).albedo_texture != null, "Road should have textured albedo material.")
	_expect(curb != null and curb.material_override is StandardMaterial3D and (curb.material_override as StandardMaterial3D).albedo_texture != null, "Curbs should have textured albedo material.")
	var pickups := runtime.get_node_or_null("BoostPickups")
	var anchors: Array = built.get("boost_anchors", [])
	_expect(pickups != null and pickups.get_child_count() == anchors.size() and anchors.size() > 0, "BoostPickups should attach one child per generated boost anchor.")
	_test_race_audio_mix_and_bus_limiter()
	await _test_kaykit_grass_palette_and_preview_overlay()
	var alpine_ground := AssetRegistry.create_ground_material(false)
	_expect(alpine_ground.albedo_texture != null, "Alpine ground material should bind albedo_texture.")
	runtime.free()


func _test_race_audio_mix_and_bus_limiter() -> void:
	var car := RallyCar.new()
	var audio := RaceAudioController.new()
	root.add_child(car)
	root.add_child(audio)
	audio.configure(car, null)

	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(0):
		var fx := AudioServer.get_bus_effect(0, i)
		if fx is AudioEffectLimiter and fx.resource_name == RaceAudioController.MASTER_BUS_EFFECT_NAME:
			has_limiter = true
	_expect(has_limiter, "Master bus must configure RallyCraftLimiter to prevent multi-source clipping.")

	car._drive.speed = RallyDriveModel.BOOST_SPEED
	car.set_touch_input(false, false, true)
	for _i in 10:
		audio.update_mix(0.016)
	var snap_skid := audio.get_mix_snapshot()
	_expect(float(snap_skid.skid_blend) > 0.85, "Tire skid blend should ramp smoothly near full gain during high-speed drift.")
	_expect(float(snap_skid.boost_engage_db) > float(snap_skid.engine_db) + 3.0, "Boost SFX must remain clearly louder than full-throttle engine loop.")
	_expect(float(snap_skid.impact_db) > float(snap_skid.music_db) + 5.0, "Impact SFX must sit well above background music.")

	car.set_touch_input(false, false, false)
	audio.update_mix(0.016)
	var snap_release := audio.get_mix_snapshot()
	_expect(float(snap_release.skid_blend) > 0.0 and float(snap_release.skid_blend) < float(snap_skid.skid_blend), "Tire skid should fade out smoothly on release instead of cutting abruptly.")

	car._contact_cooldown = 0.5
	audio.update_mix(0.016)
	var snap_duck := audio.get_mix_snapshot()
	_expect(float(snap_duck.duck_timer) > 0.2 and float(snap_duck.music_db) < RaceAudioController.BASE_MUSIC_DB - 1.5, "Foreground collision should trigger brief background music ducking.")

	audio.set_music_muted(true)
	audio.update_mix(0.016)
	var snap_music_off := audio.get_mix_snapshot()
	_expect(bool(snap_music_off.music_muted) and not bool(snap_music_off.sfx_muted), "Muting music must keep SFX enabled.")
	_expect(float(snap_music_off.music_db) <= -79.0 and float(snap_music_off.engine_db) > -25.0, "Muting music must silence music while keeping engine SFX audible.")

	audio.set_music_muted(false)
	audio.set_sfx_muted(true)
	audio.update_mix(0.016)
	var snap_sfx_off := audio.get_mix_snapshot()
	_expect(bool(snap_sfx_off.sfx_muted) and not bool(snap_sfx_off.music_muted), "Muting SFX must keep music enabled.")
	_expect(float(snap_sfx_off.engine_db) <= -79.0 and float(snap_sfx_off.skid_blend) == 0.0 and float(snap_sfx_off.music_db) > -20.0, "Muting SFX must silence engine/skid while keeping music audible.")

	audio.set_sfx_muted(false)
	audio.set_paused(true)
	audio.set_muted(true)
	_expect(audio.is_muted(), "RaceAudioController mute state should update.")
	audio.free()
	car.free()


func _test_kaykit_grass_palette_and_preview_overlay() -> void:
	var pal_tex := ResourceLoader.load("res://assets/models/nature/hill_mound_hexagons_medieval.png") as Texture2D
	_expect(pal_tex != null, "KayKit palette texture should load.")
	if pal_tex != null:
		var pal_img := pal_tex.get_image()
		if pal_img != null:
			if pal_img.is_compressed():
				pal_img.decompress()
			var turf := pal_img.get_pixel(8, 152)
			_expect(turf.g > turf.r * 1.15, "KayKit grass-top cell (0,9) should be meadow green rather than yellow-chartreuse (got r=%.2f g=%.2f)." % [turf.r, turf.g])

	var preview := TrackPreviewWidget.new()
	preview.size = Vector2(560.0, 320.0)
	root.add_child(preview)
	await process_frame
	preview.set_view_mode(TrackPreviewWidget.VIEW_3D)
	await process_frame
	var toggle_bar := preview.find_child("ViewToggleBar", true, false) as Control
	var hint_lbl := preview.find_child("OrbitHintLabel", true, false) as Control
	_expect(toggle_bar != null and hint_lbl != null, "TrackPreviewWidget must expose ViewToggleBar and OrbitHintLabel.")
	if toggle_bar != null and hint_lbl != null:
		var toggle_bottom := toggle_bar.global_position.y + toggle_bar.size.y
		_expect(hint_lbl.global_position.y >= toggle_bottom + 2.0, "OrbitHintLabel (y=%.1f) must render cleanly below ViewToggleBar bottom (y=%.1f)." % [hint_lbl.global_position.y, toggle_bottom])
	preview.free()


func _test_credits_ledger_coverage() -> void:
	var credits_path := "res://assets/ASSET_CREDITS.md"
	_expect(FileAccess.file_exists(credits_path), "Provenance ledger must exist at res://assets/ASSET_CREDITS.md.")
	if not FileAccess.file_exists(credits_path):
		return
	var credits_text := FileAccess.get_file_as_string(credits_path)
	var disk_assets := _collect_disk_assets("res://assets")
	_expect(disk_assets.size() >= 84, "Expected at least 84 non-doc files inside res://assets (found %d)." % disk_assets.size())
	for asset_path in disk_assets:
		_expect(credits_text.contains(asset_path), "Asset missing from ASSET_CREDITS.md: %s" % asset_path)
	var re := RegEx.new()
	re.compile("res://assets/[A-Za-z0-9_./-]+\\.(glb|png|svg|wav|ogg)")
	for m in re.search_all(credits_text):
		var listed_path := m.get_string()
		_expect(FileAccess.file_exists(listed_path), "Stale asset path listed in ASSET_CREDITS.md: %s" % listed_path)


func _collect_disk_assets(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var full := "%s/%s" % [dir_path, entry]
			if dir.current_is_dir():
				results.append_array(_collect_disk_assets(full))
			else:
				if not entry.ends_with(".import") and not entry.ends_with(".md"):
					results.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return results


func _compute_node_aabb(node: Node3D) -> AABB:
	var first := true
	var merged := AABB()
	for mi in AssetRegistry._collect_mesh_instances(node):
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != node:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var aabb := xf * mi.mesh.get_aabb()
		if first:
			merged = aabb
			first = false
		else:
			merged = merged.merge(aabb)
	return merged


func _test_png_vram_import_settings() -> void:
	var checked := 0
	for dir_path in ["res://assets/textures", "res://assets/models"]:
		for asset_path in _collect_disk_assets(dir_path):
			if not asset_path.ends_with(".png"):
				continue
			var imp_path := "%s.import" % asset_path
			_expect(FileAccess.file_exists(imp_path), "Missing .import file for texture: %s" % asset_path)
			if FileAccess.file_exists(imp_path):
				var txt := FileAccess.get_file_as_string(imp_path)
				_expect(txt.contains("compress/mode=2"), "3D/VFX PNG should enable VRAM compression (compress/mode=2): %s" % asset_path)
				_expect(txt.contains("mipmaps/generate=true"), "3D/VFX PNG should enable mipmaps (mipmaps/generate=true): %s" % asset_path)
				_expect(txt.contains("\"vram_texture\": true"), "3D/VFX PNG import metadata must reflect vram_texture=true: %s" % asset_path)
				checked += 1
	_expect(checked >= 16, "Expected at least 16 3D/VFX PNGs audited for VRAM import (checked %d)." % checked)


func _has_forbidden_runtime_node(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is AnimationPlayer:
		return true
	for child in node.get_children():
		if _has_forbidden_runtime_node(child):
			return true
	return false


func _validate_boost_pad_orientation(node: Node3D) -> void:
	var tip_max_x := 0.0
	var wing_max_x := 0.0
	var tail_max_x := 0.0
	for mi in AssetRegistry._collect_mesh_instances(node):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null or mat.resource_name != "BoostGlow":
				continue
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in verts:
				if v.z < -0.95:
					tip_max_x = maxf(tip_max_x, absf(v.x))
				elif v.z >= -0.85 and v.z <= -0.45:
					wing_max_x = maxf(wing_max_x, absf(v.x))
				elif v.z > 0.85:
					tail_max_x = maxf(tail_max_x, absf(v.x))
	_expect(tip_max_x > 0.0 and tip_max_x < 0.28 and wing_max_x > 0.40 and tail_max_x <= 0.35, "boost_pad BoostGlow chevron must point toward -Z (tip_x=%.2f, wing_x=%.2f, tail_x=%.2f)." % [tip_max_x, wing_max_x, tail_max_x])


func _validate_start_gantry_clearance(node: Node3D) -> void:
	var low_central_verts := 0
	for mi in AssetRegistry._collect_mesh_instances(node):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in verts:
				if absf(v.x) < 6.0 and v.y < 4.5:
					low_central_verts += 1
	_expect(low_central_verts == 0, "start_gantry central road opening (<6.0m half-width) must be unobstructed below y=4.5m (found %d verts)." % low_central_verts)


func _find_body_paint_color(node: Node3D) -> Color:
	for mi in AssetRegistry._collect_mesh_instances(node):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if mat != null and mat.resource_name.to_lower() == "bodypaint":
				return mat.albedo_color
	return Color.BLACK
