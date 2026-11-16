extends RefCounted
class_name RallyDriveModel

const CRUISE_SPEED := 32.0
const AI_BRAKE_SPEED := 14.0
const REVERSE_SPEED := 13.0
const ACCELERATION := 22.0
const BOOST_ACCELERATION := 46.0
const BOOST_IMPULSE := 6.5
const BOOST_COAST_DECEL := 14.0
const BRAKE_TAP_DECEL := 18.0
const BRAKE_DECELERATION := 56.0
const BRAKE_RAMP_SECONDS := 0.34
const DRIFT_DECEL_MIN := 11.0
const DRIFT_DECEL_MAX := 22.0
const DRIFT_MIN_SPEED := 17.5
const DRIFT_GRACE_SECONDS := 0.28
const DRIFT_SUSTAIN_STOP_SECONDS := 0.65
const REVERSE_ACCELERATION := 24.0
const REVERSE_HOLD_DELAY := 0.14
const BOOST_SPEED := 50.0
const BOOST_DURATION := 1.60

var speed := 0.0
var boost_charged := true
var boost_remaining := 0.0
var reversing := false
var _brake_stop_timer := 0.0
var _brake_hold_time := 0.0
var _drift_grace_timer := 0.0


func step(delta: float, braking: bool, boost_requested: bool, pace_multiplier: float = 1.0, allow_reverse: bool = true, is_steering: bool = false) -> Dictionary:
	if braking:
		boost_remaining = 0.0
		_brake_hold_time = minf(_brake_hold_time + delta, 5.0)
		if is_steering and speed > 8.0:
			_drift_grace_timer = DRIFT_GRACE_SECONDS
		else:
			_drift_grace_timer = maxf(0.0, _drift_grace_timer - delta)
		var press_t := clampf(_brake_hold_time / BRAKE_RAMP_SECONDS, 0.0, 1.0)
		var progressive_decel := lerpf(BRAKE_TAP_DECEL, BRAKE_DECELERATION, press_t)
		var sustain_t := clampf((_brake_hold_time - DRIFT_SUSTAIN_STOP_SECONDS) / 0.30, 0.0, 1.0)
		var drifting_hold := (is_steering or _drift_grace_timer > 0.0) and speed > 6.0 and allow_reverse and sustain_t < 0.99
		if not allow_reverse:
			var ai_target := AI_BRAKE_SPEED * clampf(pace_multiplier, 0.35, 1.05)
			speed = move_toward(speed, ai_target, BRAKE_DECELERATION * delta)
			reversing = false
		elif drifting_hold and speed > DRIFT_MIN_SPEED and sustain_t <= 0.01:
			var drift_decel := lerpf(DRIFT_DECEL_MIN, DRIFT_DECEL_MAX, press_t)
			speed = move_toward(speed, DRIFT_MIN_SPEED, drift_decel * delta)
			_brake_stop_timer = 0.0
			reversing = false
		elif drifting_hold:
			var low_drift_decel := lerpf(DRIFT_DECEL_MIN, 28.0, press_t)
			var blended_decel := lerpf(low_drift_decel, BRAKE_DECELERATION, sustain_t)
			speed = move_toward(speed, 0.0, blended_decel * delta)
			_brake_stop_timer = 0.0
			reversing = false
		elif speed > 0.0:
			var time_to_zero := speed / progressive_decel
			if delta <= time_to_zero:
				speed = move_toward(speed, 0.0, progressive_decel * delta)
				if speed < 0.05:
					speed = 0.0
				_brake_stop_timer = 0.0
				reversing = false
			else:
				var remaining_delta := delta - time_to_zero
				speed = 0.0
				_advance_reverse(remaining_delta)
		else:
			_advance_reverse(delta)
	else:
		_brake_stop_timer = 0.0
		_brake_hold_time = maxf(0.0, _brake_hold_time - delta * 3.2)
		_drift_grace_timer = maxf(0.0, _drift_grace_timer - delta)
		if boost_requested and boost_charged and boost_remaining <= 0.0:
			boost_charged = false
			boost_remaining = BOOST_DURATION
			if speed > 0.0:
				speed = minf(BOOST_SPEED, speed + BOOST_IMPULSE)
		if boost_remaining > 0.0:
			boost_remaining = maxf(0.0, boost_remaining - delta)
		var target_speed := CRUISE_SPEED * clampf(pace_multiplier, 0.35, 1.05)
		var rate := ACCELERATION
		if boost_remaining > 0.0:
			target_speed = BOOST_SPEED
			rate = BOOST_ACCELERATION
		elif speed < 0.0:
			rate = BRAKE_DECELERATION
		elif speed > target_speed:
			rate = BOOST_COAST_DECEL
		speed = move_toward(speed, target_speed, rate * delta)
		reversing = speed < -0.05
	return {
		"speed": speed,
		"reversing": reversing,
		"boost_active": boost_remaining > 0.0,
		"boost_charged": boost_charged,
	}


func _advance_reverse(delta: float) -> void:
	if _brake_stop_timer < REVERSE_HOLD_DELAY:
		_brake_stop_timer += delta
		if _brake_stop_timer <= REVERSE_HOLD_DELAY:
			speed = 0.0
			reversing = false
			return
		var reverse_delta := _brake_stop_timer - REVERSE_HOLD_DELAY
		speed = move_toward(0.0, -REVERSE_SPEED, REVERSE_ACCELERATION * reverse_delta)
	else:
		speed = move_toward(speed, -REVERSE_SPEED, REVERSE_ACCELERATION * delta)
	reversing = speed < -0.05


func reset() -> void:
	speed = 0.0
	reversing = false
	_brake_stop_timer = 0.0
	_brake_hold_time = 0.0
	_drift_grace_timer = 0.0


func refill_boost() -> void:
	boost_charged = true
