extends Control
class_name TrackSelectPanel

signal track_selected(track: TrackDefinition)
signal cancelled()

const FILTER_ALL := "all"
const FILTER_CURATED := "curated"
const FILTER_CUSTOM := "custom"

var _all_tracks: Array[TrackDefinition] = []
var _tracks: Array[TrackDefinition] = []
var _filter_mode := FILTER_ALL
var _selected_track: TrackDefinition
var _track_buttons: Dictionary = {} # track_id -> Button

var _preview_widget: TrackPreviewWidget
var _top_bar: Panel
var _back_btn: Button
var _header_label: Label
var _filter_buttons: Dictionary = {}
var _mode_2d_btn: Button
var _mode_3d_btn: Button

var _list_panel: Panel
var _list_title_label: Label
var _list_scroll: ScrollContainer
var _list_vbox: VBoxContainer

var _detail_panel: Panel
var _title_label: Label
var _badge_label: Label
var _desc_label: Label
var _stat_length_val: Label
var _stat_surface_val: Label
var _stat_width_val: Label
var _stat_biome_val: Label
var _record_card: Panel
var _records_label: Label
var _confirm_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.BG_BACKDROP
	add_child(bg)

	# Full-bleed live 3D/2D circuit backdrop behind the floating glass docks
	_preview_widget = TrackPreviewWidget.new()
	_preview_widget.name = "SelectTrackPreview"
	_preview_widget.set_full_bleed_mode(true)
	_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_3D)
	bg.add_child(_preview_widget)

	# Soft vignette top/bottom gradient wash for legibility
	var top_bar := Panel.new()
	top_bar.name = "SelectTopBar"
	top_bar.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TOPBAR_BG, 14, UITheme.BORDER_SUBTLE, 1, 8))
	add_child(top_bar)
	_top_bar = top_bar

	_back_btn = Button.new()
	_back_btn.name = "BackButton"
	_back_btn.text = "BACK"
	_back_btn.icon = AssetRegistry.load_icon("chevron_left")
	_back_btn.add_theme_constant_override("icon_max_width", 18)
	UITheme.style_secondary_button(_back_btn, 17, 11)
	_back_btn.pressed.connect(func() -> void: cancelled.emit())
	top_bar.add_child(_back_btn)

	_header_label = Label.new()
	_header_label.text = "SELECT CIRCUIT"
	UITheme.style_label(_header_label, 25, UITheme.TEXT_PRIMARY, true, false)
	top_bar.add_child(_header_label)

	var filter_specs := [
		[FILTER_ALL, "ALL"],
		[FILTER_CURATED, "CURATED"],
		[FILTER_CUSTOM, "CUSTOM"],
	]
	for spec in filter_specs:
		var f_id: String = spec[0]
		var f_btn := Button.new()
		f_btn.name = "Filter_%s_Button" % f_id
		f_btn.text = spec[1]
		f_btn.pressed.connect(func() -> void: _set_filter(f_id))
		top_bar.add_child(f_btn)
		_filter_buttons[f_id] = f_btn

	_mode_2d_btn = Button.new()
	_mode_2d_btn.name = "Select2DModeButton"
	_mode_2d_btn.text = "2D Map"
	_mode_2d_btn.pressed.connect(func() -> void:
		_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_2D)
		_refresh_view_toggle_buttons()
	)
	top_bar.add_child(_mode_2d_btn)

	_mode_3d_btn = Button.new()
	_mode_3d_btn.name = "Select3DModeButton"
	_mode_3d_btn.text = "3D Orbit"
	_mode_3d_btn.pressed.connect(func() -> void:
		_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_3D)
		_refresh_view_toggle_buttons()
	)
	top_bar.add_child(_mode_3d_btn)

	# Left Column: Floating Track Roster Dock
	_list_panel = Panel.new()
	_list_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_DARK, 16, UITheme.BORDER_GOLD, 2, 12))
	add_child(_list_panel)

	_list_title_label = Label.new()
	_list_title_label.text = "AVAILABLE TRACKS"
	UITheme.style_label(_list_title_label, 16, UITheme.GOLD, true, false)
	_list_panel.add_child(_list_title_label)

	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_panel.add_child(_list_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 10)
	_list_scroll.add_child(_list_vbox)

	# Right Column: Floating Circuit Telemetry & CTA Dock
	_detail_panel = Panel.new()
	_detail_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_DARK, 16, UITheme.BORDER_GOLD, 2, 12))
	add_child(_detail_panel)

	_badge_label = Label.new()
	UITheme.style_label(_badge_label, 14, UITheme.GOLD, true, false)
	_detail_panel.add_child(_badge_label)

	_title_label = Label.new()
	_title_label.clip_text = true
	UITheme.style_label(_title_label, 28, UITheme.TEXT_PRIMARY, true, false)
	_detail_panel.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.clip_text = true
	UITheme.style_label(_desc_label, 16, UITheme.TEXT_SECONDARY, false, false)
	_detail_panel.add_child(_desc_label)

	_stat_length_val = UITheme.make_stat_tile(_detail_panel, Vector2(20.0, 146.0), Vector2(180.0, 74.0), "LENGTH", "--")
	_stat_surface_val = UITheme.make_stat_tile(_detail_panel, Vector2(212.0, 146.0), Vector2(180.0, 74.0), "SURFACE", "--")
	_stat_width_val = UITheme.make_stat_tile(_detail_panel, Vector2(20.0, 228.0), Vector2(180.0, 74.0), "ROAD WIDTH", "--")
	_stat_biome_val = UITheme.make_stat_tile(_detail_panel, Vector2(212.0, 228.0), Vector2(180.0, 74.0), "BIOME", "--")

	_record_card = Panel.new()
	_record_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TILE_BG, 12, UITheme.BORDER_SUBTLE, 1, 0))
	_detail_panel.add_child(_record_card)

	_records_label = Label.new()
	_records_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_records_label, 16, UITheme.TEXT_PRIMARY, false, true)
	_record_card.add_child(_records_label)

	_confirm_btn = Button.new()
	_confirm_btn.name = "ConfirmTrackButton"
	_confirm_btn.text = "RACE THIS CIRCUIT"
	_confirm_btn.icon = AssetRegistry.load_icon("play")
	_confirm_btn.add_theme_constant_override("icon_max_width", 20)
	UITheme.style_primary_button(_confirm_btn, 20, 14)
	_confirm_btn.pressed.connect(confirm_selection)
	_detail_panel.add_child(_confirm_btn)

	if is_inside_tree() and get_viewport() != null:
		get_viewport().size_changed.connect(_layout_screen)
	_layout_screen()
	_refresh_filter_buttons()
	_refresh_view_toggle_buttons()
	refresh_catalog()


func _current_vp_size() -> Vector2:
	var vp := Vector2(1280.0, 720.0)
	if is_inside_tree() and get_viewport() != null:
		var vs := get_viewport().get_visible_rect().size
		if vs.x >= 640.0 and vs.y >= 360.0:
			vp = vs
	return vp


func _layout_screen() -> void:
	var vp := _current_vp_size()
	if _preview_widget != null:
		_preview_widget.position = Vector2.ZERO
		_preview_widget.size = vp
		_preview_widget.set_2d_safe_margins(452.0, 92.0, 444.0, 28.0)

	if _top_bar != null:
		_top_bar.position = Vector2(24.0, 14.0)
		_top_bar.size = Vector2(vp.x - 48.0, 56.0)
		_back_btn.position = Vector2(10.0, 9.0)
		_back_btn.size = Vector2(114.0, 38.0)
		_header_label.position = Vector2(138.0, 11.0)
		_header_label.size = Vector2(250.0, 34.0)

		var filter_x := clampf((vp.x - 48.0) * 0.5 - 160.0, 396.0, vp.x - 620.0)
		var f_keys := [FILTER_ALL, FILTER_CURATED, FILTER_CUSTOM]
		for i in f_keys.size():
			var btn: Button = _filter_buttons.get(f_keys[i])
			if btn != null:
				btn.position = Vector2(filter_x + float(i * 112), 9.0)
				btn.size = Vector2(104.0, 38.0)

		var bar_w := _top_bar.size.x
		_mode_2d_btn.position = Vector2(bar_w - 224.0, 9.0)
		_mode_2d_btn.size = Vector2(100.0, 38.0)
		_mode_3d_btn.position = Vector2(bar_w - 116.0, 9.0)
		_mode_3d_btn.size = Vector2(106.0, 38.0)

	if _list_panel != null:
		_list_panel.position = Vector2(24.0, 84.0)
		_list_panel.size = Vector2(424.0, vp.y - 104.0)
		_list_title_label.position = Vector2(20.0, 16.0)
		_list_title_label.size = Vector2(384.0, 24.0)
		_list_scroll.position = Vector2(16.0, 48.0)
		_list_scroll.size = Vector2(392.0, _list_panel.size.y - 64.0)

	if _detail_panel != null:
		_detail_panel.position = Vector2(vp.x - 436.0, 84.0)
		_detail_panel.size = Vector2(412.0, vp.y - 104.0)
		var dh := _detail_panel.size.y
		_badge_label.position = Vector2(20.0, 16.0)
		_badge_label.size = Vector2(372.0, 22.0)
		_title_label.position = Vector2(20.0, 40.0)
		_title_label.size = Vector2(372.0, 38.0)
		_desc_label.position = Vector2(20.0, 78.0)
		_desc_label.size = Vector2(372.0, 62.0)

		_record_card.position = Vector2(20.0, 312.0)
		_record_card.size = Vector2(372.0, maxf(90.0, dh - 400.0))
		_records_label.position = Vector2(16.0, 12.0)
		_records_label.size = Vector2(340.0, _record_card.size.y - 24.0)

		_confirm_btn.position = Vector2(20.0, dh - 72.0)
		_confirm_btn.size = Vector2(372.0, 56.0)


func refresh_tracks(initial_track_id: String = "") -> void:
	refresh_catalog(initial_track_id)


func refresh_catalog(initial_track_id: String = "") -> void:
	_all_tracks = CuratedTrackCatalog.get_all_tracks()
	_apply_filter(initial_track_id)


func _set_filter(mode: String) -> void:
	_filter_mode = mode
	_refresh_filter_buttons()
	_apply_filter("")


func _apply_filter(initial_track_id: String = "") -> void:
	_tracks.clear()
	for tr in _all_tracks:
		if _filter_mode == FILTER_CURATED and tr.source != TrackDefinition.SOURCE_CURATED:
			continue
		if _filter_mode == FILTER_CUSTOM and tr.source != TrackDefinition.SOURCE_CUSTOM:
			continue
		_tracks.append(tr)

	_track_buttons.clear()
	if _list_vbox != null:
		for child in _list_vbox.get_children():
			child.queue_free()

	for i in _tracks.size():
		var track := _tracks[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(374.0, 74.0)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		var tag := "FEATURED" if bool(track.metadata.get("featured", false)) else track.source.to_upper()
		var surface_cap := track.surface.capitalize()
		var biome_cap := str(BiomePresets.get_preset(track.theme).display_name)
		btn.text = "%d. %s\n   %s • %s • [%s]" % [i + 1, track.display_name, surface_cap, biome_cap, tag]
		var tid := track.track_id
		btn.pressed.connect(func() -> void: select_track_by_id(tid))
		if _list_vbox != null:
			_list_vbox.add_child(btn)
		_track_buttons[tid] = btn

	if _list_title_label != null:
		_list_title_label.text = "CIRCUIT ROSTER (%d)" % _tracks.size()

	if not initial_track_id.is_empty() and _track_buttons.has(initial_track_id):
		select_track_by_id(initial_track_id)
	elif _selected_track != null and _track_buttons.has(_selected_track.track_id):
		select_track_by_id(_selected_track.track_id)
	elif not _tracks.is_empty():
		select_track_by_id(_tracks[0].track_id)


func select_track_by_id(track_id: String) -> bool:
	for track in _tracks:
		if track.track_id == track_id:
			_selected_track = track
			_update_selection_ui()
			return true
	# If track belongs to unfiltered list, switch to ALL and select it cleanly
	for track in _all_tracks:
		if track.track_id == track_id:
			_filter_mode = FILTER_ALL
			_refresh_filter_buttons()
			_apply_filter(track_id)
			return true
	return false


func get_selected_track() -> TrackDefinition:
	return _selected_track


func get_track_count() -> int:
	return _tracks.size()


func get_preview_widget() -> TrackPreviewWidget:
	return _preview_widget


func confirm_selection() -> void:
	if _selected_track != null:
		track_selected.emit(_selected_track)


func _refresh_filter_buttons() -> void:
	for f_id in _filter_buttons.keys():
		var btn: Button = _filter_buttons[f_id]
		UITheme.style_gold_pill(btn, f_id == _filter_mode, 15, 10)


func _refresh_view_toggle_buttons() -> void:
	if _mode_2d_btn == null or _mode_3d_btn == null or _preview_widget == null:
		return
	var mode := _preview_widget.get_view_mode()
	UITheme.style_gold_pill(_mode_2d_btn, mode == TrackPreviewWidget.VIEW_2D, 15, 10)
	UITheme.style_gold_pill(_mode_3d_btn, mode == TrackPreviewWidget.VIEW_3D, 15, 10)


func _update_selection_ui() -> void:
	for tid in _track_buttons.keys():
		var btn: Button = _track_buttons[tid]
		UITheme.style_rim_pill(btn, _selected_track != null and tid == _selected_track.track_id, 17, 12)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	_refresh_view_toggle_buttons()
	if _selected_track == null or _title_label == null:
		return

	_title_label.text = _selected_track.display_name.to_upper()
	var is_featured := bool(_selected_track.metadata.get("featured", false))
	if is_featured:
		_badge_label.text = "FEATURED CURATED CIRCUIT"
	elif _selected_track.source == TrackDefinition.SOURCE_CURATED:
		_badge_label.text = "CURATED CIRCUIT"
	else:
		_badge_label.text = "CUSTOM LIBRARY CIRCUIT"

	var desc := str(_selected_track.metadata.get("description", ""))
	if desc.is_empty():
		desc = "Player-authored custom closed-loop circuit ready for Circuit Race or Time Trial."
	_desc_label.text = desc

	var compiled := _preview_widget.configure_track(_selected_track)
	var length_m := float(compiled.get("length", 0.0))
	var boost_count := (compiled.get("boost_anchors", []) as Array).size()
	var surface_str := _selected_track.surface.to_upper()
	var width_str := _selected_track.road_width.to_upper()
	var biome_str := str(BiomePresets.get_preset(_selected_track.theme).display_name).to_upper()

	_stat_length_val.text = "%.0f m" % length_m
	_stat_surface_val.text = surface_str
	_stat_width_val.text = width_str
	_stat_biome_val.text = biome_str

	var rec_res := RecordStore.new().load_record(_selected_track.track_id)
	var rec: Dictionary = rec_res.record if rec_res.record != null else {}
	var best_lap_ms := int(rec.get("best_lap_ms", 0))
	var best_race_ms := int(rec.get("best_race_ms", 0))
	var ghost_samples: Array = rec.get("ghost_samples", [])
	var lap_str := RaceResult.format_time(float(best_lap_ms) / 1000.0) if best_lap_ms > 0 else "--:--.---"
	var race_str := RaceResult.format_time(float(best_race_ms) / 1000.0) if best_race_ms > 0 else "--:--.---"
	var ghost_str := "GHOST READY (%d PTS)" % ghost_samples.size() if not ghost_samples.is_empty() else "NO GHOST YET"
	_records_label.text = (
		"PERSONAL RECORDS   •   %d BOOST PADS\n" % boost_count +
		"BEST LAP:   %s\n" % lap_str +
		"BEST RACE:  %s   •   %s" % [race_str, ghost_str]
	)
