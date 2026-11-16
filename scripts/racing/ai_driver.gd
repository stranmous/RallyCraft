extends Node
class_name AIDriver

const LOOK_AHEAD_POINTS := 2
const BASE_PACE := 0.84
const MIN_PACE := 0.64
const MAX_PACE := 0.94
const MAX_LAP_PACE_ADJUSTMENT := 0.04
const TURN_BRAKE_ANGLE := 0.68
const OFF_ROUTE_DISTANCE := 24.0
const LANE_CLEARANCE_DIST := 14.0
const MAX_LATERAL_OFFSET := 3.6

var _car: RallyCar
var _route := PackedVector3Array()
var _route_distances := PackedFloat32Array()
var _recovery := RaceRecoveryMonitor.new()
var _last_route_index := 0
var _last_valid_route_index := 0
var _lap_elapsed := 0.0
var _previous_lap_seconds := 0.0
var _pace_adjustment := 0.0
var _slot_pace_offset := 0.0
var _slot_lane_offset := 0.0
var _avoid_lane_offset := 0.0
var _cached_nearest_index := -1
var _cached_nearest_pos := Vector3(INF, INF, INF)
var _sibling_cars: Array[RallyCar] = []
var _sibling_parent_children := -1
var current_lap := 1


func configure(car: RallyCar, route: PackedVector3Array, slot_index: int = 0) -> bool:
	if car == null or route.size() < 4:
		return false
	_car = car
	_route = route
	_route_distances = _build_route_distances(route)
	_recovery.reset(0.0)
	_cached_nearest_index = -1
	_cached_nearest_pos = Vector3(INF, INF, INF)
	_sibling_cars.clear()
	_sibling_parent_children = -1
	var start_pos := _get_car_position()
	var start_nearest := _find_nearest_route_point(start_pos)
	_last_route_index = int(start_nearest.index)
	_cached_nearest_index = _last_route_index
	_cached_nearest_pos = start_pos
	_last_valid_route_index = _last_route_index
	if slot_index > 0:
		# Non-monotonic competitive pace and lateral lane spread so faster mid/back-pack AI overtake cleanly
		const SLOT_OFFSETS := [0.0, -0.04, 0.02, -0.02, 0.05, -0.05, 0.08, 0.04]
		const SLOT_LANES := [0.0, -2.6, 2.2, -1.2, 2.8, -2.8, 1.0, -0.5]
		var idx := clampi(slot_index, 1, SLOT_OFFSETS.size() - 1)
		_slot_pace_offset = float(SLOT_OFFSETS[idx])
		_slot_lane_offset = float(SLOT_LANES[idx])
	return true


func _physics_process(delta: float) -> void:
	if _car == null or _route.is_empty():
		return
	var car_pos := _get_car_position()
	var car_tf := _get_car_transform()
	var nearest := _find_nearest_route_point(car_pos)
	_cached_nearest_index = int(nearest.index)
	_cached_nearest_pos = car_pos
	var fwd := -car_tf.basis.z
	var lane_info := _compute_pack_avoidance(delta, car_pos, fwd)
	var control := compute_control(
		_route,
		nearest.index,
		car_pos,
		fwd,
		_pace_adjustment + _slot_pace_offset,
		float(lane_info.lane_offset)
	)
	var pace := float(control.pace_multiplier) * float(lane_info.pace_scale)
	_car.set_ai_input(control.steering, control.braking, pace)
	_lap_elapsed += delta
	_update_lap_adaptation(nearest.index)
	var upside_down := car_tf.basis.y.dot(Vector3.UP) < 0.25
	var speed: float = _car.get_drive_state().speed
	if _recovery.update(delta, _route_distances[nearest.index], speed, upside_down, nearest.distance > OFF_ROUTE_DISTANCE):
		_reset_to_last_valid_route_point()
	elif nearest.distance <= OFF_ROUTE_DISTANCE:
		_last_valid_route_index = nearest.index


static func compute_control(route: PackedVector3Array, nearest_index: int, car_position: Vector3, car_forward: Vector3, pace_adjustment: float = 0.0, lateral_offset: float = 0.0) -> Dictionary:
	var n := route.size()
	var look_ahead := LOOK_AHEAD_POINTS if n < 32 else clampi(int(n / 36), 3, 6)
	var target_index := (nearest_index + look_ahead) % n
	var target_pos := route[target_index]
	if absf(lateral_offset) > 0.01 and n >= 3:
		var seg_fwd := route[(target_index + 1) % n] - route[(target_index - 1 + n) % n]
		seg_fwd.y = 0.0
		if seg_fwd.length_squared() > 0.001:
			seg_fwd = seg_fwd.normalized()
			var seg_right := Vector3(-seg_fwd.z, 0.0, seg_fwd.x)
			target_pos += seg_right * lateral_offset
	var target_direction := target_pos - car_position
	target_direction.y = 0.0
	var steering := 0.0
	if target_direction.length_squared() > 0.001:
		steering = clampf(-car_forward.signed_angle_to(target_direction.normalized(), Vector3.UP) / 0.65, -1.0, 1.0)
	var curvature := _curvature_at(route, target_index)
	var braking := curvature >= TURN_BRAKE_ANGLE
	var pace := clampf(BASE_PACE + pace_adjustment - curvature * 0.28, MIN_PACE, MAX_PACE)
	return {"steering": steering, "braking": braking, "pace_multiplier": pace, "curvature": curvature}


func _update_lap_adaptation(route_index: int) -> void:
	if _last_route_index > _route.size() - 3 and route_index <= 1 and _lap_elapsed >= 8.0:
		current_lap += 1
		if _previous_lap_seconds > 0.0:
			var adjustment := -0.015 if _lap_elapsed > _previous_lap_seconds else 0.01
			_pace_adjustment = clampf(_pace_adjustment + adjustment, -MAX_LAP_PACE_ADJUSTMENT, MAX_LAP_PACE_ADJUSTMENT)
		_previous_lap_seconds = _lap_elapsed
		_lap_elapsed = 0.0
	_last_route_index = route_index


func get_route_progress() -> float:
	if _route_distances.is_empty() or _car == null:
		return 0.0
	var track_len := _route_distances[_route_distances.size() - 1]
	var car_pos := _get_car_position()
	var idx: int
	if _cached_nearest_index >= 0 and _cached_nearest_index < _route_distances.size() and car_pos.distance_squared_to(_cached_nearest_pos) < 0.001:
		idx = _cached_nearest_index
	else:
		idx = int(_find_nearest_route_point(car_pos).index)
		_cached_nearest_index = idx
		_cached_nearest_pos = car_pos
	# If still in the starting grid zone behind the start/finish line on lap 1, report negative pre-start offset
	if current_lap == 1 and _lap_elapsed < 5.0 and idx > _route.size() - 12:
		return _route_distances[idx] - track_len
	return float(current_lap - 1) * track_len + _route_distances[idx]


func reset_after_teleport(route_index: int) -> void:
	if _route_distances.is_empty():
		return
	var clamped_idx := clampi(route_index, 0, _route_distances.size() - 1)
	_last_valid_route_index = clamped_idx
	_cached_nearest_index = clamped_idx
	_cached_nearest_pos = _get_car_position()
	_last_route_index = clamped_idx
	_recovery.reset(_route_distances[clamped_idx])


func _reset_to_last_valid_route_point() -> void:
	var point := _route[_last_valid_route_index]
	var tangent := _route[(_last_valid_route_index + 1) % _route.size()] - _route[(_last_valid_route_index - 1 + _route.size()) % _route.size()]
	tangent.y = 0.0
	var new_pos := point + Vector3.UP * 0.25
	if _car.is_inside_tree():
		_car.global_position = new_pos
	else:
		_car.position = new_pos
	_car.rotation.y = atan2(-tangent.x, -tangent.z)
	_car.velocity = Vector3.ZERO
	_car.reset_drive_speed()
	_recovery.reset(_route_distances[_last_valid_route_index])


func _get_car_position() -> Vector3:
	if _car == null:
		return Vector3.ZERO
	return _car.global_position if _car.is_inside_tree() else _car.position


func _get_car_transform() -> Transform3D:
	if _car == null:
		return Transform3D()
	return _car.global_transform if _car.is_inside_tree() else _car.transform


func _find_nearest_route_point(position: Vector3) -> Dictionary:
	var n := _route.size()
	if n == 0:
		return {"index": 0, "distance": INF}
	var nearest_index := 0
	var nearest_sq := INF
	if _cached_nearest_index >= 0 and n > 48:
		var start := _cached_nearest_index
		for offset in range(-10, 11):
			var idx := (start + offset + n) % n
			var pt := _route[idx]
			var dx := position.x - pt.x
			var dz := position.z - pt.z
			var d2 := dx * dx + dz * dz
			if d2 < nearest_sq:
				nearest_sq = d2
				nearest_index = idx
		if nearest_sq <= OFF_ROUTE_DISTANCE * OFF_ROUTE_DISTANCE:
			return {"index": nearest_index, "distance": sqrt(nearest_sq)}
	for index in n:
		var pt := _route[index]
		var dx := position.x - pt.x
		var dz := position.z - pt.z
		var d2 := dx * dx + dz * dz
		if d2 < nearest_sq:
			nearest_sq = d2
			nearest_index = index
	return {"index": nearest_index, "distance": sqrt(nearest_sq)}


func _compute_pack_avoidance(delta: float, car_pos: Vector3, car_forward: Vector3) -> Dictionary:
	var target_avoid := 0.0
	var pace_scale := 1.0
	var parent := get_parent()
	if parent != null:
		var child_count := parent.get_child_count()
		if child_count != _sibling_parent_children:
			_sibling_parent_children = child_count
			_sibling_cars.clear()
			for sibling in parent.get_children():
				if sibling is RallyCar and sibling != _car:
					_sibling_cars.append(sibling as RallyCar)
		var flat_fwd := Vector3(car_forward.x, 0.0, car_forward.z)
		if flat_fwd.length_squared() > 0.001:
			flat_fwd = flat_fwd.normalized()
			var flat_right := Vector3(-flat_fwd.z, 0.0, flat_fwd.x)
			var closest_dist := INF
			var blocker_lat := 0.0
			for other in _sibling_cars:
				if not is_instance_valid(other):
					continue
				var delta_pos := other.global_position - car_pos
				delta_pos.y = 0.0
				var fwd_proj := delta_pos.dot(flat_fwd)
				var lat_proj := delta_pos.dot(flat_right)
				if fwd_proj > -1.0 and fwd_proj < LANE_CLEARANCE_DIST and absf(lat_proj) < 3.2:
					if fwd_proj < closest_dist:
						closest_dist = fwd_proj
						blocker_lat = lat_proj
			if closest_dist < INF:
				var dodge_dir := -1.0 if blocker_lat >= 0.0 else 1.0
				if absf(_slot_lane_offset) > 0.5 and absf(blocker_lat) < 0.8:
					dodge_dir = signf(_slot_lane_offset)
				target_avoid = dodge_dir * 3.0
				if closest_dist > 0.0 and closest_dist < 5.5 and absf(blocker_lat) < 1.9:
					pace_scale = 0.85
	_avoid_lane_offset = move_toward(_avoid_lane_offset, target_avoid, 7.5 * delta)
	var total_lane := clampf(_slot_lane_offset + _avoid_lane_offset, -MAX_LATERAL_OFFSET, MAX_LATERAL_OFFSET)
	return {"lane_offset": total_lane, "pace_scale": pace_scale}


func _build_route_distances(route: PackedVector3Array) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	var total := 0.0
	for index in route.size():
		distances.append(total)
		total += route[index].distance_to(route[(index + 1) % route.size()])
	return distances


static func _curvature_at(route: PackedVector3Array, index: int) -> float:
	var stride := 1 if route.size() < 32 else clampi(int(route.size() / 60), 2, 4)
	var previous := route[(index - stride + route.size()) % route.size()]
	var current := route[index]
	var following := route[(index + stride) % route.size()]
	var incoming := current - previous
	incoming.y = 0.0
	var outgoing := following - current
	outgoing.y = 0.0
	if incoming.length_squared() < 0.0001 or outgoing.length_squared() < 0.0001:
		return 0.0
	return acos(clampf(incoming.normalized().dot(outgoing.normalized()), -1.0, 1.0))
