extends SceneTree

var _failures := 0
var _main: MainController
var _step := 0


func _initialize() -> void:
	_test_curated_catalog_compilation()
	_main = MainController.new()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_step += 1
	if _step == 1:
		_test_screens_and_library_flow()
		if _main != null:
			_main.free()
		if _failures > 0:
			printerr("screens_and_library_flow_test failed with %d error(s)." % _failures)
			quit(1)
			return true
		print("screens_and_library_flow_test passed.")
		quit(0)
		return true
	return false


func _test_curated_catalog_compilation() -> void:
	var curated := CuratedTrackCatalog.get_curated_tracks()
	_expect(curated.size() == 4, "Curated catalog should provide 4 circuits (Spa, Red Bull Ring, Monza, Silverstone).")
	var expected_ids := ["curated_spa", "curated_red_bull_ring", "curated_monza", "curated_silverstone"]
	for i in curated.size():
		var track: TrackDefinition = curated[i]
		_expect(track.track_id == expected_ids[i], "Expected curated track_id '%s', got '%s'." % [expected_ids[i], track.track_id])
		var errors := track.validate()
		_expect(errors.is_empty(), "Curated track '%s' must validate cleanly: %s" % [track.display_name, errors])
		var compiled := TrackCompiler.build_runtime(track)
		_expect(bool(compiled.get("ok", false)), "Curated track '%s' must compile cleanly." % track.display_name)
		_expect(float(compiled.get("length", 0.0)) > 400.0, "Curated track '%s' should have length > 400m." % track.display_name)
		if compiled.get("runtime") != null:
			(compiled.get("runtime") as Node).free()


func _test_screens_and_library_flow() -> void:
	# 1. Verify Home screen featured track & preview widget
	_expect(_main._active_track != null and _main._active_track.track_id == "curated_spa", "Home screen should default to featured Spa Ardennes track.")
	_expect(_main._home_preview_widget != null, "Home screen should include TrackPreviewWidget.")
	_main._home_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_3D)
	_expect(_main._home_preview_widget.get_view_mode() == TrackPreviewWidget.VIEW_3D, "Home preview widget should switch to 3D orbit mode.")
	var initial_yaw := _main._home_preview_widget.get_orbit_yaw_deg()
	_main._home_preview_widget.rotate_orbit(25.0, -5.0)
	_expect(not is_equal_approx(_main._home_preview_widget.get_orbit_yaw_deg(), initial_yaw), "Orbit rotation should update camera yaw.")
	_main._home_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_2D)

	# 2. Verify Track Select screen
	var select_screen := _main._show_track_select()
	_expect(select_screen != null, "TrackSelectPanel should open from MainController.")
	_expect(select_screen.get_track_count() >= 4, "TrackSelectPanel should list at least the 4 curated tracks.")
	var selected_monza := select_screen.select_track_by_id("curated_monza")
	_expect(selected_monza and select_screen.get_selected_track().track_id == "curated_monza", "Selecting Monza should update selected track.")
	select_screen.confirm_selection()
	_expect(_main._active_track.track_id == "curated_monza", "Confirming TrackSelectPanel should set active track to Monza.")
	var picker := _main._navigation_layer.get_node_or_null("QuickPlayPicker")
	_expect(picker != null, "Confirming track selection should open EventSetupPanel.")
	if picker != null:
		picker.free()
	if is_instance_valid(select_screen):
		select_screen.free()

	# 3. Verify Create Track flow, 3D/2D preview toggle, and Save to Library
	var builder := _main._show_track_builder()
	_expect(builder != null, "TrackBuilder screen should open.")
	var canvas := builder.find_child("DrawingCanvas", true, false) as TrackDrawingCanvas
	var name_edit := builder.find_child("TrackNameEdit", true, false) as LineEdit
	var inspect_btn := builder.find_child("InspectPreviewButton", true, false) as Button
	var save_btn := builder.find_child("SaveTrackButton", true, false) as Button
	var builder_preview := builder.find_child("BuilderTrackPreview", true, false) as TrackPreviewWidget
	_expect(canvas != null and name_edit != null and inspect_btn != null and save_btn != null and builder_preview != null, "TrackBuilder controls must exist.")

	# Simulate a valid drawn loop on the canvas
	var raw_loop := PackedVector2Array([
		Vector2(140.0, 140.0),
		Vector2(360.0, 110.0),
		Vector2(560.0, 170.0),
		Vector2(600.0, 340.0),
		Vector2(500.0, 480.0),
		Vector2(260.0, 490.0),
		Vector2(130.0, 340.0),
		Vector2(140.0, 140.0),
	])
	var processed: Dictionary = TrackPathProcessor.process_drawing(raw_loop)
	_expect(bool(processed.get("ok", false)), "Simulated sketch loop should process cleanly.")
	canvas.drawing_processed.emit(processed)

	_expect(not save_btn.disabled, "Save button should enable after valid sketch.")
	_expect(not inspect_btn.disabled, "Inspect 3D/2D preview button should enable after valid sketch.")

	# Toggle 3D preview inside Create Track flow
	inspect_btn.pressed.emit()
	_expect(builder_preview.visible and builder_preview.get_view_mode() == TrackPreviewWidget.VIEW_3D, "Inspect button should reveal 3D rotatable preview.")
	inspect_btn.pressed.emit()
	_expect(canvas.visible and not builder_preview.visible, "Pressing Inspect button again should return to sketch canvas.")

	# Name and save custom track
	name_edit.text = "Test Library Loop"
	name_edit.text_changed.emit(name_edit.text)
	save_btn.pressed.emit()

	var saved_track_id := _main._active_track.track_id
	_expect(_main._active_track.display_name == "Test Library Loop", "Saving in builder should update active track to 'Test Library Loop'.")
	builder.free()

	# 4. Verify Library & Records screen (Custom Library tab, Rename, Records Hall tab, Delete)
	var lib_screen := _main._show_library_and_records()
	_expect(lib_screen != null, "LibraryRecordsPanel should open.")
	_expect(lib_screen.get_custom_track_count() >= 1, "Library should contain the newly saved custom track.")
	var found_saved := lib_screen.select_track_by_id(saved_track_id)
	_expect(found_saved, "Saved custom track should be selectable in LibraryRecordsPanel.")

	var renamed_ok := lib_screen.rename_selected_track("Renamed Test Loop")
	_expect(renamed_ok and lib_screen.get_selected_track().display_name == "Renamed Test Loop", "Renaming custom track in Library should persist and update UI.")

	# Switch to Records Hall tab
	lib_screen.set_tab(LibraryRecordsPanel.TAB_RECORDS)
	_expect(lib_screen.get_active_tab() == LibraryRecordsPanel.TAB_RECORDS, "Should switch to Records Hall tab.")
	_expect(lib_screen.select_track_by_id("curated_spa"), "Records Hall should include curated tracks.")

	# Switch back to Library tab and delete test track
	lib_screen.set_tab(LibraryRecordsPanel.TAB_LIBRARY)
	_expect(lib_screen.select_track_by_id(saved_track_id), "Custom track should still be selectable before deletion.")
	var deleted_ok := lib_screen.delete_selected_track()
	_expect(deleted_ok, "Deleting custom track from Library should succeed.")
	var reload_deleted := TrackStore.new().load_custom_track(saved_track_id)
	_expect(reload_deleted.track == null, "Deleted custom track should no longer exist in TrackStore.")

	lib_screen.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("ERROR: %s" % message)
