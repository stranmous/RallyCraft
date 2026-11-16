extends Camera3D
class_name RallyChaseCamera

@export var target: Node3D
@export var follow_distance := 6.0
@export var follow_height := 4.15
@export var follow_smoothing := 9.5
@export var base_fov := 48.0
@export var look_ahead_distance := 2.6
@export var look_height := 0.52
@export var brake_distance_pull := 1.25
@export var drift_distance_pull := 1.75
@export var drift_height_drop := 0.78
@export var drift_fov_drop := 3.5
@export var boost_fov_add := 9.5
@export var boost_distance_push := 0.90

var _orbit_yaw := 0.0
var _look_yaw := 0.0
var _orbit_initialized := false
var _close_in_blend := 0.0
var _drift_blend := 0.0
var _boost_blend := 0.0
var _lateral_shift := 0.0
var _current_dist := 6.0
var _current_height := 4.15
var _smoothed_y := 0.0
var _prev_target_pos := Vector3.ZERO


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority = 100
	fov = base_fov
	far = 520.0
	_current_dist = follow_distance
	_current_height = follow_height
	if target != null:
		snap_to_target()


func _process(delta: float) -> void:
	if target == null:
		return
	if not _orbit_initialized:
		snap_to_target()
		return

	var target_tf: Transform3D = target.get_global_transform_interpolated() if target.is_inside_tree() else target.global_transform
	var target_pos: Vector3 = target_tf.origin
	if target_pos.distance_to(_prev_target_pos) > 6.0:
		snap_to_target()
		return
	_prev_target_pos = target_pos
	var target_yaw: float = target_tf.basis.get_euler().y

	var steering := 0.0
	var braking := false
	var drifting := false
	var speed := 0.0
	var boost_remaining := 0.0
	if target is RallyCar:
		var rc := target as RallyCar
		var dyn := rc.get_camera_dynamics()
		steering = float(dyn.get("steering", 0.0))
		braking = bool(dyn.get("braking", false))
		drifting = bool(dyn.get("drifting", false))
		speed = float(dyn.get("speed", 0.0))
		boost_remaining = float(dyn.get("boost_remaining", 0.0))

	var want_brake := 1.0 if (braking and speed > 3.5) else 0.0
	var want_drift := 1.0 if (drifting or (braking and absf(steering) > 0.1 and speed > 7.5)) else 0.0
	var want_boost := 1.0 if boost_remaining > 0.01 else 0.0

	var blend_w := 1.0 - exp(-7.5 * delta)
	_close_in_blend = lerpf(_close_in_blend, want_brake, blend_w)
	_drift_blend = lerpf(_drift_blend, want_drift, blend_w)
	_boost_blend = lerpf(_boost_blend, want_boost, 1.0 - exp(-9.5 * delta))

	var target_lat := (-steering * 0.72 * _drift_blend) if absf(steering) > 0.05 else 0.0
	_lateral_shift = lerpf(_lateral_shift, target_lat, 1.0 - exp(-6.5 * delta))

	var yaw_rate := 6.4 if _drift_blend > 0.2 else 11.0
	_orbit_yaw = lerp_angle(_orbit_yaw, target_yaw, 1.0 - exp(-yaw_rate * delta))
	_look_yaw = lerp_angle(_look_yaw, target_yaw, 1.0 - exp(-18.0 * delta))

	var orbit_basis := Basis(Vector3.UP, _orbit_yaw)
	var orbit_forward := -orbit_basis.z
	var orbit_right := orbit_basis.x
	var look_basis := Basis(Vector3.UP, _look_yaw)

	var desired_dist := follow_distance - maxf(_close_in_blend * brake_distance_pull, _drift_blend * drift_distance_pull) + _boost_blend * boost_distance_push
	var desired_height := follow_height - maxf(_close_in_blend * 0.48, _drift_blend * drift_height_drop)
	var desired_fov := base_fov - maxf(_close_in_blend * 2.2, _drift_blend * drift_fov_drop) + _boost_blend * boost_fov_add

	var cam_w := 1.0 - exp(-follow_smoothing * delta)
	_current_dist = lerpf(_current_dist, desired_dist, cam_w)
	_current_height = lerpf(_current_height, desired_height, cam_w)
	_smoothed_y = target_pos.y
	fov = lerpf(fov, desired_fov, 1.0 - exp(-9.0 * delta))

	var anchor_pos := Vector3(target_pos.x, _smoothed_y, target_pos.z)
	global_position = anchor_pos - orbit_forward * _current_dist + orbit_right * _lateral_shift + Vector3.UP * _current_height

	var look_fwd := (-look_basis.z).lerp(orbit_forward, 0.35).normalized()
	look_at(anchor_pos + look_fwd * look_ahead_distance + Vector3.UP * look_height, Vector3.UP)


func snap_to_target() -> void:
	if target == null:
		return
	var target_tf: Transform3D = target.get_global_transform_interpolated() if target.is_inside_tree() else target.global_transform
	_orbit_yaw = target_tf.basis.get_euler().y
	_look_yaw = _orbit_yaw
	_orbit_initialized = true
	_close_in_blend = 0.0
	_drift_blend = 0.0
	_boost_blend = 0.0
	_lateral_shift = 0.0
	_current_dist = follow_distance
	_current_height = follow_height
	_smoothed_y = target_tf.origin.y
	_prev_target_pos = target_tf.origin
	fov = base_fov
	var forward := -target_tf.basis.z
	global_position = target_tf.origin - forward * follow_distance + Vector3.UP * follow_height
	look_at(target_tf.origin + forward * look_ahead_distance + Vector3.UP * look_height, Vector3.UP)
