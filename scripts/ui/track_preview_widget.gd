extends Control
class_name TrackPreviewWidget

const VIEW_2D := "2d"
const VIEW_3D := "3d"

var _view_mode := VIEW_2D
var _full_bleed := false
var _safe_margin_left := 0.0
var _safe_margin_top := 0.0
var _safe_margin_right := 0.0
var _safe_margin_bottom := 0.0

var _current_track: TrackDefinition
var _last_compiled: Dictionary = {}
var _3d_built_track_id := ""
var _2d_backdrop: ColorRect
var _minimap: RaceMinimap
var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _scene_root: Node3D
var _camera_pivot: Node3D
var _camera: Camera3D
var _overlay_controls: Control
var _btn_2d: Button
var _btn_3d: Button
var _hint_label: Label

var _orbit_yaw_deg := -35.0
var _orbit_pitch_deg := -36.0
var _orbit_distance := 280.0
var _orbit_center := Vector3.ZERO
var _auto_rotate := true
var _dragging := false


func _ready() -> void:
	clip_contents = true

	_2d_backdrop = ColorRect.new()
	_2d_backdrop.name = "Preview2DBackdrop"
	_2d_backdrop.color = UITheme.BG_BACKDROP
	_2d_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_2d_backdrop)

	_minimap = RaceMinimap.new()
	_minimap.name = "PreviewMinimap"
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_minimap)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "PreviewViewportContainer"
	_viewport_container.stretch = true
	_viewport_container.visible = false
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)

	# Mode toggle bar and orbit hint stacked cleanly in top-left corner (non-full-bleed mode)
	var overlay_vbox := VBoxContainer.new()
	overlay_vbox.name = "PreviewOverlayControls"
	overlay_vbox.position = Vector2(12.0, 10.0)
	overlay_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_vbox.add_theme_constant_override("separation", 6)
	add_child(overlay_vbox)
	_overlay_controls = overlay_vbox

	var toggle_bar := HBoxContainer.new()
	toggle_bar.name = "ViewToggleBar"
	toggle_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toggle_bar.add_theme_constant_override("separation", 6)
	overlay_vbox.add_child(toggle_bar)

	_btn_2d = Button.new()
	_btn_2d.text = "2D Map"
	_btn_2d.custom_minimum_size = Vector2(96.0, 34.0)
	_btn_2d.pressed.connect(func() -> void: set_view_mode(VIEW_2D))
	toggle_bar.add_child(_btn_2d)

	_btn_3d = Button.new()
	_btn_3d.text = "3D Orbit"
	_btn_3d.custom_minimum_size = Vector2(96.0, 34.0)
	_btn_3d.pressed.connect(func() -> void: set_view_mode(VIEW_3D))
	toggle_bar.add_child(_btn_3d)

	_hint_label = Label.new()
	_hint_label.name = "OrbitHintLabel"
	_hint_label.text = "Drag to rotate 3D preview"
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_hud_outlined_label(_hint_label, 15, UITheme.TEXT_PRIMARY, 4)
	_hint_label.visible = false
	overlay_vbox.add_child(_hint_label)

	resized.connect(_layout_preview_layers)
	set_full_bleed_mode(_full_bleed)
	set_view_mode(_view_mode)
	_layout_preview_layers()


func set_full_bleed_mode(enabled: bool) -> void:
	_full_bleed = enabled
	if _overlay_controls != null:
		_overlay_controls.visible = not enabled
	if _minimap != null:
		_minimap.set_hud_frameless_mode(enabled)
	_layout_preview_layers()


func set_2d_safe_margins(left: float, top: float, right: float, bottom: float) -> void:
	_safe_margin_left = left
	_safe_margin_top = top
	_safe_margin_right = right
	_safe_margin_bottom = bottom
	_layout_preview_layers()


func _layout_preview_layers() -> void:
	if _2d_backdrop != null:
		_2d_backdrop.position = Vector2.ZERO
		_2d_backdrop.size = size
	if _viewport_container != null:
		_viewport_container.position = Vector2.ZERO
		_viewport_container.size = size
	if _sub_viewport != null and size.x > 16.0 and size.y > 16.0:
		_sub_viewport.size = Vector2i(int(size.x), int(size.y))
	if _minimap != null:
		if _full_bleed:
			var w := maxf(180.0, size.x - _safe_margin_left - _safe_margin_right)
			var h := maxf(180.0, size.y - _safe_margin_top - _safe_margin_bottom)
			_minimap.position = Vector2(_safe_margin_left, _safe_margin_top)
			_minimap.size = Vector2(w, h)
		else:
			_minimap.position = Vector2.ZERO
			_minimap.size = size


func _is_effectively_visible() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	var parent_node: Node = get_parent()
	while parent_node != null:
		if parent_node is CanvasLayer and not (parent_node as CanvasLayer).visible:
			return false
		parent_node = parent_node.get_parent()
	return true


func _process(delta: float) -> void:
	var active_3d := _view_mode == VIEW_3D and _is_effectively_visible()
	if _sub_viewport != null:
		var target_mode := SubViewport.UPDATE_WHEN_VISIBLE if active_3d else SubViewport.UPDATE_DISABLED
		if _sub_viewport.render_target_update_mode != target_mode:
			_sub_viewport.render_target_update_mode = target_mode
	if not active_3d:
		return
	if _auto_rotate and not _dragging:
		_orbit_yaw_deg = fmod(_orbit_yaw_deg + delta * 12.6, 360.0)
		_update_camera_transform()


func _gui_input(event: InputEvent) -> void:
	if _view_mode != VIEW_3D:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_auto_rotate = false
	elif event is InputEventMouseMotion and _dragging:
		rotate_orbit(-event.relative.x * 0.45, -event.relative.y * 0.3)
	elif event is InputEventScreenDrag:
		_auto_rotate = false
		rotate_orbit(-event.relative.x * 0.45, -event.relative.y * 0.3)


func configure_track(track: TrackDefinition) -> Dictionary:
	if track == null:
		return {"ok": false}
	_current_track = track
	_3d_built_track_id = ""
	var compiled := TrackCompiler.compile(track)
	if not compiled.ok:
		return compiled
	_last_compiled = compiled

	if _minimap != null:
		_minimap.configure(compiled.minimap)
		var boost_markers: Array[Dictionary] = []
		var anchors: Array = compiled.get("boost_anchors", [])
		for bp in anchors:
			var pos: Vector3 = bp.position
			boost_markers.append({
				"map_point": Vector2(pos.x, pos.z),
				"active": true,
			})
		if not compiled.start_grid.is_empty():
			var start_pos: Vector3 = compiled.start_grid[0].position
			var start_hdg: Vector3 = compiled.start_grid[0].heading
			var empty_ai: Array[Vector2] = []
			_minimap.update_state(
				Vector2(start_pos.x, start_pos.z),
				Vector2(start_hdg.x, start_hdg.z),
				empty_ai,
				boost_markers
			)

	if _view_mode == VIEW_3D:
		_ensure_3d_preview()
	return compiled


func get_last_compiled() -> Dictionary:
	return _last_compiled


func set_view_mode(mode: String) -> void:
	if mode != VIEW_2D and mode != VIEW_3D:
		return
	_view_mode = mode
	if _2d_backdrop != null:
		_2d_backdrop.visible = (_view_mode == VIEW_2D)
	if _minimap != null:
		_minimap.visible = (_view_mode == VIEW_2D)
	if _viewport_container != null:
		_viewport_container.visible = (_view_mode == VIEW_3D)
	if _hint_label != null:
		_hint_label.visible = (_view_mode == VIEW_3D) and not _full_bleed
	if _view_mode == VIEW_3D:
		_ensure_3d_preview()
	_refresh_toggle_styles()
	_update_camera_transform()


func get_view_mode() -> String:
	return _view_mode


func get_orbit_yaw_deg() -> float:
	return _orbit_yaw_deg


func rotate_orbit(delta_yaw_deg: float, delta_pitch_deg: float = 0.0) -> void:
	_orbit_yaw_deg = fmod(_orbit_yaw_deg + delta_yaw_deg, 360.0)
	_orbit_pitch_deg = clampf(_orbit_pitch_deg + delta_pitch_deg, -75.0, -15.0)
	_update_camera_transform()


func _ensure_3d_preview() -> void:
	if _current_track == null:
		return
	if _sub_viewport == null:
		_sub_viewport = SubViewport.new()
		_sub_viewport.name = "PreviewSubViewport"
		_sub_viewport.own_world_3d = true
		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		_sub_viewport.size = Vector2i(max(int(size.x), 320), max(int(size.y), 200))
		if OS.has_feature("mobile"):
			_sub_viewport.scaling_3d_scale = 0.67
		_viewport_container.add_child(_sub_viewport)

		_scene_root = Node3D.new()
		_scene_root.name = "PreviewSceneRoot"
		_sub_viewport.add_child(_scene_root)

		_camera_pivot = Node3D.new()
		_camera_pivot.name = "OrbitPivot"
		_scene_root.add_child(_camera_pivot)

		_camera = Camera3D.new()
		_camera.name = "OrbitCamera"
		_camera.fov = 52.0
		_camera.near = 0.5
		_camera.far = 2000.0
		_camera_pivot.add_child(_camera)

	var build_key := "%s_%s_%s_%s" % [
		_current_track.track_id,
		_current_track.surface,
		_current_track.road_width,
		_current_track.theme,
	]
	if _3d_built_track_id == build_key:
		return
	_3d_built_track_id = build_key

	for child in _scene_root.get_children():
		if child != _camera_pivot:
			child.free()

	var compiled_rt := TrackCompiler.build_runtime(_current_track)
	if not compiled_rt.ok:
		return

	BiomePresets.apply_race_environment(_scene_root, compiled_rt, _current_track, false, true)

	var runtime_node: Node3D = compiled_rt.runtime
	_scene_root.add_child(runtime_node)

	var bounds: Rect2 = compiled_rt.minimap.get("bounds", Rect2(-120.0, -120.0, 240.0, 240.0))
	var center_2d := bounds.position + bounds.size * 0.5
	_orbit_center = Vector3(center_2d.x, 0.0, center_2d.y)
	var max_span := maxf(bounds.size.x, bounds.size.y)
	_orbit_distance = clampf(max_span * (0.85 if _full_bleed else 0.95), 140.0, 480.0)
	_auto_rotate = true
	_update_camera_transform()


func _update_camera_transform() -> void:
	if _camera_pivot == null or _camera == null:
		return
	_camera_pivot.position = _orbit_center
	_camera_pivot.rotation_degrees = Vector3(_orbit_pitch_deg, _orbit_yaw_deg, 0.0)
	_camera.position = Vector3(0.0, 0.0, _orbit_distance)
	_camera.rotation = Vector3.ZERO


func _refresh_toggle_styles() -> void:
	if _btn_2d == null or _btn_3d == null:
		return
	UITheme.style_gold_pill(_btn_2d, _view_mode == VIEW_2D, 15, 10)
	UITheme.style_gold_pill(_btn_3d, _view_mode == VIEW_3D, 15, 10)
