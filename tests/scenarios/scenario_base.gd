extends SceneTree

# Desktop dynamic verification harness base.
# Scenarios extend this script and override the hook methods below.
#
# Outputs (in --out=<dir>, default res://build/scenario_runs/manual/<scenario>):
#   telemetry.csv      per-physics-tick rows for the player and every AI car
#   frame_XXXX.png     viewport captures every CAPTURE_INTERVAL ticks (windowed only)
#   contact_sheet.png  all captures tiled into one image (windowed only)
#   summary.txt        assertion verdicts and measured metrics
#
# stdout: a [TELEMETRY] checkpoint every 0.5s plus PASS/FAIL/WARN lines.
# Exit code: 0 = all assertions passed, 1 = at least one failed.

const TICK_RATE := 60.0
const CHECKPOINT_INTERVAL := 30
const HUD_SPEED_FACTOR := 5.8 # matches RaceInputHud speedometer (raw m/s * 5.8)
const SHEET_COLUMNS := 4
const SHEET_TILE := Vector2i(480, 270)

var main: MainController
var player: RallyCar
var race_manager: RaceManager
var frame := 0
var phase := "setup"

var _out_dir := ""
var _csv: FileAccess
var _headless := false
var _capture_interval := 30
var _capture_pending := false
var _captured_paths: Array[String] = []
var _passes := 0
var _fails: Array[String] = []
var _warns: Array[String] = []
var _metrics: Array[String] = []
var _finished := false
var _overlay_label: Label
var _setup_done := false


# ---------------------------------------------------------------- hooks

func scenario_name() -> String:
	return "unnamed"


func scenario_description() -> String:
	return ""


func race_config() -> Dictionary:
	return {"mode": RaceResult.MODE_CIRCUIT, "laps": 3, "ai_count": 0}


func duration_ticks() -> int:
	return 240


func capture_interval_ticks() -> int:
	return 30


# Called once after the race scene exists.
func on_setup() -> void:
	pass


# Called every physics tick before the engine steps cars. Set inputs here.
func on_tick() -> void:
	pass


# Called after the final tick. Use assert_* helpers.
func on_evaluate() -> void:
	pass


# ---------------------------------------------------------------- lifecycle

func _initialize() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_capture_interval = capture_interval_ticks()
	_out_dir = _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_clear_old_outputs()
	print("")
	print("=== SCENARIO: %s ===" % scenario_name())
	if scenario_description() != "":
		print(scenario_description())
	print("Output: %s" % _out_dir)
	print("Mode: %s" % ("headless (no frame capture)" if _headless else "windowed (live view + frame capture)"))
	main = MainController.new()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	if _finished:
		return true
	frame += 1
	if not _setup_done:
		if not _setup_race():
			_fail_now("Race scene failed to build.")
			return true
		_setup_done = true
		on_setup()
		return false
	if player == null or not is_instance_valid(player):
		_fail_now("Player car disappeared during scenario.")
		return true
	on_tick()
	if _finished:
		return true
	_write_csv_rows()
	if frame % CHECKPOINT_INTERVAL == 0:
		_print_checkpoint()
	if not _headless and frame % _capture_interval == 0:
		_capture_pending = true
	if frame >= duration_ticks():
		_complete()
		return true
	return false


func _process(_delta: float) -> bool:
	if _overlay_label != null and player != null and is_instance_valid(player):
		var ds := player.get_drive_state()
		_overlay_label.text = "SCENARIO %s | t=%.2fs | phase: %s | %.1f m/s (HUD %03d)" % [
			scenario_name(), frame / TICK_RATE, phase, float(ds.signed_speed), hud_speed(player)]
	if _capture_pending:
		_capture_pending = false
		_capture_frame()
	return false


# ---------------------------------------------------------------- setup

func _setup_race() -> bool:
	var cfg := race_config()
	main._show_race_preview(str(cfg.get("mode", RaceResult.MODE_CIRCUIT)), int(cfg.get("laps", 3)), int(cfg.get("ai_count", 0)))
	player = main._preview_player_car
	if player == null or main._race_root == null:
		return false
	for child in main._race_root.get_children():
		if child is RaceManager:
			race_manager = child
	if race_manager == null:
		return false
	_open_csv()
	_build_overlay()
	return true


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	main._race_root.add_child(layer)
	_overlay_label = Label.new()
	_overlay_label.position = Vector2(24.0, 150.0)
	_overlay_label.add_theme_font_size_override("font_size", 18)
	_overlay_label.add_theme_color_override("font_color", Color("fde047"))
	_overlay_label.add_theme_color_override("font_outline_color", Color("000000"))
	_overlay_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_overlay_label)


func _resolve_out_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.substr(6).replace("\\", "/")
	return ProjectSettings.globalize_path("res://build/scenario_runs/manual/%s" % scenario_name())


func _clear_old_outputs() -> void:
	var dir := DirAccess.open(_out_dir)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.ends_with(".png") or file_name.ends_with(".csv") or file_name == "summary.txt":
			dir.remove(file_name)


# ---------------------------------------------------------------- helpers for scenarios

func ai_cars() -> Array[RallyCar]:
	return main._preview_ai_cars


func ai_drivers() -> Array[AIDriver]:
	return main._preview_ai_drivers


func centerline() -> PackedVector3Array:
	return race_manager._centerline


func nearest_route(car: RallyCar) -> Dictionary:
	return race_manager._find_nearest_route_point(car.global_position)


func route_tangent(index: int) -> Vector3:
	var line := centerline()
	var n := line.size()
	var t := line[(index + 1) % n] - line[(index - 1 + n) % n]
	t.y = 0.0
	return t.normalized()


# Drive the player along the road like a competent human (uses the AI steering law).
func steer_player_along_road(brake: bool = false) -> void:
	var nearest := nearest_route(player)
	var ctrl := AIDriver.compute_control(centerline(), int(nearest.index), player.global_position, -player.global_transform.basis.z)
	var st: float = float(ctrl.steering)
	player.set_touch_input(st < -0.1, st > 0.1, brake)


func signed_speed(car: RallyCar) -> float:
	return float(car.get_drive_state().get("signed_speed", 0.0))


func hud_speed(car: RallyCar) -> int:
	var raw := float(car.get_drive_state().get("speed", 0.0))
	return 0 if raw < 0.15 else roundi(raw * HUD_SPEED_FACTOR)


func yaw_degrees(car: RallyCar) -> float:
	return rad_to_deg(car.rotation.y)


func uprightness(car: RallyCar) -> float:
	return car.global_transform.basis.y.dot(Vector3.UP)


func place_car(car: RallyCar, pos: Vector3, heading: Vector3) -> void:
	var jumped := car.global_position.distance_to(pos) > 5.0
	car.global_position = pos
	car.rotation = Vector3(0.0, atan2(-heading.x, -heading.z), 0.0)
	car.velocity = Vector3.ZERO
	car.force_update_transform()
	var rid := car.get_rid()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, car.global_transform)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_KINEMATIC)
	car.reset_physics_interpolation()
	if jumped and car == player and main != null and main._race_root != null:
		for child in main._race_root.get_children():
			if child is RallyChaseCamera:
				(child as RallyChaseCamera).snap_to_target()
				break


func t_seconds() -> float:
	return frame / TICK_RATE


# End the scenario before duration_ticks() (evaluates, writes outputs, quits).
func end_scenario() -> void:
	if not _finished:
		_complete()


func metric(label: String, value: Variant) -> void:
	var line := "%s: %s" % [label, str(value)]
	_metrics.append(line)
	print("  METRIC  %s" % line)


func assert_true(condition: bool, label: String, detail: String = "") -> void:
	var text := label if detail == "" else "%s (%s)" % [label, detail]
	if condition:
		_passes += 1
		print("  PASS    %s" % text)
	else:
		_fails.append(text)
		print("  FAIL    %s" % text)


func assert_between(value: float, low: float, high: float, label: String, unit: String = "") -> void:
	assert_true(value >= low and value <= high, label, "got %.3f%s, expected %.3f..%.3f%s" % [value, unit, low, high, unit])


func assert_at_least(value: float, low: float, label: String, unit: String = "") -> void:
	assert_true(value >= low, label, "got %.3f%s, expected >= %.3f%s" % [value, unit, low, unit])


func assert_at_most(value: float, high: float, label: String, unit: String = "") -> void:
	assert_true(value <= high, label, "got %.3f%s, expected <= %.3f%s" % [value, unit, high, unit])


func warn(text: String) -> void:
	_warns.append(text)
	print("  WARN    %s" % text)


# ---------------------------------------------------------------- telemetry

func _open_csv() -> void:
	_csv = FileAccess.open(_out_dir.path_join("telemetry.csv"), FileAccess.WRITE)
	if _csv == null:
		push_error("Cannot open telemetry.csv in %s: %s" % [_out_dir, error_string(FileAccess.get_open_error())])
		return
	_csv.store_line("frame,time_s,phase,car,pos_x,pos_y,pos_z,yaw_deg,signed_speed_ms,hud_speed,target_speed_ms,braking,reversing,boost_charged,boost_remaining,on_floor,upright,slide_contacts,route_index,off_center_m,lap,expected_cp")


func _write_csv_rows() -> void:
	if _csv == null:
		return
	var status := race_manager.get_status()
	_write_car_row("player", player, status)
	var cars := ai_cars()
	for i in cars.size():
		if cars[i] != null and is_instance_valid(cars[i]):
			_write_car_row("ai%d" % (i + 1), cars[i], status)


func _write_car_row(car_label: String, car: RallyCar, status: Dictionary) -> void:
	var ds := car.get_drive_state()
	var pos := car.global_position
	var nearest := nearest_route(car)
	var lap := int(status.get("lap", 1)) if car == player else -1
	var cp := race_manager._state.expected_checkpoint if car == player else -1
	_csv.store_line("%d,%.4f,%s,%s,%.3f,%.3f,%.3f,%.2f,%.3f,%d,%.3f,%d,%d,%d,%.3f,%d,%.3f,%d,%d,%.2f,%d,%d" % [
		frame, t_seconds(), phase, car_label, pos.x, pos.y, pos.z, yaw_degrees(car),
		float(ds.signed_speed), hud_speed(car), float(ds.target_speed),
		int(bool(ds.braking)), int(bool(ds.reversing)), int(bool(ds.boost_charged)), float(ds.boost_remaining),
		int(car.is_on_floor()), uprightness(car), car.get_slide_collision_count(),
		int(nearest.index), float(nearest.distance), lap, cp])


func _print_checkpoint() -> void:
	var ds := player.get_drive_state()
	var pos := player.global_position
	var nearest := nearest_route(player)
	var line := "[TELEMETRY t=%5.2fs F=%04d %-10s] pos=(%7.1f,%5.2f,%7.1f) v=%6.2fm/s HUD=%03d brake=%d rev=%d boost=%s floor=%d offc=%5.1fm" % [
		t_seconds(), frame, phase, pos.x, pos.y, pos.z, float(ds.signed_speed), hud_speed(player),
		int(bool(ds.braking)), int(bool(ds.reversing)),
		("ACT" if float(ds.boost_remaining) > 0.0 else ("RDY" if bool(ds.boost_charged) else "---")),
		int(player.is_on_floor()), float(nearest.distance)]
	var cars := ai_cars()
	if not cars.is_empty():
		var parts: Array[String] = []
		for i in cars.size():
			parts.append("%.0f" % signed_speed(cars[i]))
		line += " | AI v=[%s]" % ", ".join(parts)
	print(line)


# ---------------------------------------------------------------- frame capture

func _capture_frame() -> void:
	var tex := root.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	var path := _out_dir.path_join("frame_%04d.png" % frame)
	var err := img.save_png(path)
	if err != OK:
		push_error("Frame capture failed: %s" % error_string(err))
		return
	_captured_paths.append(path)


func _build_contact_sheet() -> void:
	if _captured_paths.is_empty():
		return
	var rows := ceili(float(_captured_paths.size()) / SHEET_COLUMNS)
	var sheet := Image.create(SHEET_TILE.x * SHEET_COLUMNS, SHEET_TILE.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color("101418"))
	for i in _captured_paths.size():
		var img := Image.load_from_file(_captured_paths[i])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(SHEET_TILE.x, SHEET_TILE.y, Image.INTERPOLATE_BILINEAR)
		var cell := Vector2i((i % SHEET_COLUMNS) * SHEET_TILE.x, (i / SHEET_COLUMNS) * SHEET_TILE.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, SHEET_TILE), cell)
	sheet.save_png(_out_dir.path_join("contact_sheet.png"))


# ---------------------------------------------------------------- completion

func _complete() -> void:
	phase = "evaluate"
	print("--- Evaluating %s ---" % scenario_name())
	on_evaluate()
	_finish()


func _fail_now(text: String) -> void:
	_fails.append(text)
	print("  FAIL    %s" % text)
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _csv != null:
		_csv.close()
		_csv = null
	_build_contact_sheet()
	var verdict := "PASS" if _fails.is_empty() else "FAIL"
	var summary := FileAccess.open(_out_dir.path_join("summary.txt"), FileAccess.WRITE)
	if summary != null:
		summary.store_line("scenario=%s verdict=%s passes=%d fails=%d warns=%d ticks=%d" % [scenario_name(), verdict, _passes, _fails.size(), _warns.size(), frame])
		for m in _metrics:
			summary.store_line("METRIC " + m)
		for f in _fails:
			summary.store_line("FAIL " + f)
		for w in _warns:
			summary.store_line("WARN " + w)
		summary.close()
	print("=== %s: %s (%d passed, %d failed, %d warnings, %d frames captured) ===" % [scenario_name(), verdict, _passes, _fails.size(), _warns.size(), _captured_paths.size()])
	quit(0 if _fails.is_empty() else 1)
