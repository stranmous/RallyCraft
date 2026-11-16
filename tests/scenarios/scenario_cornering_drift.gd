extends "res://tests/scenarios/scenario_base.gd"

# Compares a plain steer input against a Drift/Brake + steer input of equal length
# at cruise speed, then measures how fast the car regains pace.

const TAP_TICKS := 15            # 0.25s inputs
const NORMAL_START := 121
const DRIFT_START := 241
const END_TICK := 420

var _steer_sign := 1.0
var _yaw_before := 0.0
var _speed_before := 0.0
var _normal_yaw_rate := 0.0
var _normal_speed_after := 0.0
var _normal_entry := 0.0
var _drift_yaw_rate := 0.0
var _drift_speed_after := 0.0
var _drift_entry := 0.0
var _regain_tick := -1
var _min_upright := 1.0
var _airborne := 0
var _yaw_reversals := 0
var _prev_yaw := 0.0
var _prev_yaw_step := 0.0


func scenario_name() -> String:
	return "CorneringDrift"


func scenario_description() -> String:
	return "0.25s plain steer vs 0.25s Drift/Brake+steer at cruise; yaw rate, speed retention, recovery."


func race_config() -> Dictionary:
	return {"mode": RaceResult.MODE_CIRCUIT, "laps": 3, "ai_count": 0}


func duration_ticks() -> int:
	return END_TICK


func capture_interval_ticks() -> int:
	return 15


func on_tick() -> void:
	var yaw := player.rotation.y
	var v := signed_speed(player)
	if frame < NORMAL_START:
		phase = "accelerate"
		steer_player_along_road(false)
	elif frame < NORMAL_START + TAP_TICKS:
		if frame == NORMAL_START:
			_steer_sign = _upcoming_turn_sign()
			_yaw_before = yaw
			_normal_entry = v
		phase = "steer"
		player.set_touch_input(_steer_sign < 0.0, _steer_sign > 0.0, false)
		_track_yaw_jitter(yaw)
	elif frame == NORMAL_START + TAP_TICKS:
		_normal_yaw_rate = absf(rad_to_deg(angle_difference(_yaw_before, yaw))) / (TAP_TICKS / TICK_RATE)
		_normal_speed_after = v
		phase = "recover1"
		steer_player_along_road(false)
	elif frame < DRIFT_START:
		phase = "recover1"
		steer_player_along_road(false)
	elif frame < DRIFT_START + TAP_TICKS:
		if frame == DRIFT_START:
			_steer_sign = _upcoming_turn_sign()
			_yaw_before = yaw
			_drift_entry = v
		phase = "drift"
		player.set_touch_input(_steer_sign < 0.0, _steer_sign > 0.0, true)
		_track_yaw_jitter(yaw)
	elif frame == DRIFT_START + TAP_TICKS:
		_drift_yaw_rate = absf(rad_to_deg(angle_difference(_yaw_before, yaw))) / (TAP_TICKS / TICK_RATE)
		_drift_speed_after = v
		phase = "recover2"
		steer_player_along_road(false)
	else:
		phase = "recover2"
		steer_player_along_road(false)
		if _regain_tick < 0 and v >= RallyDriveModel.CRUISE_SPEED * 0.95:
			_regain_tick = frame
	_min_upright = minf(_min_upright, uprightness(player))
	if frame > 10 and not player.is_on_floor():
		_airborne += 1
	_prev_yaw = yaw


func _upcoming_turn_sign() -> float:
	var nearest := nearest_route(player)
	var ctrl := AIDriver.compute_control(centerline(), int(nearest.index), player.global_position, -player.global_transform.basis.z)
	return -1.0 if float(ctrl.steering) < 0.0 else 1.0


func _track_yaw_jitter(yaw: float) -> void:
	var step := angle_difference(_prev_yaw, yaw)
	if absf(_prev_yaw_step) > 0.0001 and absf(step) > 0.0001 and signf(step) != signf(_prev_yaw_step):
		_yaw_reversals += 1
	_prev_yaw_step = step


func on_evaluate() -> void:
	var regain_s := (_regain_tick - (DRIFT_START + TAP_TICKS)) / TICK_RATE if _regain_tick > 0 else -1.0
	var ratio := _drift_yaw_rate / _normal_yaw_rate if _normal_yaw_rate > 0.01 else 0.0
	var retained := _drift_speed_after / _drift_entry if _drift_entry > 0.1 else 0.0
	metric("normal_entry_speed_ms", "%.2f" % _normal_entry)
	metric("normal_yaw_rate_deg_s", "%.1f" % _normal_yaw_rate)
	metric("normal_speed_after_ms", "%.2f" % _normal_speed_after)
	metric("drift_entry_speed_ms", "%.2f" % _drift_entry)
	metric("drift_yaw_rate_deg_s", "%.1f" % _drift_yaw_rate)
	metric("drift_speed_after_ms", "%.2f" % _drift_speed_after)
	metric("drift_to_normal_yaw_ratio", "%.2f" % ratio)
	metric("drift_speed_retained_pct", "%.0f" % (retained * 100.0))
	metric("regain_95pct_cruise_s", "%.3f" % regain_s)
	metric("yaw_direction_reversals_during_inputs", _yaw_reversals)
	assert_at_least(_normal_entry, 28.0, "Plain steer entered at cruise speed", " m/s")
	assert_at_least(_drift_entry, 28.0, "Drift entered at cruise speed", " m/s")
	assert_at_least(_normal_yaw_rate, 30.0, "Plain steering turns the car meaningfully", " deg/s")
	assert_at_least(_drift_yaw_rate, 30.0, "Drift steering turns the car meaningfully", " deg/s")
	assert_at_most(_yaw_reversals, 0, "Yaw is smooth while input is held (no jitter)", " reversals")
	assert_at_least(_min_upright, 0.99, "Car never tilts or flips", "")
	assert_at_most(_airborne, 0, "Car never leaves the floor", " ticks")
	assert_true(_regain_tick > 0, "Car regains 95% cruise after drift")
	assert_at_most(regain_s, 1.5, "Regain 95% cruise within 1.5s", " s")
	# Game-feel checks without a numeric spec in the PRD: report, do not fail.
	if ratio < 1.15:
		warn("Drift turns only %.2fx as sharply as plain steering (DRIFT_STEER_MULTIPLIER=%.2f is cancelled by speed loss)." % [ratio, RallyCar.DRIFT_STEER_MULTIPLIER])
	if retained < 0.6:
		warn("A 0.25s drift tap keeps only %.0f%% of entry speed; drift behaves like a hard brake." % (retained * 100.0))
