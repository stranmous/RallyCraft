extends SceneTree

var _failures := 0
var _main: MainController
var _frame := 0
var _tested_physics := false


func _initialize() -> void:
	_test_curated_circuits_geometry_and_elevation()
	_main = MainController.new()
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		# Launch a live 3D race on Spa Ardennes to verify cars climb authored hills cleanly
		var spa := CuratedTrackCatalog.get_featured_track()
		_main._show_race_preview(RaceResult.MODE_CIRCUIT, 1, 3, spa)
		return false

	var car := _main._preview_player_car
	if car == null:
		_expect(false, "Spa preview car should exist.")
		quit(1)
		return true

	# Steer player along Spa toward La Source & Eau Rouge climb
	var rm: RaceManager = null
	for child in _main._race_root.get_children():
		if child is RaceManager:
			rm = child
			break
	if rm != null:
		var nearest := rm._find_nearest_route_point(car.global_position)
		var ctrl := AIDriver.compute_control(rm._centerline, nearest.index, car.global_position, -car.global_transform.basis.z)
		var st := float(ctrl.steering)
		car.set_touch_input(st < -0.1, st > 0.1, false)

	if _frame == 150:
		_expect(car.is_on_floor(), "Player car on Spa must remain grounded on 3D road collider.")
		_expect(car.get_drive_state().speed >= 15.0, "Player car on Spa must sustain speed >= 15 m/s (got %.1f)." % car.get_drive_state().speed)
		for i in _main._preview_ai_cars.size():
			var ai := _main._preview_ai_cars[i]
			_expect(ai.is_on_floor(), "AI car %d on Spa must remain grounded on slope." % i)
		_main._close_race_preview()
		_main.free()
		if _failures > 0:
			printerr("curated_tracks_validation_test failed with %d error(s)." % _failures)
			quit(1)
		else:
			print("curated_tracks_validation_test passed.")
			quit(0)
		return true

	return false


func _test_curated_circuits_geometry_and_elevation() -> void:
	var tracks := CuratedTrackCatalog.get_curated_tracks()
	_expect(tracks.size() == 4, "Curated catalog must contain exactly 4 circuits.")

	for track in tracks:
		_expect(track.source == TrackDefinition.SOURCE_CURATED, "%s must be CURATED source." % track.track_id)
		_expect(track.centerline_points.size() >= 14, "%s should have rich hand-authored control points (>= 14)." % track.track_id)
		_expect(track.elevation_profile.size() == track.centerline_points.size(), "%s elevation_profile length must match centerline_points." % track.track_id)

		var compiled := TrackCompiler.build_runtime(track)
		_expect(bool(compiled.get("ok", false)), "%s must compile cleanly." % track.track_id)
		_expect((compiled.get("bridge_segments", []) as Array).is_empty(), "%s must not contain unintended self-crossings." % track.track_id)
		_expect(float(compiled.get("length", 0.0)) >= 900.0, "%s track length must be >= 900m (got %.1fm)." % [track.track_id, float(compiled.get("length", 0.0))])
		_expect((compiled.get("boost_anchors", []) as Array).size() >= 3, "%s should generate at least 3 safe boost anchors." % track.track_id)

		var cl: PackedVector3Array = compiled.centerline
		var min_y := INF
		var max_y := -INF
		var max_grade := 0.0
		for i in cl.size():
			var p0 := cl[i]
			var p1 := cl[(i + 1) % cl.size()]
			min_y = minf(min_y, p0.y)
			max_y = maxf(max_y, p0.y)
			var horiz := Vector2(p1.x - p0.x, p1.z - p0.z).length()
			if horiz > 0.1:
				max_grade = maxf(max_grade, absf(p1.y - p0.y) / horiz)

		_expect(min_y >= -0.01, "%s minimum elevation must stay above ground plane (min_y=%.2f)." % [track.track_id, min_y])
		_expect(max_grade <= 0.25, "%s slope grade must stay drivable <= 25%% (got %.2f%%)." % [track.track_id, max_grade * 100.0])

		if track.track_id == "curated_spa":
			_expect(max_y >= 7.5, "Spa Ardennes must include Eau Rouge / Kemmel elevation relief >= 7.5m (got %.2fm)." % max_y)
			_expect(compiled.get("embankment_mesh") != null, "Spa Ardennes must generate embankment support mesh.")
		elif track.track_id == "curated_red_bull_ring":
			_expect(max_y >= 8.5, "Red Bull Ring must include alpine summit elevation relief >= 8.5m (got %.2fm)." % max_y)
			_expect(compiled.get("embankment_mesh") != null, "Red Bull Ring must generate embankment support mesh.")

		if compiled.get("runtime") != null:
			(compiled.get("runtime") as Node).free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("ERROR: %s" % message)
