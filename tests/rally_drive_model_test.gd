extends SceneTree

const RallyDriveModelScript = preload("res://scripts/racing/rally_drive_model.gd")

var _failed := false


func _init() -> void:
	var drive := RallyDriveModelScript.new()
	for _step in 60:
		drive.step(1.0 / 60.0, false, false)
	_expect(drive.speed > 20.0, "Auto-throttle should build racing speed without accelerator input.")
	var speed_before_brake := drive.speed
	drive.step(0.4, true, false)
	_expect(drive.speed < speed_before_brake, "Drift/brake input should reduce speed.")
	for _step in 35:
		drive.step(1.0 / 60.0, true, false)
	_expect(is_zero_approx(drive.speed) or drive.speed <= 0.0, "Holding brake should bring forward speed all the way to zero.")
	for _step in 60:
		drive.step(1.0 / 60.0, true, false)
	_expect(drive.speed < -5.0 and drive.reversing, "Continuing to hold brake after stopping should engage reverse.")
	for _step in 90:
		drive.step(1.0 / 60.0, false, false)
	_expect(drive.speed > 15.0 and not drive.reversing, "Releasing brake should return the car to forward auto-throttle.")
	drive.refill_boost()
	var boost_state := drive.step(0.01, false, true)
	_expect(boost_state.boost_active and not boost_state.boost_charged, "A charged boost should activate once and consume its charge.")
	drive.step(RallyDriveModelScript.BOOST_DURATION + 0.1, false, false)
	_expect(drive.boost_remaining == 0.0, "Boost should finish after its fixed duration.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
