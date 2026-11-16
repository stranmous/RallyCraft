extends RefCounted
class_name GhostRecorder

const SAMPLE_INTERVAL := 0.1

var _samples: Array[Dictionary] = []
var _sample_accumulator := 0.0
var _elapsed := 0.0


func reset() -> void:
	_samples.clear()
	_sample_accumulator = 0.0
	_elapsed = 0.0


func capture(delta: float, transform: Transform3D) -> void:
	_elapsed += delta
	_sample_accumulator += delta
	if _sample_accumulator < SAMPLE_INTERVAL:
		return
	_sample_accumulator = 0.0
	_samples.append({
		"time": _elapsed,
		"position": [transform.origin.x, transform.origin.y, transform.origin.z],
		"rotation_y": transform.basis.get_euler().y,
	})


func get_samples() -> Array[Dictionary]:
	return _samples.duplicate(true)
