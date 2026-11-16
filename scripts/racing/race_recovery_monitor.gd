extends RefCounted
class_name RaceRecoveryMonitor

const RECOVERY_DELAY := 2.0
const MIN_PROGRESS_DISTANCE := 2.0
const MIN_RECOVERY_SPEED := 1.5

const PROGRESS_GRACE_SECONDS := 0.5

var _last_route_distance := -1.0
var _stalled_seconds := 0.0
var _progress_wait_seconds := 0.0


func reset(route_distance: float) -> void:
	_last_route_distance = route_distance
	_stalled_seconds = 0.0
	_progress_wait_seconds = 0.0


func update(delta: float, route_distance: float, speed: float, is_upside_down: bool, is_off_route: bool) -> bool:
	if is_upside_down or is_off_route:
		_progress_wait_seconds = 0.0
		_stalled_seconds += delta
		return _stalled_seconds >= RECOVERY_DELAY
	var made_progress := _last_route_distance < 0.0 or absf(route_distance - _last_route_distance) >= MIN_PROGRESS_DISTANCE
	if made_progress and speed >= MIN_RECOVERY_SPEED:
		_last_route_distance = route_distance
		_stalled_seconds = 0.0
		_progress_wait_seconds = 0.0
		return false
	if speed < MIN_RECOVERY_SPEED:
		_progress_wait_seconds = 0.0
		_stalled_seconds += delta
	else:
		# Do not bank sub-step stall time during normal forward driving between 2m progress ticks.
		_progress_wait_seconds += delta
		if _progress_wait_seconds >= PROGRESS_GRACE_SECONDS:
			_stalled_seconds += delta
		else:
			_stalled_seconds = 0.0
	return _stalled_seconds >= RECOVERY_DELAY


func get_stalled_seconds() -> float:
	return _stalled_seconds
