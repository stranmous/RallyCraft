extends Control
class_name TrackDrawingCanvas

signal drawing_processed(result: Dictionary)
signal path_status_changed(is_closed: bool, point_count: int, bridge_count: int)

const MODE_IDLE := 0
const MODE_SKETCHING := 1
const MODE_RESHAPING := 2

const CLOSE_SNAP_RADIUS := 36.0
const RESHAPE_GRAB_RADIUS := 48.0
const MIN_STROKE_SPACING := 6.0

var _drawing := PackedVector2Array()
var _preview := PackedVector2Array()
var _is_drawing := false
var _is_loop_closed := false
var _interaction_mode := MODE_IDLE
var _reshape_center_index := -1
var _reshape_last_pos := Vector2.ZERO
var _hover_snap_close := false
var _undo_stack: Array[Dictionary] = []
var _last_result: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_pointer(event.position, event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(event.position, event.pressed)
	elif event is InputEventScreenDrag and _is_drawing:
		_handle_drag(event.position)
	elif event is InputEventMouseMotion and _is_drawing:
		_handle_drag(event.position)


func clear_drawing() -> void:
	_drawing.clear()
	_preview.clear()
	_undo_stack.clear()
	_is_drawing = false
	_is_loop_closed = false
	_interaction_mode = MODE_IDLE
	_hover_snap_close = false
	_last_result = {}
	path_status_changed.emit(false, 0, 0)
	queue_redraw()


func is_loop_closed() -> bool:
	return _is_loop_closed


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func get_bridge_count() -> int:
	if _last_result.get("ok", false):
		return int(_last_result.get("preview", {}).get("bridge_count", 0))
	return TrackPathProcessor.detect_self_intersections(_drawing).size() if _drawing.size() >= 4 else 0


func undo_last_action() -> bool:
	if _undo_stack.is_empty():
		return false
	var snap: Dictionary = _undo_stack.pop_back()
	_drawing = (snap.get("drawing", PackedVector2Array()) as PackedVector2Array).duplicate()
	_is_loop_closed = bool(snap.get("closed", false))
	_hover_snap_close = false
	if _is_loop_closed and _drawing.size() >= TrackPathProcessor.MIN_INPUT_POINTS:
		_recompute_closed_loop(true)
	else:
		_preview.clear()
		_last_result = {}
		drawing_processed.emit({"ok": false, "errors": PackedStringArray(["Finish closing your loop or tap Close Loop."])})
		path_status_changed.emit(false, _drawing.size(), get_bridge_count())
		queue_redraw()
	return true


func close_loop_now() -> bool:
	if _drawing.size() < TrackPathProcessor.MIN_INPUT_POINTS:
		return false
	if not _is_loop_closed:
		_push_undo()
		_is_loop_closed = true
	_drawing = _resample_canvas_loop(_drawing, 18.0, 64)
	_recompute_closed_loop(true)
	return bool(_last_result.get("ok", false))


func load_preset_points(world_points: PackedVector2Array) -> void:
	if world_points.size() < TrackPathProcessor.MIN_INPUT_POINTS:
		return
	var bounds := Rect2(world_points[0], Vector2.ZERO)
	for p in world_points:
		bounds = bounds.expand(p)
	var span := maxf(maxf(bounds.size.x, bounds.size.y), 40.0)
	var usable := Vector2(maxf(size.x, 420.0), maxf(size.y, 300.0)) - Vector2(96.0, 96.0)
	var map_scale := minf(usable.x / span, usable.y / span)
	var world_center := bounds.position + bounds.size * 0.5
	var canvas_center := Vector2(maxf(size.x, 420.0), maxf(size.y, 300.0)) * 0.5
	var canvas_pts := PackedVector2Array()
	for p in world_points:
		canvas_pts.append(canvas_center + (p - world_center) * map_scale)
	_undo_stack.clear()
	_drawing = _resample_canvas_loop(canvas_pts, 18.0, 64)
	_is_loop_closed = true
	_recompute_closed_loop(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _push_undo() -> void:
	_undo_stack.append({
		"drawing": _drawing.duplicate(),
		"closed": _is_loop_closed,
	})
	if _undo_stack.size() > 24:
		_undo_stack.remove_at(0)


func _clamp_canvas_point(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 16.0, maxf(size.x - 16.0, 32.0)), clampf(pos.y, 16.0, maxf(size.y - 16.0, 32.0)))


func _handle_pointer(position: Vector2, pressed: bool) -> void:
	var clamped := _clamp_canvas_point(position)
	if pressed:
		if _is_loop_closed and _drawing.size() >= TrackPathProcessor.MIN_INPUT_POINTS:
			var grab_idx := _find_nearest_point_index(clamped, RESHAPE_GRAB_RADIUS)
			if grab_idx >= 0:
				_push_undo()
				_is_drawing = true
				_interaction_mode = MODE_RESHAPING
				_reshape_center_index = grab_idx
				_reshape_last_pos = clamped
				queue_redraw()
			return

		# Open sketching mode (multi-stroke friendly: pressing does not wipe previous strokes!)
		_push_undo()
		_is_drawing = true
		_interaction_mode = MODE_SKETCHING
		if _drawing.is_empty():
			_drawing.append(clamped)
		else:
			if _drawing.size() >= 10 and clamped.distance_to(_drawing[0]) <= CLOSE_SNAP_RADIUS:
				_is_drawing = false
				_interaction_mode = MODE_IDLE
				close_loop_now()
				return
			_connect_stroke_gap(clamped)
		path_status_changed.emit(false, _drawing.size(), get_bridge_count())
		queue_redraw()
		return

	if not _is_drawing:
		return
	_is_drawing = false
	if _interaction_mode == MODE_SKETCHING:
		_append_point(clamped)
		_hover_snap_close = false
		if _drawing.size() >= 10 and clamped.distance_to(_drawing[0]) <= CLOSE_SNAP_RADIUS:
			_is_loop_closed = true
			_drawing = _resample_canvas_loop(_drawing, 18.0, 64)
			_recompute_closed_loop(true)
		else:
			path_status_changed.emit(false, _drawing.size(), get_bridge_count())
			queue_redraw()
	elif _interaction_mode == MODE_RESHAPING:
		_recompute_closed_loop(true)
	_interaction_mode = MODE_IDLE
	_reshape_center_index = -1


func _handle_drag(position: Vector2) -> void:
	var clamped := _clamp_canvas_point(position)
	if _interaction_mode == MODE_SKETCHING:
		_append_point(clamped)
		_hover_snap_close = (_drawing.size() >= 10 and clamped.distance_to(_drawing[0]) <= CLOSE_SNAP_RADIUS)
		path_status_changed.emit(false, _drawing.size(), get_bridge_count())
		queue_redraw()
	elif _interaction_mode == MODE_RESHAPING and _reshape_center_index >= 0 and _drawing.size() >= 6:
		var delta := clamped - _reshape_last_pos
		if delta.length_squared() < 0.25:
			return
		_reshape_last_pos = clamped
		var n := _drawing.size()
		var sigma := clampf(float(n) * 0.12, 2.5, 9.0)
		var two_sigma_sq := 2.0 * sigma * sigma
		for i in n:
			var raw_dist := absi(i - _reshape_center_index)
			var cyc_dist := mini(raw_dist, n - raw_dist)
			var weight := exp(-float(cyc_dist * cyc_dist) / two_sigma_sq)
			if weight > 0.02:
				_drawing[i] = _clamp_canvas_point(_drawing[i] + delta * weight)
		_recompute_closed_loop(true)


func _connect_stroke_gap(target: Vector2) -> void:
	if _drawing.is_empty():
		_drawing.append(target)
		return
	var start_pt := _drawing[_drawing.size() - 1]
	var dist := start_pt.distance_to(target)
	if dist <= MIN_STROKE_SPACING:
		return
	var steps := clampi(int(floor(dist / 12.0)), 1, 24)
	for s in range(1, steps + 1):
		_drawing.append(start_pt.lerp(target, float(s) / float(steps)))


func _append_point(clamped: Vector2) -> void:
	if _drawing.is_empty() or _drawing[_drawing.size() - 1].distance_to(clamped) >= MIN_STROKE_SPACING:
		_drawing.append(clamped)


func _find_nearest_point_index(pos: Vector2, max_radius: float) -> int:
	var best_idx := -1
	var best_dist_sq := max_radius * max_radius
	for i in _drawing.size():
		var d_sq := _drawing[i].distance_squared_to(pos)
		if d_sq <= best_dist_sq:
			best_dist_sq = d_sq
			best_idx = i
	return best_idx


func _recompute_closed_loop(emit_signal: bool) -> void:
	var closed_input := _drawing.duplicate()
	if closed_input.size() >= 3:
		closed_input.append(closed_input[0])
	_last_result = TrackPathProcessor.process_drawing(closed_input)
	if _last_result.get("ok", false):
		_preview = _last_result.points
	else:
		_preview.clear()
	path_status_changed.emit(_is_loop_closed, _drawing.size(), get_bridge_count())
	if emit_signal:
		drawing_processed.emit(_last_result)
	queue_redraw()


func _resample_canvas_loop(points: PackedVector2Array, spacing: float, max_pts: int) -> PackedVector2Array:
	if points.size() < 4:
		return points.duplicate()
	var lengths: Array[float] = []
	var total := 0.0
	for i in points.size():
		var l := points[i].distance_to(points[(i + 1) % points.size()])
		lengths.append(l)
		total += l
	if total <= 1.0:
		return points.duplicate()
	var count := clampi(int(round(total / spacing)), 24, max_pts)
	var out := PackedVector2Array()
	var step_dist := total / float(count)
	for k in count:
		var target := float(k) * step_dist
		var acc := 0.0
		var seg := 0
		while seg < lengths.size() - 1 and acc + lengths[seg] < target:
			acc += lengths[seg]
			seg += 1
		var seg_len := maxf(lengths[seg], 0.001)
		var t := clampf((target - acc) / seg_len, 0.0, 1.0)
		out.append(points[seg].lerp(points[(seg + 1) % points.size()], t))
	return out


func _draw() -> void:
	# British Racing Green drafting board surface
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.CANVAS_BG, true)

	# Drafting grid lines (minor + major every 3 steps)
	var grid_step := 48.0
	var gx := grid_step
	var col_idx := 1
	while gx < size.x:
		var line_col := UITheme.CANVAS_GRID_MAJOR if (col_idx % 3 == 0) else UITheme.CANVAS_GRID_MINOR
		draw_line(Vector2(gx, 0.0), Vector2(gx, size.y), line_col, 1.0)
		gx += grid_step
		col_idx += 1
	var gy := grid_step
	var row_idx := 1
	while gy < size.y:
		var line_col := UITheme.CANVAS_GRID_MAJOR if (row_idx % 3 == 0) else UITheme.CANVAS_GRID_MINOR
		draw_line(Vector2(0.0, gy), Vector2(size.x, gy), line_col, 1.0)
		gy += grid_step
		row_idx += 1

	draw_rect(Rect2(Vector2.ZERO, size), UITheme.BORDER_GOLD, false, 2.0)

	# Determine which loop to render: interactive canvas-space closed loop OR preview loop (e.g. direct test assignment)
	if _is_loop_closed and _drawing.size() >= 3:
		_draw_closed_road_loop(_drawing)
		return

	if _preview.size() > 1:
		var preview_points := PackedVector2Array()
		var map_scale: float = minf(size.x, size.y) / 430.0
		for point in _preview:
			preview_points.append(size * 0.5 + point * map_scale)
		_draw_closed_road_loop(preview_points)
		return

	# Open sketching state (multi-stroke path in progress)
	if _drawing.size() >= 1:
		if _drawing.size() > 1:
			draw_polyline(_drawing, Color(0.02, 0.05, 0.04, 0.85), 11.0, true)
			draw_polyline(_drawing, UITheme.GOLD, 5.0, true)
			# Draw any self-intersections already visible while sketching
			for b in TrackPathProcessor.detect_self_intersections(_drawing):
				_draw_bridge_marker(b.get("point", Vector2.ZERO), b.get("tangent", Vector2.RIGHT), 5.0)
		# Start dot with snap-to-close halo
		var start_pt := _drawing[0]
		var halo_col := UITheme.EMERALD if _hover_snap_close else Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.36)
		var halo_radius := CLOSE_SNAP_RADIUS * 0.65 if _hover_snap_close else 15.0
		draw_arc(start_pt, halo_radius, 0.0, TAU, 24, halo_col, 2.0, true)
		draw_circle(start_pt, 7.5, UITheme.TEXT_PRIMARY)
		draw_circle(start_pt, 4.5, UITheme.EMERALD if _hover_snap_close else UITheme.GOLD)
		# Current stroke tip dot
		if _drawing.size() > 1:
			var tip_pt := _drawing[_drawing.size() - 1]
			draw_circle(tip_pt, 5.5, UITheme.GOLD_HOVER)


func _draw_closed_road_loop(loop_pts: PackedVector2Array) -> void:
	var closed := loop_pts.duplicate()
	closed.append(loop_pts[0])
	# Shadowed asphalt casing + warm road glow + crisp centerline
	draw_polyline(closed, Color(0.02, 0.05, 0.04, 0.90), 16.0, true)
	draw_polyline(closed, Color(0.953, 0.757, 0.294, 0.28), 11.5, true)
	draw_polyline(closed, UITheme.GOLD, 5.5, true)

	# 2D Bridge overpass crossing markers
	for bridge in TrackPathProcessor.detect_self_intersections(loop_pts):
		_draw_bridge_marker(bridge.get("point", Vector2.ZERO), bridge.get("tangent", Vector2.RIGHT), 5.5)

	# Subtle reshape control anchors every few vertices
	if _is_loop_closed and loop_pts.size() >= 12:
		var step := maxi(1, int(loop_pts.size() / 16))
		for i in range(0, loop_pts.size(), step):
			var is_grabbed := (_interaction_mode == MODE_RESHAPING and i == _reshape_center_index)
			draw_circle(loop_pts[i], 5.0 if is_grabbed else 3.4, UITheme.EMERALD if is_grabbed else UITheme.TEXT_PRIMARY)

	# Start / finish checkered flag bar perpendicular to track
	var dir := (loop_pts[1] - loop_pts[0]).normalized() if loop_pts.size() > 1 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var start_pt := loop_pts[0]
	draw_line(start_pt - perp * 11.0, start_pt + perp * 11.0, UITheme.TEXT_PRIMARY, 5.0, true)
	draw_circle(start_pt, 6.0, UITheme.DARK_INK)
	draw_circle(start_pt, 3.6, UITheme.EMERALD)


func _draw_bridge_marker(point: Vector2, tangent: Vector2, road_w: float) -> void:
	var dir := tangent.normalized() if tangent.length_squared() > 0.0001 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var span := dir * 13.0
	var rail := perp * (road_w + 3.5)
	# Underpass shadow gap + elevated upper deck + bright gold side parapets
	draw_line(point - span, point + span, UITheme.CANVAS_BG, road_w + 7.0, true)
	draw_line(point - span, point + span, UITheme.GOLD, road_w, true)
	draw_line(point - span - rail, point + span - rail, UITheme.TEXT_PRIMARY, 2.5, true)
	draw_line(point - span + rail, point + span + rail, UITheme.TEXT_PRIMARY, 2.5, true)
