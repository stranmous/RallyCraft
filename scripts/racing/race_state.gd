extends RefCounted
class_name RaceState

var lap_target := 1
var current_lap := 1
var expected_checkpoint := 0
var last_valid_checkpoint := 0
var elapsed_seconds := 0.0
var finished := false
var finish_seconds := 0.0
var _checkpoint_count := 0


func configure(checkpoint_count: int, target_laps: int) -> bool:
	if checkpoint_count < 2 or target_laps < 1 or target_laps > 5:
		return false
	_checkpoint_count = checkpoint_count
	lap_target = target_laps
	current_lap = 1
	expected_checkpoint = 1
	last_valid_checkpoint = 0
	elapsed_seconds = 0.0
	finished = false
	finish_seconds = 0.0
	return true


func tick(delta: float) -> void:
	if not finished:
		elapsed_seconds += delta


func pass_checkpoint(checkpoint_index: int) -> bool:
	if finished or checkpoint_index != expected_checkpoint:
		return false
	last_valid_checkpoint = checkpoint_index
	if checkpoint_index == 0:
		if current_lap >= lap_target:
			finished = true
			finish_seconds = elapsed_seconds
			return true
		current_lap += 1
	expected_checkpoint = (checkpoint_index + 1) % _checkpoint_count
	return true


func get_status() -> Dictionary:
	return {
		"lap": current_lap,
		"lap_target": lap_target,
		"elapsed_seconds": elapsed_seconds,
		"finished": finished,
		"finish_seconds": finish_seconds,
		"last_valid_checkpoint": last_valid_checkpoint,
	}
