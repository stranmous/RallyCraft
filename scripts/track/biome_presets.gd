extends RefCounted
class_name BiomePresets

const PRESET_ORDER: Array[String] = [
	"forest",
	"desert",
	"spa_forest",
	"alpine",
	"parkland",
	"open_grassland",
]

const CURB_WIDTH := 0.8
const MAX_CENTERLINE_SAMPLE := 320


static func normalize_theme(theme_name: String) -> String:
	var key := theme_name.strip_edges().to_lower()
	if PRESET_ORDER.has(key):
		return key
	return "forest"


static func get_preset(theme_name: String) -> Dictionary:
	var key := normalize_theme(theme_name)
	match key:
		"desert":
			return {
				"id": "desert",
				"display_name": "Desert",
				"sky_top": Color("3f86c9"),
				"sky_horizon": Color("e9c496"),
				"ground_bottom": Color("8d6d48"),
				"ground_horizon": Color("dfba87"),
				"ambient_color": Color("fae6c7"),
				"ambient_energy": 0.68,
				"sun_color": Color("fff1d4"),
				"sun_energy": 1.25,
				"sun_pitch_deg": -46.0,
				"sun_yaw_deg": -34.0,
				"fog_color": Color("dfba87"),
				"ground_texture": "ground_sand",
				"ground_albedo": Color("e4c692"),
				"road_asphalt_tint": Color("e0e4ea"),
				"road_dirt_tint": Color("f0d8ba"),
				"embankment_color": Color("9b7a52"),
				"bridge_color": Color("7d6b58"),
				"dust_color": Color("dec092"),
				"trees": [
					{"key": "palm_desert", "weight": 0.36, "scale_min": 0.90, "scale_max": 1.30},
					{"key": "cactus_saguaro", "weight": 0.34, "scale_min": 0.85, "scale_max": 1.28},
					{"key": "cactus_small", "weight": 0.30, "scale_min": 0.85, "scale_max": 1.35},
				],
				"scatter": [
					{"key": "rock_boulder", "weight": 0.50, "scale_min": 0.85, "scale_max": 1.65},
					{"key": "rock_cluster", "weight": 0.50, "scale_min": 0.90, "scale_max": 1.60},
				],
				"hills": [],
				"vista": [
					{"key": "rock_boulder", "weight": 0.55, "scale_min": 3.2, "scale_max": 5.5},
					{"key": "rock_cluster", "weight": 0.45, "scale_min": 2.8, "scale_max": 4.8},
				],
				"tree_count": 155,
				"scatter_count": 90,
				"hill_count": 0,
				"vista_count": 18,
				"cloud_count": 8,
				"near_clearance": 7.5,
				"band_width": 62.0,
				"grandstands": 0,
				"paddock_tents": 4,
				"corner_barrier": "tire_stack",
				"straight_fence": "wood_fence",
				"cone_count": 12,
				"checkpoint_arches": 1,
			}
		"spa_forest":
			return {
				"id": "spa_forest",
				"display_name": "Spa Forest",
				"sky_top": Color("47789e"),
				"sky_horizon": Color("b5ced3"),
				"ground_bottom": Color("2a3c2f"),
				"ground_horizon": Color("9db9b0"),
				"ambient_color": Color("dbe9e2"),
				"ambient_energy": 0.68,
				"sun_color": Color("fff6e6"),
				"sun_energy": 1.12,
				"sun_pitch_deg": -48.0,
				"sun_yaw_deg": -24.0,
				"fog_color": Color("adc4bd"),
				"ground_texture": "ground_grass",
				"ground_albedo": Color("65985c"),
				"road_asphalt_tint": Color("dfe5ec"),
				"road_dirt_tint": Color("edd5b8"),
				"embankment_color": Color("435444"),
				"bridge_color": Color("5c6168"),
				"dust_color": Color("b7afa2"),
				"trees": [
					{"key": "pine_tall", "weight": 0.30, "scale_min": 0.90, "scale_max": 1.30},
					{"key": "pine_dense", "weight": 0.28, "scale_min": 0.90, "scale_max": 1.25},
					{"key": "pine_round", "weight": 0.18, "scale_min": 0.85, "scale_max": 1.20},
					{"key": "conifer_compact", "weight": 0.14, "scale_min": 0.90, "scale_max": 1.22},
					{"key": "tree_parkland", "weight": 0.10, "scale_min": 0.88, "scale_max": 1.18},
				],
				"scatter": [
					{"key": "bush_lush", "weight": 0.42, "scale_min": 0.85, "scale_max": 1.30},
					{"key": "grass_clump", "weight": 0.32, "scale_min": 0.90, "scale_max": 1.35},
					{"key": "tree_stump", "weight": 0.14, "scale_min": 0.90, "scale_max": 1.25},
					{"key": "rock_alpine", "weight": 0.12, "scale_min": 0.85, "scale_max": 1.30},
				],
				"hills": [
					{"key": "hill_treed", "weight": 1.0, "scale_min": 1.7, "scale_max": 2.6},
				],
				"vista": [
					{"key": "hill_treed", "weight": 0.70, "scale_min": 2.4, "scale_max": 3.4},
					{"key": "alpine_mountain_a", "weight": 0.30, "scale_min": 1.8, "scale_max": 2.5},
				],
				"tree_count": 210,
				"scatter_count": 105,
				"hill_count": 14,
				"vista_count": 18,
				"cloud_count": 10,
				"near_clearance": 6.8,
				"band_width": 58.0,
				"grandstands": 3,
				"paddock_tents": 5,
				"corner_barrier": "guardrail_double",
				"corner_accent": "barrier_wall",
				"apex_tires": true,
				"straight_fence": "",
				"cone_count": 10,
				"checkpoint_arches": 2,
			}
		"alpine":
			return {
				"id": "alpine",
				"display_name": "Alpine",
				"sky_top": Color("2f6eb5"),
				"sky_horizon": Color("bddcf2"),
				"ground_bottom": Color("39523b"),
				"ground_horizon": Color("a9cbe0"),
				"ambient_color": Color("e2f0f8"),
				"ambient_energy": 0.70,
				"sun_color": Color("fffaf0"),
				"sun_energy": 1.20,
				"sun_pitch_deg": -50.0,
				"sun_yaw_deg": -32.0,
				"fog_color": Color("b6d4e8"),
				"ground_texture": "ground_grass",
				"ground_albedo": Color("74a668"),
				"road_asphalt_tint": Color("e5ebf2"),
				"road_dirt_tint": Color("f0dac0"),
				"embankment_color": Color("546952"),
				"bridge_color": Color("676e76"),
				"dust_color": Color("cbd4dc"),
				"trees": [
					{"key": "pine_tall", "weight": 0.36, "scale_min": 0.88, "scale_max": 1.28},
					{"key": "pine_round", "weight": 0.30, "scale_min": 0.85, "scale_max": 1.22},
					{"key": "conifer_compact", "weight": 0.34, "scale_min": 0.88, "scale_max": 1.25},
				],
				"scatter": [
					{"key": "rock_alpine", "weight": 0.36, "scale_min": 0.90, "scale_max": 1.45},
					{"key": "rock_boulder", "weight": 0.24, "scale_min": 0.80, "scale_max": 1.35},
					{"key": "bush_lush", "weight": 0.20, "scale_min": 0.85, "scale_max": 1.20},
					{"key": "grass_clump", "weight": 0.20, "scale_min": 0.90, "scale_max": 1.30},
				],
				"hills": [
					{"key": "hill_mound", "weight": 0.50, "scale_min": 1.5, "scale_max": 2.3},
					{"key": "hill_treed", "weight": 0.50, "scale_min": 1.6, "scale_max": 2.4},
				],
				"vista": [
					{"key": "alpine_mountain_a", "weight": 0.50, "scale_min": 2.2, "scale_max": 3.4},
					{"key": "alpine_mountain_b", "weight": 0.50, "scale_min": 2.0, "scale_max": 3.2},
				],
				"tree_count": 185,
				"scatter_count": 95,
				"hill_count": 14,
				"vista_count": 22,
				"cloud_count": 12,
				"near_clearance": 7.5,
				"band_width": 64.0,
				"grandstands": 3,
				"paddock_tents": 4,
				"corner_barrier": "guardrail_double",
				"corner_accent": "barrier_wall",
				"apex_tires": false,
				"straight_fence": "wood_fence",
				"cone_count": 8,
				"checkpoint_arches": 1,
			}
		"parkland":
			return {
				"id": "parkland",
				"display_name": "Parkland",
				"sky_top": Color("3f82c4"),
				"sky_horizon": Color("d9e4d2"),
				"ground_bottom": Color("3e5a38"),
				"ground_horizon": Color("c7d8bc"),
				"ambient_color": Color("eef2e2"),
				"ambient_energy": 0.68,
				"sun_color": Color("fff4d8"),
				"sun_energy": 1.18,
				"sun_pitch_deg": -45.0,
				"sun_yaw_deg": -22.0,
				"fog_color": Color("cbd9c3"),
				"ground_texture": "ground_grass",
				"ground_albedo": Color("7eb062"),
				"road_asphalt_tint": Color("eaeef4"),
				"road_dirt_tint": Color("f2dec4"),
				"embankment_color": Color("5a704c"),
				"bridge_color": Color("71757a"),
				"dust_color": Color("d5dce2"),
				"trees": [
					{"key": "tree_parkland", "weight": 0.34, "scale_min": 0.90, "scale_max": 1.24},
					{"key": "tree_oak", "weight": 0.30, "scale_min": 0.88, "scale_max": 1.22},
					{"key": "tree_rounded", "weight": 0.22, "scale_min": 0.88, "scale_max": 1.20},
					{"key": "tree_meadow", "weight": 0.14, "scale_min": 0.90, "scale_max": 1.18},
				],
				"scatter": [
					{"key": "bush_lush", "weight": 0.32, "scale_min": 0.85, "scale_max": 1.20},
					{"key": "grass_clump", "weight": 0.36, "scale_min": 0.90, "scale_max": 1.28},
					{"key": "flower_clump", "weight": 0.32, "scale_min": 1.00, "scale_max": 1.50},
				],
				"hills": [
					{"key": "hill_mound", "weight": 1.0, "scale_min": 1.4, "scale_max": 2.0},
				],
				"vista": [],
				"tree_count": 190,
				"scatter_count": 110,
				"hill_count": 8,
				"vista_count": 0,
				"cloud_count": 10,
				"near_clearance": 7.5,
				"band_width": 66.0,
				"grandstands": 4,
				"paddock_tents": 6,
				"corner_barrier": "barrier_wall",
				"corner_accent": "guardrail_double",
				"apex_tires": true,
				"straight_fence": "",
				"cone_count": 16,
				"checkpoint_arches": 2,
			}
		"open_grassland":
			return {
				"id": "open_grassland",
				"display_name": "Open Grassland",
				"sky_top": Color("4686c2"),
				"sky_horizon": Color("d6e6eb"),
				"ground_bottom": Color("47613f"),
				"ground_horizon": Color("c3d9cb"),
				"ambient_color": Color("eaf2eb"),
				"ambient_energy": 0.72,
				"sun_color": Color("fff9e8"),
				"sun_energy": 1.16,
				"sun_pitch_deg": -52.0,
				"sun_yaw_deg": -28.0,
				"fog_color": Color("cde0d9"),
				"ground_texture": "ground_grass",
				"ground_albedo": Color("88b866"),
				"road_asphalt_tint": Color("e4eaf0"),
				"road_dirt_tint": Color("f1dcc2"),
				"embankment_color": Color("5f7450"),
				"bridge_color": Color("747980"),
				"dust_color": Color("cfd8df"),
				"trees": [
					{"key": "tree_meadow", "weight": 0.42, "scale_min": 0.90, "scale_max": 1.25},
					{"key": "tree_oak", "weight": 0.34, "scale_min": 0.88, "scale_max": 1.20},
					{"key": "tree_rounded", "weight": 0.24, "scale_min": 0.85, "scale_max": 1.18},
				],
				"scatter": [
					{"key": "grass_clump", "weight": 0.56, "scale_min": 0.95, "scale_max": 1.45},
					{"key": "flower_clump", "weight": 0.44, "scale_min": 1.00, "scale_max": 1.55},
				],
				"hills": [
					{"key": "hill_mound", "weight": 1.0, "scale_min": 1.6, "scale_max": 2.4},
				],
				"vista": [],
				"tree_count": 155,
				"scatter_count": 115,
				"hill_count": 10,
				"vista_count": 0,
				"cloud_count": 12,
				"near_clearance": 14.5,
				"band_width": 84.0,
				"grandstands": 2,
				"paddock_tents": 5,
				"corner_barrier": "barrier_wall",
				"corner_accent": "",
				"apex_tires": false,
				"straight_fence": "wood_fence",
				"cone_count": 16,
				"checkpoint_arches": 1,
			}
		_: # "forest"
			return {
				"id": "forest",
				"display_name": "Forest",
				"sky_top": Color("467a9c"),
				"sky_horizon": Color("bdd6ce"),
				"ground_bottom": Color("314631"),
				"ground_horizon": Color("a4bfb0"),
				"ambient_color": Color("e1eee5"),
				"ambient_energy": 0.66,
				"sun_color": Color("fff4df"),
				"sun_energy": 1.14,
				"sun_pitch_deg": -50.0,
				"sun_yaw_deg": -26.0,
				"fog_color": Color("aec8ba"),
				"ground_texture": "ground_grass",
				"ground_albedo": Color("6da158"),
				"road_asphalt_tint": Color("dde3ea"),
				"road_dirt_tint": Color("ebd4b7"),
				"embankment_color": Color("5b4d3e"),
				"bridge_color": Color("62584d"),
				"dust_color": Color("a88a68"),
				"trees": [
					{"key": "pine_dense", "weight": 0.30, "scale_min": 0.90, "scale_max": 1.28},
					{"key": "pine_tall", "weight": 0.28, "scale_min": 0.90, "scale_max": 1.30},
					{"key": "pine_round", "weight": 0.22, "scale_min": 0.85, "scale_max": 1.22},
					{"key": "tree_oak", "weight": 0.20, "scale_min": 0.88, "scale_max": 1.20},
				],
				"scatter": [
					{"key": "bush_lush", "weight": 0.34, "scale_min": 0.88, "scale_max": 1.32},
					{"key": "tree_stump", "weight": 0.22, "scale_min": 0.90, "scale_max": 1.30},
					{"key": "grass_clump", "weight": 0.22, "scale_min": 0.90, "scale_max": 1.35},
					{"key": "rock_boulder", "weight": 0.12, "scale_min": 0.80, "scale_max": 1.30},
					{"key": "rock_cluster", "weight": 0.10, "scale_min": 0.85, "scale_max": 1.30},
				],
				"hills": [
					{"key": "hill_treed", "weight": 1.0, "scale_min": 1.6, "scale_max": 2.4},
				],
				"vista": [],
				"tree_count": 210,
				"scatter_count": 105,
				"hill_count": 12,
				"vista_count": 0,
				"cloud_count": 10,
				"near_clearance": 6.4,
				"band_width": 54.0,
				"grandstands": 0,
				"paddock_tents": 3,
				"corner_barrier": "tire_stack",
				"corner_accent": "",
				"apex_tires": true,
				"straight_fence": "wood_fence",
				"cone_count": 12,
				"checkpoint_arches": 1,
			}


static func get_embankment_color(theme_name: String) -> Color:
	return get_preset(theme_name).get("embankment_color", Color("4a574b")) as Color


static func get_bridge_color(theme_name: String) -> Color:
	return get_preset(theme_name).get("bridge_color", Color("55504b")) as Color


static func get_dust_color(theme_name: String, surface_name: String) -> Color:
	var preset := get_preset(theme_name)
	if surface_name == "dirt" or normalize_theme(theme_name) == "desert":
		return preset.get("dust_color", Color("c8aa80")) as Color
	return Color("d4dce3")


static func compute_scenery_layout(compiled: Dictionary, track: TrackDefinition, ground_y: float = -0.02) -> Dictionary:
	var theme_key := normalize_theme(track.theme if track != null else "forest")
	var preset := get_preset(theme_key)
	var layout := {
		"theme": theme_key,
		"preset": preset,
		"arch_transforms": [] as Array[Transform3D],
		"trackside_batches": {},
		"nature_batches": {},
	}
	if not bool(compiled.get("ok", false)) or track == null:
		return layout

	var trackside := _collect_trackside_scenery(compiled, track, preset, ground_y)
	var occupied: Array[Dictionary] = trackside.get("occupied", [])
	var nature_batches := _collect_nature_scenery(compiled, track, preset, occupied, ground_y)

	layout["arch_transforms"] = trackside.get("arch_transforms", [] as Array[Transform3D])
	layout["trackside_batches"] = trackside.get("batches", {})
	layout["nature_batches"] = nature_batches
	return layout


static func apply_race_environment(parent: Node3D, compiled: Dictionary, track: TrackDefinition, with_ground_collision: bool = true, is_preview: bool = false) -> Node3D:
	var theme_key := normalize_theme(track.theme if track != null else "forest")
	var preset := get_preset(theme_key)
	var ground_y := -0.05 if is_preview else -0.02

	var env_root := Node3D.new()
	env_root.name = "BiomeEnvironment"
	parent.add_child(env_root)

	_add_sky_and_lighting(env_root, preset, is_preview)
	var ground_mesh := _add_ground_plane(env_root, compiled, track, theme_key, with_ground_collision, ground_y)

	if compiled.get("ok", false) and track != null:
		var layout := compute_scenery_layout(compiled, track, ground_y)
		var mesh_cache := {}
		var trackside_group := Node3D.new()
		trackside_group.name = "BiomeTrackside"
		env_root.add_child(trackside_group)

		var nature_group := Node3D.new()
		nature_group.name = "BiomeNature"
		env_root.add_child(nature_group)

		var arch_transforms: Array[Transform3D] = layout.get("arch_transforms", [] as Array[Transform3D])
		for idx in arch_transforms.size():
			var arch := AssetRegistry.instantiate_trackside("checkpoint_arch")
			if arch == null:
				continue
			arch.name = "CheckpointArch_%d" % idx
			arch.transform = arch_transforms[idx]
			trackside_group.add_child(arch)

		var trackside_batches: Dictionary = layout.get("trackside_batches", {})
		for model_key in trackside_batches.keys():
			var transforms: Array[Transform3D] = trackside_batches[model_key]
			var vis_end := 0.0
			if not is_preview and model_key == "traffic_cone":
				vis_end = 190.0
			elif not is_preview:
				vis_end = 420.0
			_create_multimesh_node(trackside_group, "MM_Trackside_%s" % model_key, model_key, false, transforms, mesh_cache, vis_end)

		var nature_batches: Dictionary = layout.get("nature_batches", {})
		for model_key in nature_batches.keys():
			var transforms: Array[Transform3D] = nature_batches[model_key]
			var vis_end := 0.0
			if not is_preview:
				if model_key == "grass_clump" or model_key == "flower_clump":
					vis_end = 200.0
				elif model_key == "bush_lush" or model_key == "tree_stump":
					vis_end = 310.0
				elif not str(model_key).begins_with("alpine_mountain") and not str(model_key).begins_with("hill_") and model_key != "sky_cloud":
					vis_end = 480.0
			_create_multimesh_node(nature_group, "MM_Nature_%s" % model_key, model_key, true, transforms, mesh_cache, vis_end)

		if with_ground_collision and not is_preview and ground_mesh != null:
			var obstacle_body := StaticBody3D.new()
			obstacle_body.name = "EnvironmentObstacles"
			env_root.add_child(obstacle_body)
			var half_width := float(TrackCompiler.ROAD_HALF_WIDTHS.get(track.road_width, 7.0))
			var outer_half := half_width + CURB_WIDTH
			_attach_environment_colliders(
				obstacle_body,
				arch_transforms,
				trackside_batches,
				nature_batches,
				compiled.get("centerline", PackedVector3Array()) as PackedVector3Array,
				outer_half
			)

		mesh_cache.clear()

	return env_root


static func _add_sky_and_lighting(parent: Node3D, preset: Dictionary, is_preview: bool) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = preset.sky_top
	sky_mat.sky_horizon_color = preset.sky_horizon
	sky_mat.ground_bottom_color = preset.ground_bottom
	sky_mat.ground_horizon_color = preset.ground_horizon
	sky_mat.sky_curve = 0.14
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08

	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	var env_data := Environment.new()
	env_data.background_mode = Environment.BG_SKY
	env_data.sky = sky
	env_data.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_data.ambient_light_color = preset.ambient_color
	env_data.ambient_light_energy = float(preset.ambient_energy)
	env_data.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_data.tonemap_exposure = 1.06
	env_data.tonemap_white = 5.5
	if not is_preview:
		env_data.fog_enabled = true
		env_data.fog_mode = Environment.FOG_MODE_DEPTH
		env_data.fog_light_color = preset.fog_color
		env_data.fog_depth_begin = 115.0
		env_data.fog_depth_end = 380.0
		env_data.fog_sky_affect = 0.22

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env_data
	parent.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.name = "SunLight"
	light.rotation_degrees = Vector3(float(preset.sun_pitch_deg), float(preset.sun_yaw_deg), 0.0)
	light.light_color = preset.sun_color
	light.light_energy = float(preset.sun_energy)
	light.shadow_enabled = false
	parent.add_child(light)


static func _add_ground_plane(
	parent: Node3D,
	compiled: Dictionary,
	track: TrackDefinition,
	theme_key: String,
	with_collision: bool,
	ground_y: float
) -> StaticBody3D:
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.name = "GroundMesh"
	var ground_mat := AssetRegistry.create_ground_material_for_theme(theme_key)
	var centerline: PackedVector3Array = compiled.get("centerline", PackedVector3Array())
	var sculpted := bool(compiled.get("ok", false)) and track != null and centerline.size() >= 6
	if sculpted:
		ground_mesh.mesh = _build_sculpted_terrain_mesh(compiled, track, ground_y)
		ground_mesh.position.y = 0.0
	else:
		var plane := PlaneMesh.new()
		plane.size = Vector2(1200.0, 1200.0)
		ground_mesh.mesh = plane
		ground_mesh.position.y = ground_y
	ground_mesh.material_override = ground_mat

	if with_collision:
		var ground_body := StaticBody3D.new()
		ground_body.name = "PreviewGround"
		ground_body.add_child(ground_mesh)
		var ground_collision := CollisionShape3D.new()
		ground_collision.name = "TerrainSurface"
		if sculpted and ground_mesh.mesh != null:
			var terrain_shape := ConcavePolygonShape3D.new()
			terrain_shape.backface_collision = true
			terrain_shape.set_faces(ground_mesh.mesh.get_faces())
			ground_collision.shape = terrain_shape
			ground_collision.position.y = 0.0
		else:
			var ground_shape := BoxShape3D.new()
			ground_shape.size = Vector3(1200.0, 1.0, 1200.0)
			ground_collision.shape = ground_shape
			ground_collision.position.y = ground_y - 0.5
		ground_body.add_child(ground_collision)
		parent.add_child(ground_body)
		return ground_body
	else:
		parent.add_child(ground_mesh)
		return null


static func sample_terrain_height(
	point_2d: Vector2,
	sample_cl: PackedVector3Array,
	half_width: float,
	terrain_seed: int,
	ground_y: float
) -> float:
	if sample_cl.is_empty():
		return ground_y
	var best_sq := INF
	var nearest_y := ground_y
	for cp in sample_cl:
		var dx := point_2d.x - cp.x
		var dz := point_2d.y - cp.z
		var d2 := dx * dx + dz * dz
		if d2 < best_sq:
			best_sq = d2
			nearest_y = cp.y
	var d := sqrt(best_sq)
	var outer_half := half_width + CURB_WIDTH
	var under_road_y := nearest_y - 0.14
	var verge_y := minf(ground_y - 0.03, nearest_y - 0.05)
	if d <= outer_half + 2.5:
		return under_road_y
	if d <= outer_half + 5.5:
		var curb_t := (d - (outer_half + 2.5)) / 3.0
		return lerpf(under_road_y, verge_y, curb_t)
	var flat_clearance := outer_half + 15.0
	if d <= flat_clearance:
		return verge_y
	var t_ramp := clampf((d - flat_clearance) / 38.0, 0.0, 1.0)
	var blend := t_ramp * t_ramp * (3.0 - 2.0 * t_ramp)
	var phase_a := float(posmod(terrain_seed, 997)) * 0.013
	var phase_b := float(posmod(terrain_seed / 7, 997)) * 0.017
	var wave1 := 0.5 + 0.5 * sin(point_2d.x * 0.022 + phase_a) * cos(point_2d.y * 0.019 + phase_b)
	var wave2 := 0.5 + 0.5 * sin((point_2d.x + point_2d.y) * 0.037 - phase_a * 0.7)
	var perimeter_lift := clampf((d - 38.0) / 140.0, 0.0, 1.0) * 14.0
	var hill_h := 16.0 * wave1 + 7.5 * wave2 + perimeter_lift
	return lerpf(verge_y, ground_y + hill_h, blend)


static func _build_sculpted_terrain_mesh(compiled: Dictionary, track: TrackDefinition, ground_y: float) -> ArrayMesh:
	var centerline: PackedVector3Array = compiled.get("centerline", PackedVector3Array())
	var terrain_cl := _build_ground_centerline(centerline, compiled.get("bridge_segments", []), 140)
	var half_width: float = float(TrackCompiler.ROAD_HALF_WIDTHS.get(track.road_width, 7.0))
	var theme_key := normalize_theme(track.theme)
	var terrain_seed := int(hash("%s_%s_terrain" % [track.track_id, theme_key]))
	var bounds: Rect2 = compiled.get("minimap", {}).get("bounds", Rect2(-180.0, -180.0, 360.0, 360.0))
	var center_2d := bounds.position + bounds.size * 0.5

	const GRID := 64
	const SPAN := 960.0
	var step := SPAN / float(GRID - 1)
	var origin_x := center_2d.x - SPAN * 0.5
	var origin_z := center_2d.y - SPAN * 0.5

	var heights := PackedFloat32Array()
	heights.resize(GRID * GRID)
	for gz in GRID:
		var wz := origin_z + float(gz) * step
		var row_base := gz * GRID
		for gx in GRID:
			var wx := origin_x + float(gx) * step
			heights[row_base + gx] = sample_terrain_height(Vector2(wx, wz), terrain_cl, half_width, terrain_seed, ground_y)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(GRID * GRID)
	normals.resize(GRID * GRID)
	uvs.resize(GRID * GRID)

	var inv_2step := 1.0 / (2.0 * step)
	for gz in GRID:
		var wz := origin_z + float(gz) * step
		var v_uv := float(gz) / float(GRID - 1)
		var gz_m := maxi(0, gz - 1)
		var gz_p := mini(GRID - 1, gz + 1)
		for gx in GRID:
			var idx := gz * GRID + gx
			var wx := origin_x + float(gx) * step
			var u_uv := float(gx) / float(GRID - 1)
			vertices[idx] = Vector3(wx, heights[idx], wz)
			uvs[idx] = Vector2(u_uv, v_uv)
			var gx_m := maxi(0, gx - 1)
			var gx_p := mini(GRID - 1, gx + 1)
			var dh_dx := (heights[gz * GRID + gx_p] - heights[gz * GRID + gx_m]) * inv_2step
			var dh_dz := (heights[gz_p * GRID + gx] - heights[gz_m * GRID + gx]) * inv_2step
			normals[idx] = Vector3(-dh_dx, 1.0, -dh_dz).normalized()

	indices.resize((GRID - 1) * (GRID - 1) * 6)
	var ptr := 0
	for gz in range(GRID - 1):
		for gx in range(GRID - 1):
			var i0 := gz * GRID + gx
			var i1 := i0 + 1
			var i2 := i0 + GRID
			var i3 := i2 + 1
			indices[ptr] = i0
			indices[ptr + 1] = i1
			indices[ptr + 2] = i2
			indices[ptr + 3] = i1
			indices[ptr + 4] = i3
			indices[ptr + 5] = i2
			ptr += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _collect_trackside_scenery(
	compiled: Dictionary,
	track: TrackDefinition,
	preset: Dictionary,
	ground_y: float
) -> Dictionary:
	var centerline: PackedVector3Array = compiled.get("centerline", PackedVector3Array())
	if centerline.size() < 6:
		return {
			"arch_transforms": [] as Array[Transform3D],
			"batches": {},
			"occupied": [] as Array[Dictionary],
		}
	var half_width: float = float(TrackCompiler.ROAD_HALF_WIDTHS.get(track.road_width, 7.0))
	var road_total_width := half_width * 2.0
	var outer_half := half_width + CURB_WIDTH
	var bridge_lookup := _build_bridge_lookup(compiled.get("bridge_segments", []), centerline.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s_trackside" % [track.track_id, preset.id])
	var terrain_seed := int(hash("%s_%s_terrain" % [track.track_id, preset.id]))
	var terrain_cl := _build_ground_centerline(centerline, compiled.get("bridge_segments", []), 96)

	var occupied: Array[Dictionary] = []
	var arch_leg_occupied: Array[Dictionary] = []
	var checkpoints: Array = compiled.get("checkpoints", [])
	if not checkpoints.is_empty():
		var start_pos: Vector3 = checkpoints[0].position
		var start_t: Vector3 = checkpoints[0].get("tangent", Vector3.FORWARD)
		start_t.y = 0.0
		var start_tan := start_t.normalized() if start_t.length_squared() > 0.0001 else Vector3.FORWARD
		var start_lat := Vector3(-start_tan.z, 0.0, start_tan.x)
		occupied.append({"pos": Vector2(start_pos.x, start_pos.z), "radius": outer_half + 14.0})
		for leg_side: float in [-1.0, 1.0]:
			var leg_p := start_pos + start_lat * (leg_side * (outer_half + 1.3))
			arch_leg_occupied.append({"pos": Vector2(leg_p.x, leg_p.z), "radius": 1.6})

	# 1. Checkpoint arches at flat, straight non-bridge mid-loop sectors
	var arch_budget := int(preset.get("checkpoint_arches", 1))
	var arch_transforms := _collect_checkpoint_arch_transforms(checkpoints, centerline, bridge_lookup, road_total_width, arch_budget, occupied, arch_leg_occupied)

	var batches := {} # model_key -> Array[Transform3D]
	var grandstand_count := int(preset.get("grandstands", 0))
	if grandstand_count > 0:
		_collect_grandstands(centerline, terrain_cl, half_width, terrain_seed, bridge_lookup, outer_half, grandstand_count, ground_y, occupied, batches)

	var tent_count := int(preset.get("paddock_tents", 0))
	if tent_count > 0:
		_collect_paddock_tents(centerline, terrain_cl, half_width, terrain_seed, bridge_lookup, outer_half, tent_count, ground_y, occupied, batches)

	var corner_barrier := str(preset.get("corner_barrier", ""))
	var corner_accent := str(preset.get("corner_accent", ""))
	var straight_fence := str(preset.get("straight_fence", ""))
	var use_apex_tires := bool(preset.get("apex_tires", false))
	_collect_edge_barriers(
		centerline,
		bridge_lookup,
		outer_half,
		ground_y,
		corner_barrier,
		corner_accent,
		straight_fence,
		use_apex_tires,
		arch_leg_occupied,
		batches
	)

	var cone_count := int(preset.get("cone_count", 0))
	if cone_count > 0:
		_collect_paddock_cones(centerline, bridge_lookup, outer_half, cone_count, ground_y, rng, batches)

	return {
		"arch_transforms": arch_transforms,
		"batches": batches,
		"occupied": occupied,
	}


static func _collect_checkpoint_arch_transforms(
	checkpoints: Array,
	centerline: PackedVector3Array,
	bridge_lookup: Dictionary,
	road_total_width: float,
	arch_budget: int,
	occupied: Array[Dictionary],
	arch_leg_occupied: Array[Dictionary]
) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var n := centerline.size()
	if checkpoints.size() < 3 or arch_budget <= 0 or n < 5:
		return transforms
	var anchors: Array[int] = []
	if arch_budget == 1:
		anchors.append(checkpoints.size() / 2)
	else:
		anchors.append(maxi(1, checkpoints.size() / 3))
		anchors.append(mini(checkpoints.size() - 1, (checkpoints.size() * 2) / 3))

	var used_cp := {}
	for target_cp in anchors:
		var chosen_cp := -1
		for delta in range(0, checkpoints.size()):
			for sign_val: int in [1, -1]:
				var idx := target_cp + delta * sign_val
				if idx <= 0 or idx >= checkpoints.size() or used_cp.has(idx):
					continue
				var cp_cand: Dictionary = checkpoints[idx]
				var cl_idx := int(cp_cand.get("index", 0))
				if bridge_lookup.has(cl_idx):
					continue
				var cl_prev := centerline[(cl_idx - 1 + n) % n]
				var cl_next := centerline[(cl_idx + 1) % n]
				var grade := absf(cl_next.y - cl_prev.y) / maxf(0.5, Vector2(cl_next.x - cl_prev.x, cl_next.z - cl_prev.z).length())
				var max_turn := maxf(
					_turn_angle_at(centerline, (cl_idx - 1 + n) % n),
					maxf(_turn_angle_at(centerline, cl_idx), _turn_angle_at(centerline, (cl_idx + 1) % n))
				)
				if grade <= 0.10 and max_turn <= 0.08:
					chosen_cp = idx
					break
			if chosen_cp >= 0:
				break
		if chosen_cp < 0:
			continue
		used_cp[chosen_cp] = true
		var cp: Dictionary = checkpoints[chosen_cp]
		var pos: Vector3 = cp.position
		var cp_tangent: Vector3 = cp.tangent
		var yaw := atan2(-cp_tangent.x, -cp_tangent.z)
		var scale_x := (road_total_width * 0.5 + CURB_WIDTH + 0.90) / 3.558
		var scale_y := clampf(lerpf(1.0, scale_x, 0.35), 1.0, 1.85)
		var arch_basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled_local(Vector3(scale_x, scale_y, 1.15))
		transforms.append(Transform3D(arch_basis, Vector3(pos.x, maxf(-0.32, pos.y - 0.34), pos.z)))
		occupied.append({"pos": Vector2(pos.x, pos.z), "radius": 6.6 * scale_x})
		var t_flat := Vector3(cp_tangent.x, 0.0, cp_tangent.z)
		var tangent_n := t_flat.normalized() if t_flat.length_squared() > 0.0001 else Vector3.FORWARD
		var lateral := Vector3(-tangent_n.z, 0.0, tangent_n.x)
		for side_val: float in [-1.0, 1.0]:
			var leg_pos := pos + lateral * (side_val * 5.029 * scale_x)
			var leg_entry := {"pos": Vector2(leg_pos.x, leg_pos.z), "radius": 1.6 * scale_x}
			occupied.append(leg_entry)
			arch_leg_occupied.append(leg_entry)
	return transforms


static func _collect_grandstands(
	centerline: PackedVector3Array,
	terrain_cl: PackedVector3Array,
	half_width: float,
	terrain_seed: int,
	bridge_lookup: Dictionary,
	outer_half: float,
	target_count: int,
	ground_y: float,
	occupied: Array[Dictionary],
	batches: Dictionary
) -> void:
	var n := centerline.size()
	var clearance := outer_half + 10.5
	var transforms: Array[Transform3D] = []
	var stride := maxi(4, n / maxi(6, target_count * 4))
	for i in range(6, n, stride):
		if transforms.size() >= target_count:
			break
		if bridge_lookup.has(i):
			continue
		var p := centerline[i]
		if p.y > 1.3:
			continue
		if _turn_angle_at(centerline, i) > 0.11:
			continue
		var tangent := _flat_tangent(centerline, i)
		var lateral := Vector3(-tangent.z, 0.0, tangent.x)
		for side_val: float in [1.0, -1.0]:
			var candidate := p + lateral * (side_val * (outer_half + 12.2))
			var cand_2d := Vector2(candidate.x, candidate.z)
			if _min_dist_sq_to_track(cand_2d, centerline) < clearance * clearance:
				continue
			if _is_near_occupied(cand_2d, 15.0, occupied):
				continue
			var toward_road := (-lateral * side_val).normalized()
			var yaw := atan2(-toward_road.x, -toward_road.z)
			var y_pos := sample_terrain_height(cand_2d, terrain_cl, half_width, terrain_seed, ground_y)
			var pos := Vector3(candidate.x, y_pos, candidate.z)
			transforms.append(Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), pos))
			occupied.append({"pos": cand_2d, "radius": 13.0})
			break
	if not transforms.is_empty():
		batches["grandstand_covered"] = transforms


static func _collect_paddock_tents(
	centerline: PackedVector3Array,
	terrain_cl: PackedVector3Array,
	half_width: float,
	terrain_seed: int,
	bridge_lookup: Dictionary,
	outer_half: float,
	target_count: int,
	ground_y: float,
	occupied: Array[Dictionary],
	batches: Dictionary
) -> void:
	var n := centerline.size()
	var clearance := outer_half + 6.5
	var transforms: Array[Transform3D] = []
	for offset in range(4, mini(n, 48), 3):
		if transforms.size() >= target_count:
			break
		var idx := offset % n
		if bridge_lookup.has(idx):
			continue
		var p := centerline[idx]
		if p.y > 1.3 or _turn_angle_at(centerline, idx) > 0.18:
			continue
		var tangent := _flat_tangent(centerline, idx)
		var lateral := Vector3(-tangent.z, 0.0, tangent.x)
		var side := -1.0 if offset % 2 == 0 else 1.0
		var candidate := p + lateral * (side * (outer_half + 7.8))
		var cand_2d := Vector2(candidate.x, candidate.z)
		if _min_dist_sq_to_track(cand_2d, centerline) < clearance * clearance:
			continue
		if _is_near_occupied(cand_2d, 7.5, occupied):
			continue
		var toward_road := (-lateral * side).normalized()
		var yaw := atan2(-toward_road.x, -toward_road.z)
		var y_pos := sample_terrain_height(cand_2d, terrain_cl, half_width, terrain_seed, ground_y)
		transforms.append(Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), Vector3(candidate.x, y_pos, candidate.z)))
		occupied.append({"pos": cand_2d, "radius": 6.5})
	if not transforms.is_empty():
		batches["paddock_tent"] = transforms


static func _collect_edge_barriers(
	centerline: PackedVector3Array,
	bridge_lookup: Dictionary,
	outer_half: float,
	ground_y: float,
	corner_barrier: String,
	corner_accent: String,
	straight_fence: String,
	use_apex_tires: bool,
	arch_leg_occupied: Array[Dictionary],
	batches: Dictionary
) -> void:
	var n := centerline.size()
	var barrier_list: Array[Transform3D] = []
	var accent_list: Array[Transform3D] = []
	var fence_list: Array[Transform3D] = []
	var tire_list: Array[Transform3D] = []

	var last_barrier_pos := Vector2(INF, INF)
	var last_fence_pos := Vector2(INF, INF)
	var last_tire_pos := Vector2(INF, INF)
	var barrier_seq := 0
	var corner_min_sq := (outer_half + 0.25) * (outer_half + 0.25)
	var endpoint_min_sq := (outer_half + 0.20) * (outer_half + 0.20)
	var fence_min_sq := (outer_half + 1.2) * (outer_half + 1.2)

	for i in range(4, maxi(4, n - 4)):
		if bridge_lookup.has(i):
			continue
		var p := centerline[i]
		var signed_turn := _signed_turn_at(centerline, i)
		var abs_turn := absf(signed_turn)
		var tangent := _flat_tangent(centerline, i)
		var lateral := Vector3(-tangent.z, 0.0, tangent.x)

		if abs_turn >= 0.055 and not corner_barrier.is_empty():
			# Positive cross.y means left turn -> car pushes right (+lateral). Negative -> pushes left (-lateral).
			var outer_sign := 1.0 if signed_turn > 0.0 else -1.0
			var edge_offset := outer_half + 0.72
			var pos := p + lateral * (outer_sign * edge_offset)
			var pos_2d := Vector2(pos.x, pos.z)
			if _is_near_occupied(pos_2d, 0.4, arch_leg_occupied):
				continue
			if _min_dist_sq_to_track(pos_2d, centerline) < corner_min_sq:
				continue
			var end_a := Vector2(pos.x + tangent.x * 1.9, pos.z + tangent.z * 1.9)
			var end_b := Vector2(pos.x - tangent.x * 1.9, pos.z - tangent.z * 1.9)
			if _min_dist_sq_to_track(end_a, centerline) < endpoint_min_sq or _min_dist_sq_to_track(end_b, centerline) < endpoint_min_sq:
				continue
			if pos_2d.distance_to(last_barrier_pos) >= 2.8:
				last_barrier_pos = pos_2d
				var in_dir := (-lateral * outer_sign).normalized()
				var yaw := atan2(-in_dir.x, -in_dir.z)
				var base_y := maxf(ground_y, p.y - 0.08)
				if corner_barrier == "tire_stack":
					tire_list.append(Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), Vector3(pos.x, base_y, pos.z)))
				else:
					var use_accent := not corner_accent.is_empty() and abs_turn >= 0.14 and ((barrier_seq / 4) % 3 == 1)
					var target_arr := accent_list if use_accent else barrier_list
					target_arr.append(Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled_local(Vector3(1.10, 1.15, 1.15)), Vector3(pos.x, base_y, pos.z)))
				barrier_seq += 1
			if use_apex_tires and abs_turn >= 0.16 and pos_2d.distance_to(last_tire_pos) >= 8.5:
				var tire_pos := pos + lateral * (outer_sign * 0.9)
				var tire_2d := Vector2(tire_pos.x, tire_pos.z)
				if not _is_near_occupied(tire_2d, 0.4, arch_leg_occupied) and tire_2d.distance_to(last_tire_pos) >= 6.5:
					last_tire_pos = tire_2d
					tire_list.append(Transform3D(Basis.from_euler(Vector3(0.0, float(i) * 0.6, 0.0)), Vector3(tire_pos.x, maxf(ground_y, p.y - 0.12), tire_pos.z)))
		elif abs_turn < 0.055 and not straight_fence.is_empty():
			var side := 1.0 if (i / 10) % 2 == 0 else -1.0
			var edge_offset := outer_half + 1.85
			var pos := p + lateral * (side * edge_offset)
			var pos_2d := Vector2(pos.x, pos.z)
			if _is_near_occupied(pos_2d, 0.4, arch_leg_occupied):
				continue
			if _min_dist_sq_to_track(pos_2d, centerline) < fence_min_sq:
				continue
			if pos_2d.distance_to(last_fence_pos) >= 3.5:
				last_fence_pos = pos_2d
				var out_dir := (lateral * side).normalized()
				var yaw := atan2(-out_dir.x, -out_dir.z)
				fence_list.append(Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled_local(Vector3(1.08, 1.10, 1.10)), Vector3(pos.x, maxf(ground_y, p.y - 0.14), pos.z)))

	if not barrier_list.is_empty() and not corner_barrier.is_empty() and corner_barrier != "tire_stack":
		batches[corner_barrier] = barrier_list
	if not accent_list.is_empty() and not corner_accent.is_empty():
		batches[corner_accent] = accent_list
	if not fence_list.is_empty() and not straight_fence.is_empty():
		batches[straight_fence] = fence_list
	if not tire_list.is_empty():
		batches["tire_stack"] = tire_list


static func _collect_paddock_cones(
	centerline: PackedVector3Array,
	bridge_lookup: Dictionary,
	outer_half: float,
	target_count: int,
	ground_y: float,
	rng: RandomNumberGenerator,
	batches: Dictionary
) -> void:
	var n := centerline.size()
	var transforms: Array[Transform3D] = []
	for step in range(target_count):
		var idx := (3 + step * 3) % n
		if bridge_lookup.has(idx):
			continue
		var p := centerline[idx]
		if p.y > 1.0:
			continue
		var tangent := _flat_tangent(centerline, idx)
		var lateral := Vector3(-tangent.z, 0.0, tangent.x)
		var side := -1.0 if step % 2 == 0 else 1.0
		var pos := p + lateral * (side * (outer_half + 1.2))
		var yaw := rng.randf_range(0.0, TAU)
		transforms.append(Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), Vector3(pos.x, maxf(ground_y, p.y - 0.05), pos.z)))
	if not transforms.is_empty():
		batches["traffic_cone"] = transforms


static func _collect_nature_scenery(
	compiled: Dictionary,
	track: TrackDefinition,
	preset: Dictionary,
	occupied: Array[Dictionary],
	ground_y: float
) -> Dictionary:
	var nature_batches := {}
	var centerline: PackedVector3Array = compiled.get("centerline", PackedVector3Array())
	if centerline.size() < 6:
		return nature_batches
	var half_width: float = float(TrackCompiler.ROAD_HALF_WIDTHS.get(track.road_width, 7.0))
	var bounds: Rect2 = compiled.get("minimap", {}).get("bounds", Rect2(-180.0, -180.0, 360.0, 360.0))
	var center_2d := bounds.position + bounds.size * 0.5
	var track_radius := maxf(120.0, bounds.size.length() * 0.5)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s_nature" % [track.track_id, preset.id])
	var terrain_seed := int(hash("%s_%s_terrain" % [track.track_id, preset.id]))
	var terrain_cl := _build_ground_centerline(centerline, compiled.get("bridge_segments", []), 96)

	var near_clearance := half_width + CURB_WIDTH + float(preset.get("near_clearance", 7.0))
	var band_width := float(preset.get("band_width", 58.0))
	var sample_cl := _downsample_centerline(centerline, MAX_CENTERLINE_SAMPLE)

	# 1. Primary Trees / Cacti / Palms (corridor-weighted on sculpted hillsides)
	var tree_specs: Array = preset.get("trees", [])
	var tree_target := int(preset.get("tree_count", 80))
	_scatter_weighted_band(
		tree_specs,
		tree_target,
		near_clearance,
		near_clearance + band_width,
		3.6,
		center_2d,
		track_radius + band_width + 32.0,
		sample_cl,
		centerline,
		terrain_cl,
		half_width,
		terrain_seed,
		occupied,
		ground_y,
		rng,
		nature_batches
	)

	# 2. Ground Scatter (bushes, rocks, stumps, grass tufts, flowers)
	var scatter_specs: Array = preset.get("scatter", [])
	var scatter_target := int(preset.get("scatter_count", 50))
	_scatter_weighted_band(
		scatter_specs,
		scatter_target,
		half_width + CURB_WIDTH + 3.4,
		near_clearance + band_width * 0.75,
		2.0,
		center_2d,
		track_radius + band_width + 18.0,
		sample_cl,
		centerline,
		terrain_cl,
		half_width,
		terrain_seed,
		occupied,
		ground_y,
		rng,
		nature_batches
	)

	# 3. Rolling Hills & Mounds (placed behind roadside trees with base sunk into sculpted terrain)
	var hill_specs: Array = preset.get("hills", [])
	var hill_target := int(preset.get("hill_count", 0))
	if hill_target > 0 and not hill_specs.is_empty():
		_scatter_weighted_band(
			hill_specs,
			hill_target,
			half_width + 48.0,
			half_width + 135.0,
			22.0,
			center_2d,
			track_radius + 125.0,
			sample_cl,
			centerline,
			terrain_cl,
			half_width,
			terrain_seed,
			occupied,
			ground_y - 0.15,
			rng,
			nature_batches
		)

	# 4. Distant Perimeter Mountain / Mesa Vista Ring
	var vista_specs: Array = preset.get("vista", [])
	var vista_target := int(preset.get("vista_count", 0))
	if vista_target > 0 and not vista_specs.is_empty():
		_populate_vista_ring(
			vista_specs,
			vista_target,
			center_2d,
			track_radius + 78.0,
			track_radius + 145.0,
			half_width + 44.0,
			centerline,
			terrain_cl,
			half_width,
			terrain_seed,
			ground_y - 0.25,
			rng,
			nature_batches
		)

	# 5. Low-Poly Sky Clouds outside central preview cone
	var cloud_target := int(preset.get("cloud_count", 10))
	if cloud_target > 0:
		_populate_sky_clouds(cloud_target, center_2d, track_radius + 35.0, track_radius + 160.0, rng, nature_batches)

	return nature_batches


static func _scatter_weighted_band(
	specs: Array,
	target_count: int,
	min_road_dist: float,
	max_road_dist: float,
	min_self_spacing: float,
	center_2d: Vector2,
	outer_radius: float,
	sample_cl: PackedVector3Array,
	full_cl: PackedVector3Array,
	terrain_cl: PackedVector3Array,
	half_width: float,
	terrain_seed: int,
	occupied: Array[Dictionary],
	base_y: float,
	rng: RandomNumberGenerator,
	batches: Dictionary
) -> void:
	if specs.is_empty() or target_count <= 0:
		return
	var safe_min := maxf(min_road_dist, half_width + CURB_WIDTH + 3.0)
	var min_sq := safe_min * safe_min
	var max_sq := max_road_dist * max_road_dist
	var placed_points: Array[Vector2] = []
	var self_sq := min_self_spacing * min_self_spacing
	var attempts := target_count * 14
	var cl_n := sample_cl.size()
	for _attempt in attempts:
		if placed_points.size() >= target_count:
			break
		var cand := Vector2.ZERO
		if rng.randf() < 0.75 and cl_n >= 4:
			var cl_idx := rng.randi_range(0, cl_n - 1)
			var tangent := _flat_tangent(sample_cl, cl_idx)
			var lateral := Vector2(-tangent.z, tangent.x)
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var span_t := pow(rng.randf(), 1.35)
			var lat_dist := lerpf(safe_min + 0.6, minf(max_road_dist, safe_min + 36.0), span_t)
			var pt3 := sample_cl[cl_idx]
			cand = Vector2(pt3.x, pt3.z) + lateral * (side * lat_dist)
		else:
			var angle := rng.randf_range(0.0, TAU)
			var rad := sqrt(rng.randf()) * outer_radius
			cand = center_2d + Vector2(cos(angle), sin(angle)) * rad
		var road_sq := _min_dist_sq_to_track(cand, full_cl)
		if road_sq < min_sq or road_sq > max_sq:
			continue
		if _is_near_occupied(cand, min_self_spacing + 3.0, occupied):
			continue
		var too_close := false
		for prev in placed_points:
			if cand.distance_squared_to(prev) < self_sq:
				too_close = true
				break
		if too_close:
			continue
		var spec := _pick_weighted_spec(specs, rng)
		var model_key := str(spec.key)
		var scale_val := rng.randf_range(float(spec.scale_min), float(spec.scale_max))
		var yaw := rng.randf_range(0.0, TAU)
		var y_pos := sample_terrain_height(cand, terrain_cl, half_width, terrain_seed, base_y)
		var scale_vec := Vector3.ONE * scale_val
		if model_key.begins_with("hill_") or model_key.begins_with("alpine_mountain"):
			y_pos -= 1.35 * scale_val
			if model_key.begins_with("hill_"):
				scale_vec = Vector3(scale_val * 1.45, scale_val * 0.78, scale_val * 1.45)
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled_local(scale_vec)
		var tf := Transform3D(basis, Vector3(cand.x, y_pos, cand.y))
		_append_batch_transform(batches, model_key, tf)
		placed_points.append(cand)


static func _populate_vista_ring(
	specs: Array,
	target_count: int,
	center_2d: Vector2,
	min_ring_r: float,
	max_ring_r: float,
	min_road_clearance: float,
	full_cl: PackedVector3Array,
	terrain_cl: PackedVector3Array,
	half_width: float,
	terrain_seed: int,
	base_y: float,
	rng: RandomNumberGenerator,
	batches: Dictionary
) -> void:
	var min_sq := min_road_clearance * min_road_clearance
	for i in target_count:
		var base_angle := (float(i) / float(target_count)) * TAU + rng.randf_range(-0.14, 0.14)
		var r := rng.randf_range(min_ring_r, max_ring_r)
		var pos_2d := center_2d + Vector2(cos(base_angle), sin(base_angle)) * r
		if _min_dist_sq_to_track(pos_2d, full_cl) < min_sq:
			continue
		var spec := _pick_weighted_spec(specs, rng)
		var model_key := str(spec.key)
		var s := rng.randf_range(float(spec.scale_min), float(spec.scale_max))
		var yaw := rng.randf_range(0.0, TAU)
		var y_pos := sample_terrain_height(pos_2d, terrain_cl, half_width, terrain_seed, base_y)
		var scale_vec := Vector3.ONE * s
		if model_key.begins_with("hill_") or model_key.begins_with("alpine_mountain"):
			y_pos -= 1.35 * s
			if model_key.begins_with("hill_"):
				scale_vec = Vector3(s * 1.45, s * 0.78, s * 1.45)
		var tf := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled_local(scale_vec), Vector3(pos_2d.x, y_pos, pos_2d.y))
		_append_batch_transform(batches, model_key, tf)


static func _append_batch_transform(batches: Dictionary, model_key: String, tf: Transform3D) -> void:
	if not batches.has(model_key):
		var list: Array[Transform3D] = []
		batches[model_key] = list
	(batches[model_key] as Array[Transform3D]).append(tf)


static func _populate_sky_clouds(
	target_count: int,
	center_2d: Vector2,
	min_r: float,
	max_r: float,
	rng: RandomNumberGenerator,
	batches: Dictionary
) -> void:
	var transforms: Array[Transform3D] = []
	for i in target_count:
		var angle := (float(i) / float(target_count)) * TAU + rng.randf_range(-0.18, 0.18)
		var r := rng.randf_range(min_r, max_r)
		var pos := Vector3(center_2d.x + cos(angle) * r, rng.randf_range(68.0, 108.0), center_2d.y + sin(angle) * r)
		var s := rng.randf_range(2.6, 4.8)
		var basis := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled_local(Vector3(s * 1.35, s * 0.72, s))
		transforms.append(Transform3D(basis, pos))
	if not transforms.is_empty():
		batches["sky_cloud"] = transforms


static func _create_multimesh_node(
	parent: Node3D,
	node_name: String,
	model_key: String,
	is_nature: bool,
	transforms: Array[Transform3D],
	mesh_cache: Dictionary,
	visibility_end: float
) -> void:
	if transforms.is_empty():
		return
	var mesh := _get_cached_mesh(model_key, is_nature, mesh_cache)
	if mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])

	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if visibility_end > 0.0:
		inst.visibility_range_end = visibility_end
		inst.visibility_range_end_margin = 24.0
	parent.add_child(inst)


static func _get_cached_mesh(model_key: String, is_nature: bool, mesh_cache: Dictionary) -> Mesh:
	var cache_key := "%s:%s" % ["N" if is_nature else "T", model_key]
	if mesh_cache.has(cache_key):
		return mesh_cache[cache_key] as Mesh
	var node := AssetRegistry.instantiate_nature(model_key) if is_nature else AssetRegistry.instantiate_trackside(model_key)
	var mesh: Mesh = null
	if node != null:
		var meshes := AssetRegistry._collect_mesh_instances(node)
		if not meshes.is_empty():
			mesh = meshes[0].mesh
		node.free()
	mesh_cache[cache_key] = mesh
	return mesh


static func _pick_weighted_spec(specs: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for spec in specs:
		total += float(spec.weight)
	var roll := rng.randf_range(0.0, maxf(0.001, total))
	var acc := 0.0
	for spec in specs:
		acc += float(spec.weight)
		if roll <= acc:
			return spec
	return specs[specs.size() - 1]


static func _build_bridge_lookup(bridge_segments: Array, centerline_size: int) -> Dictionary:
	var skip := {}
	if centerline_size <= 0:
		return skip
	for bridge in bridge_segments:
		var start_idx := int(bridge.get("start_index", 0))
		var end_idx := int(bridge.get("end_index", 0))
		var span := (end_idx - start_idx + centerline_size) % centerline_size
		for off in range(-2, span + 3):
			skip[(start_idx + off + centerline_size) % centerline_size] = true
	return skip


const _COLLIDER_SPECS := {
	"guardrail_double": {"shape": "beveled_box", "size": Vector3(4.0, 1.15, 0.42), "center_y": 0.575},
	"barrier_wall": {"shape": "beveled_box", "size": Vector3(4.0, 0.85, 0.58), "center_y": 0.425},
	"wood_fence": {"shape": "beveled_box", "size": Vector3(4.2, 1.05, 0.36), "center_y": 0.525},
	"tire_stack": {"shape": "box", "size": Vector3(1.8, 1.15, 1.18), "center_y": 0.575},
	"grandstand_covered": {"shape": "box", "size": Vector3(12.0, 6.0, 12.2), "center_y": 3.0},
	"paddock_tent": {"shape": "box", "size": Vector3(5.0, 3.5, 5.0), "center_y": 1.75},
	"tree_stump": {"shape": "cyl", "radius": 0.72, "height": 1.1, "center_y": 0.55},
	"cactus_saguaro": {"shape": "cyl", "radius": 0.75, "height": 3.8, "center_y": 1.9},
	"cactus_small": {"shape": "cyl", "radius": 0.65, "height": 2.4, "center_y": 1.2},
	"rock_cluster": {"shape": "cyl", "radius": 0.80, "height": 1.5, "center_y": 0.75},
	"rock_alpine": {"shape": "cyl", "radius": 1.35, "height": 1.6, "center_y": 0.8},
	"rock_boulder": {"shape": "cyl", "radius": 1.35, "height": 1.2, "center_y": 0.6},
	"tree_meadow": {"shape": "cyl", "radius": 0.65, "height": 5.0, "center_y": 2.5},
	"hill_mound": {"shape": "box", "size": Vector3(13.5, 4.0, 9.8), "center_y": 2.0},
	"hill_treed": {"shape": "box", "size": Vector3(12.6, 5.5, 12.6), "center_y": 2.75},
	"alpine_mountain_a": {"shape": "box", "size": Vector3(16.0, 14.0, 16.5), "center_y": 7.0},
	"alpine_mountain_b": {"shape": "box", "size": Vector3(13.8, 18.0, 14.2), "center_y": 9.0},
}


static func _collider_spec_for_model(model_key: String) -> Dictionary:
	if _COLLIDER_SPECS.has(model_key):
		return _COLLIDER_SPECS[model_key]
	if model_key.begins_with("pine_") or model_key.begins_with("tree_") or model_key.begins_with("conifer_") or model_key.begins_with("palm_"):
		return {"shape": "cyl", "radius": 0.80, "height": 5.0, "center_y": 2.5}
	if model_key.begins_with("rock_") or model_key.begins_with("sandstone_"):
		return {"shape": "cyl", "radius": 1.35, "height": 1.6, "center_y": 0.8}
	return {}


static func _extract_rot_and_scale(tf: Transform3D) -> Dictionary:
	var bx := tf.basis.x
	var by := tf.basis.y
	var bz := tf.basis.z
	var sx := maxf(0.05, bx.length())
	var sy := maxf(0.05, by.length())
	var sz := maxf(0.05, bz.length())
	var ux := bx / sx
	var uy := by / sy
	var uz := bz / sz
	return {
		"rot": Basis(ux, uy, uz).orthonormalized(),
		"scale": Vector3(sx, sy, sz),
		"ux": ux,
		"uy": uy,
	}


static func _get_cached_collider_shape(shape_cache: Dictionary, model_key: String, spec: Dictionary, scale: Vector3) -> Shape3D:
	var sx := snappedf(scale.x, 0.05)
	var sy := snappedf(scale.y, 0.05)
	var sz := snappedf(scale.z, 0.05)
	var cache_key := "%s:%.2f,%.2f,%.2f" % [model_key, sx, sy, sz]
	if shape_cache.has(cache_key):
		return shape_cache[cache_key] as Shape3D
	var shape: Shape3D = null
	var shape_kind := str(spec.shape)
	if shape_kind == "beveled_box":
		var base_size: Vector3 = spec.size
		var hx := base_size.x * sx * 0.5
		var hy := base_size.y * sy * 0.5
		var hz := base_size.z * sz * 0.5
		var mx := hx * 0.65
		var poly := ConvexPolygonShape3D.new()
		poly.points = PackedVector3Array([
			Vector3(-hx, -hy, 0.0),
			Vector3(-mx, -hy, hz),
			Vector3(mx, -hy, hz),
			Vector3(hx, -hy, 0.0),
			Vector3(mx, -hy, -hz),
			Vector3(-mx, -hy, -hz),
			Vector3(-hx, hy, 0.0),
			Vector3(-mx, hy, hz),
			Vector3(mx, hy, hz),
			Vector3(hx, hy, 0.0),
			Vector3(mx, hy, -hz),
			Vector3(-mx, hy, -hz),
		])
		shape = poly
	elif shape_kind == "box":
		var base_size: Vector3 = spec.size
		var box := BoxShape3D.new()
		box.size = Vector3(base_size.x * sx, base_size.y * sy, base_size.z * sz)
		shape = box
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = float(spec.radius) * maxf(sx, sz)
		cyl.height = float(spec.height) * sy
		shape = cyl
	shape_cache[cache_key] = shape
	return shape


static func _attach_collider_batches(
	obstacle_body: StaticBody3D,
	batches: Dictionary,
	shape_cache: Dictionary,
	prefix: String,
	centerline: PackedVector3Array = PackedVector3Array(),
	max_track_dist_sq: float = INF
) -> void:
	for model_key_var in batches.keys():
		var model_key := str(model_key_var)
		var spec := _collider_spec_for_model(model_key)
		if spec.is_empty():
			continue
		var transforms: Array = batches[model_key_var]
		for idx in transforms.size():
			var tf: Transform3D = transforms[idx]
			if max_track_dist_sq < INF and not centerline.is_empty():
				var pos_2d := Vector2(tf.origin.x, tf.origin.z)
				if _min_dist_sq_to_track(pos_2d, centerline) > max_track_dist_sq:
					continue
			var rs := _extract_rot_and_scale(tf)
			var scale: Vector3 = rs.scale
			var uy: Vector3 = rs.uy
			var col := CollisionShape3D.new()
			col.name = "%s_%s_%d" % [prefix, model_key, idx]
			col.shape = _get_cached_collider_shape(shape_cache, model_key, spec, scale)
			col.transform = Transform3D(rs.rot as Basis, tf.origin + uy * (float(spec.center_y) * scale.y))
			obstacle_body.add_child(col)


static func _attach_environment_colliders(
	obstacle_body: StaticBody3D,
	arch_transforms: Array[Transform3D],
	trackside_batches: Dictionary,
	nature_batches: Dictionary,
	centerline: PackedVector3Array = PackedVector3Array(),
	outer_half: float = 9.0
) -> void:
	if obstacle_body == null:
		return
	var shape_cache := {}
	var arch_leg_spec := {"shape": "box", "size": Vector3(2.6, 5.2, 2.1), "center_y": 2.6}
	for idx in arch_transforms.size():
		var tf: Transform3D = arch_transforms[idx]
		var rs := _extract_rot_and_scale(tf)
		var scale: Vector3 = rs.scale
		var ux: Vector3 = rs.ux
		var uy: Vector3 = rs.uy
		var leg_shape := _get_cached_collider_shape(shape_cache, "checkpoint_arch_leg", arch_leg_spec, scale)
		for side_idx in range(2):
			var side_sign := -1.0 if side_idx == 0 else 1.0
			var col := CollisionShape3D.new()
			col.name = "Env_ArchLeg_%d_%d" % [idx, side_idx]
			col.shape = leg_shape
			col.transform = Transform3D(
				rs.rot as Basis,
				tf.origin + ux * (side_sign * 5.03 * scale.x) + uy * (2.6 * scale.y)
			)
			obstacle_body.add_child(col)

	var nature_reach := outer_half + 24.0
	var nature_max_sq := nature_reach * nature_reach
	_attach_collider_batches(obstacle_body, trackside_batches, shape_cache, "Env_Trackside", centerline, INF)
	_attach_collider_batches(obstacle_body, nature_batches, shape_cache, "Env_Nature", centerline, nature_max_sq)


static func _build_ground_centerline(centerline: PackedVector3Array, bridge_segments: Array, max_pts: int) -> PackedVector3Array:
	if centerline.is_empty():
		return centerline
	var bridge_lookup := _build_bridge_lookup(bridge_segments, centerline.size())
	var ground_pts := PackedVector3Array()
	for i in centerline.size():
		if not bridge_lookup.has(i):
			ground_pts.append(centerline[i])
	if ground_pts.size() < 4:
		return _downsample_centerline(centerline, max_pts)
	return _downsample_centerline(ground_pts, max_pts)


static func _downsample_centerline(centerline: PackedVector3Array, max_pts: int) -> PackedVector3Array:
	if centerline.size() <= max_pts:
		return centerline
	var out := PackedVector3Array()
	var step := float(centerline.size()) / float(max_pts)
	for i in max_pts:
		out.append(centerline[mini(centerline.size() - 1, int(floor(float(i) * step)))])
	return out


static func _min_dist_sq_to_track(point: Vector2, centerline: PackedVector3Array) -> float:
	var best := INF
	for cp in centerline:
		var dx := point.x - cp.x
		var dz := point.y - cp.z
		var d2 := dx * dx + dz * dz
		if d2 < best:
			best = d2
	return best


static func _is_near_occupied(point: Vector2, extra_padding: float, occupied: Array[Dictionary]) -> bool:
	for entry in occupied:
		var op: Vector2 = entry.pos
		var r := float(entry.radius) + extra_padding
		if point.distance_squared_to(op) < r * r:
			return true
	return false


static func _flat_tangent(centerline: PackedVector3Array, index: int) -> Vector3:
	var n := centerline.size()
	var prev := centerline[(index - 1 + n) % n]
	var next := centerline[(index + 1) % n]
	var t := next - prev
	t.y = 0.0
	return t.normalized() if t.length_squared() > 0.0001 else Vector3.FORWARD


static func _signed_turn_at(centerline: PackedVector3Array, index: int) -> float:
	var n := centerline.size()
	var t_prev := _flat_tangent(centerline, (index - 2 + n) % n)
	var t_next := _flat_tangent(centerline, (index + 2) % n)
	return t_prev.signed_angle_to(t_next, Vector3.UP)


static func _turn_angle_at(centerline: PackedVector3Array, index: int) -> float:
	return absf(_signed_turn_at(centerline, index))
