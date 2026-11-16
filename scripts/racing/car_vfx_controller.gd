extends Node3D
class_name CarVfxController

## Lightweight mobile-budget particle VFX for rally cars (dust, boost flare, impact sparks).

var _car: RallyCar
var _surface := "asphalt"
var _is_player := true
var _dust_color := Color("d4dce3")

var _dust_emitter: CPUParticles3D
var _boost_emitter: CPUParticles3D
var _spark_emitter: CPUParticles3D
var _skid_mesh_instance: MeshInstance3D
var _skid_mesh: ImmediateMesh
var _skid_segments: Array[Dictionary] = []
var _has_prev_skid_pos := false
var _prev_left_wheel := Vector3.ZERO
var _prev_right_wheel := Vector3.ZERO
var _prev_car_pos := Vector3.ZERO

var _prev_contact_cooldown := 0.0


func configure(car: RallyCar, surface_name: String, theme_name: String, is_player: bool = true) -> void:
	_car = car
	_surface = surface_name
	_is_player = is_player
	_dust_color = BiomePresets.get_dust_color(theme_name, surface_name)
	_prev_contact_cooldown = 0.0
	_build_emitters()


func get_vfx_textures_used() -> Array[String]:
	var keys: Array[String] = []
	if _dust_emitter != null:
		keys.append("dust_puff")
	if _boost_emitter != null:
		keys.append("boost_flare")
	if _spark_emitter != null:
		keys.append("spark_hit")
	return keys


func _build_emitters() -> void:
	for child in get_children():
		child.queue_free()
	_dust_emitter = null
	_boost_emitter = null
	_spark_emitter = null
	_skid_mesh_instance = null
	_skid_mesh = null
	_skid_segments.clear()
	_has_prev_skid_pos = false

	if _is_player:
		var dust_grad := Gradient.new()
		dust_grad.colors = PackedColorArray([
			Color(_dust_color.r, _dust_color.g, _dust_color.b, 0.60),
			Color(_dust_color.r, _dust_color.g, _dust_color.b, 0.0),
		])
		_dust_emitter = _create_emitter(
			"DustEmitter",
			AssetRegistry.load_vfx_texture("dust_puff"),
			Vector2(1.05, 1.05),
			22,
			0.55,
			false,
			false,
			BaseMaterial3D.BLEND_MODE_MIX,
			dust_grad
		)
		_dust_emitter.position = Vector3(0.0, 0.22, 1.45)
		_dust_emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_dust_emitter.emission_box_extents = Vector3(0.72, 0.08, 0.24)
		_dust_emitter.direction = Vector3(0.0, 0.35, 1.0)
		_dust_emitter.spread = 30.0
		_dust_emitter.gravity = Vector3(0.0, 1.2, 0.0)
		_dust_emitter.initial_velocity_min = 1.6
		_dust_emitter.initial_velocity_max = 3.8
		_dust_emitter.scale_amount_min = 0.90
		_dust_emitter.scale_amount_max = 2.20

		_skid_mesh = ImmediateMesh.new()
		var skid_mat := StandardMaterial3D.new()
		skid_mat.albedo_color = Color(0.08, 0.08, 0.09, 0.62)
		skid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		skid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		skid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_skid_mesh_instance = MeshInstance3D.new()
		_skid_mesh_instance.name = "SkidTrailMesh"
		_skid_mesh_instance.mesh = _skid_mesh
		_skid_mesh_instance.material_override = skid_mat
		_skid_mesh_instance.top_level = true
		_skid_mesh_instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_skid_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_skid_mesh_instance)

	if _is_player:
		var boost_grad := Gradient.new()
		boost_grad.colors = PackedColorArray([
			Color("ffffff"),
			Color("38bdf8ee"),
			Color("0284c700"),
		])
		boost_grad.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
		_boost_emitter = _create_emitter(
			"BoostEmitter",
			AssetRegistry.load_vfx_texture("boost_flare"),
			Vector2(1.05, 1.05),
			10,
			0.24,
			true,
			false,
			BaseMaterial3D.BLEND_MODE_ADD,
			boost_grad
		)
		_boost_emitter.position = Vector3(0.0, 0.42, 1.98)
		_boost_emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_boost_emitter.emission_box_extents = Vector3(0.32, 0.10, 0.10)
		_boost_emitter.direction = Vector3(0.0, 0.08, 1.0)
		_boost_emitter.spread = 16.0
		_boost_emitter.gravity = Vector3.ZERO
		_boost_emitter.initial_velocity_min = 8.0
		_boost_emitter.initial_velocity_max = 12.5
		_boost_emitter.scale_amount_min = 0.75
		_boost_emitter.scale_amount_max = 1.35

	var spark_grad := Gradient.new()
	spark_grad.colors = PackedColorArray([
		Color("fff7cc"),
		Color("fb923cee"),
		Color("ea580c00"),
	])
	spark_grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	_spark_emitter = _create_emitter(
		"SparkEmitter",
		AssetRegistry.load_vfx_texture("spark_hit"),
		Vector2(0.95, 0.95),
		12 if _is_player else 6,
		0.30,
		false,
		true,
		BaseMaterial3D.BLEND_MODE_ADD,
		spark_grad
	)
	_spark_emitter.position = Vector3(0.0, 0.72, 0.0)
	_spark_emitter.explosiveness = 0.94
	_spark_emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_spark_emitter.emission_sphere_radius = 0.95
	_spark_emitter.direction = Vector3(0.0, 1.0, 0.0)
	_spark_emitter.spread = 115.0
	_spark_emitter.gravity = Vector3(0.0, -9.8, 0.0)
	_spark_emitter.initial_velocity_min = 5.5
	_spark_emitter.initial_velocity_max = 10.5
	_spark_emitter.angle_min = -180.0
	_spark_emitter.angle_max = 180.0


func _create_emitter(
	emitter_name: String,
	tex: Texture2D,
	quad_size: Vector2,
	particle_amount: int,
	particle_lifetime: float,
	use_local_coords: bool,
	is_one_shot: bool,
	blend_mode: BaseMaterial3D.BlendMode,
	gradient: Gradient
) -> CPUParticles3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = 1
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.blend_mode = blend_mode

	var quad := QuadMesh.new()
	quad.size = quad_size
	quad.material = mat

	var emitter := CPUParticles3D.new()
	emitter.name = emitter_name
	emitter.mesh = quad
	emitter.amount = particle_amount
	emitter.lifetime = particle_lifetime
	emitter.local_coords = use_local_coords
	emitter.one_shot = is_one_shot
	emitter.emitting = false
	emitter.color_ramp = gradient
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	return emitter


func _process(_delta: float) -> void:
	if _car == null or not is_instance_valid(_car) or not is_inside_tree() or not _car.is_inside_tree():
		return
	if not _is_player:
		if _spark_emitter != null:
			var cd_ai := _car._contact_cooldown
			if cd_ai > 0.1 and _prev_contact_cooldown <= 0.1:
				_spark_emitter.restart()
				_spark_emitter.emitting = true
			_prev_contact_cooldown = cd_ai
		return
	var ds := _car.get_drive_state()
	var dyn := _car.get_camera_dynamics()
	var speed := float(ds.get("speed", 0.0))
	var braking := bool(ds.get("braking", false))
	var boost_rem := float(ds.get("boost_remaining", 0.0))
	var slip_yaw := float(dyn.get("slip_yaw", 0.0))
	var grounded := _car.is_on_floor()

	if _dust_emitter != null:
		var kicking_dust := grounded and ((_surface == "dirt" and speed > 5.0) or (braking and speed > 6.5) or absf(slip_yaw) > 0.12)
		_dust_emitter.emitting = kicking_dust

	if _is_player and _skid_mesh != null:
		_update_skid_trail(grounded, speed, braking, slip_yaw)

	if _boost_emitter != null:
		_boost_emitter.emitting = boost_rem > 0.01

	if _spark_emitter != null:
		var cd := _car._contact_cooldown
		if cd > 0.1 and _prev_contact_cooldown <= 0.1:
			_spark_emitter.restart()
			_spark_emitter.emitting = true
		_prev_contact_cooldown = cd


func _update_skid_trail(grounded: bool, speed: float, braking: bool, slip_yaw: float) -> void:
	var car_pos := _car.global_position
	if _has_prev_skid_pos and car_pos.distance_to(_prev_car_pos) > 5.0:
		_skid_segments.clear()
		_has_prev_skid_pos = false
		_skid_mesh.clear_surfaces()
	_prev_car_pos = car_pos

	var skidding := (braking or absf(slip_yaw) > 0.12) and grounded and speed > 6.5
	if not skidding:
		_has_prev_skid_pos = false
		return

	var visual := _car.get_node_or_null("CarVisual") as Node3D
	var basis := visual.global_transform.basis if visual != null and visual.is_inside_tree() else _car.global_transform.basis
	var back := basis.z
	back.y = 0.0
	if back.length_squared() < 0.001:
		back = Vector3.BACK
	back = back.normalized()
	var right := basis.x
	right.y = 0.0
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()

	var rear_center := Vector3(car_pos.x, car_pos.y + 0.031, car_pos.z) + back * 1.15
	var left_w := rear_center - right * 0.62
	var right_w := rear_center + right * 0.62

	if not _has_prev_skid_pos:
		_prev_left_wheel = left_w
		_prev_right_wheel = right_w
		_has_prev_skid_pos = true
		return

	if _prev_left_wheel.distance_to(left_w) < 0.35:
		return

	_skid_segments.append({
		"l0": _prev_left_wheel,
		"l1": left_w,
		"r0": _prev_right_wheel,
		"r1": right_w,
		"side": right * 0.12,
	})
	if _skid_segments.size() > 72:
		_skid_segments.pop_front()
	_prev_left_wheel = left_w
	_prev_right_wheel = right_w
	_rebuild_skid_mesh()


func _rebuild_skid_mesh() -> void:
	_skid_mesh.clear_surfaces()
	if _skid_segments.is_empty():
		return
	_skid_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in _skid_segments:
		var side: Vector3 = seg.side
		for pair in [[seg.l0, seg.l1], [seg.r0, seg.r1]]:
			var p0: Vector3 = pair[0]
			var p1: Vector3 = pair[1]
			var v0 := p0 - side
			var v1 := p0 + side
			var v2 := p1 - side
			var v3 := p1 + side
			_skid_mesh.surface_set_normal(Vector3.UP)
			_skid_mesh.surface_add_vertex(v0)
			_skid_mesh.surface_add_vertex(v1)
			_skid_mesh.surface_add_vertex(v2)
			_skid_mesh.surface_add_vertex(v1)
			_skid_mesh.surface_add_vertex(v3)
			_skid_mesh.surface_add_vertex(v2)
	_skid_mesh.surface_end()
