extends RefCounted
class_name AssetRegistry

const CAR_MODELS := {
	"rally_coupe": "res://assets/models/cars/rally_coupe.glb",
	"rally_hatch": "res://assets/models/cars/rally_hatch.glb",
	"touring_sedan": "res://assets/models/cars/touring_sedan.glb",
}

const CAR_VARIANT_ORDER: Array[String] = [
	"rally_coupe",
	"rally_hatch",
	"touring_sedan",
]

const TRACKSIDE_MODELS := {
	"start_gantry": "res://assets/models/trackside/start_gantry.glb",
	"checkpoint_arch": "res://assets/models/trackside/checkpoint_arch.glb",
	"boost_pad": "res://assets/models/trackside/boost_pad.glb",
	"flag_checkered": "res://assets/models/trackside/flag_checkered.glb",
	"barrier_wall": "res://assets/models/trackside/barrier_wall.glb",
	"guardrail_double": "res://assets/models/trackside/guardrail_double.glb",
	"grandstand_covered": "res://assets/models/trackside/grandstand_covered.glb",
	"paddock_tent": "res://assets/models/trackside/paddock_tent.glb",
	"tire_stack": "res://assets/models/trackside/tire_stack.glb",
	"traffic_cone": "res://assets/models/trackside/traffic_cone.glb",
	"wood_fence": "res://assets/models/trackside/wood_fence.glb",
}

const NATURE_MODELS := {
	"pine_tall": "res://assets/models/nature/pine_tall.glb",
	"pine_round": "res://assets/models/nature/pine_round.glb",
	"pine_dense": "res://assets/models/nature/pine_dense.glb",
	"tree_oak": "res://assets/models/nature/tree_oak.glb",
	"tree_parkland": "res://assets/models/nature/tree_parkland.glb",
	"tree_rounded": "res://assets/models/nature/tree_rounded.glb",
	"tree_meadow": "res://assets/models/nature/tree_meadow.glb",
	"tree_stump": "res://assets/models/nature/tree_stump.glb",
	"bush_lush": "res://assets/models/nature/bush_lush.glb",
	"grass_clump": "res://assets/models/nature/grass_clump.glb",
	"flower_clump": "res://assets/models/nature/flower_clump.glb",
	"palm_desert": "res://assets/models/nature/palm_desert.glb",
	"cactus_small": "res://assets/models/nature/cactus_small.glb",
	"cactus_saguaro": "res://assets/models/nature/cactus_saguaro.glb",
	"rock_boulder": "res://assets/models/nature/rock_boulder.glb",
	"rock_cluster": "res://assets/models/nature/rock_cluster.glb",
	"alpine_mountain_a": "res://assets/models/nature/alpine_mountain_a.glb",
	"alpine_mountain_b": "res://assets/models/nature/alpine_mountain_b.glb",
	"hill_treed": "res://assets/models/nature/hill_treed.glb",
	"hill_mound": "res://assets/models/nature/hill_mound.glb",
	"rock_alpine": "res://assets/models/nature/rock_alpine.glb",
	"conifer_compact": "res://assets/models/nature/conifer_compact.glb",
	"sky_cloud": "res://assets/models/nature/sky_cloud.glb",
}

const SURFACE_TEXTURES := {
	"road_asphalt": "res://assets/textures/surfaces/road_asphalt.png",
	"road_dirt": "res://assets/textures/surfaces/road_dirt.png",
	"curb_concrete": "res://assets/textures/surfaces/curb_concrete.png",
	"ground_grass": "res://assets/textures/surfaces/ground_grass.png",
	"ground_sand": "res://assets/textures/surfaces/ground_sand.png",
}

const VFX_TEXTURES := {
	"dust_puff": "res://assets/textures/vfx/dust_puff.png",
	"boost_flare": "res://assets/textures/vfx/boost_flare.png",
	"spark_hit": "res://assets/textures/vfx/spark_hit.png",
}

const UI_ICONS := {
	"play": "res://assets/icons/play.svg",
	"map": "res://assets/icons/map.svg",
	"route": "res://assets/icons/route.svg",
	"pencil": "res://assets/icons/pencil.svg",
	"folder": "res://assets/icons/folder.svg",
	"trophy": "res://assets/icons/trophy.svg",
	"flag": "res://assets/icons/flag.svg",
	"pause": "res://assets/icons/pause.svg",
	"rotate_ccw": "res://assets/icons/rotate_ccw.svg",
	"sliders": "res://assets/icons/sliders.svg",
	"house": "res://assets/icons/house.svg",
	"share": "res://assets/icons/share.svg",
	"download": "res://assets/icons/download.svg",
	"upload": "res://assets/icons/upload.svg",
	"trash": "res://assets/icons/trash.svg",
	"zap": "res://assets/icons/zap.svg",
	"chevron_left": "res://assets/icons/chevron_left.svg",
	"chevron_right": "res://assets/icons/chevron_right.svg",
	"volume_on": "res://assets/icons/volume_on.svg",
	"volume_off": "res://assets/icons/volume_off.svg",
	"car": "res://assets/icons/car.svg",
	"timer": "res://assets/icons/timer.svg",
	"plus": "res://assets/icons/plus.svg",
	"copy": "res://assets/icons/copy.svg",
	"check": "res://assets/icons/check.svg",
	"close": "res://assets/icons/close.svg",
}

const AUDIO_SFX := {
	"engine_loop": "res://assets/audio/sfx/engine_loop.wav",
	"tire_skid": "res://assets/audio/sfx/tire_skid.wav",
	"boost_pickup": "res://assets/audio/sfx/boost_pickup.ogg",
	"boost_engage": "res://assets/audio/sfx/boost_engage.ogg",
	"impact_bump": "res://assets/audio/sfx/impact_bump.ogg",
	"countdown_beep": "res://assets/audio/sfx/countdown_beep.ogg",
	"lap_complete": "res://assets/audio/sfx/lap_complete.ogg",
	"finish_fanfare": "res://assets/audio/sfx/finish_fanfare.ogg",
	"ui_click": "res://assets/audio/sfx/ui_click.ogg",
	"ui_confirm": "res://assets/audio/sfx/ui_confirm.ogg",
	"ui_back": "res://assets/audio/sfx/ui_back.ogg",
}

const AUDIO_MUSIC := {
	"menu_theme": "res://assets/audio/music/menu_theme.ogg",
	"race_theme": "res://assets/audio/music/race_theme.ogg",
}


static func get_all_asset_paths() -> Array[String]:
	var paths: Array[String] = []
	for bucket in [CAR_MODELS, TRACKSIDE_MODELS, NATURE_MODELS, SURFACE_TEXTURES, VFX_TEXTURES, UI_ICONS, AUDIO_SFX, AUDIO_MUSIC]:
		for key in bucket.keys():
			paths.append(str(bucket[key]))
	return paths


static func instantiate_car_visual(variant_index: int = 0, body_color: Color = Color("e5a83a"), as_ghost: bool = false) -> Node3D:
	var key := CAR_VARIANT_ORDER[posmod(variant_index, CAR_VARIANT_ORDER.size())]
	var path := str(CAR_MODELS.get(key, ""))
	var root := _instantiate_glb(path)
	if root == null:
		return _build_fallback_car_visual(body_color, as_ghost)
	root.name = "GhostVisual" if as_ghost else "CarVisual"
	if as_ghost:
		var ghost_mat := StandardMaterial3D.new()
		ghost_mat.albedo_color = Color("6fd6ee88")
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_apply_override_all_surfaces(root, ghost_mat)
		return root
	_apply_car_paint_color(root, body_color)
	return root


static func instantiate_trackside(key: String) -> Node3D:
	return _instantiate_glb(str(TRACKSIDE_MODELS.get(key, "")))


static func instantiate_nature(key: String) -> Node3D:
	return _instantiate_glb(str(NATURE_MODELS.get(key, "")))


static func load_surface_texture(key: String) -> Texture2D:
	var path := str(SURFACE_TEXTURES.get(key, ""))
	return _load_texture(path)


static func load_vfx_texture(key: String) -> Texture2D:
	var path := str(VFX_TEXTURES.get(key, ""))
	return _load_texture(path)


static func load_icon(key: String) -> Texture2D:
	var path := str(UI_ICONS.get(key, ""))
	return _load_texture(path)


static func load_audio_stream(key: String, looping: bool = false) -> AudioStream:
	var path := str(AUDIO_SFX.get(key, AUDIO_MUSIC.get(key, "")))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if not (res is AudioStream):
		return null
	var stream: AudioStream = res
	if looping:
		if stream is AudioStreamWAV:
			var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
			var total_samples := maxi(1, roundi(wav.get_length() * float(maxi(1, wav.mix_rate))))
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			if wav.loop_end <= 0 or wav.loop_end > total_samples:
				wav.loop_end = total_samples
			return wav
		elif stream is AudioStreamOggVorbis:
			var ogg := (stream as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
			ogg.loop = true
			return ogg
	return stream


static func create_road_material(surface_name: String) -> StandardMaterial3D:
	return create_road_material_for_theme(surface_name, "forest")


static func create_road_material_for_theme(surface_name: String, theme_name: String) -> StandardMaterial3D:
	var is_dirt := surface_name == "dirt"
	var preset := BiomePresets.get_preset(theme_name)
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.94 if is_dirt else 0.88
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tex := load_surface_texture("road_dirt" if is_dirt else "road_asphalt")
	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = (preset.get("road_dirt_tint", Color("ebd4b7")) if is_dirt else preset.get("road_asphalt_tint", Color("dde3ea"))) as Color
		mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		mat.albedo_color = Color("a67b50") if is_dirt else Color("6c737d")
	return mat


static func create_curb_material(surface_name: String) -> StandardMaterial3D:
	var is_dirt := surface_name == "dirt"
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.86
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tex := load_surface_texture("curb_concrete")
	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = Color("f0e2ce") if is_dirt else Color("ffffff")
		mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		mat.albedo_color = Color("eae4d6")
	return mat


static func create_ground_material(is_desert: bool) -> StandardMaterial3D:
	return create_ground_material_for_theme("desert" if is_desert else "forest")


static func create_ground_material_for_theme(theme_name: String) -> StandardMaterial3D:
	var preset := BiomePresets.get_preset(theme_name)
	var tex_key := str(preset.get("ground_texture", "ground_grass"))
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	var tex := load_surface_texture(tex_key)
	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = preset.get("ground_albedo", Color("77997a")) as Color
		mat.uv1_scale = Vector3(52.0, 52.0, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		mat.albedo_color = preset.get("ground_bottom", Color("385346")) as Color
	return mat


static func _instantiate_glb(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene := ResourceLoader.load(path)
	if scene is PackedScene:
		var node := (scene as PackedScene).instantiate()
		if node is Node3D:
			return node as Node3D
		if node != null:
			node.free()
	return null


static func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	return res as Texture2D


static func _apply_car_paint_color(root: Node, body_color: Color) -> void:
	var paint_mat := StandardMaterial3D.new()
	paint_mat.resource_name = "BodyPaint"
	paint_mat.albedo_color = body_color
	paint_mat.metallic = 0.22
	paint_mat.roughness = 0.34

	var accent_mat := StandardMaterial3D.new()
	accent_mat.resource_name = "BodyAccent"
	accent_mat.albedo_color = body_color.darkened(0.32)
	accent_mat.metallic = 0.18
	accent_mat.roughness = 0.44

	for mesh_inst in _collect_mesh_instances(root):
		var mesh := mesh_inst.mesh
		if mesh == null:
			continue
		var unique_mesh: Mesh = null
		for surf_idx in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surf_idx)
			if mat == null:
				continue
			var mat_name := mat.resource_name.to_lower()
			if mat_name.contains("bodypaint"):
				if unique_mesh == null:
					unique_mesh = mesh.duplicate(false) as Mesh
				unique_mesh.surface_set_material(surf_idx, paint_mat)
			elif mat_name.contains("bodyaccent"):
				if unique_mesh == null:
					unique_mesh = mesh.duplicate(false) as Mesh
				unique_mesh.surface_set_material(surf_idx, accent_mat)
		if unique_mesh != null:
			mesh_inst.mesh = unique_mesh


static func _apply_override_all_surfaces(root: Node, override_mat: Material) -> void:
	for mesh_inst in _collect_mesh_instances(root):
		mesh_inst.material_override = override_mat


static func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		list.append(root as MeshInstance3D)
	for child in root.get_children():
		list.append_array(_collect_mesh_instances(child))
	return list


static func _build_fallback_car_visual(body_color: Color, as_ghost: bool) -> Node3D:
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "GhostFallback" if as_ghost else "CarFallback"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.8, 0.7, 3.4)
	body_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6fd6ee88") if as_ghost else body_color
	if as_ghost:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		material.metallic = 0.15
	body_mesh.material_override = material
	body_mesh.position = Vector3(0.0, 0.35, 0.0)
	return body_mesh
