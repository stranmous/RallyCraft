extends "res://tests/scenarios/scenario_base.gd"

# Full 8-car grid (player + 7 AI) racing for 25 seconds.
# Checks every AI keeps making progress, never needs a recovery reset,
# never stays glued to another car, and reports position changes.

const RUN_TICKS := 1500
const STALL_SPEED := 1.0
const STUCK_DISTANCE := 2.4

var _last_pos: Array[Vector3] = []
var _teleports: Array[int] = []
var _stall_streak: Array[int] = []
var _max_stall: Array[int] = []
var _airborne: Array[int] = []
var _min_upright := 1.0
var _pair_streak := {}
var _max_pair_streak := 0
var _order: Array[String] = []
var _order_changes := 0
var _player_rank_changes := 0
var _last_player_rank := 1
var _max_speed_seen := 0.0


func scenario_name() -> String:
	return "AiPackOvertake"


func scenario_description() -> String:
	return "Player + 7 AI from the grid for 25s: progress, stalls, resets, pile-ups, position changes."


func race_config() -> Dictionary:
	return {"mode": RaceResult.MODE_CIRCUIT, "laps": 5, "ai_count": 7}


func duration_ticks() -> int:
	return RUN_TICKS


func capture_interval_ticks() -> int:
	return 75


func on_setup() -> void:
	for car in ai_cars():
		_last_pos.append(car.global_position)
		_teleports.append(0)
		_stall_streak.append(0)
		_max_stall.append(0)
		_airborne.append(0)


func on_tick() -> void:
	phase = "race"
	steer_player_along_road(false)
	var cars := ai_cars()
	for i in cars.size():
		var car := cars[i]
		var pos := car.global_position
		if pos.distance_to(_last_pos[i]) > 5.0:
			_teleports[i] += 1
		_last_pos[i] = pos
		var v := signed_speed(car)
		_max_speed_seen = maxf(_max_speed_seen, absf(v))
		if frame > 60 and absf(v) < STALL_SPEED:
			_stall_streak[i] += 1
			_max_stall[i] = maxi(_max_stall[i], _stall_streak[i])
		else:
			_stall_streak[i] = 0
		if frame > 10 and not car.is_on_floor():
			_airborne[i] += 1
		_min_upright = minf(_min_upright, uprightness(car))
	_track_pairs()
	if frame % 10 == 0:
		_track_order()


func _track_pairs() -> void:
	var all: Array[RallyCar] = [player]
	all.append_array(ai_cars())
	for a in all.size():
		for b in range(a + 1, all.size()):
			var key := "%d-%d" % [a, b]
			var d := all[a].global_position.distance_to(all[b].global_position)
			if frame > 60 and d < STUCK_DISTANCE:
				_pair_streak[key] = int(_pair_streak.get(key, 0)) + 1
				_max_pair_streak = maxi(_max_pair_streak, int(_pair_streak[key]))
			else:
				_pair_streak[key] = 0


func _track_order() -> void:
	var entries: Array = [["P", race_manager.get_player_progress()]]
	var drivers := ai_drivers()
	for i in drivers.size():
		entries.append(["A%d" % (i + 1), drivers[i].get_route_progress()])
	entries.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
	var order: Array[String] = []
	for e in entries:
		order.append(str(e[0]))
	if not _order.is_empty():
		for k in order.size():
			if order[k] != _order[k]:
				_order_changes += 1
				break
	_order = order
	var rank := int(race_manager.get_status().get("position", 1))
	if rank != _last_player_rank:
		_player_rank_changes += 1
		_last_player_rank = rank


func on_evaluate() -> void:
	var track_len := race_manager._route_distances[race_manager._route_distances.size() - 1]
	var min_progress := INF
	var drivers := ai_drivers()
	var progress_parts: Array[String] = []
	for i in drivers.size():
		var p := drivers[i].get_route_progress()
		min_progress = minf(min_progress, p)
		progress_parts.append("%.0f" % p)
	var total_teleports := 0
	var worst_stall := 0
	var worst_air := 0
	for i in _teleports.size():
		total_teleports += _teleports[i]
		worst_stall = maxi(worst_stall, _max_stall[i])
		worst_air = maxi(worst_air, _airborne[i])
	metric("track_length_m", "%.0f" % track_len)
	metric("ai_count", drivers.size())
	metric("ai_route_progress_m", "[%s]" % ", ".join(progress_parts))
	metric("player_route_progress_m", "%.0f" % race_manager.get_player_progress())
	metric("ai_recovery_teleports", "%s" % str(_teleports))
	metric("worst_ai_stall_ticks", worst_stall)
	metric("worst_ai_airborne_ticks", worst_air)
	metric("longest_cars_glued_ticks", _max_pair_streak)
	metric("race_order_changes", _order_changes)
	metric("player_rank_changes", _player_rank_changes)
	metric("final_order", ", ".join(_order))
	metric("max_speed_any_ai_ms", "%.1f" % _max_speed_seen)
	var expected := RallyDriveModel.CRUISE_SPEED * (RUN_TICKS / TICK_RATE)
	assert_true(drivers.size() == 7, "All 7 AI cars spawned", "got %d" % drivers.size())
	assert_at_least(min_progress, expected * 0.5, "Slowest AI covers >= 50%% of cruise distance in 25s", " m")
	assert_at_most(worst_stall, 60, "No AI stalls (< 1 m/s) for more than 1s", " ticks")
	assert_at_most(total_teleports, 0, "No AI needs a recovery reset on a clean race", " resets")
	assert_at_most(worst_air, 6, "AI cars stay on the floor", " ticks")
	assert_at_least(_min_upright, 0.99, "No AI tilts or flips", "")
	assert_at_most(_max_pair_streak, 60, "No two cars stay glued together for more than 1s", " ticks")
	assert_at_most(_max_speed_seen, RallyDriveModel.BOOST_SPEED + 2.0, "No physics explosion (speed <= boost cap)", " m/s")
	if _order_changes == 0:
		warn("No position changes in 25s: the pack runs as a procession (no overtakes).")
