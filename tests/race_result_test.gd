extends SceneTree

const RaceResultScript = preload("res://scripts/racing/race_result.gd")

var _failed := false


func _init() -> void:
	var circuit := RaceResultScript.build(RaceResultScript.MODE_CIRCUIT, 93.456, 3)
	_expect(circuit.title == "RACE COMPLETE" and circuit.laps == 3, "Circuit results should show a multi-lap race completion.")
	var time_trial := RaceResultScript.build(RaceResultScript.MODE_TIME_TRIAL, 61.2, 1)
	_expect(time_trial.title == "TIME TRIAL COMPLETE" and time_trial.laps == 1, "Time Trial results should show a one-lap completion.")
	_expect(RaceResultScript.format_time(61.2) == "01:01.200", "Result times should use minutes, seconds, and milliseconds.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
