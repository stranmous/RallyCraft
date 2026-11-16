extends "res://tests/scenarios/scenario_base.gd"

# Off-route recovery: (A) car dropped 40m off the road while driving at speed,
# (B) car dropped off the road while holding brake (stopped off-route).
# Both must reset to the last valid checkpoint after 3s, facing along the road.

const OFFSET := 40.0
const TIMEOUT := 1100

var _state := "drive_a"
var _drop_tick := -1
var _recovered_tick := -1
var _recovery_count := 0
var _results: Array[Dictionary] = []
var _post_tick := 0
var _post_max_speed := 0.0


func scenario_name() -> String:
	return "BoundaryRecovery"


func scenario_description() -> String:
	return "Drop the car 40m off-route (A: driving, B: braking). Expect a reset after 3s, aligned with the road."


func race_config() -> Dictionary:
	return {"mode": RaceResult.MODE_CIRCUIT, "laps": 3, "ai_count": 0}


func duration_ticks() -> int:
	return TIMEOUT


func capture_interval_ticks() -> int:
	return 30


func on_setup() -> void:
	race_manager.car_recovered.connect(func(cp: int) -> void:
		_recovered_tick = frame
		_recovery_count += 1
		metric("recovery_%d_checkpoint" % _recovery_count, cp)
	)


func on_tick() -> void:
	phase = _state
	match _state:
		"drive_a":
			steer_player_along_road(false)
			if frame >= 90:
				_drop_off_route()
				_state = "offroute_a"
		"offroute_a":
			player.set_touch_input(false, false, false)
			_check_recovered("A_driving", "drive_b")
		"drive_b":
			steer_player_along_road(false)
			_post_tick += 1
			_post_max_speed = maxf(_post_max_speed, signed_speed(player))
			if _post_tick == 90:
				_results[0]["speed_1_5s_after"] = _post_max_speed
			if _post_tick >= 150:
				_drop_off_route()
				_state = "offroute_b"
		"offroute_b":
			player.set_touch_input(false, false, true)
			_check_recovered("B_braking", "done")
		"done":
			steer_player_along_road(false)
			_post_tick += 1
			if _post_tick >= 30:
				_complete_early()
	if _drop_tick > 0 and frame - _drop_tick > 300 and _state.begins_with("offroute"):
		_complete_early()


func _drop_off_route() -> void:
	var nearest := nearest_route(player)
	var idx := int(nearest.index)
	var tangent := route_tangent(idx)
	var lateral := tangent.cross(Vector3.UP).normalized()
	var center := _loop_centroid()
	var base := centerline()[idx]
	if (base + lateral).distance_to(center) < base.distance_to(center):
		lateral = -lateral
	place_car(player, base + lateral * OFFSET + Vector3.UP * 0.25, tangent)
	_drop_tick = frame
	_recovered_tick = -1


func _check_recovered(label: String, next_state: String) -> void:
	if _recovered_tick < 0:
		return
	var nearest := nearest_route(player)
	var tangent := route_tangent(int(nearest.index))
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	_results.append({
		"label": label,
		"delay_s": (_recovered_tick - _drop_tick) / TICK_RATE,
		"off_center_m": float(nearest.distance),
		"heading_dot": fwd.normalized().dot(tangent),
		"upright": uprightness(player),
		"speed_after": signed_speed(player),
	})
	_drop_tick = -1
	_post_tick = 0
	_post_max_speed = 0.0
	_state = next_state


func _loop_centroid() -> Vector3:
	var sum := Vector3.ZERO
	for p in centerline():
		sum += p
	return sum / float(centerline().size())


func _complete_early() -> void:
	end_scenario()


func on_evaluate() -> void:
	metric("recoveries_observed", _recovery_count)
	assert_true(_results.size() == 2, "Both off-route drops were recovered", "got %d of 2" % _results.size())
	for r in _results:
		var label: String = r.label
		metric("%s_delay_s" % label, "%.3f" % float(r.delay_s))
		metric("%s_off_center_m" % label, "%.2f" % float(r.off_center_m))
		metric("%s_heading_dot" % label, "%.3f" % float(r.heading_dot))
		assert_between(float(r.delay_s), 1.95, 2.2, "%s: reset fires after 2s" % label, " s")
		assert_at_most(float(r.off_center_m), 2.0, "%s: reset lands on the road centerline" % label, " m")
		assert_at_least(float(r.heading_dot), 0.95, "%s: reset faces along the road" % label, "")
		assert_at_least(float(r.upright), 0.99, "%s: reset car is upright" % label, "")
		if r.has("speed_1_5s_after"):
			metric("%s_speed_1_5s_after_ms" % label, "%.2f" % float(r.speed_1_5s_after))
			assert_at_least(float(r.speed_1_5s_after), 20.0, "%s: car drives off again after reset" % label, " m/s")
