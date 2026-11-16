extends Node3D
class_name GhostPlayback

var _samples: Array[Dictionary] = []
var _elapsed := 0.0
var _sample_index := 0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func configure(samples: Array[Dictionary]) -> bool:
	if samples.size() < 2:
		return false
	_samples = samples.duplicate(true)
	return true


func _process(delta: float) -> void:
	if _samples.size() < 2:
		return
	_elapsed += delta
	while _sample_index < _samples.size() - 2 and float(_samples[_sample_index + 1].time) < _elapsed:
		_sample_index += 1
	if _elapsed > float(_samples[_samples.size() - 1].time):
		visible = false
		return
	var first: Dictionary = _samples[_sample_index]
	var second: Dictionary = _samples[_sample_index + 1]
	var duration := maxf(float(second.time) - float(first.time), 0.001)
	var blend := clampf((_elapsed - float(first.time)) / duration, 0.0, 1.0)
	var first_position := _to_vector3(first.position)
	var second_position := _to_vector3(second.position)
	global_position = first_position.lerp(second_position, blend)
	rotation.y = lerp_angle(float(first.rotation_y), float(second.rotation_y), blend)


func _to_vector3(raw: Array) -> Vector3:
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
