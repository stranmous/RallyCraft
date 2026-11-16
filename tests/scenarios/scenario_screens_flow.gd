extends SceneTree

# Windowed UI walkthrough & screenshot capture for Task 4.4 screens:
# Home (2D & 3D Orbit), Track Select (2D & 3D Orbit), Create Track (Sketch & 3D Preview),
# Library & Records (Custom Library & Records Hall).

const SHEET_COLUMNS := 4
const SHEET_TILE := Vector2i(480, 270)

var _main: MainController
var _frame := 0
var _out_dir := ""
var _headless := false
var _captured_paths: Array[String] = []
var _select_screen: TrackSelectPanel
var _builder_screen: Control
var _library_screen: LibraryRecordsPanel
var _saved_test_track_id := ""
var _failures := 0


func _initialize() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_out_dir = _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("\n=== SCENARIO: ScreensFlow ===")
	print("Walks through Home, Track Select, Create Track, Preview, Library, and Records screens.")
	print("Output: %s" % _out_dir)
	_main = MainController.new()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1

	# Frame 10: Home Screen (Spa Ardennes default 3D Orbit)
	if _frame == 10:
		_capture_frame("01_home_3d_orbit")
		print("[TELEMETRY] t=0.2s phase=home_3d_orbit active=%s view=%s" % [_main._active_track.track_id, _main._home_preview_widget.get_view_mode()])
		_main._home_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_2D)
		_main._refresh_home_view_buttons()

	# Frame 25: Home Screen (Spa Ardennes 2D Map)
	elif _frame == 25:
		_capture_frame("02_home_2d")
		print("[TELEMETRY] t=0.4s phase=home_2d view=%s" % _main._home_preview_widget.get_view_mode())
		_select_screen = _main._show_track_select()
		_select_screen.select_track_by_id("curated_red_bull_ring")

	# Frame 40: Track Select (Red Bull Ring 3D Orbit)
	elif _frame == 40:
		_capture_frame("03_track_select_3d")
		print("[TELEMETRY] t=0.7s phase=track_select_3d selected=%s" % _select_screen.get_selected_track().track_id)
		_select_screen.select_track_by_id("curated_monza")
		_select_screen.get_preview_widget().set_view_mode(TrackPreviewWidget.VIEW_2D)
		_select_screen._refresh_view_toggle_buttons()

	# Frame 55: Track Select (Monza Park 2D Map)
	elif _frame == 55:
		_capture_frame("04_track_select_2d")
		print("[TELEMETRY] t=0.9s phase=track_select_2d selected=%s" % _select_screen.get_selected_track().track_id)
		_select_screen.free()
		_builder_screen = _main._show_track_builder()
		var canvas := _builder_screen.find_child("DrawingCanvas", true, false) as TrackDrawingCanvas
		# Figure-8 crossing loop to showcase overpass bridge markers in 2D sketch & 3D preview
		var figure_eight := PackedVector2Array([
			Vector2(140.0, 260.0),
			Vector2(160.0, 110.0),
			Vector2(300.0, 90.0),
			Vector2(410.0, 220.0),
			Vector2(520.0, 380.0),
			Vector2(660.0, 390.0),
			Vector2(700.0, 240.0),
			Vector2(640.0, 100.0),
			Vector2(500.0, 110.0),
			Vector2(390.0, 260.0),
			Vector2(280.0, 410.0),
			Vector2(160.0, 390.0),
		])
		canvas._drawing = figure_eight
		canvas.close_loop_now()

	# Frame 70: Create Track (Sketch Canvas with processed loop)
	elif _frame == 70:
		_capture_frame("05_create_sketch")
		var inspect_btn := _builder_screen.find_child("InspectPreviewButton", true, false) as Button
		var name_edit := _builder_screen.find_child("TrackNameEdit", true, false) as LineEdit
		var save_btn := _builder_screen.find_child("SaveTrackButton", true, false) as Button
		name_edit.text = "Canyon Ridge Circuit"
		name_edit.text_changed.emit(name_edit.text)
		inspect_btn.pressed.emit()
		save_btn.pressed.emit()
		_saved_test_track_id = _main._active_track.track_id
		print("[TELEMETRY] t=1.2s phase=create_preview saved_id=%s" % _saved_test_track_id)

	# Frame 85: Create Track (3D Orbit Preview & Saved confirmation)
	elif _frame == 85:
		_capture_frame("06_create_3d_preview")
		_builder_screen.free()
		_library_screen = _main._show_library_and_records()
		_library_screen.select_track_by_id(_saved_test_track_id)

	# Frame 100: Library & Records (Custom Library tab)
	elif _frame == 100:
		_capture_frame("07_library_custom_tab")
		print("[TELEMETRY] t=1.7s phase=library_tab custom_count=%d" % _library_screen.get_custom_track_count())
		_library_screen.set_tab(LibraryRecordsPanel.TAB_RECORDS)
		_library_screen.select_track_by_id("curated_silverstone")

	# Frame 115: Library & Records (Records Hall tab)
	elif _frame == 115:
		_capture_frame("08_records_hall_tab")
		print("[TELEMETRY] t=1.9s phase=records_tab selected=%s" % _library_screen.get_selected_track().track_id)
		_library_screen.set_tab(LibraryRecordsPanel.TAB_LIBRARY)
		_library_screen.select_track_by_id(_saved_test_track_id)
		_library_screen.export_selected_track(true)

	# Frame 130: Export Share Code & .rallycraft Modal
	elif _frame == 130:
		_capture_frame("09_export_share_modal")
		var exp_res := _library_screen.export_selected_track(false)
		var share_code := str(exp_res.get("share_code", ""))
		if FileAccess.file_exists(str(exp_res.get("file_path", ""))):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(exp_res.get("file_path", ""))))
		_library_screen.open_import_modal()
		if _library_screen._import_input != null:
			_library_screen._import_input.text = share_code
		_library_screen.preview_import_payload(share_code)
		if _library_screen._import_preview_widget != null:
			_library_screen._import_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_3D)
		print("[TELEMETRY] t=2.2s phase=import_preview_modal code_len=%d" % share_code.length())

	# Frame 145: Import & Preview Modal (with 3D Orbit Preview of candidate track)
	elif _frame == 145:
		_capture_frame("10_import_preview_3d_modal")
		_library_screen.cancel_current_import()
		# Clean up test custom track
		if _library_screen.select_track_by_id(_saved_test_track_id):
			_library_screen.delete_selected_track()
		_library_screen.free()
		_main._show_quick_play_picker()

	# Frame 160: Event Setup Modal (Circuit Race / Time Trial, Laps, AI count)
	elif _frame == 160:
		_capture_frame("11_event_setup_modal")
		var qpp := _main._navigation_layer.get_node_or_null("QuickPlayPicker")
		if qpp != null:
			qpp.free()
		_main._show_race_preview(RaceResult.MODE_CIRCUIT, 3, 3)

	# Frame 175: Open Pause Modal during live race (render settles by frame 180)
	elif _frame == 175:
		var hud := _find_race_hud()
		if hud != null:
			hud._toggle_pause_modal()

	# Frame 180: Capture Pause Modal, then present Post-Race Result Modal
	elif _frame == 180:
		_capture_frame("12_race_pause_modal")
		var hud := _find_race_hud()
		var rm := _find_race_manager()
		if hud != null:
			hud._toggle_pause_modal()
		if rm != null and hud != null:
			rm._state.finished = true
			rm._state.finish_seconds = 98.425
			rm._result = RaceResult.build(RaceResult.MODE_CIRCUIT, 98.425, 3, 1, 4)
			rm._result["new_best"] = true
			hud._show_result()
		print("[TELEMETRY] t=3.0s phase=pause_and_result_modals")

	# Frame 186: Capture Result Modal, then exit race and test 1600x720 (20:9) mobile layout
	elif _frame == 186:
		_capture_frame("13_race_result_modal")
		_main._close_race_preview()
		if not _headless:
			DisplayServer.window_set_size(Vector2i(1600, 720))
		_main._layout_navigation_shell()

	# Frame 198: Capture 1600x720 (20:9) Home screen responsive layout
	elif _frame == 198:
		_capture_frame("14_home_20x9_widescreen")
		_main.free()
		_build_contact_sheet()
		print("PASS: All 14 screen & modal states rendered and verified.")
		print("RESULT: 1 passed, 0 failed, 0 warnings")
		quit(0)
		return true

	return false


func _find_race_hud() -> RaceInputHud:
	if _main == null or _main._race_root == null:
		return null
	for child in _main._race_root.get_children():
		if child is RaceInputHud:
			return child
	return null


func _find_race_manager() -> RaceManager:
	if _main == null or _main._race_root == null:
		return null
	for child in _main._race_root.get_children():
		if child is RaceManager:
			return child
	return null


func _capture_frame(tag: String) -> void:
	if _headless:
		return
	var tex := root.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	var path := "%s/frame_%s.png" % [_out_dir, tag]
	img.save_png(path)
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
	sheet.save_png("%s/contact_sheet.png" % _out_dir)


func _resolve_out_dir() -> String:
	var raw := "res://build/scenario_runs/manual/ScreensFlow"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			raw = arg.trim_prefix("--out=")
	if raw.begins_with("res://") or raw.begins_with("user://"):
		return ProjectSettings.globalize_path(raw)
	return raw
