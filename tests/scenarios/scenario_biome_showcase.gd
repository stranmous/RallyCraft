extends SceneTree

# Windowed & headless verification scenario for Task 5.4:
# Steps across all 6 biome presets (Spa Forest, Alpine, Parkland, Open Grassland, Desert Dirt, Forest Dirt),
# verifies BiomeEnvironment + CarVfxController (DustEmitter, BoostEmitter, SparkEmitter),
# showcases the 6-biome Track Builder UI, and builds a contact sheet for visual inspection.

const SHEET_COLUMNS := 4
const SHEET_TILE := Vector2i(480, 270)
const TIMEOUT_TICKS := 900

var _main: MainController
var _headless := false
var _out_dir := ""
var _tick := 0
var _stage := 0
var _stage_tick := 0
var _wait_frames := 0
var _pending_tag := ""
var _captured_paths: Array[String] = []
var _passes := 0
var _fails: Array[String] = []
var _metrics: Array[String] = []
var _stages: Array[Dictionary] = []

var _curated_by_theme := {}
var _builder_screen: Control = null
var _spark_contact_seen := false
var _spark_capture_countdown := -1
var _dust_active_seen := false
var _boost_active_seen := false


func _initialize() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_out_dir = _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_clear_old_outputs()

	print("\n=== SCENARIO: BiomeShowcase ===")
	print("Verifies all 6 biome presets, 3 VFX emitters (dust, boost, spark), and 6-biome Track Builder UI.")
	print("Output: %s" % _out_dir)
	print("Mode: %s" % ("headless (no frame capture)" if _headless else "windowed (1280x720 live + frame capture)"))

	for tr in CuratedTrackCatalog.get_curated_tracks():
		_curated_by_theme[tr.theme] = tr

	var desert_track := TrackDefinition.create_custom("Sahara Dirt Stage", PackedVector2Array([
		Vector2(-150, -70), Vector2(-40, -135), Vector2(115, -100),
		Vector2(175, 10), Vector2(95, 130), Vector2(-95, 115),
	]))
	desert_track.track_id = "showcase_desert_dirt"
	desert_track.surface = "dirt"
	desert_track.road_width = "wide"
	desert_track.theme = "desert"

	var forest_track := TrackDefinition.create_custom("Timber Dirt Stage", PackedVector2Array([
		Vector2(-80, -50), Vector2(80, 50), Vector2(150, 75), Vector2(170, 0),
		Vector2(150, -75), Vector2(80, -50), Vector2(-80, 50), Vector2(-150, 75),
		Vector2(-170, 0), Vector2(-150, -75),
	]))
	forest_track.track_id = "showcase_forest_dirt"
	forest_track.surface = "dirt"
	forest_track.road_width = "standard"
	forest_track.theme = "forest"

	_stages = [
		{"tag": "01_spa_forest", "track": _curated_by_theme.get("spa_forest"), "ai": 3, "ticks": 28, "mode": "cruise", "cl_frac": 0.22},
		{"tag": "02_alpine", "track": _curated_by_theme.get("alpine"), "ai": 2, "ticks": 28, "mode": "cruise", "cl_frac": 0.34},
		{"tag": "03_parkland", "track": _curated_by_theme.get("parkland"), "ai": 2, "ticks": 28, "mode": "cruise", "cl_frac": 0.46},
		{"tag": "04_open_grassland", "track": _curated_by_theme.get("open_grassland"), "ai": 2, "ticks": 28, "mode": "cruise", "cl_frac": 0.38},
		{"tag": "05_desert_dirt_boost", "track": desert_track, "ai": 1, "ticks": 34, "mode": "dirt_boost", "cl_frac": 0.14},
		{"tag": "06_forest_dirt_drift", "track": forest_track, "ai": 1, "ticks": 32, "mode": "dirt_drift", "cl_frac": 0.12},
		{"tag": "07_contact_sparks", "track": _curated_by_theme.get("parkland"), "ai": 1, "ticks": 70, "mode": "spark", "cl_frac": 0.04},
	]

	_main = MainController.new()
	root.add_child(_main)
	await process_frame
	_start_stage(0)


func _physics_process(_delta: float) -> bool:
	_tick += 1
	if _tick >= TIMEOUT_TICKS:
		_expect(false, "BiomeShowcase timed out at tick %d." % _tick)
		_finish()
		return true

	if _wait_frames > 0:
		_wait_frames -= 1
		if _wait_frames == 0:
			if _stage < _stages.size():
				_start_stage(_stage)
			elif _stage == _stages.size():
				_start_builder_stage()
		return false

	if _stage < _stages.size():
		_step_race_stage(_stages[_stage])
	elif _stage == _stages.size():
		_step_builder_stage()
	return false


func _process(_delta: float) -> bool:
	if not _pending_tag.is_empty():
		var tag := _pending_tag
		_pending_tag = ""
		_capture_frame(tag)
		if tag == "08_builder_six_biomes_3d":
			_cleanup_and_finish()
	return false


func _start_stage(idx: int) -> void:
	_stage = idx
	_stage_tick = 0
	var cfg: Dictionary = _stages[idx]
	var track: TrackDefinition = cfg.track as TrackDefinition
	if track == null:
		_expect(false, "Missing track for stage %d (%s)." % [idx, cfg.tag])
		_advance_after_close()
		return
	_main._show_race_preview(RaceResult.MODE_CIRCUIT, 2, int(cfg.ai), track)
	_verify_race_environment(track, str(cfg.tag))
	if str(cfg.mode) == "spark":
		_setup_spark_collision_approach()
	else:
		_position_cars_on_scenic_sector(float(cfg.get("cl_frac", 0.25)), str(cfg.mode) != "cruise")


func _verify_race_environment(track: TrackDefinition, tag: String) -> void:
	var race_root := _main._race_root
	_expect(race_root != null, "%s: RacePreview root must exist." % tag)
	if race_root == null:
		return
	var env := race_root.get_node_or_null("BiomeEnvironment") as Node3D
	var ts := env.get_node_or_null("BiomeTrackside") as Node3D if env != null else null
	var nat := env.get_node_or_null("BiomeNature") as Node3D if env != null else null
	_expect(env != null and ts != null and ts.get_child_count() > 0, "%s: BiomeTrackside populated." % tag)
	_expect(nat != null and nat.get_child_count() > 0, "%s: BiomeNature populated." % tag)
	var player := _main._preview_player_car
	var vfx := player.get_node_or_null("CarVfxController") as CarVfxController if player != null else null
	_expect(vfx != null, "%s: Player CarVfxController attached." % tag)


func _position_cars_on_scenic_sector(cl_frac: float, high_speed: bool) -> void:
	var rm := _find_race_manager()
	var player := _main._preview_player_car
	if rm == null or player == null:
		return
	var cl: PackedVector3Array = rm._centerline
	if cl.size() < 16:
		return
	var n := cl.size()
	var idx := clampi(int(round(float(n) * cl_frac)), 4, n - 4)
	var fwd := (cl[(idx + 1) % n] - cl[(idx - 1 + n) % n])
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	player.global_position = cl[idx] + Vector3.UP * 0.25
	player.rotation = Vector3(0.0, atan2(-fwd.x, -fwd.z), 0.0)
	var launch_spd := 22.0 if high_speed else 20.0
	player._drive.speed = launch_spd
	player.velocity = fwd * launch_spd

	var ai := _main._preview_ai_cars
	for i in ai.size():
		var a_idx := (idx + 2 + i * 2) % n
		var a_fwd := (cl[(a_idx + 1) % n] - cl[(a_idx - 1 + n) % n])
		a_fwd.y = 0.0
		a_fwd = a_fwd.normalized()
		var lat := -2.2 if i % 2 == 0 else 2.2
		ai[i].global_position = cl[a_idx] + Vector3(-a_fwd.z, 0.0, a_fwd.x) * lat + Vector3.UP * 0.25
		ai[i].rotation = Vector3(0.0, atan2(-a_fwd.x, -a_fwd.z), 0.0)
		ai[i]._drive.speed = 21.0
		ai[i].velocity = a_fwd * 21.0

	for child in _main._race_root.get_children():
		if child is RallyChaseCamera:
			(child as RallyChaseCamera).snap_to_target()
			break


func _step_race_stage(cfg: Dictionary) -> void:
	_stage_tick += 1
	var player := _main._preview_player_car
	if player == null or not is_instance_valid(player):
		return
	var mode := str(cfg.mode)
	var target_ticks := int(cfg.ticks)
	var vfx := player.get_node_or_null("CarVfxController") as CarVfxController
	var dust := vfx.get_node_or_null("DustEmitter") as CPUParticles3D if vfx != null else null
	var boost := vfx.get_node_or_null("BoostEmitter") as CPUParticles3D if vfx != null else null

	if mode == "cruise":
		_steer_along_road(player, false)
	elif mode == "dirt_boost":
		_steer_along_road(player, false)
		if _stage_tick == 12:
			player.request_touch_boost()
		if dust != null and dust.emitting:
			_dust_active_seen = true
		if boost != null and boost.emitting:
			_boost_active_seen = true
	elif mode == "dirt_drift":
		var drift_brake := _stage_tick >= 20 and _stage_tick <= 28
		if drift_brake:
			player.set_touch_input(true, false, true)
		else:
			_steer_along_road(player, false)
		if _stage_tick == 16:
			player.request_touch_boost()
		if dust != null and dust.emitting:
			_dust_active_seen = true
		if boost != null and boost.emitting:
			_boost_active_seen = true
	elif mode == "spark":
		_drive_into_rival(player)
		if player._contact_cooldown > 0.1 and not _spark_contact_seen:
			_spark_contact_seen = true
			_spark_capture_countdown = 3
		if _spark_capture_countdown > 0:
			_spark_capture_countdown -= 1
			if _spark_capture_countdown == 0:
				_pending_tag = str(cfg.tag)
				print("[TELEMETRY] stage=%s tick=%d contact_cooldown=%.2f" % [cfg.tag, _stage_tick, player._contact_cooldown])
				_advance_after_close()
				return

	if _stage_tick >= target_ticks:
		var ds := player.get_drive_state()
		print("[TELEMETRY] stage=%s tick=%d speed=%.1fm/s boost=%.2f dust=%s" % [
			cfg.tag, _stage_tick, float(ds.get("speed", 0.0)), float(ds.get("boost_remaining", 0.0)),
			str(dust.emitting if dust != null else false)
		])
		_pending_tag = str(cfg.tag)
		_advance_after_close()


func _advance_after_close() -> void:
	_main._close_race_preview()
	_stage += 1
	_wait_frames = 3


func _start_builder_stage() -> void:
	_stage_tick = 0
	_builder_screen = _main._show_track_builder()
	var alpine_btn := _builder_screen.find_child("Theme_alpine_Button", true, false) as Button
	var canvas := _builder_screen.find_child("DrawingCanvas", true, false) as TrackDrawingCanvas
	var inspect_btn := _builder_screen.find_child("InspectPreviewButton", true, false) as Button
	for theme_id in TrackDefinition.THEMES:
		var btn := _builder_screen.find_child("Theme_%s_Button" % theme_id, true, false) as Button
		_expect(btn != null, "08_builder_six_biomes_3d: Theme_%s_Button present." % theme_id)
	if canvas != null:
		var loop := PackedVector2Array([
			Vector2(140, 140), Vector2(360, 110), Vector2(560, 170),
			Vector2(600, 340), Vector2(500, 480), Vector2(260, 490),
			Vector2(130, 340), Vector2(140, 140),
		])
		var processed := TrackPathProcessor.process_drawing(loop)
		canvas.drawing_processed.emit(processed)
	if alpine_btn != null:
		alpine_btn.pressed.emit()
	if inspect_btn != null:
		inspect_btn.pressed.emit()


func _step_builder_stage() -> void:
	_stage_tick += 1
	if _stage_tick == 12:
		print("[TELEMETRY] stage=08_builder_six_biomes_3d tick=%d" % _stage_tick)
		_pending_tag = "08_builder_six_biomes_3d"
		_stage += 1


func _setup_spark_collision_approach() -> void:
	var rm := _find_race_manager()
	var player := _main._preview_player_car
	var cars := _main._preview_ai_cars
	var drivers := _main._preview_ai_drivers
	if rm == null or player == null or cars.is_empty():
		return
	var cl: PackedVector3Array = rm._centerline
	if cl.size() < 12:
		return
	var idx := 6
	var p := cl[idx]
	var fwd := (cl[idx + 1] - cl[idx - 1])
	fwd.y = 0.0
	fwd = fwd.normalized()
	var rival: RallyCar = cars[0]
	rival.set_drive_enabled(false)
	if not drivers.is_empty() and is_instance_valid(drivers[0]):
		drivers[0].set_physics_process(false)
	rival.global_position = p + fwd * 11.0 + Vector3.UP * 0.25
	rival.rotation = Vector3(0.0, atan2(-fwd.x, -fwd.z), 0.0)
	rival.velocity = Vector3.ZERO
	rival._drive.speed = 0.0

	player.global_position = p + Vector3.UP * 0.25
	player.rotation = Vector3(0.0, atan2(-fwd.x, -fwd.z), 0.0)
	player._drive.speed = 26.0
	player.velocity = fwd * 26.0
	player._contact_cooldown = 0.0
	player.request_touch_boost()
	for child in _main._race_root.get_children():
		if child is RallyChaseCamera:
			(child as RallyChaseCamera).snap_to_target()
			break


func _drive_into_rival(player: RallyCar) -> void:
	var cars := _main._preview_ai_cars
	if cars.is_empty() or cars[0] == null or not is_instance_valid(cars[0]):
		_steer_along_road(player, false)
		return
	var rival: RallyCar = cars[0]
	var to_rival := rival.global_position - player.global_position
	var right := player.global_transform.basis.x
	var lat := to_rival.dot(right)
	player.set_touch_input(lat < -0.15, lat > 0.15, false)


func _steer_along_road(player: RallyCar, brake: bool) -> void:
	var rm := _find_race_manager()
	if rm == null:
		return
	var nearest := rm._find_nearest_route_point(player.global_position)
	var ctrl := AIDriver.compute_control(rm._centerline, int(nearest.index), player.global_position, -player.global_transform.basis.z)
	var st := float(ctrl.steering)
	player.set_touch_input(st < -0.1, st > 0.1, brake)


func _find_race_manager() -> RaceManager:
	if _main == null or _main._race_root == null:
		return null
	for child in _main._race_root.get_children():
		if child is RaceManager:
			return child as RaceManager
	return null


func _cleanup_and_finish() -> void:
	_expect(_dust_active_seen, "DustEmitter emitted during dirt road / braking drift showcase.")
	_expect(_boost_active_seen, "BoostEmitter emitted during boost showcase.")
	_expect(_spark_contact_seen, "SparkEmitter contact cooldown triggered on car collision.")
	_metrics.append("stages_rendered=%d" % _stages.size())
	_metrics.append("captured_frames=%d" % _captured_paths.size())
	_metrics.append("dust_active=%s boost_active=%s spark_contact=%s" % [str(_dust_active_seen), str(_boost_active_seen), str(_spark_contact_seen)])
	if _builder_screen != null and is_instance_valid(_builder_screen):
		_builder_screen.free()
	if _main != null and is_instance_valid(_main):
		_main.free()
	_build_contact_sheet()
	_finish()


func _finish() -> void:
	var verdict := "PASS" if _fails.is_empty() else "FAIL"
	var summary := FileAccess.open(_out_dir.path_join("summary.txt"), FileAccess.WRITE)
	if summary != null:
		summary.store_line("scenario=BiomeShowcase verdict=%s passes=%d fails=%d ticks=%d" % [verdict, _passes, _fails.size(), _tick])
		for m in _metrics:
			summary.store_line("METRIC " + m)
		for f in _fails:
			summary.store_line("FAIL " + f)
		summary.close()
	for m in _metrics:
		print("  METRIC  %s" % m)
	print("=== BiomeShowcase: %s (%d passed, %d failed, %d frames captured) ===" % [verdict, _passes, _fails.size(), _captured_paths.size()])
	quit(0 if _fails.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  PASS    %s" % msg)
	else:
		_fails.append(msg)
		printerr("  FAIL    %s" % msg)


func _capture_frame(tag: String) -> void:
	if _headless:
		return
	var tex := root.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	var path := _out_dir.path_join("frame_%s.png" % tag)
	if img.save_png(path) == OK:
		_captured_paths.append(path)


func _build_contact_sheet() -> void:
	if _headless or _captured_paths.is_empty():
		return
	var count := _captured_paths.size()
	var cols := mini(SHEET_COLUMNS, count)
	var rows := int(ceil(float(count) / float(cols)))
	var sheet := Image.create(cols * SHEET_TILE.x, rows * SHEET_TILE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("070d10"))
	for i in count:
		var tile := Image.load_from_file(_captured_paths[i])
		if tile == null:
			continue
		tile.resize(SHEET_TILE.x, SHEET_TILE.y, Image.INTERPOLATE_BILINEAR)
		if tile.get_format() != Image.FORMAT_RGBA8:
			tile.convert(Image.FORMAT_RGBA8)
		var col := i % cols
		var row := int(i / cols)
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, SHEET_TILE), Vector2i(col * SHEET_TILE.x, row * SHEET_TILE.y))
	sheet.save_png(_out_dir.path_join("contact_sheet.png"))


func _clear_old_outputs() -> void:
	var dir := DirAccess.open(_out_dir)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.ends_with(".png") or file_name.ends_with(".csv") or file_name == "summary.txt":
			dir.remove(file_name)


func _resolve_out_dir() -> String:
	var raw := "res://build/scenario_runs/manual/BiomeShowcase"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			raw = arg.trim_prefix("--out=")
	if raw.begins_with("res://") or raw.begins_with("user://"):
		return ProjectSettings.globalize_path(raw)
	return raw
