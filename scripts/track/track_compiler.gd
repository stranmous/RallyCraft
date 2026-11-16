extends RefCounted
class_name TrackCompiler

const ROAD_HALF_WIDTHS := {"narrow": 5.0, "standard": 7.0, "wide": 9.0}
const CURB_WIDTH := 0.8
const CURB_HEIGHT := 0.04
const BRIDGE_CLEARANCE := 6.8
const BRIDGE_HALF_SPAN := 14
const DENSE_CENTERLINE_THRESHOLD := 48
const TARGET_SEGMENT_SPACING := 4.0
const CHECKPOINT_SPACING := 72.0
const BOOST_MIN_SPACING := 90.0
const BOOST_MIN_START_CLEARANCE := 40.0
const BOOST_MAX_TURN_RADIANS := 0.22
const GRID_ROW_SPACING := 12.0
const GRID_LANE_OFFSET := 2.8


static func compile(track: TrackDefinition) -> Dictionary:
	var errors := track.validate()
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var centerline := _build_centerline(track)
	if centerline.size() < TrackDefinition.MIN_CENTERLINE_POINTS:
		return {"ok": false, "errors": PackedStringArray(["Track has too few usable centerline points."])}
	var bridge_segments := _find_bridge_segments(_project_to_2d(centerline))
	_apply_bridge_elevation(centerline, bridge_segments)
	var half_width: float = ROAD_HALF_WIDTHS[track.road_width]
	var geometry := _build_road_geometry(centerline, half_width)
	var bridge_mesh := _build_bridge_support_mesh(centerline, bridge_segments, half_width)
	var checkpoints := _build_checkpoints(centerline, half_width)
	var start_grid := _build_start_grid(centerline, half_width)
	var minimap := _build_minimap_data(centerline)
	var boost_anchors := _build_safe_boost_anchors(centerline)
	var road_mesh := _create_mesh(geometry.road_vertices, geometry.road_normals, geometry.road_uvs, geometry.road_indices)
	var curb_mesh := _create_mesh(geometry.curb_vertices, geometry.curb_normals, geometry.curb_uvs, geometry.curb_indices)
	var marking_mesh := _create_mesh(geometry.mark_vertices, geometry.mark_normals, geometry.mark_uvs, geometry.mark_indices)
	var embankment_mesh := _build_embankment_mesh(centerline, bridge_segments, half_width)
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"centerline": centerline,
		"half_width": half_width,
		"road_mesh": road_mesh,
		"curb_mesh": curb_mesh,
		"marking_mesh": marking_mesh,
		"embankment_mesh": embankment_mesh,
		"bridge_mesh": bridge_mesh,
		"collision_faces": geometry.road_faces,
		"bridge_segments": bridge_segments,
		"checkpoints": checkpoints,
		"start_grid": start_grid,
		"minimap": minimap,
		"boost_anchors": boost_anchors,
		"length": _get_loop_length(centerline),
	}


static func build_runtime(track: TrackDefinition) -> Dictionary:
	var compiled := compile(track)
	if not compiled.ok:
		return compiled
	var root := Node3D.new()
	root.name = "CompiledTrack_%s" % track.track_id

	var road := MeshInstance3D.new()
	road.name = "Road"
	road.mesh = compiled.road_mesh
	road.material_override = AssetRegistry.create_road_material_for_theme(track.surface, track.theme)
	road.position.y = 0.02
	root.add_child(road)

	var curbs := MeshInstance3D.new()
	curbs.name = "Curbs"
	curbs.mesh = compiled.curb_mesh
	curbs.material_override = AssetRegistry.create_curb_material(track.surface)
	curbs.position.y = 0.02
	root.add_child(curbs)

	if compiled.get("marking_mesh") != null:
		var markings := MeshInstance3D.new()
		markings.name = "RoadMarkings"
		markings.mesh = compiled.marking_mesh
		var mark_mat := StandardMaterial3D.new()
		mark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mark_mat.roughness = 0.65
		if track.surface == "dirt":
			mark_mat.albedo_color = Color("e6d5b873")
			mark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		else:
			mark_mat.albedo_color = Color("f1f5f9")
		markings.material_override = mark_mat
		markings.position.y = 0.026
		root.add_child(markings)

	if not compiled.checkpoints.is_empty():
		var start_cp: Dictionary = compiled.checkpoints[0]
		var road_total_width := float(ROAD_HALF_WIDTHS[track.road_width]) * 2.0
		var start_line := MeshInstance3D.new()
		start_line.name = "StartFinishLine"
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(road_total_width, 0.04, 1.1)
		start_line.mesh = line_mesh
		var line_mat := StandardMaterial3D.new()
		line_mat.albedo_color = Color("e2e8f0")
		line_mat.roughness = 0.85
		start_line.material_override = line_mat
		var cp_tangent: Vector3 = start_cp.tangent
		var cp_yaw := atan2(-cp_tangent.x, -cp_tangent.z)
		start_line.position = start_cp.position + Vector3.UP * 0.04
		start_line.rotation.y = cp_yaw
		root.add_child(start_line)

		var gantry_scale_x := (road_total_width + CURB_WIDTH * 2.0 + 1.2) / 12.882
		var start_gantry := AssetRegistry.instantiate_trackside("start_gantry")
		if start_gantry != null:
			start_gantry.name = "StartGantry"
			start_gantry.position = start_cp.position + Vector3.UP * 0.02
			start_gantry.rotation.y = cp_yaw
			start_gantry.scale = Vector3(gantry_scale_x, 1.0, 1.0)
			root.add_child(start_gantry)

		var cp_lateral := Vector3(-cp_tangent.z, 0.0, cp_tangent.x).normalized()
		for side in [-1.0, 1.0]:
			var flag_node := AssetRegistry.instantiate_trackside("flag_checkered")
			if flag_node != null:
				flag_node.name = "StartFlag_%s" % ("L" if side < 0.0 else "R")
				var flag_pos: Vector3 = start_cp.position + cp_lateral * (side * (road_total_width * 0.5 + 2.2))
				if flag_pos.y > 0.25:
					flag_pos.y = maxf(0.0, flag_pos.y - 0.18)
				flag_node.position = flag_pos
				flag_node.rotation.y = cp_yaw + (PI * 0.5 if side < 0.0 else -PI * 0.5)
				root.add_child(flag_node)

	if compiled.get("embankment_mesh") != null:
		var embankment := MeshInstance3D.new()
		embankment.name = "Embankment"
		embankment.mesh = compiled.embankment_mesh
		embankment.material_override = _create_material(BiomePresets.get_embankment_color(track.theme))
		root.add_child(embankment)

	if compiled.bridge_mesh != null:
		var bridge_supports := MeshInstance3D.new()
		bridge_supports.name = "BridgeSupports"
		bridge_supports.mesh = compiled.bridge_mesh
		bridge_supports.material_override = _create_material(BiomePresets.get_bridge_color(track.theme))
		root.add_child(bridge_supports)

	var collision_body := StaticBody3D.new()
	collision_body.name = "RoadCollision"
	collision_body.position.y = 0.02
	var collision := CollisionShape3D.new()
	collision.name = "RoadSurface"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(compiled.collision_faces)
	collision.shape = shape
	collision_body.add_child(collision)
	root.add_child(collision_body)
	if not compiled.checkpoints.is_empty():
		var start_cp: Dictionary = compiled.checkpoints[0]
		var road_total_width := float(ROAD_HALF_WIDTHS[track.road_width]) * 2.0
		var gantry_scale_x := (road_total_width + CURB_WIDTH * 2.0 + 1.2) / 12.882
		var cp_tangent: Vector3 = start_cp.tangent
		var cp_yaw := atan2(-cp_tangent.x, -cp_tangent.z)
		var gantry_basis := Basis.from_euler(Vector3(0.0, cp_yaw, 0.0))
		var gantry_body := StaticBody3D.new()
		gantry_body.name = "StartGantryBody"
		var pillar_shape := BoxShape3D.new()
		pillar_shape.size = Vector3(1.26 * gantry_scale_x, 6.72, 1.84)
		for side in [-1.0, 1.0]:
			var pillar_col := CollisionShape3D.new()
			pillar_col.name = "StartGantryPillar_%s" % ("L" if side < 0.0 else "R")
			pillar_col.shape = pillar_shape
			var local_pos := Vector3(side * 7.07 * gantry_scale_x, 3.36, 0.0)
			pillar_col.transform = Transform3D(gantry_basis, start_cp.position + gantry_basis * local_pos)
			gantry_body.add_child(pillar_col)
		root.add_child(gantry_body)

	var boost_root := Node3D.new()
	boost_root.name = "BoostPickups"
	var boost_nodes: Array[Node3D] = []
	var fallback_pad_mesh := CylinderMesh.new()
	fallback_pad_mesh.top_radius = 1.65
	fallback_pad_mesh.bottom_radius = 1.85
	fallback_pad_mesh.height = 0.24
	fallback_pad_mesh.radial_segments = 12
	fallback_pad_mesh.rings = 1
	var fallback_pad_mat := StandardMaterial3D.new()
	fallback_pad_mat.albedo_color = Color("f3c14b")
	fallback_pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for anchor in compiled.boost_anchors:
		var heading: Vector3 = anchor.get("heading", Vector3.FORWARD)
		var pad_visual := AssetRegistry.instantiate_trackside("boost_pad")
		var pad: Node3D
		if pad_visual != null:
			pad = pad_visual
			pad.position = anchor.position - Vector3.UP * 0.67
			pad.rotation.y = atan2(-heading.x, -heading.z)
		else:
			var fallback_pad := MeshInstance3D.new()
			fallback_pad.mesh = fallback_pad_mesh
			fallback_pad.material_override = fallback_pad_mat
			fallback_pad.position = anchor.position - Vector3.UP * 0.45
			pad = fallback_pad
		pad.name = "BoostPad_%d" % int(anchor.index)
		boost_root.add_child(pad)
		boost_nodes.append(pad)
	root.add_child(boost_root)
	compiled["boost_pickup_nodes"] = boost_nodes
	compiled["runtime"] = root
	return compiled


static func _build_centerline(track: TrackDefinition) -> PackedVector3Array:
	var raw_points := PackedVector3Array()
	for index in track.centerline_points.size():
		var point := track.centerline_points[index]
		var elevation := 0.0
		if index < track.elevation_profile.size():
			elevation = track.elevation_profile[index]
		raw_points.append(Vector3(point.x, elevation, point.y))
	if raw_points.size() < TrackDefinition.MIN_CENTERLINE_POINTS:
		return raw_points
	if raw_points.size() >= DENSE_CENTERLINE_THRESHOLD:
		return raw_points
	return _resample_catmull_rom(raw_points, TARGET_SEGMENT_SPACING)


static func _resample_catmull_rom(points: PackedVector3Array, target_spacing: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	var n := points.size()
	for i in n:
		var p0 := points[(i - 1 + n) % n]
		var p1 := points[i]
		var p2 := points[(i + 1) % n]
		var p3 := points[(i + 2) % n]
		var seg_len := p1.distance_to(p2)
		var samples := clampi(int(round(seg_len / target_spacing)), 4, 32)
		for s in samples:
			var t := float(s) / float(samples)
			var pt := _catmull_rom_3d(p0, p1, p2, p3, t)
			pt.y = maxf(pt.y, 0.0)
			result.append(pt)
	return result


static func _catmull_rom_3d(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


static func _project_to_2d(points_3d: PackedVector3Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points_3d:
		result.append(Vector2(p.x, p.z))
	return result


static func _find_bridge_segments(points: PackedVector2Array) -> Array[Dictionary]:
	var bridges: Array[Dictionary] = []
	var half_span := mini(BRIDGE_HALF_SPAN, maxi(2, points.size() / 4))
	for first_index in points.size():
		var first_next := (first_index + 1) % points.size()
		for second_index in range(first_index + 2, points.size()):
			var second_next := (second_index + 1) % points.size()
			if first_index == second_next or first_next == second_index:
				continue
			var crossing: Variant = _segment_intersection(points[first_index], points[first_next], points[second_index], points[second_next])
			if crossing == null:
				continue
			var bridge_start := (second_index - half_span + points.size()) % points.size()
			var bridge_end := (second_index + half_span + 1) % points.size()
			bridges.append({
				"start_index": bridge_start,
				"end_index": bridge_end,
				"crossing": crossing,
				"clearance": BRIDGE_CLEARANCE,
			})
	return bridges


static func _apply_bridge_elevation(centerline: PackedVector3Array, bridges: Array[Dictionary]) -> void:
	for bridge in bridges:
		var start_index: int = bridge.start_index
		var end_index: int = bridge.end_index
		var span_count := _cyclic_distance(start_index, end_index, centerline.size())
		for offset in range(span_count + 1):
			var index := (start_index + offset) % centerline.size()
			var progress := float(offset) / maxf(float(span_count), 1.0)
			var ramp := 0.5 * (1.0 - cos(progress * TAU))
			centerline[index].y = maxf(centerline[index].y, ramp * BRIDGE_CLEARANCE)


static func _build_road_geometry(centerline: PackedVector3Array, half_width: float) -> Dictionary:
	var road_vertices := PackedVector3Array()
	var road_normals := PackedVector3Array()
	var road_uvs := PackedVector2Array()
	var road_indices := PackedInt32Array()
	var road_faces := PackedVector3Array()
	var curb_vertices := PackedVector3Array()
	var curb_normals := PackedVector3Array()
	var curb_uvs := PackedVector2Array()
	var curb_indices := PackedInt32Array()
	var mark_vertices := PackedVector3Array()
	var mark_normals := PackedVector3Array()
	var mark_uvs := PackedVector2Array()
	var mark_indices := PackedInt32Array()
	var travelled := 0.0
	var stripe_outer := maxf(0.5, half_width - 0.44)
	var stripe_inner := maxf(0.28, half_width - 0.66)
	var center_half := 0.09
	var n := centerline.size()
	var point_laterals := PackedVector3Array()
	point_laterals.resize(n)
	for index in n:
		var previous := centerline[(index - 1 + n) % n]
		var current := centerline[index]
		var following := centerline[(index + 1) % n]
		var tangent := (following - previous)
		tangent.y = 0.0
		tangent = tangent.normalized()
		var lateral := Vector3(-tangent.z, 0.0, tangent.x)
		point_laterals[index] = lateral
		var left := current - lateral * half_width
		var right := current + lateral * half_width
		road_vertices.append(left)
		road_vertices.append(right)
		road_normals.append(Vector3.UP)
		road_normals.append(Vector3.UP)
		road_uvs.append(Vector2(0.0, travelled / 12.0))
		road_uvs.append(Vector2(1.0, travelled / 12.0))
		_append_curb_pair(curb_vertices, curb_normals, curb_uvs, current, lateral, half_width, travelled)
		for edge_pt in [
			current - lateral * stripe_outer,
			current - lateral * stripe_inner,
			current + lateral * stripe_inner,
			current + lateral * stripe_outer,
		]:
			mark_vertices.append(edge_pt)
			mark_normals.append(Vector3.UP)
			mark_uvs.append(Vector2(0.0, travelled / 12.0))
		travelled += current.distance_to(following)
	for index in n:
		var next := (index + 1) % n
		_append_quad_indices(road_indices, index * 2, next * 2, index * 2 + 1, next * 2 + 1)
		var curb_base := index * 4
		var curb_next := next * 4
		_append_quad_indices(curb_indices, curb_base, curb_next, curb_base + 1, curb_next + 1)
		_append_quad_indices(curb_indices, curb_base + 2, curb_next + 2, curb_base + 3, curb_next + 3)
		var lo0 := curb_vertices[curb_base]
		var ro0 := curb_vertices[curb_base + 3]
		var lo1 := curb_vertices[curb_next]
		var ro1 := curb_vertices[curb_next + 3]
		road_faces.append_array(PackedVector3Array([lo0, lo1, ro0, ro0, lo1, ro1]))
		_append_quad_indices(mark_indices, curb_base, curb_next, curb_base + 1, curb_next + 1)
		_append_quad_indices(mark_indices, curb_base + 2, curb_next + 2, curb_base + 3, curb_next + 3)
		if index % 2 == 0:
			var c0 := centerline[index]
			var c1 := centerline[next]
			var l0 := point_laterals[index]
			var l1 := point_laterals[next]
			var q_base := mark_vertices.size()
			mark_vertices.append(c0 - l0 * center_half)
			mark_vertices.append(c0 + l0 * center_half)
			mark_vertices.append(c1 - l1 * center_half)
			mark_vertices.append(c1 + l1 * center_half)
			for _m in 4:
				mark_normals.append(Vector3.UP)
				mark_uvs.append(Vector2(0.5, 0.5))
			_append_quad_indices(mark_indices, q_base, q_base + 2, q_base + 1, q_base + 3)
	return {
		"road_vertices": road_vertices,
		"road_normals": road_normals,
		"road_uvs": road_uvs,
		"road_indices": road_indices,
		"road_faces": road_faces,
		"curb_vertices": curb_vertices,
		"curb_normals": curb_normals,
		"curb_uvs": curb_uvs,
		"curb_indices": curb_indices,
		"mark_vertices": mark_vertices,
		"mark_normals": mark_normals,
		"mark_uvs": mark_uvs,
		"mark_indices": mark_indices,
	}


static func _append_curb_pair(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, center: Vector3, lateral: Vector3, half_width: float, distance: float) -> void:
	var left_outer := center - lateral * (half_width + CURB_WIDTH)
	var left_inner := center - lateral * half_width + Vector3.UP * CURB_HEIGHT
	var right_inner := center + lateral * half_width + Vector3.UP * CURB_HEIGHT
	var right_outer := center + lateral * (half_width + CURB_WIDTH)
	for point in [left_outer, left_inner, right_inner, right_outer]:
		vertices.append(point)
		normals.append(Vector3.UP)
	uvs.append(Vector2(0.0, distance / 12.0))
	uvs.append(Vector2(1.0, distance / 12.0))
	uvs.append(Vector2(0.0, distance / 12.0))
	uvs.append(Vector2(1.0, distance / 12.0))


static func _append_quad_indices(indices: PackedInt32Array, bottom_left: int, top_left: int, bottom_right: int, top_right: int) -> void:
	indices.append_array(PackedInt32Array([bottom_left, bottom_right, top_left, bottom_right, top_right, top_left]))


static func _build_embankment_mesh(centerline: PackedVector3Array, bridges: Array[Dictionary], half_width: float) -> ArrayMesh:
	var max_elev := 0.0
	for p in centerline:
		max_elev = maxf(max_elev, p.y)
	if max_elev <= 0.25:
		return null

	var skip_indices := {}
	for bridge in bridges:
		var start_index: int = bridge.start_index
		var end_index: int = bridge.end_index
		var span := _cyclic_distance(start_index, end_index, centerline.size())
		for offset in range(span + 1):
			skip_indices[(start_index + offset) % centerline.size()] = true

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var outer_half := half_width + CURB_WIDTH
	var skirt_flare := 2.4

	for index in centerline.size():
		var next := (index + 1) % centerline.size()
		if skip_indices.has(index) or skip_indices.has(next):
			continue
		var c0 := centerline[index]
		var c1 := centerline[next]
		if c0.y <= 0.08 and c1.y <= 0.08:
			continue

		var t0 := _flat_tangent(centerline, index)
		var l0 := Vector3(-t0.z, 0.0, t0.x)
		var t1 := _flat_tangent(centerline, next)
		var l1 := Vector3(-t1.z, 0.0, t1.x)

		# Left embankment slope
		var lt0 := c0 - l0 * outer_half
		var lb0 := Vector3(lt0.x - l0.x * skirt_flare, -0.05, lt0.z - l0.z * skirt_flare)
		var lt1 := c1 - l1 * outer_half
		var lb1 := Vector3(lt1.x - l1.x * skirt_flare, -0.05, lt1.z - l1.z * skirt_flare)
		_append_skirt_quad(vertices, normals, uvs, indices, lt0, lt1, lb0, lb1, (-l0 + Vector3.UP).normalized())

		# Right embankment slope
		var rt0 := c0 + l0 * outer_half
		var rb0 := Vector3(rt0.x + l0.x * skirt_flare, -0.05, rt0.z + l0.z * skirt_flare)
		var rt1 := c1 + l1 * outer_half
		var rb1 := Vector3(rt1.x + l1.x * skirt_flare, -0.05, rt1.z + l1.z * skirt_flare)
		_append_skirt_quad(vertices, normals, uvs, indices, rt0, rt1, rb0, rb1, (l0 + Vector3.UP).normalized())

	return _create_mesh(vertices, normals, uvs, indices)


static func _append_skirt_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, top0: Vector3, top1: Vector3, bot0: Vector3, bot1: Vector3, normal: Vector3) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([top0, top1, bot0, bot1]))
	for _i in 4:
		normals.append(normal)
	uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]))
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))


static func _build_bridge_support_mesh(centerline: PackedVector3Array, bridges: Array[Dictionary], half_width: float) -> ArrayMesh:
	if bridges.is_empty():
		return null
	var bridge_indices := {}
	for bridge in bridges:
		var span := _cyclic_distance(int(bridge.start_index), int(bridge.end_index), centerline.size())
		for offset in range(span + 1):
			bridge_indices[(int(bridge.start_index) + offset) % centerline.size()] = true

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var lower_road_clearance := half_width + CURB_WIDTH + half_width * 0.65
	for bridge in bridges:
		var start_index: int = bridge.start_index
		var end_index: int = bridge.end_index
		var span_count := _cyclic_distance(start_index, end_index, centerline.size())
		var candidate_ratios: Array[float] = [0.24, 0.36, 0.64, 0.76]
		var placed := 0
		for ratio in candidate_ratios:
			var idx := (start_index + int(round(float(span_count) * ratio))) % centerline.size()
			var point := centerline[idx]
			if point.y <= 0.6:
				continue
			if _is_near_lower_road(point, centerline, bridge_indices, lower_road_clearance):
				continue
			_append_box(
				vertices, normals, uvs, indices,
				point - Vector3(half_width * 0.42, point.y * 0.5, half_width * 0.42),
				Vector3(half_width * 0.84, point.y, half_width * 0.84)
			)
			placed += 1
		if placed == 0:
			# Edge portal columns outside road corridor if bridge crosses at shallow angle
			for ratio in [0.35, 0.65]:
				var idx := (start_index + int(round(float(span_count) * ratio))) % centerline.size()
				var point := centerline[idx]
				if point.y <= 0.6:
					continue
				var tang := _flat_tangent(centerline, idx)
				var lat := Vector3(-tang.z, 0.0, tang.x)
				for side: float in [-1.0, 1.0]:
					var col_pt: Vector3 = point + lat * (side * (half_width + CURB_WIDTH + 0.9))
					if _is_near_lower_road(col_pt, centerline, bridge_indices, half_width + CURB_WIDTH + 1.2):
						continue
					_append_box(
						vertices, normals, uvs, indices,
						col_pt - Vector3(0.75, col_pt.y * 0.5, 0.75),
						Vector3(1.5, col_pt.y, 1.5)
					)
	return _create_mesh(vertices, normals, uvs, indices)


static func _is_near_lower_road(point: Vector3, centerline: PackedVector3Array, bridge_indices: Dictionary, clearance: float) -> bool:
	var clearance_sq := clearance * clearance
	var p2 := Vector2(point.x, point.z)
	for i in centerline.size():
		if bridge_indices.has(i):
			continue
		var c := centerline[i]
		if c.y >= point.y - 1.2:
			continue
		var dx := p2.x - c.x
		var dz := p2.y - c.z
		if dx * dx + dz * dz < clearance_sq:
			return true
	return false


static func _append_box(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, origin: Vector3, box_size: Vector3) -> void:
	var base := vertices.size()
	var corners := PackedVector3Array([
		origin, origin + Vector3(box_size.x, 0, 0), origin + Vector3(box_size.x, box_size.y, 0), origin + Vector3(0, box_size.y, 0),
		origin + Vector3(0, 0, box_size.z), origin + Vector3(box_size.x, 0, box_size.z), origin + box_size, origin + Vector3(0, box_size.y, box_size.z),
	])
	vertices.append_array(corners)
	for _index in corners.size():
		normals.append(Vector3.UP)
		uvs.append(Vector2.ZERO)
	var faces := PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6, 0, 4, 5, 0, 5, 1, 3, 2, 6, 3, 6, 7, 1, 5, 6, 1, 6, 2, 0, 3, 7, 0, 7, 4])
	for face_index in faces:
		indices.append(base + face_index)


static func _create_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _create_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _build_checkpoints(centerline: PackedVector3Array, half_width: float) -> Array[Dictionary]:
	var checkpoints: Array[Dictionary] = []
	var distance_since_last := CHECKPOINT_SPACING
	var travelled := 0.0
	for index in centerline.size():
		var next := (index + 1) % centerline.size()
		if distance_since_last >= CHECKPOINT_SPACING or index == 0:
			var tangent := _flat_tangent(centerline, index)
			checkpoints.append({
				"index": index,
				"position": centerline[index],
				"tangent": tangent,
				"width": half_width * 3.2,
				"route_distance": travelled,
			})
			distance_since_last = 0.0
		var segment_length := centerline[index].distance_to(centerline[next])
		travelled += segment_length
		distance_since_last += segment_length
	return checkpoints


static func _build_start_grid(centerline: PackedVector3Array, half_width: float) -> Array[Dictionary]:
	var grid: Array[Dictionary] = []
	var n := centerline.size()
	for racer_index in 8:
		var row: int = racer_index >> 1
		var stagger: float = float(racer_index % 2) * 5.0
		var back_dist := float(row) * GRID_ROW_SPACING + stagger
		var sample := _sample_centerline_backwards(centerline, back_dist)
		var sample_pos: Vector3 = sample.position
		var sample_tangent: Vector3 = sample.tangent
		var lateral := Vector3(-sample_tangent.z, 0.0, sample_tangent.x)
		var lane_sign: float = -1.0 if racer_index % 2 == 0 else 1.0
		grid.append({
			"racer_index": racer_index,
			"position": sample_pos + lateral * (lane_sign * minf(GRID_LANE_OFFSET, half_width * 0.45)),
			"heading": sample_tangent,
		})
	return grid


static func _sample_centerline_backwards(centerline: PackedVector3Array, back_dist: float) -> Dictionary:
	var n := centerline.size()
	if n == 0:
		return {"position": Vector3.ZERO, "tangent": Vector3.FORWARD}
	if back_dist <= 0.01:
		return {"position": centerline[0], "tangent": _flat_tangent(centerline, 0)}
	var remaining := back_dist
	var idx := 0
	for _step in n:
		var prev_idx := (idx - 1 + n) % n
		var seg_len := centerline[idx].distance_to(centerline[prev_idx])
		if remaining <= seg_len and seg_len > 0.001:
			var t := remaining / seg_len
			var pos := centerline[idx].lerp(centerline[prev_idx], t)
			var tangent := _flat_tangent(centerline, prev_idx).lerp(_flat_tangent(centerline, idx), 1.0 - t).normalized()
			return {"position": pos, "tangent": tangent}
		remaining -= seg_len
		idx = prev_idx
	return {"position": centerline[0], "tangent": _flat_tangent(centerline, 0)}


static func _build_minimap_data(centerline: PackedVector3Array) -> Dictionary:
	var points := PackedVector2Array()
	var bounds := Rect2(Vector2(centerline[0].x, centerline[0].z), Vector2.ZERO)
	for point in centerline:
		var map_point := Vector2(point.x, point.z)
		points.append(map_point)
		bounds = bounds.expand(map_point)
	return {"points": points, "bounds": bounds, "start_index": 0}


static func _build_safe_boost_anchors(centerline: PackedVector3Array) -> Array[Dictionary]:
	var anchors: Array[Dictionary] = []
	var distance_since_last := BOOST_MIN_SPACING
	var route_distance := 0.0
	var total_length := _get_loop_length(centerline)
	for index in centerline.size():
		var next := (index + 1) % centerline.size()
		var tangent_before := _flat_tangent(centerline, (index - 1 + centerline.size()) % centerline.size())
		var tangent_after := _flat_tangent(centerline, index)
		var turn := absf(tangent_before.signed_angle_to(tangent_after, Vector3.UP))
		var dist_from_start := minf(route_distance, maxf(0.0, total_length - route_distance))
		var start_Dist_3d := centerline[index].distance_to(centerline[0])
		if index != 0 and dist_from_start >= BOOST_MIN_START_CLEARANCE and start_Dist_3d >= BOOST_MIN_START_CLEARANCE and distance_since_last >= BOOST_MIN_SPACING and turn <= BOOST_MAX_TURN_RADIANS:
			anchors.append({
				"index": index,
				"position": centerline[index] + Vector3.UP * 0.7,
				"heading": tangent_after,
				"route_distance": route_distance,
			})
			distance_since_last = 0.0
		var segment_length := centerline[index].distance_to(centerline[next])
		route_distance += segment_length
		distance_since_last += segment_length
	return anchors


static func _flat_tangent(centerline: PackedVector3Array, index: int) -> Vector3:
	var previous := centerline[(index - 1 + centerline.size()) % centerline.size()]
	var following := centerline[(index + 1) % centerline.size()]
	var tangent := following - previous
	tangent.y = 0.0
	return tangent.normalized()


static func _get_loop_length(points: PackedVector3Array) -> float:
	var length := 0.0
	for index in points.size():
		length += points[index].distance_to(points[(index + 1) % points.size()])
	return length


static func _cyclic_distance(start_index: int, end_index: int, size: int) -> int:
	return (end_index - start_index + size) % size


static func _segment_intersection(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Variant:
	var first := b - a
	var second := d - c
	var denominator := first.cross(second)
	if absf(denominator) < 0.001:
		return null
	var offset := c - a
	var first_ratio := offset.cross(second) / denominator
	var second_ratio := offset.cross(first) / denominator
	if first_ratio < 0.0 or first_ratio >= 1.0 or second_ratio < 0.0 or second_ratio >= 1.0:
		return null
	return a + first * first_ratio
