extends Node
class_name RaceManager

signal checkpoint_passed(checkpoint_index: int)
signal car_recovered(checkpoint_index: int)
signal boost_collected(pickup_index: int, by_player: bool)
signal race_finished(result: Dictionary)

const OFF_ROUTE_MARGIN := 0.55
const OFF_ROUTE_HEIGHT_DIFF := 2.4
const BOOST_RESPAWN_SECONDS := 8.0
const BOOST_PICKUP_RADIUS := 4.5

var _car: RallyCar
var _state := RaceState.new()
var _recovery := RaceRecoveryMonitor.new()
var _checkpoints: Array[Dictionary] = []
var _centerline := PackedVector3Array()
var _route_distances := PackedFloat32Array()
var _minimap_data: Dictionary = {}
var _boost_pickups: Array[Dictionary] = []
var _road_half_width := 7.0
var _mode := RaceResult.MODE_CIRCUIT
var _track_id := ""
var _ghost_recorder := GhostRecorder.new()
var _record_store := RecordStore.new()
var _result: Dictionary = {}
var _ai_cars: Array[RallyCar] = []
var _ai_drivers: Array[AIDriver] = []
var _player_position := 1
var _total_racers := 1
var _cached_player_route_idx := -1
var _cached_player_pos := Vector3(INF, INF, INF)


func configure(car: RallyCar, compiled_track: Dictionary, track_id: String, mode: String, laps: int, ai_cars: Array[RallyCar] = [], ai_drivers: Array[AIDriver] = []) -> bool:
	if not compiled_track.get("ok", false):
		return false
	if mode != RaceResult.MODE_CIRCUIT and mode != RaceResult.MODE_TIME_TRIAL:
		return false
	_car = car
	_mode = mode
	_track_id = track_id
	_checkpoints = compiled_track.checkpoints
	_centerline = compiled_track.centerline
	_road_half_width = float(compiled_track.get("half_width", 7.0))
	_route_distances = _build_route_distances(_centerline)
	_minimap_data = compiled_track.get("minimap", {})
	_ai_cars = ai_cars
	_ai_drivers = ai_drivers
	_total_racers = 1 + _ai_cars.size()
	_player_position = 1
	_cached_player_route_idx = -1
	_cached_player_pos = Vector3(INF, INF, INF)
	var target_laps := 1 if mode == RaceResult.MODE_TIME_TRIAL else clampi(laps, 1, 5)
	if not _state.configure(_checkpoints.size(), target_laps):
		return false
	_configure_boost_pickups(compiled_track)
	_recovery.reset(0.0)
	_ghost_recorder.reset()
	_result = {}
	return true


func _physics_process(delta: float) -> void:
	if _car == null or _checkpoints.is_empty() or _centerline.is_empty():
		return
	_state.tick(delta)
	if _mode == RaceResult.MODE_TIME_TRIAL and not _state.finished:
		_ghost_recorder.capture(delta, _get_car_transform())
	_check_expected_checkpoint()
	_check_recovery(delta)
	_update_boost_pickups(delta)
	_update_player_position()


func get_status() -> Dictionary:
	var status := _state.get_status()
	status["recovery_seconds"] = _recovery.get_stalled_seconds()
	status["mode"] = _mode
	status["position"] = _player_position
	status["total_racers"] = _total_racers
	status["track_id"] = _track_id
	return status


func get_minimap_data() -> Dictionary:
	return _minimap_data


func get_boost_pickups_state() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in _boost_pickups:
		var pos: Vector3 = p.position
		out.append({
			"index": p.index,
			"position": pos,
			"map_point": Vector2(pos.x, pos.z),
			"active": p.active,
			"cooldown": p.cooldown,
		})
	return out


func get_racer_map_markers() -> Dictionary:
	var player_pos := _get_car_position()
	var player_tf := _get_car_transform()
	var forward := -player_tf.basis.z
	var ai_points: Array[Vector2] = []
	for ai_car in _ai_cars:
		if ai_car != null:
			var ap := ai_car.global_position if ai_car.is_inside_tree() else ai_car.position
			ai_points.append(Vector2(ap.x, ap.z))
	return {
		"player_point": Vector2(player_pos.x, player_pos.z),
		"player_heading": Vector2(forward.x, forward.z).normalized(),
		"ai_points": ai_points,
	}


func get_result() -> Dictionary:
	if not _state.finished:
		return {}
	if not _result.is_empty():
		return _result.duplicate(true)
	var result := RaceResult.build(_mode, _state.finish_seconds, _state.lap_target, _player_position, _total_racers)
	var finish_ms := roundi(_state.finish_seconds * 1000.0)
	if _mode == RaceResult.MODE_TIME_TRIAL:
		var save_result := _record_store.save_best_lap(_track_id, finish_ms, _ghost_recorder.get_samples())
		result["new_best"] = save_result.get("improved", false)
		if not save_result.get("ok", false):
			result["record_error"] = "Unable to save the Time Trial ghost."
	else:
		var save_race := _record_store.save_best_race(_track_id, finish_ms)
		result["new_best"] = save_race.get("improved", false)
	_result = result
	return _result.duplicate(true)


func _configure_boost_pickups(compiled_track: Dictionary) -> void:
	_boost_pickups.clear()
	var anchors: Array = compiled_track.get("boost_anchors", [])
	var nodes: Array = compiled_track.get("boost_pickup_nodes", [])
	for i in anchors.size():
		var anchor: Dictionary = anchors[i]
		var node: Node3D = nodes[i] if i < nodes.size() else null
		if node != null:
			node.visible = true
		_boost_pickups.append({
			"index": anchor.get("index", i),
			"position": anchor.get("position", Vector3.ZERO),
			"cooldown": 0.0,
			"active": true,
			"node": node,
		})


func _update_boost_pickups(delta: float) -> void:
	if _boost_pickups.is_empty():
		return
	var player_pos := _get_car_position()
	for pickup in _boost_pickups:
		if not pickup.active:
			pickup.cooldown = maxf(0.0, float(pickup.cooldown) - delta)
			if float(pickup.cooldown) <= 0.0:
				pickup.active = true
				if pickup.node != null:
					pickup.node.visible = true
			continue
		var pad_pos: Vector3 = pickup.position
		if _is_within_pickup(player_pos, pad_pos):
			_car.refill_boost()
			_consume_pickup(pickup, true)
			continue
		for ai_car in _ai_cars:
			if ai_car == null:
				continue
			var ai_pos := ai_car.global_position if ai_car.is_inside_tree() else ai_car.position
			if _is_within_pickup(ai_pos, pad_pos):
				ai_car.refill_boost()
				_consume_pickup(pickup, false)
				break


func _is_within_pickup(car_pos: Vector3, pad_pos: Vector3) -> bool:
	if absf(car_pos.y - pad_pos.y) > 3.2:
		return false
	return Vector2(car_pos.x, car_pos.z).distance_to(Vector2(pad_pos.x, pad_pos.z)) <= BOOST_PICKUP_RADIUS


func _consume_pickup(pickup: Dictionary, by_player: bool) -> void:
	pickup.active = false
	pickup.cooldown = BOOST_RESPAWN_SECONDS
	if pickup.node != null:
		pickup.node.visible = false
	boost_collected.emit(int(pickup.index), by_player)


func _update_player_position() -> void:
	if _ai_drivers.is_empty() or _state.finished:
		return
	var player_progress := get_player_progress()
	var rank := 1
	for driver in _ai_drivers:
		if driver != null and driver.get_route_progress() > player_progress:
			rank += 1
	_player_position = rank


func get_player_progress() -> float:
	if _route_distances.is_empty() or _car == null:
		return 0.0
	var track_len := _route_distances[_route_distances.size() - 1]
	var car_pos := _get_car_position()
	var idx: int
	if _cached_player_route_idx >= 0 and _cached_player_route_idx < _route_distances.size() and car_pos.distance_squared_to(_cached_player_pos) < 0.001:
		idx = _cached_player_route_idx
	else:
		idx = int(_find_nearest_route_point(car_pos).index)
		_cached_player_route_idx = idx
		_cached_player_pos = car_pos
	if _state.current_lap == 1 and _state.last_valid_checkpoint == 0 and idx > _centerline.size() - 12:
		return _route_distances[idx] - track_len
	if _state.expected_checkpoint == 0 and idx <= 12:
		return float(_state.current_lap) * track_len + _route_distances[idx]
	return float(_state.current_lap - 1) * track_len + _route_distances[idx]


func _check_expected_checkpoint() -> void:
	var expected_idx := _state.expected_checkpoint
	var checkpoint: Dictionary = _checkpoints[expected_idx]
	var horizontal_car_position := _get_car_position()
	horizontal_car_position.y = checkpoint.position.y
	if expected_idx == 0:
		var cp_pos: Vector3 = checkpoint.position
		var cp_tangent: Vector3 = checkpoint.tangent
		var cp_width: float = float(checkpoint.width)
		var offset: Vector3 = horizontal_car_position - cp_pos
		var forward_dot: float = offset.dot(cp_tangent)
		var lateral_dist: float = (offset - cp_tangent * forward_dot).length()
		if forward_dot < -1.5 or forward_dot > 8.0 or lateral_dist > cp_width * 0.5:
			return
		if _state.pass_checkpoint(0):
			checkpoint_passed.emit(_state.last_valid_checkpoint)
			if _state.finished:
				_car.set_drive_enabled(false)
				race_finished.emit(get_result())
		return
	if horizontal_car_position.distance_to(checkpoint.position) <= checkpoint.width * 0.5:
		if _state.pass_checkpoint(expected_idx):
			checkpoint_passed.emit(_state.last_valid_checkpoint)
			if _state.finished:
				_car.set_drive_enabled(false)
				race_finished.emit(get_result())


func _check_recovery(delta: float) -> void:
	var car_pos := _get_car_position()
	var car_tf := _get_car_transform()
	var nearest := _find_nearest_route_point(car_pos)
	_cached_player_route_idx = int(nearest.index)
	_cached_player_pos = car_pos
	var nearest_point: Vector3 = nearest.get("point", car_pos)
	var upside_down := car_tf.basis.y.dot(Vector3.UP) < 0.25
	var max_road_offset := _road_half_width + TrackCompiler.CURB_WIDTH + OFF_ROUTE_MARGIN
	var is_off_route := float(nearest.distance) > max_road_offset or absf(car_pos.y - nearest_point.y) > OFF_ROUTE_HEIGHT_DIFF
	var drive_state := _car.get_drive_state()
	var speed: float = drive_state.speed
	var route_dist := _route_distances[nearest.index] if not _route_distances.is_empty() else 0.0
	if not upside_down and not is_off_route and bool(drive_state.get("braking", false)):
		_recovery.reset(route_dist)
		return
	if _recovery.update(delta, route_dist, speed, upside_down, is_off_route):
		_reset_to_checkpoint(_state.last_valid_checkpoint)


func _reset_to_checkpoint(checkpoint_index: int) -> void:
	var checkpoint: Dictionary = _checkpoints[checkpoint_index]
	var new_pos: Vector3 = checkpoint.position + Vector3.UP * 0.25
	if _car.is_inside_tree():
		_car.global_position = new_pos
	else:
		_car.position = new_pos
	_car.rotation.y = atan2(-checkpoint.tangent.x, -checkpoint.tangent.z)
	_car.velocity = Vector3.ZERO
	_car.force_update_transform()
	if _car.is_inside_tree():
		var rid := _car.get_rid()
		PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, _car.global_transform)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_KINEMATIC)
	_car.reset_physics_interpolation()
	_car.reset_drive_speed()
	_cached_player_route_idx = -1
	_cached_player_pos = Vector3(INF, INF, INF)
	_recovery.reset(checkpoint.route_distance)
	car_recovered.emit(checkpoint_index)


func _get_car_position() -> Vector3:
	if _car == null:
		return Vector3.ZERO
	return _car.global_position if _car.is_inside_tree() else _car.position


func _get_car_transform() -> Transform3D:
	if _car == null:
		return Transform3D()
	return _car.global_transform if _car.is_inside_tree() else _car.transform


func _find_nearest_route_point(position: Vector3) -> Dictionary:
	var n := _centerline.size()
	if n == 0:
		return {"index": 0, "distance": INF, "point": position}
	var best_score := INF
	var closest_distance := INF
	var closest_index := 0
	var closest_point := _centerline[0]
	if _cached_player_route_idx >= 0 and n > 40:
		var start := _cached_player_route_idx
		for offset in range(-10, 11):
			var index := (start + offset + n) % n
			var next_idx := (index + 1) % n
			var a := _centerline[index]
			var b := _centerline[next_idx]
			var ab_x := b.x - a.x
			var ab_z := b.z - a.z
			var ab_sq := ab_x * ab_x + ab_z * ab_z
			var t := clampf(((position.x - a.x) * ab_x + (position.z - a.z) * ab_z) / ab_sq, 0.0, 1.0) if ab_sq > 0.0001 else 0.0
			var proj := a.lerp(b, t)
			var dx := position.x - proj.x
			var dz := position.z - proj.z
			var flat_dist := sqrt(dx * dx + dz * dz)
			var score := flat_dist + maxf(0.0, absf(position.y - proj.y) - 2.0) * 1.5
			if score < best_score:
				best_score = score
				closest_distance = flat_dist
				closest_index = index if t <= 0.5 else next_idx
				closest_point = proj
		if closest_distance <= _road_half_width + 14.0:
			return {"index": closest_index, "distance": closest_distance, "point": closest_point}
	best_score = INF
	closest_distance = INF
	for index in n:
		var next_idx := (index + 1) % n
		var a := _centerline[index]
		var b := _centerline[next_idx]
		var ab_x := b.x - a.x
		var ab_z := b.z - a.z
		var ab_sq := ab_x * ab_x + ab_z * ab_z
		var t := clampf(((position.x - a.x) * ab_x + (position.z - a.z) * ab_z) / ab_sq, 0.0, 1.0) if ab_sq > 0.0001 else 0.0
		var proj := a.lerp(b, t)
		var dx := position.x - proj.x
		var dz := position.z - proj.z
		var flat_dist := sqrt(dx * dx + dz * dz)
		var score := flat_dist + maxf(0.0, absf(position.y - proj.y) - 2.0) * 1.5
		if score < best_score:
			best_score = score
			closest_distance = flat_dist
			closest_index = index if t <= 0.5 else next_idx
			closest_point = proj
	return {"index": closest_index, "distance": closest_distance, "point": closest_point}


func _build_route_distances(route: PackedVector3Array) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	var total := 0.0
	for index in route.size():
		distances.append(total)
		total += route[index].distance_to(route[(index + 1) % route.size()])
	return distances
