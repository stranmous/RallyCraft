extends SceneTree

const RaceStateScript = preload("res://scripts/racing/race_state.gd")
const RecoveryMonitorScript = preload("res://scripts/racing/race_recovery_monitor.gd")

var _failed := false


func _init() -> void:
	var state := RaceStateScript.new()
	_expect(state.configure(3, 1), "Race state should accept 1 lap.")
	_expect(state.configure(3, 5), "Race state should accept 5 laps.")
	_expect(not state.configure(3, 0), "Race state must reject 0 laps.")
	_expect(not state.configure(3, 6), "Race state must reject 6 laps.")
	_expect(state.configure(3, 2), "Race state should accept valid checkpoint and lap counts.")
	state.tick(12.5)
	_expect(state.pass_checkpoint(1), "The first expected checkpoint should count.")
	_expect(not state.pass_checkpoint(0), "Skipping a checkpoint must not count.")
	_expect(state.pass_checkpoint(2), "The next expected checkpoint should count.")
	_expect(state.pass_checkpoint(0), "Crossing the start after all checkpoints should finish a lap.")
	_expect(state.current_lap == 2 and not state.finished, "The first completed lap should advance the lap count.")
	_expect(state.pass_checkpoint(1) and state.pass_checkpoint(2) and state.pass_checkpoint(0), "The second lap should finish in checkpoint order.")
	_expect(state.finished and state.finish_seconds > 0.0, "Completing the target lap count should finish the race.")

	var recovery := RecoveryMonitorScript.new()
	recovery.reset(0.0)
	_expect(not recovery.update(1.9, 0.0, 0.0, false, false), "Recovery must wait for the full two-second delay.")
	_expect(recovery.update(0.2, 0.0, 0.0, false, false), "A stopped car should recover after two seconds.")
	recovery.reset(0.0)
	_expect(not recovery.update(2.0, 4.0, 18.0, false, false), "Route progress should prevent recovery.")
	_expect(recovery.update(2.1, 4.0, 18.0, false, true), "An off-route car should recover after two seconds.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
