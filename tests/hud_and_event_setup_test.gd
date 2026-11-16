extends SceneTree

var _failed := false


func _init() -> void:
	_test_event_setup_panel()
	_test_minimap_projection()
	_test_shared_boost_pickups_and_hud()
	quit(1 if _failed else 0)


func _test_event_setup_panel() -> void:
	var track := TrackDefinition.create_custom("Test Track", PackedVector2Array([
		Vector2(-100.0, -60.0), Vector2(0.0, -110.0), Vector2(100.0, -60.0),
		Vector2(110.0, 50.0), Vector2(0.0, 100.0), Vector2(-110.0, 50.0),
	]))
	track.track_id = "hud_test_track"

	var panel := EventSetupPanel.new()
	panel._ready()
	panel.configure(track, {"mode": RaceResult.MODE_CIRCUIT, "laps": 4, "ai_count": 6}, {"best_lap_ms": 52400, "best_race_ms": 161250})
	var cfg := panel.get_config()
	_expect(cfg.mode == RaceResult.MODE_CIRCUIT and cfg.laps == 4 and cfg.ai_count == 6, "EventSetupPanel should apply initial circuit configuration.")
	_expect(cfg.effective_laps == 4 and cfg.effective_ai_count == 6, "Circuit mode effective laps and AI count should match selection.")

	panel.set_laps(5)
	panel.set_ai_count(7)
	cfg = panel.get_config()
	_expect(cfg.laps == 5 and cfg.ai_count == 7, "EventSetupPanel should update laps to 5 and AI count to 7.")

	panel.set_mode(RaceResult.MODE_TIME_TRIAL)
	cfg = panel.get_config()
	_expect(cfg.mode == RaceResult.MODE_TIME_TRIAL and cfg.effective_laps == 1 and cfg.effective_ai_count == 0, "Time Trial mode must enforce 1 effective lap and 0 effective AI cars.")

	panel.set_mode(RaceResult.MODE_CIRCUIT)
	cfg = panel.get_config()
	_expect(cfg.effective_laps == 5 and cfg.effective_ai_count == 7, "Switching back to Circuit Race should restore selected laps and AI count.")
	panel.free()


func _test_minimap_projection() -> void:
	var minimap := RaceMinimap.new()
	minimap.size = Vector2(180.0, 148.0)
	var pts := PackedVector2Array([
		Vector2(-100.0, -80.0), Vector2(100.0, -80.0),
		Vector2(100.0, 80.0), Vector2(-100.0, 80.0),
	])
	var bounds := Rect2(Vector2(-100.0, -80.0), Vector2(200.0, 160.0))
	minimap.configure({"points": pts, "bounds": bounds, "start_index": 0})
	for pt in pts:
		var mapped := minimap.world_to_map(pt)
		_expect(mapped.x >= RaceMinimap.PADDING - 0.5 and mapped.x <= minimap.size.x - RaceMinimap.PADDING + 0.5, "Minimap X coordinate must stay within padded bounds.")
		_expect(mapped.y >= RaceMinimap.PADDING - 0.5 and mapped.y <= minimap.size.y - RaceMinimap.PADDING + 0.5, "Minimap Y coordinate must stay within padded bounds.")
	minimap.free()


func _test_shared_boost_pickups_and_hud() -> void:
	var track := TrackDefinition.create_custom("HUD Sim Circuit", PackedVector2Array([
		Vector2(-120.0, -55.0), Vector2(-35.0, -110.0), Vector2(85.0, -78.0),
		Vector2(135.0, 10.0), Vector2(60.0, 105.0), Vector2(-72.0, 92.0),
	]))
	track.track_id = "hud_sim_circuit"
	track.road_width = "wide"
	var compiled := TrackCompiler.build_runtime(track)
	_expect(compiled.ok, "HUD test track should compile.")
	_expect(not compiled.boost_anchors.is_empty(), "Compiled track should include safe boost anchors.")

	var player := RallyCar.new()
	var ai_cars: Array[RallyCar] = []
	var ai_drivers: Array[AIDriver] = []
	for i in 7:
		var ac := RallyCar.new()
		var ad := AIDriver.new()
		ad.configure(ac, compiled.centerline)
		ai_cars.append(ac)
		ai_drivers.append(ad)

	var rm := RaceManager.new()
	_expect(rm.configure(player, compiled, track.track_id, RaceResult.MODE_CIRCUIT, 5, ai_cars, ai_drivers), "RaceManager should configure for HUD test.")

	var hud := RaceInputHud.new()
	hud._ready()
	hud.configure(player, rm)
	hud._process(0.016)
	var snap := hud.get_hud_snapshot()
	_expect(snap.position_text == "1ST" and snap.position_sub_text == "OF 8", "HUD should show 1ST OF 8 at start.")
	_expect(snap.lap_text == "LAP 1 / 5", "HUD should show LAP 1 / 5.")
	_expect(snap.boost_state == "READY", "HUD boost state should start READY.")

	# Activate boost and verify ACTIVE -> EMPTY transition
	player.request_touch_boost()
	player._drive.step(0.05, false, true)
	player._touch_boost_requested = false
	hud._process(0.016)
	_expect(hud.get_hud_snapshot().boost_state == "ACTIVE", "HUD boost state should become ACTIVE during boost burst.")

	player._drive.step(RallyDriveModel.BOOST_DURATION + 0.1, false, false)
	hud._process(0.016)
	_expect(hud.get_hud_snapshot().boost_state == "EMPTY", "HUD boost state should become EMPTY after burst ends.")

	# Move player onto the first boost pickup anchor to collect it
	var first_pad_pos: Vector3 = compiled.boost_anchors[0].position
	player.position = first_pad_pos
	rm._update_boost_pickups(0.016)
	var pickups := rm.get_boost_pickups_state()
	_expect(not pickups[0].active and is_equal_approx(float(pickups[0].cooldown), RaceManager.BOOST_RESPAWN_SECONDS), "Collected boost pickup should enter 8-second global cooldown.")
	_expect(player.get_drive_state().boost_charged, "Collecting a boost pickup should refill the player's boost charge.")
	hud._process(0.016)
	_expect(hud.get_hud_snapshot().boost_state == "READY", "HUD boost state should return to READY after collecting a pickup.")

	# Move player away and verify 8-second global respawn
	player.position = Vector3(500.0, 0.0, 500.0)
	rm._update_boost_pickups(7.9)
	_expect(not rm.get_boost_pickups_state()[0].active, "Boost pickup must remain inactive before 8 seconds elapse.")
	rm._update_boost_pickups(0.2)
	_expect(rm.get_boost_pickups_state()[0].active, "Boost pickup should respawn globally after 8 seconds.")

	# Verify AI car can also collect the shared pickup and trigger the 8-second cooldown
	ai_cars[0].position = first_pad_pos
	rm._update_boost_pickups(0.016)
	_expect(not rm.get_boost_pickups_state()[0].active, "AI car collecting a boost pickup must put it on global cooldown for all racers.")

	# Verify recovery banner appears when car is stalled/off-route
	rm._recovery._stalled_seconds = 1.5
	hud._process(0.016)
	_expect(hud.get_hud_snapshot().banner_visible, "HUD recovery warning banner should appear when car is stalled/off-route.")

	# Verify BBR2 corner brake / boost layout and screen-half touch steering (no visible steer buttons)
	_expect(hud._left_button == null and hud._right_button == null, "Visible corner steer buttons must be removed in BBR2 touch mode.")
	_expect(hud._brake_left_button.position.x < 100.0 and hud._brake_button.position.x > 1000.0, "Left and right brake buttons must sit in the bottom-left and bottom-right corners.")
	_expect(hud._boost_button.position.x > 1000.0 and hud._boost_button.position.y + hud._boost_button.size.y < hud._brake_button.position.y, "BoostButton must sit on the right side directly above DriftBrakeButton.")
	_expect(hud._pedal_hit_test(hud._brake_left_button.position + Vector2(24.0, 24.0)) == "brake", "Tapping bottom-left brake button must trigger brake.")
	_expect(hud._pedal_hit_test(hud._brake_button.position + Vector2(24.0, 24.0)) == "brake", "Tapping bottom-right brake button must trigger brake.")
	_expect(hud._pedal_hit_test(hud._boost_button.position + Vector2(24.0, 24.0)) == "boost", "Tapping right-side BoostButton must trigger boost.")
	var touch_left := InputEventScreenTouch.new()
	touch_left.index = 0
	touch_left.pressed = true
	touch_left.position = Vector2(220.0, 260.0)
	hud._input(touch_left)
	_expect(player._touch_left and not player._touch_right, "Touching the left side of the screen must steer left.")

	var release_left := InputEventScreenTouch.new()
	release_left.index = 0
	release_left.pressed = false
	release_left.position = Vector2(220.0, 260.0)
	hud._input(release_left)

	var touch_right := InputEventScreenTouch.new()
	touch_right.index = 1
	touch_right.pressed = true
	touch_right.position = Vector2(960.0, 260.0)
	hud._input(touch_right)
	_expect(player._touch_right and not player._touch_left, "Touching the right side of the screen must steer right.")

	var release_right := InputEventScreenTouch.new()
	release_right.index = 1
	release_right.pressed = false
	release_right.position = Vector2(960.0, 260.0)
	hud._input(release_right)
	_expect(hud._pedal_hit_test(hud._pause_button.position + Vector2(12.0, 12.0)) == "", "Tapping PauseButton must not trigger screen-half steering.")
	_expect(hud._pedal_hit_test(hud._sfx_mute_button.position + Vector2(12.0, 12.0)) == "", "Tapping SfxMuteButton must not trigger screen-half steering.")
	_expect(hud._pedal_hit_test(hud._music_mute_button.position + Vector2(12.0, 12.0)) == "", "Tapping MusicMuteButton must not trigger screen-half steering.")

	# Verify independent SFX and Music HUD toggles
	hud._sfx_mute_button.pressed.emit()
	_expect(bool(hud.get_hud_snapshot().sfx_muted) and not bool(hud.get_hud_snapshot().music_muted), "Toggling SFX mute must leave Music unmuted.")
	hud._music_mute_button.pressed.emit()
	_expect(bool(hud.get_hud_snapshot().sfx_muted) and bool(hud.get_hud_snapshot().music_muted), "Toggling Music mute must update music_muted independently.")
	hud._sfx_mute_button.pressed.emit()
	_expect(not bool(hud.get_hud_snapshot().sfx_muted) and bool(hud.get_hud_snapshot().music_muted), "Unmuting SFX must leave Music muted.")

	hud.free()
	rm.free()
	player.free()
	for ac in ai_cars:
		ac.free()
	for ad in ai_drivers:
		ad.free()
	if compiled.has("runtime") and compiled.runtime != null:
		compiled.runtime.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
