extends SceneTree

const GhostRecorderScript = preload("res://scripts/racing/ghost_recorder.gd")

var _failed := false


func _init() -> void:
	var recorder := GhostRecorderScript.new()
	recorder.capture(0.05, Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0)))
	_expect(recorder.get_samples().is_empty(), "Ghost recording should sample at a bounded fixed interval.")
	recorder.capture(0.06, Transform3D(Basis.from_euler(Vector3(0.0, 0.5, 0.0)), Vector3(4.0, 2.0, 3.0)))
	var samples := recorder.get_samples()
	_expect(samples.size() == 1, "Ghost recording should create a sample after the interval elapses.")
	_expect(samples[0].position == [4.0, 2.0, 3.0], "Ghost samples should retain the car position.")
	_expect(absf(float(samples[0].rotation_y) - 0.5) < 0.01, "Ghost samples should retain heading.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
