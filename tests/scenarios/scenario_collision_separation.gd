extends "res://tests/scenarios/scenario_base.gd"

# Soft arcade contact:
# (A) player at cruise rear-ends a stopped car placed on the racing line,
# (B) player side-swipes a car running alongside at speed.
# PRD: limited speed loss and separation, no flips, no prolonged blocking.

const A_START := 120
const A_END := 270
const B_START := 300
const B_STEER_TICKS := 24
const B_END := 450

var _rival: RallyCar
var _rival_driver: AIDriver
var _a_entry := 0.0
var _a_contact_tick := -1
var _a_contact_ticks := 0
var _a_max_contact_streak := 0
var _a_streak := 0
var _a_min_speed_after := INF
var _a_progress_at_contact := 0.0
var _a_progress_after := 0.0
var _a_min_gap := INF
var _b_contact_tick := -1
var _b_min_speed := INF
var _b_rival_min_speed := INF
var _b_max_streak := 0
var _b_streak := 0
var _b_gap_after := 0.0
var _max_y := 0.0
var _min_upright := 1.0
var _max_speed := 0.0
var _side_sign := 1.0


func scenario_name() -> String:
	return "CollisionSeparation"


func scenario_description() -> String:
	return "A: rear-end a stopped car at cruise. B: side-swipe a car alongside. Expect soft separation."


func race_config() -> Dictionary:
	return {"mode": RaceResult.MODE_CIRCUIT, "laps": 3, "ai_count": 1}


func duration_ticks() -> int:
	return B_END


func capture_interval_ticks() -> int:
	return 15


func on_setup() -> void:
	_rival = ai_cars()[0]
	_rival_driver = ai_drivers()[0]


func on_tick() -> void:
	var touching := _touching()
	if frame < A_START:
		phase = "accelerate"
		steer_player_along_road(false)
	elif frame == A_START:
		phase = "A_rear_end"
		_a_entry = signed_speed(player)
		var line := centerline()
		var idx := int(nearest_route(player).index)
		var look_ahead := AIDriver.LOOK_AHEAD_POINTS if line.size() < 32 else clampi(int(line.size() / 36), 3, 6)
		var target_idx := (idx + look_ahead) % line.size()
		var mid_idx := (idx + maxi(2, look_ahead / 2)) % line.size()
		var rival_pos := player.global_position.lerp(line[target_idx], 0.6)
		rival_pos.y = line[mid_idx].y + 0.25
		place_car(_rival, rival_pos, route_tangent(mid_idx))
		_rival.set_drive_enabled(false)
		_rival_driver.set_physics_process(false)
		steer_player_along_road(false)
	elif frame < A_END:
		phase = "A_rear_end"
		steer_player_along_road(false)
		var d := player.global_position.distance_to(_rival.global_position)
		if touching:
			_a_contact_ticks += 1
			_a_streak += 1
			_a_max_contact_streak = maxi(_a_max_contact_streak, _a_streak)
			if _a_contact_tick < 0:
				_a_contact_tick = frame
				_a_progress_at_contact = race_manager.get_player_progress()
		else:
			_a_streak = 0
		if _a_contact_tick > 0:
			if frame - _a_contact_tick <= 60:
				_a_min_speed_after = minf(_a_min_speed_after, signed_speed(player))
			if frame - _a_contact_tick > 12:
				_a_min_gap = minf(_a_min_gap, d)
			if frame - _a_contact_tick == 90:
				_a_progress_after = race_manager.get_player_progress() - _a_progress_at_contact
	elif frame < B_START:
		phase = "reset"
		steer_player_along_road(false)
	elif frame == B_START:
		phase = "B_side_swipe"
		var line := centerline()
		var idx := int(nearest_route(player).index)
		var tangent := route_tangent(idx)
		var lateral := tangent.cross(Vector3.UP).normalized()
		var base := line[idx] + Vector3.UP * 0.25
		place_car(player, base - lateral * 1.3, tangent)
		place_car(_rival, base + lateral * 1.3, tangent)
		_side_sign = 1.0
		_rival_driver.reset_after_teleport(idx)
		_rival.set_drive_enabled(true)
		_rival._drive.speed = 24.0
		_rival._actual_speed = 24.0
		_rival._signed_actual_speed = 24.0
		_rival_driver.set_physics_process(true)
		player.set_touch_input(false, true, false)
	elif frame < B_START + B_STEER_TICKS:
		phase = "B_side_swipe"
		player.set_touch_input(false, true, false)
		_b_track(touching)
	else:
		phase = "B_after"
		steer_player_along_road(false)
		_b_track(touching)
		if frame == B_END - 1:
			_b_gap_after = _lateral_gap()
	_max_y = maxf(_max_y, maxf(player.global_position.y, _rival.global_position.y))
	_min_upright = minf(_min_upright, minf(uprightness(player), uprightness(_rival)))
	_max_speed = maxf(_max_speed, maxf(absf(signed_speed(player)), absf(signed_speed(_rival))))


func _b_track(touching: bool) -> void:
	if touching:
		if _b_contact_tick < 0:
			_b_contact_tick = frame
		_b_streak += 1
		_b_max_streak = maxi(_b_max_streak, _b_streak)
	else:
		_b_streak = 0
	_b_min_speed = minf(_b_min_speed, signed_speed(player))
	_b_rival_min_speed = minf(_b_rival_min_speed, signed_speed(_rival))


func _touching() -> bool:
	for i in player.get_slide_collision_count():
		if player.get_slide_collision(i).get_collider() == _rival:
			return true
	for i in _rival.get_slide_collision_count():
		if _rival.get_slide_collision(i).get_collider() == player:
			return true
	return player.global_position.distance_to(_rival.global_position) < 2.0


func _lateral_gap() -> float:
	var d := _rival.global_position - player.global_position
	d.y = 0.0
	return d.length()


func on_evaluate() -> void:
	var a_loss := 1.0 - (_a_min_speed_after / _a_entry) if _a_entry > 0.1 and _a_min_speed_after < INF else -1.0
	metric("A_entry_speed_ms", "%.2f" % _a_entry)
	metric("A_first_contact_t", "%.2f" % (_a_contact_tick / TICK_RATE))
	metric("A_total_contact_ticks", _a_contact_ticks)
	metric("A_longest_contact_streak_ticks", _a_max_contact_streak)
	metric("A_min_speed_1s_after_ms", "%.2f" % _a_min_speed_after)
	metric("A_speed_loss_pct", "%.0f" % (a_loss * 100.0))
	metric("A_progress_1_5s_after_m", "%.1f" % _a_progress_after)
	metric("A_min_center_gap_after_m", "%.2f" % _a_min_gap)
	metric("B_first_contact_t", "%.2f" % (_b_contact_tick / TICK_RATE))
	metric("B_longest_contact_streak_ticks", _b_max_streak)
	metric("B_player_min_speed_ms", "%.2f" % _b_min_speed)
	metric("B_rival_min_speed_ms", "%.2f" % _b_rival_min_speed)
	metric("B_gap_at_end_m", "%.2f" % _b_gap_after)
	metric("max_car_y_m", "%.2f" % _max_y)
	assert_true(_a_contact_tick > 0, "A: rear-end contact happens")
	assert_at_most(_a_max_contact_streak, 30, "A: no prolonged blocking (contact streak <= 0.5s)", " ticks")
	assert_at_least(_a_progress_after, 15.0, "A: player gets past the stopped car within 1.5s", " m")
	assert_at_most(a_loss, 0.5, "A: speed loss from contact is limited", " fraction")
	assert_at_least(_a_min_gap, 1.6, "A: cars do not interpenetrate after contact", " m")
	assert_true(_b_contact_tick > 0, "B: side-swipe contact happens")
	assert_at_most(_b_max_streak, 30, "B: cars separate (contact streak <= 0.5s)", " ticks")
	assert_at_least(_b_min_speed, RallyDriveModel.CRUISE_SPEED * 0.5, "B: player keeps >= 50% cruise", " m/s")
	assert_at_least(_b_rival_min_speed, RallyDriveModel.CRUISE_SPEED * 0.4, "B: rival is not stopped by the hit", " m/s")
	assert_at_least(_b_gap_after, 2.0, "B: cars end separated", " m")
	assert_at_most(_max_y, 1.0, "No car is launched into the air", " m")
	assert_at_least(_min_upright, 0.99, "No car tilts or flips", "")
	assert_at_most(_max_speed, RallyDriveModel.BOOST_SPEED + 2.0, "No physics explosion (speed <= boost cap)", " m/s")
