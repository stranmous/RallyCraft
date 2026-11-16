extends SceneTree

# Headless multi-second driving simulation test for AIDriver and car motion logic.
# Validates:
# 1. Car reaches and maintains racing speed (average speed >= 18 m/s).
# 2. Car follows the route and stays within road boundaries (distance to centerline <= 12.0 m).
# 3. AI recovery resets the car when progress is stalled for 3+ seconds.

var _failed := false


func _init() -> void:
	var track := TrackDefinition.create_custom("AI Simulation Circuit", PackedVector2Array([
		Vector2(-120.0, -55.0), Vector2(-35.0, -110.0), Vector2(85.0, -78.0),
		Vector2(135.0, 10.0), Vector2(60.0, 105.0), Vector2(-72.0, 92.0),
	]))
	track.track_id = "ai_sim_circuit"
	track.road_width = "wide"
	track.surface = "asphalt"

	var compiled := TrackCompiler.compile(track)
	_expect(compiled.ok, "Simulation track should compile cleanly.")
	var centerline: PackedVector3Array = compiled.centerline
	_expect(centerline.size() >= 48, "Centerline should be smoothly resampled into >= 48 points (got %d)." % centerline.size())

	# Start car at grid slot 1
	var car_pos: Vector3 = compiled.start_grid[1].position
	var start_heading: Vector3 = compiled.start_grid[1].heading
	var car_rotation_y := atan2(-start_heading.x, -start_heading.z)
	var drive := RallyDriveModel.new()

	var delta := 1.0 / 60.0
	var total_frames := 600 # 10 seconds of simulated driving
	var speed_sum := 0.0
	var max_centerline_distance := 0.0
	var total_travelled := 0.0
	var pace_adjustment := 0.0
	var last_route_index := 0
	var lap_elapsed := 0.0
	var previous_lap_seconds := 0.0

	for frame in total_frames:
		# 1. Find nearest route point
		var nearest_index := 0
		var nearest_dist := INF
		for idx in centerline.size():
			var p := centerline[idx]
			p.y = car_pos.y
			var d := car_pos.distance_to(p)
			if d < nearest_dist:
				nearest_dist = d
				nearest_index = idx

		max_centerline_distance = maxf(max_centerline_distance, nearest_dist)

		# 2. Compute AI control
		var car_forward := -Basis(Vector3.UP, car_rotation_y).z
		var control: Dictionary = AIDriver.compute_control(
			centerline, nearest_index, car_pos, car_forward, pace_adjustment
		)

		# 3. Step drive model
		var drive_state: Dictionary = drive.step(delta, control.braking, false, control.pace_multiplier, false)
		var current_speed: float = drive_state.speed
		speed_sum += current_speed

		# 4. Integrate steering & position (matching RallyCar._physics_process)
		var turn_rate: float = RallyCar.STEER_RATE * (RallyCar.DRIFT_STEER_MULTIPLIER if control.braking else 1.0)
		car_rotation_y -= float(control.steering) * turn_rate * delta * clampf(current_speed / RallyDriveModel.CRUISE_SPEED, 0.35, 1.25)

		var move_forward := -Basis(Vector3.UP, car_rotation_y).z
		var step_move := move_forward * current_speed * delta
		car_pos += step_move
		total_travelled += step_move.length()

		# 5. Lap adaptation tracking
		lap_elapsed += delta
		if last_route_index > centerline.size() - 4 and nearest_index <= 2:
			if previous_lap_seconds > 0.0:
				var adj := -0.015 if lap_elapsed > previous_lap_seconds else 0.01
				pace_adjustment = clampf(pace_adjustment + adj, -AIDriver.MAX_LAP_PACE_ADJUSTMENT, AIDriver.MAX_LAP_PACE_ADJUSTMENT)
			previous_lap_seconds = lap_elapsed
			lap_elapsed = 0.0
		last_route_index = nearest_index

	var avg_speed := speed_sum / float(total_frames)
	_expect(avg_speed >= 18.0, "AI average speed should be >= 18 m/s (got %.1f m/s). Must not be permanently braking." % avg_speed)
	_expect(total_travelled >= 180.0, "AI car should travel >= 180 m in 10 seconds (travelled %.1f m)." % total_travelled)
	_expect(max_centerline_distance <= 12.0, "AI car should stay within road bounds (max offset was %.1f m, limit 12.0 m)." % max_centerline_distance)

	# --- Test AI Recovery when stopped ---
	var recovery_monitor := RaceRecoveryMonitor.new()
	recovery_monitor.reset(0.0)
	var recovered := false
	for frame in 200: # ~3.3 seconds at 0.016s delta
		# Car is stopped (speed = 0.0), no route progress
		if recovery_monitor.update(delta, 0.0, 0.0, false, false):
			recovered = true
			break
	_expect(recovered, "AI recovery monitor should trigger after 3 seconds of being stopped.")

	# --- Test 0-7 AI cars and 1-5 laps in RaceManager ---
	var dummy_car := RallyCar.new()
	var dummy_ai_cars: Array[RallyCar] = []
	var dummy_ai_drivers: Array[AIDriver] = []
	for i in 7:
		var ac := RallyCar.new()
		var ad := AIDriver.new()
		ad.configure(ac, centerline)
		dummy_ai_cars.append(ac)
		dummy_ai_drivers.append(ad)

	# 0 AI cars, 1 lap
	var rm_solo := RaceManager.new()
	_expect(rm_solo.configure(dummy_car, compiled, track.track_id, RaceResult.MODE_CIRCUIT, 1, [], []), "RaceManager should configure with 0 AI cars and 1 lap.")
	var solo_status := rm_solo.get_status()
	_expect(solo_status.total_racers == 1 and solo_status.position == 1 and solo_status.lap_target == 1, "Solo circuit race should report 1 racer, 1 lap.")

	# 7 AI cars, 5 laps
	var rm_full := RaceManager.new()
	_expect(rm_full.configure(dummy_car, compiled, track.track_id, RaceResult.MODE_CIRCUIT, 5, dummy_ai_cars, dummy_ai_drivers), "RaceManager should configure with 7 AI cars and 5 laps.")
	var full_status := rm_full.get_status()
	_expect(full_status.total_racers == 8 and full_status.lap_target == 5, "Full circuit race should report 8 racers and 5 laps.")

	# Test dynamic position ranking
	# Place all 7 AI cars at route index 10..16 (ahead of player at route index 0)
	dummy_car.position = centerline[0]
	for i in 7:
		dummy_ai_cars[i].position = centerline[10 + i]
	rm_full._update_player_position()
	_expect(rm_full.get_status().position == 8, "Player behind all 7 AI cars should be in 8th place (got %d)." % rm_full.get_status().position)

	# Place player at route index 25 (ahead of all 7 AI cars)
	dummy_car.position = centerline[25]
	rm_full._update_player_position()
	_expect(rm_full.get_status().position == 1, "Player ahead of all 7 AI cars should be in 1st place (got %d)." % rm_full.get_status().position)

	# Place player in middle (ahead of 3, behind 4)
	for i in 7:
		dummy_ai_cars[i].position = centerline[5 + i * 5] # positions: 5, 10, 15, 20, 25, 30, 35
	dummy_car.position = centerline[18] # behind 20, 25, 30, 35 (4 cars ahead)
	rm_full._update_player_position()
	_expect(rm_full.get_status().position == 5, "Player behind 4 AI cars should be in 5th place (got %d)." % rm_full.get_status().position)

	# Place player at index 22 (behind 25, 30, 35 -> 3 cars ahead)
	dummy_car.position = centerline[22]
	rm_full._update_player_position()
	_expect(rm_full.get_status().position == 4, "Player behind 3 AI cars should be in 4th place (got %d)." % rm_full.get_status().position)

	dummy_car.free()
	for ac in dummy_ai_cars:
		ac.free()
	for ad in dummy_ai_drivers:
		ad.free()
	rm_solo.free()
	rm_full.free()

	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
