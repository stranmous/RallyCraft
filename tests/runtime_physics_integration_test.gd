extends SceneTree

# Real-engine Jolt Physics integration test.
# Runs MainController and RacePreview inside the live SceneTree physics loop
# to verify that cars stand on the road collider, accelerate physically,
# pass checkpoints, recover when off-route while moving, and finish a race.

var _main: MainController
var _frame := 0
var _failed := false
var _start_player_pos := Vector3.ZERO
var _start_ai_pos := Vector3.ZERO
var _phase := 0
var _off_route_recovered := false


func _initialize() -> void:
	_main = MainController.new()
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_main._show_race_preview(RaceResult.MODE_CIRCUIT, 1, 3, _main._build_preview_track())
		if _main._preview_player_car != null:
			_start_player_pos = _main._preview_player_car.global_position
		if not _main._preview_ai_cars.is_empty():
			_start_ai_pos = _main._preview_ai_cars[0].global_position
		return false
	var player := _main._preview_player_car
	if player == null:
		_expect(false, "Preview player car should exist in race scene.")
		quit(1)
		return true

	# Phase 0 (frames 1..120): Let player and AI cars drive forward on real physics
	if _phase == 0:
		# Steer player along the road using AIDriver.compute_control so it follows the curve
		var rm: RaceManager = _main._race_root.get_node_or_null("RaceManager") if _main._race_root != null else null
		if rm == null:
			for child in _main._race_root.get_children():
				if child is RaceManager:
					rm = child
					break
		if rm != null:
			var nearest := rm._find_nearest_route_point(player.global_position)
			var ctrl := AIDriver.compute_control(rm._centerline, nearest.index, player.global_position, -player.global_transform.basis.z)
			var st: float = float(ctrl.steering)
			player.set_touch_input(st < -0.1, st > 0.1, false)

		if _frame == 90:
			var p_dist := player.global_position.distance_to(_start_player_pos)
			var ai_dist := _main._preview_ai_cars[0].global_position.distance_to(_start_ai_pos)
			var p_speed: float = player.get_drive_state().speed
			_expect(player.global_position.y >= -0.05, "Player car must stay on top of road collision (y=%.3f)." % player.global_position.y)
			_expect(player.is_on_floor(), "Player car must be supported by floor collision.")
			_expect(p_speed >= 15.0, "Player car must achieve real physical velocity >= 15 m/s (got %.1f m/s)." % p_speed)
			_expect(p_dist >= 22.0, "Player car must physically move >= 22m from start in 90 frames (moved %.1fm)." % p_dist)
			_expect(ai_dist >= 18.0, "AI car 0 must physically move >= 18m from start in 90 frames (moved %.1fm)." % ai_dist)
			for i in _main._preview_ai_cars.size():
				var ac := _main._preview_ai_cars[i]
				_expect(ac.global_position.y >= -0.05 and ac.is_on_floor(), "AI car %d must stay on floor (y=%.3f, on_floor=%s)." % [i, ac.global_position.y, ac.is_on_floor()])

			# Transition to Phase 1: test long-press brake to 0 and reverse in real 3D physics
			_phase = 1
			player.set_touch_input(false, false, true)

	elif _phase == 1:
		var rm := _find_race_manager()
		if rm != null:
			var nearest := rm._find_nearest_route_point(player.global_position)
			var ctrl := AIDriver.compute_control(rm._centerline, nearest.index, player.global_position, -player.global_transform.basis.z)
			var st: float = float(ctrl.steering)
			player.set_touch_input(st < -0.1, st > 0.1, true)
		else:
			player.set_touch_input(false, false, true)
		if _frame == 180:
			var ds := player.get_drive_state()
			_expect(bool(ds.get("reversing", false)), "Long-pressing brake in 3D physics must engage reverse.")
			_expect(float(ds.get("signed_speed", 0.0)) < -6.0, "Car must physically move backward when reversing (signed_speed=%.2f)." % float(ds.get("signed_speed", 0.0)))
			_phase = 2
			player.set_touch_input(false, false, false)
			if rm != null and not rm.car_recovered.is_connected(_on_player_recovered):
				rm.car_recovered.connect(_on_player_recovered)
			# Place player far outside the loop on the grass, still driving at full speed
			player.global_position = Vector3(-320.0, 0.25, -320.0)

	elif _phase == 2:
		# Wait up to 210 frames (~3.5s) for automatic off-route recovery to teleport the moving car back
		if _off_route_recovered:
			var rm := _find_race_manager()
			var nearest := rm._find_nearest_route_point(player.global_position)
			_expect(nearest.distance < 5.0, "Recovered player car must be back on the road centerline (dist=%.2fm)." % nearest.distance)
			_phase = 3
			# Complete the remaining checkpoints to verify full race completion & Result Modal
			for cp_idx in range(1, rm._checkpoints.size()):
				var cp: Dictionary = rm._checkpoints[cp_idx]
				player.global_position = cp.position + Vector3.UP * 0.25
				rm._check_expected_checkpoint()
			var start_cp: Dictionary = rm._checkpoints[0]
			player.global_position = start_cp.position + Vector3.UP * 0.25
			rm._check_expected_checkpoint()
			_expect(rm.get_status().finished, "Crossing all checkpoints and finish line must finish the race.")
			quit(1 if _failed else 0)
			return true
		elif _frame > 420:
			_expect(false, "Off-route moving car failed to recover within 3.5 seconds.")
			quit(1)
			return true

	return false


func _on_player_recovered(_cp_index: int) -> void:
	_off_route_recovered = true


func _find_race_manager() -> RaceManager:
	if _main._race_root == null:
		return null
	for child in _main._race_root.get_children():
		if child is RaceManager:
			return child
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
