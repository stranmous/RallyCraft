extends "res://tests/scenarios/scenario_base.gd"

# Boost lifecycle: fire the starting charge, collect a pad, verify the pad
# cannot be re-collected while on its 8s global cooldown, and that it respawns.

const TIMEOUT := 1400
const APPROACH := 25.0

var _state := "accelerate"
var _events: Array[Dictionary] = []
var _start_charged := false
var _boost_fire_tick := -1
var _boost_end_tick := -1
var _boost_peak := 0.0
var _cruise_before := 0.0
var _pad_index := -1
var _pad_pos := Vector3.ZERO
var _pad_approach_pos := Vector3.ZERO
var _pad_heading := Vector3.FORWARD
var _approach_tick := -1
var _collect_tick := -1
var _charged_after_collect := false
var _cooldown_after_collect := 0.0
var _recollect_attempt_tick := -1
var _recollected := false
var _charged_after_recollect := false
var _respawn_tick := -1
var _wait_tick := 0


func scenario_name() -> String:
	return "BoostPickup"


func scenario_description() -> String:
	return "Fire boost, collect a pad, try to re-collect during cooldown, wait for 8s respawn."


func race_config() -> Dictionary:
	return {"mode": RaceResult.MODE_CIRCUIT, "laps": 3, "ai_count": 0}


func duration_ticks() -> int:
	return TIMEOUT


func capture_interval_ticks() -> int:
	return 30


func on_setup() -> void:
	_start_charged = bool(player.get_drive_state().boost_charged)
	race_manager.boost_collected.connect(func(idx: int, by_player: bool) -> void:
		_events.append({"tick": frame, "pad": idx, "by_player": by_player, "pos": player.global_position})
		if idx == _pad_index and by_player:
			if _collect_tick < 0 and _state == "approach":
				_collect_tick = frame
			elif _state == "recollect":
				_recollected = true
	)


func on_tick() -> void:
	phase = _state
	var ds := player.get_drive_state()
	var v := signed_speed(player)
	match _state:
		"accelerate":
			steer_player_along_road(false)
			if frame >= 120:
				_cruise_before = v
				player.request_touch_boost()
				_state = "boosting"
		"boosting":
			steer_player_along_road(false)
			if _boost_fire_tick < 0 and float(ds.boost_remaining) > 0.0:
				_boost_fire_tick = frame
			_boost_peak = maxf(_boost_peak, v)
			if _boost_fire_tick > 0 and float(ds.boost_remaining) <= 0.0:
				_boost_end_tick = frame
				_state = "coast"
			if frame > 260:
				_state = "coast"
		"coast":
			steer_player_along_road(false)
			_wait_tick += 1
			if _wait_tick >= 30:
				_pick_pad_and_teleport()
				_state = "approach"
		"approach":
			steer_player_along_road(false)
			if _collect_tick > 0:
				_charged_after_collect = bool(ds.boost_charged)
				_cooldown_after_collect = _pad_state().get("cooldown", 0.0)
				player.request_touch_boost()
				_wait_tick = 0
				_state = "spend"
			elif frame - _approach_tick > 120:
				_state = "wait_respawn"
		"spend":
			steer_player_along_road(false)
			_wait_tick += 1
			if _wait_tick >= 90:
				place_car(player, _pad_approach_pos, _pad_heading)
				_recollect_attempt_tick = frame
				_state = "recollect"
		"recollect":
			steer_player_along_road(false)
			if frame - _recollect_attempt_tick >= 90:
				_charged_after_recollect = bool(ds.boost_charged)
				_state = "wait_respawn"
		"wait_respawn":
			steer_player_along_road(false)
			if _collect_tick > 0 and bool(_pad_state().get("active", false)):
				_respawn_tick = frame
				end_scenario()


func _pick_pad_and_teleport() -> void:
	var pads := race_manager.get_boost_pickups_state()
	for p in pads:
		if bool(p.active):
			_pad_index = int(p.index)
			_pad_pos = p.position
			break
	if _pad_index < 0:
		return
	var idx := int(race_manager._find_nearest_route_point(_pad_pos).index)
	_pad_heading = route_tangent(idx)
	_pad_approach_pos = _pad_pos - _pad_heading * APPROACH + Vector3.UP * 0.25
	place_car(player, _pad_approach_pos, _pad_heading)
	_approach_tick = frame


func _pad_state() -> Dictionary:
	for p in race_manager.get_boost_pickups_state():
		if int(p.index) == _pad_index:
			return p
	return {}


func on_evaluate() -> void:
	var pads := race_manager.get_boost_pickups_state()
	var boost_s := (_boost_end_tick - _boost_fire_tick) / TICK_RATE if _boost_end_tick > 0 else -1.0
	var respawn_s := (_respawn_tick - _collect_tick) / TICK_RATE if _respawn_tick > 0 else -1.0
	var grid_pos: Vector3 = race_manager._checkpoints[0].position
	var nearest_pad_to_start := INF
	for p in pads:
		nearest_pad_to_start = minf(nearest_pad_to_start, Vector2(p.position.x, p.position.z).distance_to(Vector2(grid_pos.x, grid_pos.z)))
	metric("pad_count", pads.size())
	metric("player_starts_with_charge", _start_charged)
	metric("nearest_pad_to_start_line_m", "%.1f" % nearest_pad_to_start)
	metric("collection_events", str(_events.map(func(e: Dictionary) -> String: return "t=%.2fs pad%d %s" % [e.tick / TICK_RATE, e.pad, "player" if e.by_player else "ai"])))
	metric("cruise_before_boost_ms", "%.2f" % _cruise_before)
	metric("boost_peak_ms", "%.2f" % _boost_peak)
	metric("boost_duration_s", "%.3f" % boost_s)
	metric("tested_pad", _pad_index)
	metric("cooldown_reported_after_collect_s", "%.2f" % float(_cooldown_after_collect))
	metric("pad_respawn_s", "%.3f" % respawn_s)
	assert_true(pads.size() > 0, "Track generates at least one boost pad")
	assert_true(_boost_fire_tick > 0, "Boost button fires the charge")
	assert_at_least(_boost_peak, RallyDriveModel.BOOST_SPEED * 0.9, "Boost reaches near BOOST_SPEED", " m/s")
	assert_between(boost_s, 1.55, 1.65, "Boost burst lasts 1.6s", " s")
	assert_true(_collect_tick > 0, "Driving over an active pad collects it")
	assert_true(_charged_after_collect, "Collecting a pad fills the boost charge")
	assert_between(float(_cooldown_after_collect), 7.9, 8.0, "Collected pad enters 8s cooldown", " s")
	assert_true(not _recollected, "Pad cannot be re-collected while cooling down")
	assert_true(not _charged_after_recollect, "Driving over a cooling pad does not refill charge")
	assert_between(respawn_s, 7.95, 8.1, "Pad respawns after 8s", " s")
	if nearest_pad_to_start < 30.0:
		warn("A boost pad sits %.1fm from the start line: whoever launches first takes it at t<1s." % nearest_pad_to_start)
