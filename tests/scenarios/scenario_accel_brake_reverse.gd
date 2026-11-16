extends "res://tests/scenarios/scenario_base.gd"

# Straight acceleration -> hold brake to a full stop -> keep holding into reverse.
# Solo car so no AI contact contaminates the measurement.

const ACCEL_END := 120   # 2.0s full auto-throttle
const BRAKE_END := 270   # 2.5s brake held

var _max_forward := 0.0
var _brake_start_speed := 0.0
var _stop_tick := -1
var _reverse_tick := -1
var _min_signed := 0.0
var _plateau_ticks := 0
var _max_plateau_ticks := 0
var _prev_speed := 0.0
var _airborne_ticks := 0
var _max_off_center := 0.0


func scenario_name() -> String:
	return "AccelBrakeReverse"


func scenario_description() -> String:
	return "2.0s auto-throttle, then brake held 2.5s: must reach 0, hold briefly, then reverse."


func race_config() -> Dictionary:
	return {"mode": RaceResult.MODE_CIRCUIT, "laps": 3, "ai_count": 0}


func duration_ticks() -> int:
	return BRAKE_END


func capture_interval_ticks() -> int:
	return 20


func on_tick() -> void:
	var v := signed_speed(player)
	if frame <= ACCEL_END:
		phase = "accelerate"
		steer_player_along_road(false)
		_max_forward = maxf(_max_forward, v)
		_brake_start_speed = v
	else:
		phase = "brake" if v > 0.05 and _stop_tick < 0 else ("reverse" if v < -0.05 else "stopped")
		# Steer along the road only while rolling forward; go straight in reverse.
		if v > 0.5:
			steer_player_along_road(true)
		else:
			player.set_touch_input(false, false, true)
		if _stop_tick < 0 and absf(v) < 0.2:
			_stop_tick = frame
		if _reverse_tick < 0 and v < -1.0:
			_reverse_tick = frame
		_min_signed = minf(_min_signed, v)
		# Plateau detector: speed above 1 m/s that stops falling while brake is held
		# (this is the old "stuck at 48" bug signature).
		if _stop_tick < 0 and v > 1.0 and absf(v - _prev_speed) < 0.05:
			_plateau_ticks += 1
			_max_plateau_ticks = maxi(_max_plateau_ticks, _plateau_ticks)
		else:
			_plateau_ticks = 0
	_prev_speed = v
	if frame > 10 and not player.is_on_floor():
		_airborne_ticks += 1
	_max_off_center = maxf(_max_off_center, float(nearest_route(player).distance))


func on_evaluate() -> void:
	var stop_time := (_stop_tick - ACCEL_END) / TICK_RATE if _stop_tick > 0 else -1.0
	var reverse_delay := (_reverse_tick - _stop_tick) / TICK_RATE if _reverse_tick > 0 and _stop_tick > 0 else -1.0
	metric("max_forward_speed_ms", "%.2f" % _max_forward)
	metric("speed_at_brake_start_ms", "%.2f" % _brake_start_speed)
	metric("brake_to_stop_s", "%.3f" % stop_time)
	metric("stop_to_reverse_s", "%.3f" % reverse_delay)
	metric("min_signed_speed_ms", "%.2f" % _min_signed)
	metric("longest_brake_plateau_ticks", _max_plateau_ticks)
	metric("airborne_ticks", _airborne_ticks)
	metric("max_off_center_m", "%.2f" % _max_off_center)
	assert_at_least(_max_forward, 28.0, "Auto-throttle reaches near cruise speed", " m/s")
	assert_true(_stop_tick > 0, "Holding brake reaches a full stop (|v| < 0.2 m/s)")
	assert_between(stop_time, 0.2, 1.2, "Brake-to-stop time from cruise", " s")
	assert_at_most(_max_plateau_ticks, 3, "No speed plateau while braking (old 48 km/h bug)", " ticks")
	assert_true(_reverse_tick > 0, "Continued brake hold engages reverse (v < -1 m/s)")
	assert_between(reverse_delay, 0.05, 0.6, "Stop-to-reverse delay", " s")
	assert_at_most(_min_signed, -10.0, "Reverse reaches meaningful speed", " m/s")
	assert_at_least(_min_signed, -RallyDriveModel.REVERSE_SPEED - 0.5, "Reverse respects REVERSE_SPEED cap", " m/s")
	assert_at_most(_airborne_ticks, 0, "Car never leaves the floor", " ticks")
	assert_at_most(_max_off_center, TrackCompiler.ROAD_HALF_WIDTHS["wide"], "Car stays on the road surface the whole time", " m")
