extends Control
class_name RaceMinimap

const PADDING := 14.0

var _points := PackedVector2Array()
var _bounds := Rect2()
var _start_index := 0
var _ai_colors: Array[Color] = []
var _player_point := Vector2.ZERO
var _player_heading := Vector2(0.0, -1.0)
var _ai_points: Array[Vector2] = []
var _boost_pickups: Array[Dictionary] = []
var _has_state := false
var _hud_frameless := false
var _cached_size := Vector2(-1.0, -1.0)
var _cached_loop := PackedVector2Array()
var _cached_start_pt := Vector2.ZERO
var _world_bridges: Array[Dictionary] = []
var _cached_bridges: Array[Dictionary] = []
var _cached_pickup_pts := PackedVector2Array()
var _cached_pickup_size := Vector2(-1.0, -1.0)


func set_hud_frameless_mode(enabled: bool) -> void:
	if _hud_frameless == enabled:
		return
	_hud_frameless = enabled
	queue_redraw()


func configure(minimap_data: Dictionary, ai_colors: Array[Color] = []) -> void:
	_points = minimap_data.get("points", PackedVector2Array())
	_bounds = minimap_data.get("bounds", Rect2())
	_start_index = int(minimap_data.get("start_index", 0))
	_ai_colors = ai_colors.duplicate()
	_world_bridges = TrackPathProcessor.detect_self_intersections(_points)
	_cached_size = Vector2(-1.0, -1.0)
	_cached_pickup_size = Vector2(-1.0, -1.0)
	_cached_pickup_pts.clear()
	queue_redraw()


func update_state(player_point: Vector2, player_heading: Vector2, ai_points: Array[Vector2], boost_pickups: Array[Dictionary] = []) -> void:
	_player_point = player_point
	if player_heading.length_squared() > 0.001:
		_player_heading = player_heading.normalized()
	_ai_points = ai_points
	_boost_pickups = boost_pickups
	_has_state = true
	queue_redraw()


func world_to_map(world_point: Vector2) -> Vector2:
	var usable := size - Vector2(PADDING * 2.0, PADDING * 2.0)
	if usable.x <= 1.0 or usable.y <= 1.0:
		return size * 0.5
	var span_x := maxf(_bounds.size.x, 1.0)
	var span_y := maxf(_bounds.size.y, 1.0)
	var scale_factor := minf(usable.x / span_x, usable.y / span_y)
	var world_center := _bounds.position + _bounds.size * 0.5
	var map_center := size * 0.5
	return map_center + (world_point - world_center) * scale_factor


func _draw() -> void:
	if not _hud_frameless:
		var bg_rect := Rect2(Vector2.ZERO, size)
		draw_rect(bg_rect, UITheme.BG_BACKDROP, true)
		# Subtle racing grid inside boxed 2D preview
		var step := 44.0
		var gx := step
		while gx < size.x:
			draw_line(Vector2(gx, 0.0), Vector2(gx, size.y), UITheme.CANVAS_GRID_MINOR, 1.0)
			gx += step
		var gy := step
		while gy < size.y:
			draw_line(Vector2(0.0, gy), Vector2(size.x, gy), UITheme.CANVAS_GRID_MINOR, 1.0)
			gy += step
		draw_rect(bg_rect, UITheme.BORDER_SUBTLE, false, 1.5)

	if _points.size() < 2:
		return

	if _cached_size != size or _cached_loop.is_empty():
		_cached_size = size
		_cached_loop = PackedVector2Array()
		var stride := maxi(1, int(_points.size() / 110))
		for i in range(0, _points.size(), stride):
			_cached_loop.append(world_to_map(_points[i]))
		_cached_loop.append(_cached_loop[0])
		if _start_index >= 0 and _start_index < _points.size():
			_cached_start_pt = world_to_map(_points[_start_index])
		_cached_bridges.clear()
		for b in _world_bridges:
			var pt := world_to_map(b.get("point", Vector2.ZERO))
			var tang := (b.get("tangent", Vector2.RIGHT) as Vector2).normalized()
			_cached_bridges.append({"point": pt, "tangent": tang})

	# Outer shadowed casing and crisp inner road ribbon
	var casing_w := 10.5 if _hud_frameless else 9.0
	var ribbon_w := 5.0 if _hud_frameless else 4.5
	var casing_col := Color(0.02, 0.05, 0.04, 0.85) if _hud_frameless else Color(0.02, 0.06, 0.04, 0.96)
	var ribbon_col := Color(0.92, 0.94, 0.91, 0.94) if _hud_frameless else Color("b8cec3")
	draw_polyline(_cached_loop, casing_col, casing_w, true)
	draw_polyline(_cached_loop, ribbon_col, ribbon_w, true)

	# 2D Overpass bridge crossing markers (dark underpass gap + parallel Champagne Gold bridge rails)
	for bridge in _cached_bridges:
		var b_pt: Vector2 = bridge.point
		var b_dir: Vector2 = bridge.tangent
		var b_perp := Vector2(-b_dir.y, b_dir.x)
		var span := b_dir * 8.5
		var rail_offset := b_perp * (ribbon_w * 0.72 + 1.5)
		draw_line(b_pt - span, b_pt + span, casing_col, ribbon_w + 3.2, true)
		draw_line(b_pt - span, b_pt + span, ribbon_col, ribbon_w, true)
		draw_line(b_pt - span - rail_offset, b_pt + span - rail_offset, UITheme.GOLD, 2.2, true)
		draw_line(b_pt - span + rail_offset, b_pt + span + rail_offset, UITheme.GOLD, 2.2, true)

	# Start / Finish line marker
	if _start_index >= 0 and _start_index < _points.size():
		draw_circle(_cached_start_pt, 5.4, UITheme.TEXT_PRIMARY)
		draw_circle(_cached_start_pt, 3.2, UITheme.DARK_INK)

	# Boost pickup markers (strictly Champagne Gold / Muted Moss, no cyan)
	if _cached_pickup_size != size or _cached_pickup_pts.size() != _boost_pickups.size():
		_cached_pickup_size = size
		_cached_pickup_pts.resize(_boost_pickups.size())
		for i in _boost_pickups.size():
			_cached_pickup_pts[i] = world_to_map(_boost_pickups[i].get("map_point", Vector2.ZERO))
	for i in _boost_pickups.size():
		var map_pt := _cached_pickup_pts[i]
		var is_active: bool = _boost_pickups[i].get("active", false)
		if is_active:
			draw_circle(map_pt, 3.8, UITheme.DARK_INK)
			draw_circle(map_pt, 2.5, UITheme.GOLD)
		else:
			draw_circle(map_pt, 2.2, Color(UITheme.TEXT_MUTED.r, UITheme.TEXT_MUTED.g, UITheme.TEXT_MUTED.b, 0.55))

	if not _has_state:
		return

	# AI racer dots
	for i in _ai_points.size():
		var ai_pt := world_to_map(_ai_points[i])
		var col := _ai_colors[i % _ai_colors.size()] if not _ai_colors.is_empty() else UITheme.COPPER
		draw_circle(ai_pt, 4.8, UITheme.DARK_INK)
		draw_circle(ai_pt, 3.3, col)

	# Player dot & heading pointer on top
	var p_map := world_to_map(_player_point)
	var tip := p_map + _player_heading * 8.0
	draw_line(p_map, tip, UITheme.TEXT_PRIMARY, 2.4, true)
	draw_circle(p_map, 6.4, UITheme.TEXT_PRIMARY)
	draw_circle(p_map, 4.5, UITheme.GOLD)
