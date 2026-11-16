extends CharacterBody3D
class_name RallyCar

const STEER_RATE := 1.85
const DRIFT_STEER_MULTIPLIER := 1.48
const GRAVITY := 28.0
const CONTACT_SEPARATION_SPEED := 6.0
const CONTACT_SPEED_LOSS := 0.88
const CONTACT_COOLDOWN_SECONDS := 0.55

var _drive := RallyDriveModel.new()
var _touch_left := false
var _touch_right := false
var _touch_brake := false
var _touch_boost_requested := false
var _drive_enabled := true
var _ai_enabled := false
var _ai_steering := 0.0
var _ai_braking := false
var _ai_pace_multiplier := 1.0
var _actual_speed := 0.0
var _signed_actual_speed := 0.0
var _physics_stepped := false
var _contact_push := Vector3.ZERO
var _contact_cooldown := 0.0
var _current_steering := 0.0
var _visual_slip_yaw := 0.0
static var _shared_shadow_mesh: PlaneMesh = null
static var _shared_shadow_mat: StandardMaterial3D = null

var _car_visual: Node3D = null
var _visual_roll := 0.0
var _visual_pitch := 0.0
var _is_drifting_visual := false
var _move_dir := Vector3.FORWARD
var _has_move_dir := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	platform_floor_layers = 1
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	floor_snap_length = 0.50
	floor_max_angle = deg_to_rad(42.0)
	floor_constant_speed = true
	floor_stop_on_slope = false
	_ensure_contact_shadow()


func _physics_process(delta: float) -> void:
	if not _drive_enabled:
		velocity = Vector3.ZERO
		_actual_speed = 0.0
		_signed_actual_speed = 0.0
		_current_steering = 0.0
		_is_drifting_visual = false
		_has_move_dir = false
		_update_car_visual_attitude(delta, false, false, 0.0)
		return
	var steering := _ai_steering if _ai_enabled else _get_steering_input()
	_current_steering = steering
	var braking := _ai_braking if _ai_enabled else _touch_brake or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)
	var boost_requested := false if _ai_enabled else _touch_boost_requested or Input.is_key_pressed(KEY_F)
	_touch_boost_requested = false
	var is_steering := not _ai_enabled and absf(steering) > 0.05
	var drive_state := _drive.step(delta, braking, boost_requested, _ai_pace_multiplier if _ai_enabled else 1.0, not _ai_enabled, is_steering)
	var abs_speed := absf(drive_state.speed)
	var is_drifting: bool = not _ai_enabled and braking and is_steering and float(drive_state.speed) > 7.5
	if abs_speed > 0.25:
		var steer_sign := -1.0 if drive_state.speed < 0.0 else 1.0
		var turn_rate := STEER_RATE * (DRIFT_STEER_MULTIPLIER if is_drifting else 1.0)
		var speed_factor := clampf(abs_speed / RallyDriveModel.CRUISE_SPEED, 0.35, 1.25)
		rotation.y -= steering * steer_sign * turn_rate * delta * speed_factor

	_update_car_visual_attitude(delta, braking, _drive.boost_remaining > 0.01, drive_state.speed)

	var forward := -global_transform.basis.z
	var flat_fwd := Vector3(forward.x, 0.0, forward.z).normalized()
	if flat_fwd.length_squared() < 0.001:
		flat_fwd = Vector3.FORWARD
	if not _has_move_dir or drive_state.speed <= 1.0:
		_move_dir = flat_fwd
		_has_move_dir = true
	else:
		var grip_rate := 5.2 if _is_drifting_visual else 16.5
		_move_dir = _move_dir.slerp(flat_fwd, 1.0 - exp(-grip_rate * delta)).normalized()
	var travel_dir := _move_dir if drive_state.speed > 0.5 else flat_fwd
	velocity.x = travel_dir.x * drive_state.speed + _contact_push.x
	velocity.z = travel_dir.z * drive_state.speed + _contact_push.z
	_contact_push = _contact_push.move_toward(Vector3.ZERO, 16.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.5
	move_and_slide()
	var horizontal_vel := Vector2(velocity.x, velocity.z)
	var forward_2d := Vector2(forward.x, forward.z).normalized()
	_signed_actual_speed = horizontal_vel.dot(forward_2d)
	_actual_speed = horizontal_vel.length()
	if _actual_speed < 0.08 and absf(_drive.speed) < 0.08:
		_actual_speed = 0.0
		_signed_actual_speed = 0.0
	_physics_stepped = true
	if _contact_cooldown > 0.0:
		_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	var car_hit := _apply_soft_contacts()
	if not car_hit and _contact_cooldown <= 0.0 and _actual_speed < absf(_drive.speed) * 0.45:
		var clamped_target := maxf(0.0, _signed_actual_speed) if _drive.speed >= 0.0 else _signed_actual_speed
		_drive.speed = move_toward(_drive.speed, clamped_target, 28.0 * delta)


func set_touch_input(left_pressed: bool, right_pressed: bool, brake_pressed: bool) -> void:
	_touch_left = left_pressed
	_touch_right = right_pressed
	_touch_brake = brake_pressed


func request_touch_boost() -> void:
	_touch_boost_requested = true


func refill_boost() -> bool:
	var was_charged := _drive.boost_charged
	_drive.refill_boost()
	return not was_charged


func get_drive_state() -> Dictionary:
	var is_braking := _ai_braking if _ai_enabled else (_touch_brake or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT))
	var use_physics := is_inside_tree() and _physics_stepped
	var reported_speed := _actual_speed if use_physics else absf(_drive.speed)
	var signed_speed := _signed_actual_speed if use_physics else _drive.speed
	if use_physics and _contact_cooldown > 0.0 and not is_braking and absf(_drive.speed) > 1.0:
		var floor_speed := absf(_drive.speed) * 0.72
		if reported_speed < floor_speed:
			reported_speed = floor_speed
			signed_speed = signf(_drive.speed) * floor_speed
	return {
		"speed": reported_speed,
		"signed_speed": signed_speed,
		"reversing": _drive.reversing or (is_braking and signed_speed < -0.25),
		"target_speed": _drive.speed,
		"boost_charged": _drive.boost_charged,
		"boost_remaining": _drive.boost_remaining,
		"braking": is_braking,
	}


func get_camera_dynamics() -> Dictionary:
	var is_braking := _ai_braking if _ai_enabled else (_touch_brake or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT))
	return {
		"steering": _current_steering,
		"drifting": _is_drifting_visual,
		"braking": is_braking,
		"slip_yaw": _visual_slip_yaw,
		"speed": _actual_speed,
		"boost_remaining": _drive.boost_remaining,
	}


func reset_drive_speed() -> void:
	_drive.reset()
	_actual_speed = 0.0
	_signed_actual_speed = 0.0
	_physics_stepped = false
	_contact_push = Vector3.ZERO
	_current_steering = 0.0
	_visual_slip_yaw = 0.0
	_visual_roll = 0.0
	_visual_pitch = 0.0
	_is_drifting_visual = false
	_has_move_dir = false
	var car_visual := get_node_or_null("CarVisual") as Node3D
	if car_visual != null:
		car_visual.rotation = Vector3.ZERO
		car_visual.reset_physics_interpolation()
	_drive_enabled = true


func set_drive_enabled(enabled: bool) -> void:
	_drive_enabled = enabled
	if not enabled:
		_actual_speed = 0.0


func set_ai_input(steering: float, braking: bool, pace_multiplier: float) -> void:
	_ai_enabled = true
	_ai_steering = clampf(steering, -1.0, 1.0)
	_ai_braking = braking
	_ai_pace_multiplier = clampf(pace_multiplier, 0.35, 1.05)


func clear_ai_input() -> void:
	_ai_enabled = false


func _compute_contact_push(out_normal: Vector3, car_basis: Basis) -> Vector3:
	# Deflect inline/corner contacts laterally across the overlap cone so cars glide past cleanly.
	var right := car_basis.x
	right.y = 0.0
	if right.length_squared() > 0.001:
		right = right.normalized()
		var dot_right := out_normal.dot(right)
		if absf(dot_right) < 0.85:
			var side := 1.0 if dot_right >= -0.02 else -1.0
			return (right * (side * 1.25) + out_normal * 0.2).normalized() * (CONTACT_SEPARATION_SPEED * 2.1)
	return out_normal * CONTACT_SEPARATION_SPEED


func _apply_soft_contacts() -> bool:
	var hit_obstacle := false
	var has_wall_hit := false
	var best_wall_n := Vector3.ZERO
	var best_wall_score := -INF
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var other: Variant = collision.get_collider()
		if other is RallyCar:
			hit_obstacle = true
			var other_car: RallyCar = other
			var separation: Vector3 = global_position - other_car.global_position
			separation.y = 0.0
			if separation.length_squared() <= 0.001:
				continue
			var normal: Vector3 = separation.normalized()
			var fresh_contact := _contact_cooldown <= 0.0
			_contact_push = _compute_contact_push(normal, global_transform.basis)
			if fresh_contact:
				_drive.speed *= CONTACT_SPEED_LOSS
				_contact_cooldown = CONTACT_COOLDOWN_SECONDS
			if other_car._drive_enabled and other_car._contact_cooldown <= 0.0:
				other_car._contact_push = _compute_contact_push(-normal, other_car.global_transform.basis)
				other_car._drive.speed *= CONTACT_SPEED_LOSS
				other_car._contact_cooldown = CONTACT_COOLDOWN_SECONDS
		elif other is Node and (other.name == "RoadCollision" or other.name == "PreviewGround"):
			continue
		else:
			var col_n := collision.get_normal()
			if absf(col_n.y) < 0.45 and absf(_drive.speed) > 3.0:
				hit_obstacle = true
				var wall_n := Vector3(col_n.x, 0.0, col_n.z)
				var col_shape_obj := collision.get_collider_shape() as Node3D
				if col_shape_obj != null and (
					col_shape_obj.name.contains("guardrail_double")
					or col_shape_obj.name.contains("barrier_wall")
					or col_shape_obj.name.contains("wood_fence")
				):
					var lat_n := col_shape_obj.global_transform.basis.z
					lat_n.y = 0.0
					if lat_n.length_squared() > 0.001:
						if lat_n.dot(global_position - col_shape_obj.global_transform.origin) < 0.0:
							lat_n = -lat_n
						wall_n = lat_n
				if wall_n.length_squared() > 0.001:
					wall_n = wall_n.normalized()
					var score := -_move_dir.dot(wall_n)
					if not has_wall_hit or score > best_wall_score:
						best_wall_score = score
						best_wall_n = wall_n
						has_wall_hit = true
	if has_wall_hit:
		var fwd := -global_transform.basis.z
		fwd.y = 0.0
		var fwd_n := fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
		var head_on := maxf(0.0, -fwd_n.dot(best_wall_n))
		var wall_tangent := Vector3(-best_wall_n.z, 0.0, best_wall_n.x)
		if wall_tangent.dot(fwd_n) < 0.0:
			wall_tangent = -wall_tangent
		var slide_dir := _move_dir - best_wall_n * minf(0.0, _move_dir.dot(best_wall_n))
		if slide_dir.length_squared() <= 0.001:
			slide_dir = wall_tangent
		else:
			slide_dir = slide_dir.normalized()
			if _drive.speed > 0.0 and slide_dir.dot(fwd_n) < 0.25:
				slide_dir = wall_tangent
		_move_dir = slide_dir
		if head_on > 0.05:
			_contact_push = best_wall_n * maxf(1.8, 3.4 * head_on) + wall_tangent * (1.6 * head_on)
		if _drive.speed > 2.5:
			var wall_yaw := atan2(-wall_tangent.x, -wall_tangent.z)
			rotation.y = lerp_angle(rotation.y, wall_yaw, clampf(0.15 + head_on * 0.22, 0.15, 0.35))
		if _contact_cooldown <= 0.0 and head_on > 0.12:
			if _drive.speed > 0.0:
				var impact_retain := clampf(1.0 - head_on * 0.62, 0.36, 0.92)
				_drive.speed = maxf(8.0, _drive.speed * impact_retain)
			_contact_cooldown = CONTACT_COOLDOWN_SECONDS
	return hit_obstacle


func _ensure_contact_shadow() -> void:
	if get_node_or_null("ContactShadow") != null:
		return
	if _shared_shadow_mesh == null or _shared_shadow_mat == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for py in 64:
			var ny := (float(py) + 0.5) / 64.0 * 2.0 - 1.0
			for px in 64:
				var nx := (float(px) + 0.5) / 64.0 * 2.0 - 1.0
				var dist := sqrt(nx * nx + ny * ny)
				var falloff := clampf(1.0 - dist, 0.0, 1.0)
				var alpha := pow(falloff, 1.55) * 0.44
				img.set_pixel(px, py, Color(0.02, 0.03, 0.04, alpha))
		var shadow_tex := ImageTexture.create_from_image(img)
		var shadow_mat := StandardMaterial3D.new()
		shadow_mat.albedo_texture = shadow_tex
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_shadow_mat = shadow_mat
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.05, 3.65)
		_shared_shadow_mesh = plane
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = _shared_shadow_mesh
	shadow.material_override = _shared_shadow_mat
	shadow.position = Vector3(0.0, 0.038, 0.0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)


func _update_car_visual_attitude(delta: float, braking: bool, boosting: bool, drive_speed: float) -> void:
	var abs_speed := absf(drive_speed)
	var drifting_now := braking and drive_speed > 7.5 and absf(_current_steering) > 0.05
	_is_drifting_visual = drifting_now
	var target_slip := 0.0
	if drifting_now:
		target_slip = -_current_steering * deg_to_rad(23.0) * clampf(abs_speed / RallyDriveModel.CRUISE_SPEED, 0.5, 1.15)
	elif absf(_current_steering) > 0.05 and drive_speed > 3.0:
		target_slip = -_current_steering * deg_to_rad(5.0) * clampf(abs_speed / RallyDriveModel.CRUISE_SPEED, 0.3, 1.0)
	var target_roll := _current_steering * deg_to_rad(4.2 if drifting_now else 2.6) * clampf(abs_speed / RallyDriveModel.CRUISE_SPEED, 0.0, 1.1)
	var target_pitch := 0.0
	if braking and drive_speed > 2.5:
		target_pitch = deg_to_rad(-2.2)
	elif boosting:
		target_pitch = deg_to_rad(1.8)
	var weight := 1.0 - exp(-10.0 * delta)
	_visual_slip_yaw = lerpf(_visual_slip_yaw, target_slip, weight)
	_visual_roll = lerpf(_visual_roll, target_roll, weight)
	_visual_pitch = lerpf(_visual_pitch, target_pitch, weight)
	if _car_visual == null:
		_car_visual = get_node_or_null("CarVisual") as Node3D
	if _car_visual != null:
		_car_visual.rotation = Vector3(_visual_pitch, _visual_slip_yaw, _visual_roll)


func _get_steering_input() -> float:
	var left := _touch_left or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right := _touch_right or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	return float(int(right) - int(left))
