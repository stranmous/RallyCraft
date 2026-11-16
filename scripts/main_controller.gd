extends Node
class_name MainController

const MENU_ACTIONS: Array[String] = ["Play", "Track Select", "Create Track", "Library"]
const AI_CAR_COLORS: Array[Color] = [
	Color("d55c50"), # Red
	Color("3b82f6"), # Blue
	Color("22c55e"), # Green
	Color("f97316"), # Orange
	Color("a855f7"), # Purple
	Color("06b6d4"), # Cyan
	Color("e2e8f0"), # Silver
]

var _status_label: Label
var _navigation_layer: CanvasLayer
var _race_root: Node3D
var _preview_player_car: RallyCar
var _preview_ai_cars: Array[RallyCar] = []
var _preview_ai_drivers: Array[AIDriver] = []
var _debug_label: Label
var _debug_visible := false
var _active_track: TrackDefinition
var _last_event_setup := {
	"mode": RaceResult.MODE_CIRCUIT,
	"laps": 3,
	"ai_count": 3,
}

# Home screen showcase references
var _home_background: ColorRect
var _home_top_bar: Panel
var _home_brand_title: Label
var _home_brand_subtitle: Label
var _home_badge_label: Label
var _home_menu_dock: Panel
var _home_featured_card: Panel
var _home_kicker_label: Label
var _home_mode_2d_btn: Button
var _home_mode_3d_btn: Button
var _home_track_title: Label
var _home_track_meta: Label
var _home_stat_length: Label
var _home_stat_surface: Label
var _home_stat_width: Label
var _home_stat_biome: Label
var _home_records_card: Panel
var _home_track_records: Label
var _home_prev_btn: Button
var _home_next_btn: Button
var _home_preview_widget: TrackPreviewWidget
var _home_sfx_button: Button
var _home_music_button: Button

# Menu & global audio state
var _sfx_muted := false
var _music_muted := false
var _menu_music_player: AudioStreamPlayer
var _ui_sfx_players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile"):
		get_viewport().scaling_3d_scale = minf(get_viewport().scaling_3d_scale, 0.67)
		if OS.has_feature("android"):
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	var storage_error := TrackStore.new().ensure_storage()
	if storage_error != OK:
		push_error("Unable to initialize local RallyCraft storage: %s" % error_string(storage_error))
	_active_track = CuratedTrackCatalog.get_featured_track()
	_init_menu_audio()
	_build_navigation_shell()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_layout_navigation_shell):
		get_viewport().size_changed.connect(_layout_navigation_shell)
	_refresh_home_card()


func _build_navigation_shell() -> void:
	var layer := CanvasLayer.new()
	layer.name = "NavigationShell"
	add_child(layer)
	_navigation_layer = layer

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = UITheme.BG_BACKDROP
	layer.add_child(background)
	_home_background = background

	# Full-bleed interactive 3D / 2D circuit backdrop (Option 1 + Palette 4)
	_home_preview_widget = TrackPreviewWidget.new()
	_home_preview_widget.name = "HomeTrackPreview"
	_home_preview_widget.set_full_bleed_mode(true)
	_home_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_3D)
	background.add_child(_home_preview_widget)

	# Full-width top header bar
	var top_bar := Panel.new()
	top_bar.name = "HomeTopBar"
	top_bar.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TOPBAR_BG, 14, UITheme.BORDER_SUBTLE, 1, 8))
	background.add_child(top_bar)
	_home_top_bar = top_bar

	_home_brand_title = Label.new()
	_home_brand_title.text = "RALLYCRAFT 3D"
	_home_brand_title.position = Vector2(18.0, 8.0)
	_home_brand_title.size = Vector2(280.0, 40.0)
	UITheme.style_label(_home_brand_title, 30, UITheme.GOLD, true, false)
	top_bar.add_child(_home_brand_title)

	_home_brand_subtitle = Label.new()
	_home_brand_subtitle.text = "CREATE • RACE • MASTER"
	_home_brand_subtitle.position = Vector2(298.0, 17.0)
	_home_brand_subtitle.size = Vector2(260.0, 24.0)
	UITheme.style_label(_home_brand_subtitle, 15, UITheme.TEXT_SECONDARY, true, false)
	top_bar.add_child(_home_brand_subtitle)

	_home_badge_label = Label.new()
	_home_badge_label.name = "HomeActiveBadgeLabel"
	_home_badge_label.text = "FEATURED CURATED CIRCUIT"
	_home_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(_home_badge_label, 15, UITheme.GOLD, true, false)
	top_bar.add_child(_home_badge_label)

	_home_sfx_button = Button.new()
	_home_sfx_button.name = "HomeSfxButton"
	_home_sfx_button.add_theme_constant_override("icon_max_width", 16)
	_home_sfx_button.pressed.connect(func() -> void:
		_set_sfx_muted(not _sfx_muted)
		_play_ui_sfx("ui_click")
	)
	top_bar.add_child(_home_sfx_button)

	_home_music_button = Button.new()
	_home_music_button.name = "HomeMusicButton"
	_home_music_button.add_theme_constant_override("icon_max_width", 16)
	_home_music_button.pressed.connect(func() -> void:
		_set_music_muted(not _music_muted)
		_play_ui_sfx("ui_click")
	)
	top_bar.add_child(_home_music_button)
	_refresh_home_audio_buttons()

	# Left floating smoked-glass Navigation Dock
	var menu_dock := Panel.new()
	menu_dock.name = "HomeMenuDock"
	menu_dock.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_DARK, 18, UITheme.BORDER_SUBTLE, 2, 12))
	background.add_child(menu_dock)
	_home_menu_dock = menu_dock

	var menu_kicker := Label.new()
	menu_kicker.text = "RACE & WORKSHOP"
	menu_kicker.position = Vector2(20.0, 16.0)
	menu_kicker.size = Vector2(292.0, 22.0)
	UITheme.style_label(menu_kicker, 15, UITheme.TEXT_MUTED, true, false)
	menu_dock.add_child(menu_kicker)

	var left_col := VBoxContainer.new()
	left_col.name = "HomeMenuColumn"
	left_col.position = Vector2(18.0, 44.0)
	left_col.size = Vector2(296.0, 344.0)
	left_col.add_theme_constant_override("separation", 14)
	menu_dock.add_child(left_col)

	for action_name in MENU_ACTIONS:
		var button := Button.new()
		button.name = "%sButton" % action_name.replace(" ", "")
		button.text = action_name.to_upper()
		button.custom_minimum_size = Vector2(296.0, 72.0 if action_name == "Play" else 62.0)
		button.add_theme_constant_override("icon_max_width", 24 if action_name == "Play" else 20)
		if action_name == "Play":
			UITheme.style_primary_button(button, 25, 14)
			button.icon = AssetRegistry.load_icon("play")
			button.pressed.connect(func() -> void:
				_play_ui_sfx("ui_confirm")
				_show_quick_play_picker()
			)
		elif action_name == "Track Select":
			UITheme.style_secondary_button(button, 20, 13)
			button.icon = AssetRegistry.load_icon("map")
			button.pressed.connect(func() -> void:
				_play_ui_sfx("ui_click")
				_show_track_select()
			)
		elif action_name == "Create Track":
			UITheme.style_secondary_button(button, 20, 13)
			button.icon = AssetRegistry.load_icon("pencil")
			button.pressed.connect(func() -> void:
				_play_ui_sfx("ui_click")
				_show_track_builder()
			)
		elif action_name == "Library":
			UITheme.style_secondary_button(button, 20, 13)
			button.icon = AssetRegistry.load_icon("folder")
			button.pressed.connect(func() -> void:
				_play_ui_sfx("ui_click")
				_show_library_and_records()
			)
		left_col.add_child(button)

	var controls_card := Panel.new()
	controls_card.name = "HomeControlsSummary"
	controls_card.position = Vector2(18.0, 398.0)
	controls_card.size = Vector2(296.0, 126.0)
	controls_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TILE_BG, 12, UITheme.BORDER_SUBTLE, 1, 0))
	menu_dock.add_child(controls_card)

	var controls_title := Label.new()
	controls_title.text = "TOUCH CONTROLS"
	controls_title.position = Vector2(14.0, 10.0)
	controls_title.size = Vector2(268.0, 20.0)
	UITheme.style_label(controls_title, 14, UITheme.GOLD, true, false)
	controls_card.add_child(controls_title)

	var controls_body := Label.new()
	controls_body.text = "Touch Left / Right Screen: Steer\nCorner Pads: Analog Drift Brake\nRight Pad: Nitro Boost"
	controls_body.position = Vector2(14.0, 34.0)
	controls_body.size = Vector2(268.0, 84.0)
	controls_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(controls_body, 15, UITheme.TEXT_SECONDARY, false, false)
	controls_card.add_child(controls_body)

	_status_label = Label.new()
	_status_label.name = "HomeStatusLabel"
	_status_label.text = "Featured track ready: Spa Ardennes"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_status_label, 16, UITheme.TEXT_MUTED, false, false)
	menu_dock.add_child(_status_label)

	# Right floating smoked-glass Active Circuit Showcase Dock
	var featured_card := Panel.new()
	featured_card.name = "FeaturedTrackCard"
	featured_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_DARK, 18, UITheme.BORDER_GOLD, 2, 12))
	background.add_child(featured_card)
	_home_featured_card = featured_card

	_home_kicker_label = Label.new()
	_home_kicker_label.position = Vector2(20.0, 18.0)
	_home_kicker_label.size = Vector2(184.0, 24.0)
	_home_kicker_label.text = "ACTIVE CIRCUIT"
	UITheme.style_label(_home_kicker_label, 15, UITheme.GOLD, true, false)
	featured_card.add_child(_home_kicker_label)

	_home_mode_2d_btn = Button.new()
	_home_mode_2d_btn.name = "Home2DModeButton"
	_home_mode_2d_btn.text = "2D Map"
	_home_mode_2d_btn.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		_home_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_2D)
		_refresh_home_view_buttons()
	)
	featured_card.add_child(_home_mode_2d_btn)

	_home_mode_3d_btn = Button.new()
	_home_mode_3d_btn.name = "Home3DModeButton"
	_home_mode_3d_btn.text = "3D Orbit"
	_home_mode_3d_btn.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		_home_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_3D)
		_refresh_home_view_buttons()
	)
	featured_card.add_child(_home_mode_3d_btn)
	_refresh_home_view_buttons()

	_home_track_title = Label.new()
	_home_track_title.position = Vector2(20.0, 52.0)
	_home_track_title.size = Vector2(356.0, 38.0)
	_home_track_title.clip_text = true
	UITheme.style_label(_home_track_title, 28, UITheme.TEXT_PRIMARY, true, false)
	featured_card.add_child(_home_track_title)

	_home_track_meta = Label.new()
	_home_track_meta.position = Vector2(20.0, 92.0)
	_home_track_meta.size = Vector2(380.0, 66.0)
	_home_track_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_home_track_meta.clip_text = true
	UITheme.style_label(_home_track_meta, 16, UITheme.TEXT_SECONDARY, false, false)
	featured_card.add_child(_home_track_meta)

	_home_stat_length = UITheme.make_stat_tile(featured_card, Vector2(20.0, 162.0), Vector2(184.0, 74.0), "LENGTH")
	_home_stat_surface = UITheme.make_stat_tile(featured_card, Vector2(216.0, 162.0), Vector2(184.0, 74.0), "SURFACE")
	_home_stat_width = UITheme.make_stat_tile(featured_card, Vector2(20.0, 246.0), Vector2(184.0, 74.0), "ROAD WIDTH")
	_home_stat_biome = UITheme.make_stat_tile(featured_card, Vector2(216.0, 246.0), Vector2(184.0, 74.0), "BIOME")

	_home_records_card = Panel.new()
	_home_records_card.position = Vector2(20.0, 336.0)
	_home_records_card.size = Vector2(356.0, 194.0)
	_home_records_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TILE_BG, 14, UITheme.BORDER_SUBTLE, 1, 0))
	featured_card.add_child(_home_records_card)

	var rec_kicker := Label.new()
	rec_kicker.text = "CIRCUIT RECORDS & GHOST"
	rec_kicker.position = Vector2(16.0, 12.0)
	rec_kicker.size = Vector2(320.0, 22.0)
	UITheme.style_label(rec_kicker, 15, UITheme.GOLD, true, false)
	_home_records_card.add_child(rec_kicker)

	_home_track_records = Label.new()
	_home_track_records.position = Vector2(16.0, 38.0)
	_home_track_records.size = Vector2(320.0, 140.0)
	_home_track_records.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_home_track_records, 18, UITheme.TEXT_PRIMARY, false, true)
	_home_records_card.add_child(_home_track_records)

	_home_prev_btn = Button.new()
	_home_prev_btn.name = "HomePrevCircuitButton"
	_home_prev_btn.text = "PREV CIRCUIT"
	_home_prev_btn.icon = AssetRegistry.load_icon("chevron_left")
	_home_prev_btn.add_theme_constant_override("icon_max_width", 18)
	UITheme.style_secondary_button(_home_prev_btn, 16, 12)
	_home_prev_btn.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		_cycle_active_track(-1)
	)
	featured_card.add_child(_home_prev_btn)

	_home_next_btn = Button.new()
	_home_next_btn.name = "HomeNextCircuitButton"
	_home_next_btn.text = "NEXT CIRCUIT"
	_home_next_btn.icon = AssetRegistry.load_icon("chevron_right")
	_home_next_btn.add_theme_constant_override("icon_max_width", 18)
	UITheme.style_secondary_button(_home_next_btn, 16, 12)
	_home_next_btn.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		_cycle_active_track(1)
	)
	featured_card.add_child(_home_next_btn)

	_layout_navigation_shell()


func _layout_navigation_shell() -> void:
	if _home_background == null or _home_top_bar == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = Vector2(1280.0, 720.0)

	var top_w := vp.x - 48.0
	_home_top_bar.position = Vector2(24.0, 14.0)
	_home_top_bar.size = Vector2(top_w, 56.0)
	_home_music_button.position = Vector2(top_w - 148.0, 9.0)
	_home_music_button.size = Vector2(136.0, 38.0)
	_home_sfx_button.position = Vector2(top_w - 280.0, 9.0)
	_home_sfx_button.size = Vector2(124.0, 38.0)
	_home_badge_label.position = Vector2(maxf(520.0, top_w - 620.0), 17.0)
	_home_badge_label.size = Vector2(328.0, 24.0)

	var dock_h := vp.y - 104.0
	var left_w := 332.0
	_home_menu_dock.position = Vector2(24.0, 84.0)
	_home_menu_dock.size = Vector2(left_w, dock_h)
	if _status_label != null:
		_status_label.position = Vector2(18.0, dock_h - 68.0)
		_status_label.size = Vector2(left_w - 36.0, 56.0)

	var right_w := clampf(vp.x * 0.325, 420.0, 428.0)
	var right_x := vp.x - right_w - 24.0
	_home_featured_card.position = Vector2(right_x, 84.0)
	_home_featured_card.size = Vector2(right_w, dock_h)

	_home_mode_3d_btn.position = Vector2(right_w - 116.0, 12.0)
	_home_mode_3d_btn.size = Vector2(98.0, 34.0)
	_home_mode_2d_btn.position = Vector2(right_w - 216.0, 12.0)
	_home_mode_2d_btn.size = Vector2(92.0, 34.0)
	_home_track_title.size = Vector2(right_w - 40.0, 38.0)
	_home_track_meta.size = Vector2(right_w - 40.0, 66.0)

	if _home_records_card != null:
		var rec_h := maxf(136.0, dock_h - 420.0)
		_home_records_card.position = Vector2(20.0, 336.0)
		_home_records_card.size = Vector2(right_w - 40.0, rec_h)
		if _home_track_records != null:
			_home_track_records.size = Vector2(right_w - 72.0, rec_h - 50.0)

	var nav_btn_w := (right_w - 52.0) * 0.5
	_home_prev_btn.position = Vector2(20.0, dock_h - 68.0)
	_home_prev_btn.size = Vector2(nav_btn_w, 50.0)
	_home_next_btn.position = Vector2(32.0 + nav_btn_w, dock_h - 68.0)
	_home_next_btn.size = Vector2(nav_btn_w, 50.0)

	if _home_preview_widget != null:
		_home_preview_widget.position = Vector2.ZERO
		_home_preview_widget.size = vp
		_home_preview_widget.set_2d_safe_margins(24.0 + left_w + 18.0, 84.0, right_w + 42.0, 24.0)


func _refresh_home_view_buttons() -> void:
	if _home_mode_2d_btn == null or _home_mode_3d_btn == null or _home_preview_widget == null:
		return
	var is_3d := _home_preview_widget.get_view_mode() == TrackPreviewWidget.VIEW_3D
	UITheme.style_rim_pill(_home_mode_2d_btn, not is_3d, 15, 10)
	UITheme.style_rim_pill(_home_mode_3d_btn, is_3d, 15, 10)


func _cycle_active_track(delta: int) -> void:
	var all_tracks := CuratedTrackCatalog.get_all_tracks()
	if all_tracks.is_empty():
		return
	var current_idx := 0
	if _active_track != null:
		for i in all_tracks.size():
			if all_tracks[i].track_id == _active_track.track_id:
				current_idx = i
				break
	var next_idx := wrapi(current_idx + delta, 0, all_tracks.size())
	_active_track = all_tracks[next_idx]
	if _status_label != null:
		_status_label.text = "Selected circuit: %s" % _active_track.display_name
	_refresh_home_card()


func _refresh_home_card() -> void:
	if _active_track == null:
		_active_track = CuratedTrackCatalog.get_featured_track()
	if _home_track_title == null:
		return

	var is_featured := bool(_active_track.metadata.get("featured", false))
	if is_featured:
		_home_badge_label.text = "FEATURED CURATED CIRCUIT"
		_home_kicker_label.text = "FEATURED CIRCUIT"
	elif _active_track.source == TrackDefinition.SOURCE_CURATED:
		_home_badge_label.text = "SELECTED CURATED CIRCUIT"
		_home_kicker_label.text = "CURATED CIRCUIT"
	else:
		_home_badge_label.text = "SELECTED CUSTOM CIRCUIT"
		_home_kicker_label.text = "CUSTOM CIRCUIT"

	_home_track_title.text = _active_track.display_name.to_upper()
	var compiled := _home_preview_widget.configure_track(_active_track)
	_refresh_home_view_buttons()
	var length_m := float(compiled.get("length", 0.0))
	var desc := str(_active_track.metadata.get("description", "Custom player-drawn rally loop."))
	_home_track_meta.text = desc

	if _home_stat_length != null:
		_home_stat_length.text = "%.0f m" % length_m
	if _home_stat_surface != null:
		_home_stat_surface.text = _active_track.surface.to_upper()
	if _home_stat_width != null:
		_home_stat_width.text = _active_track.road_width.to_upper()
	if _home_stat_biome != null:
		_home_stat_biome.text = str(BiomePresets.get_preset(_active_track.theme).display_name).to_upper()

	var rec_res := RecordStore.new().load_record(_active_track.track_id)
	var rec: Dictionary = rec_res.record if rec_res.record != null else {}
	var best_lap_ms := int(rec.get("best_lap_ms", 0))
	var best_race_ms := int(rec.get("best_race_ms", 0))
	var ghost_samples: Array = rec.get("ghost_samples", [])
	var lap_str := RaceResult.format_time(float(best_lap_ms) / 1000.0) if best_lap_ms > 0 else "--:--.---"
	var race_str := RaceResult.format_time(float(best_race_ms) / 1000.0) if best_race_ms > 0 else "--:--.---"
	var ghost_str := "GHOST READY" if not ghost_samples.is_empty() else "NO GHOST"
	_home_track_records.text = (
		"Best Lap:    %s\nBest Race:   %s\nTime Trial:  %s" % [lap_str, race_str, ghost_str]
	)


func _build_preview_track() -> TrackDefinition:
	var track := TrackDefinition.create_custom("Preview Circuit", PackedVector2Array([
		Vector2(-120.0, -55.0), Vector2(-35.0, -110.0), Vector2(85.0, -78.0),
		Vector2(135.0, 10.0), Vector2(60.0, 105.0), Vector2(-72.0, 92.0),
	]))
	track.track_id = "preview_circuit"
	track.road_width = "wide"
	track.surface = "asphalt"
	track.theme = "forest"
	return track


func _sync_home_background_visibility(exiting_node: Node = null) -> void:
	if _home_background == null:
		return
	if _race_root != null:
		_home_background.visible = false
		return
	if _navigation_layer != null:
		for overlay_name in ["TrackSelectScreen", "LibraryRecordsScreen", "TrackBuilder"]:
			var node := _navigation_layer.get_node_or_null(overlay_name)
			if node != null and node != exiting_node and not node.is_queued_for_deletion():
				_home_background.visible = false
				return
	_home_background.visible = true


func _show_track_select() -> TrackSelectPanel:
	var existing := _navigation_layer.get_node_or_null("TrackSelectScreen")
	if existing != null:
		existing.queue_free()
	var panel := TrackSelectPanel.new()
	panel.name = "TrackSelectScreen"
	_navigation_layer.add_child(panel)
	_sync_home_background_visibility()
	panel.tree_exiting.connect(func() -> void: _sync_home_background_visibility(panel))
	if _active_track != null:
		panel.select_track_by_id(_active_track.track_id)
	panel.cancelled.connect(panel.queue_free)
	panel.track_selected.connect(func(selected: TrackDefinition) -> void:
		_active_track = selected
		_status_label.text = "Selected circuit: %s" % selected.display_name
		_refresh_home_card()
		panel.queue_free()
		_show_quick_play_picker(selected)
	)
	return panel


func _show_library_and_records() -> LibraryRecordsPanel:
	var existing := _navigation_layer.get_node_or_null("LibraryRecordsScreen")
	if existing != null:
		existing.queue_free()
	var panel := LibraryRecordsPanel.new()
	panel.name = "LibraryRecordsScreen"
	_navigation_layer.add_child(panel)
	_sync_home_background_visibility()
	panel.tree_exiting.connect(func() -> void: _sync_home_background_visibility(panel))
	panel.cancelled.connect(func() -> void:
		_refresh_home_card()
		panel.queue_free()
	)
	panel.track_deleted.connect(func(deleted_id: String) -> void:
		if _active_track != null and _active_track.track_id == deleted_id:
			_active_track = CuratedTrackCatalog.get_featured_track()
		_refresh_home_card()
	)
	panel.race_track_requested.connect(func(selected: TrackDefinition) -> void:
		_active_track = selected
		_status_label.text = "Selected circuit: %s" % selected.display_name
		_refresh_home_card()
		panel.queue_free()
		_show_quick_play_picker(selected)
	)
	panel.edit_track_requested.connect(func(selected: TrackDefinition) -> void:
		_active_track = selected
		panel.queue_free()
		_show_track_builder(selected)
	)
	return panel


func _show_quick_play_picker(custom_track: TrackDefinition = null) -> EventSetupPanel:
	if custom_track != null:
		_active_track = custom_track
	elif _active_track == null:
		_active_track = _build_preview_track()
	_refresh_home_card()
	var track := _active_track
	var record_res := RecordStore.new().load_record(track.track_id)
	var saved_record: Dictionary = record_res.record if record_res.record != null else {}

	var panel := EventSetupPanel.new()
	panel.name = "QuickPlayPicker"
	_navigation_layer.add_child(panel)
	panel.configure(track, _last_event_setup, saved_record)
	panel.cancelled.connect(panel.queue_free)
	panel.start_requested.connect(func(config: Dictionary) -> void:
		_last_event_setup = {
			"mode": config.get("mode", RaceResult.MODE_CIRCUIT),
			"laps": int(config.get("laps", 3)),
			"ai_count": int(config.get("ai_count", 3)),
		}
		panel.queue_free()
		_show_race_preview(
			str(_last_event_setup["mode"]),
			int(_last_event_setup["laps"]),
			int(_last_event_setup["ai_count"]),
			track
		)
	)
	return panel


func _show_race_preview(mode: String, laps: int = 3, ai_count: int = 3, custom_track: TrackDefinition = null) -> void:
	if _race_root != null:
		return
	if custom_track != null:
		_active_track = custom_track
	elif _active_track == null:
		_active_track = _build_preview_track()
	var track := _active_track
	_last_event_setup = {
		"mode": mode,
		"laps": clampi(laps, 1, 5),
		"ai_count": clampi(ai_count, 0, 7),
	}
	if _navigation_layer != null:
		_navigation_layer.visible = false
	if _home_background != null:
		_home_background.visible = false
	if _menu_music_player != null and _menu_music_player.playing:
		_menu_music_player.stop()
	if is_inside_tree():
		get_tree().paused = false
	_race_root = Node3D.new()
	_race_root.name = "RacePreview"
	_race_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_race_root)

	var compiled := TrackCompiler.build_runtime(track)
	if not compiled.ok:
		push_error("Preview circuit could not compile: %s" % compiled.errors)
		_close_race_preview()
		return
	BiomePresets.apply_race_environment(_race_root, compiled, track, true, false)
	_race_root.add_child(compiled.runtime)

	var car := _create_preview_car()
	var start_position: Vector3 = compiled.start_grid[0].position
	var heading: Vector3 = compiled.start_grid[0].heading
	_race_root.add_child(car)
	_attach_car_vfx(car, track, true)
	car.global_position = start_position + Vector3.UP * 0.25
	car.rotation.y = atan2(-heading.x, -heading.z)
	_preview_player_car = car

	var target_laps := 1 if mode == RaceResult.MODE_TIME_TRIAL else clampi(laps, 1, 5)
	var active_ai := 0 if mode == RaceResult.MODE_TIME_TRIAL else clampi(ai_count, 0, 7)

	if mode == RaceResult.MODE_TIME_TRIAL:
		_add_best_lap_ghost(track.track_id)
	else:
		_spawn_ai_cars(compiled, active_ai, track)

	var race_manager := RaceManager.new()
	if not race_manager.configure(car, compiled, track.track_id, mode, target_laps, _preview_ai_cars, _preview_ai_drivers):
		push_error("Preview race state could not be configured.")
		_close_race_preview()
		return
	_race_root.add_child(race_manager)

	var camera := RallyChaseCamera.new()
	camera.target = car
	camera.current = true
	_race_root.add_child(camera)
	camera.snap_to_target()

	var hud := RaceInputHud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.configure(car, race_manager, AI_CAR_COLORS)
	hud.retry_requested.connect(_restart_current_event)
	hud.event_setup_requested.connect(func() -> void:
		_close_race_preview()
		_show_quick_play_picker()
	)
	hud.exit_to_menu_requested.connect(_close_race_preview)
	_race_root.add_child(hud)

	var audio_ctrl := RaceAudioController.new()
	audio_ctrl.name = "RaceAudioController"
	_race_root.add_child(audio_ctrl)
	audio_ctrl.configure(car, race_manager)
	audio_ctrl.set_sfx_muted(_sfx_muted)
	audio_ctrl.set_music_muted(_music_muted)
	hud.set_sfx_muted(_sfx_muted)
	hud.set_music_muted(_music_muted)
	hud.pause_toggled.connect(func(paused: bool) -> void:
		if is_inside_tree():
			get_tree().paused = paused
		audio_ctrl.set_paused(paused)
	)
	race_manager.car_recovered.connect(func(_cp: int) -> void:
		camera.snap_to_target()
	)
	hud.sfx_mute_toggled.connect(audio_ctrl.set_sfx_muted)
	hud.sfx_mute_toggled.connect(_set_sfx_muted)
	hud.music_mute_toggled.connect(audio_ctrl.set_music_muted)
	hud.music_mute_toggled.connect(_set_music_muted)

	_build_debug_overlay()


func _restart_current_event() -> void:
	if is_inside_tree():
		get_tree().paused = false
	var mode := str(_last_event_setup.get("mode", RaceResult.MODE_CIRCUIT))
	var laps := int(_last_event_setup.get("laps", 3))
	var ai_count := int(_last_event_setup.get("ai_count", 3))
	_close_race_preview()
	_show_race_preview(mode, laps, ai_count)


func _create_preview_car(body_color: Color = Color("e5a83a"), variant_index: int = 0) -> RallyCar:
	var car := RallyCar.new()
	car.name = "PlayerCar"
	var visual := AssetRegistry.instantiate_car_visual(variant_index, body_color, false)
	car.add_child(visual)
	var collision := CollisionShape3D.new()
	const HW := 0.83
	const HL := 1.60
	const CHAM_XZ := 0.18
	const BEVEL_Y := 0.14
	const PAD_W := 0.58
	const PAD_L := 0.95
	const H := 0.85
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		# Central flat floor contact pad (y = 0.0)
		Vector3(-PAD_W, 0.0, -PAD_L),
		Vector3(PAD_W, 0.0, -PAD_L),
		Vector3(PAD_W, 0.0, PAD_L),
		Vector3(-PAD_W, 0.0, PAD_L),
		# Beveled lower bumper perimeter (y = 0.14, ski-tip clearance over slope transitions)
		Vector3(-HW, BEVEL_Y, -HL + CHAM_XZ),
		Vector3(-HW + CHAM_XZ, BEVEL_Y, -HL),
		Vector3(HW - CHAM_XZ, BEVEL_Y, -HL),
		Vector3(HW, BEVEL_Y, -HL + CHAM_XZ),
		Vector3(HW, BEVEL_Y, HL - CHAM_XZ),
		Vector3(HW - CHAM_XZ, BEVEL_Y, HL),
		Vector3(-HW + CHAM_XZ, BEVEL_Y, HL),
		Vector3(-HW, BEVEL_Y, HL - CHAM_XZ),
		# Roof perimeter (y = 0.85)
		Vector3(-HW, H, -HL + CHAM_XZ),
		Vector3(-HW + CHAM_XZ, H, -HL),
		Vector3(HW - CHAM_XZ, H, -HL),
		Vector3(HW, H, -HL + CHAM_XZ),
		Vector3(HW, H, HL - CHAM_XZ),
		Vector3(HW - CHAM_XZ, H, HL),
		Vector3(-HW + CHAM_XZ, H, HL),
		Vector3(-HW, H, HL - CHAM_XZ),
	])
	collision.shape = shape
	collision.position = Vector3.ZERO
	car.add_child(collision)
	return car


func _attach_car_vfx(car: RallyCar, track: TrackDefinition, is_player: bool) -> void:
	if car == null or track == null:
		return
	var vfx := CarVfxController.new()
	vfx.name = "CarVfxController"
	car.add_child(vfx)
	vfx.configure(car, track.surface, track.theme, is_player)


func _spawn_ai_cars(compiled: Dictionary, count: int, track: TrackDefinition = null) -> void:
	_preview_ai_cars.clear()
	_preview_ai_drivers.clear()
	for i in count:
		var slot_index := i + 1
		if slot_index >= compiled.start_grid.size():
			break
		var color: Color = AI_CAR_COLORS[i % AI_CAR_COLORS.size()]
		var ai_car := _create_preview_car(color, slot_index)
		ai_car.name = "PreviewAI_%d" % slot_index
		var start_position: Vector3 = compiled.start_grid[slot_index].position
		var heading: Vector3 = compiled.start_grid[slot_index].heading
		_race_root.add_child(ai_car)
		_attach_car_vfx(ai_car, track, false)
		ai_car.global_position = start_position + Vector3.UP * 0.25
		ai_car.rotation.y = atan2(-heading.x, -heading.z)
		var driver := AIDriver.new()
		driver.name = "CurvatureDriver_%d" % slot_index
		if not driver.configure(ai_car, compiled.centerline, slot_index):
			push_error("Preview AI %d could not be configured." % slot_index)
			ai_car.queue_free()
			continue
		_race_root.add_child(driver)
		_preview_ai_cars.append(ai_car)
		_preview_ai_drivers.append(driver)


func _add_best_lap_ghost(track_id: String) -> void:
	var record_result := RecordStore.new().load_record(track_id)
	if record_result.record == null:
		return
	var samples: Array[Dictionary] = record_result.record.ghost_samples
	var ghost := GhostPlayback.new()
	if not ghost.configure(samples):
		return
	ghost.name = "BestLapGhost"
	var ghost_visual := AssetRegistry.instantiate_car_visual(0, Color("6fd6ee88"), true)
	ghost.add_child(ghost_visual)
	_race_root.add_child(ghost)


func _process(_delta: float) -> void:
	if _debug_label == null:
		return
	if not _debug_visible:
		_debug_label.visible = false
		return
	_debug_label.visible = true
	var p_speed: float = _preview_player_car.get_drive_state().speed if _preview_player_car != null else 0.0
	var text := "[F1] Telemetry Overlay | %d FPS\n" % Engine.get_frames_per_second()
	text += "Player: %.1f m/s (%.0f km/h)\n" % [p_speed, p_speed * 3.6]
	if not _preview_ai_cars.is_empty():
		text += "AI Racers: %d active\n" % _preview_ai_cars.size()
		for i in min(_preview_ai_cars.size(), 3):
			var ai_car: RallyCar = _preview_ai_cars[i]
			if ai_car != null:
				var ai_speed: float = ai_car.get_drive_state().speed
				text += "AI %d: %.1f m/s | St: %+.2f\n" % [i + 1, ai_speed, ai_car._ai_steering]
	_debug_label.text = text


func _build_debug_overlay() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "DebugOverlay"
	_race_root.add_child(canvas_layer)

	var label := Label.new()
	label.name = "TelemetryLabel"
	label.position = Vector2(24.0, 126.0)
	label.size = Vector2(300.0, 140.0)
	label.visible = _debug_visible
	UITheme.style_label(label, 15, UITheme.TEXT_PRIMARY, false, true)
	var style := UITheme.make_panel_style(UITheme.GLASS_DARK, 12, UITheme.BORDER_GOLD, 1, 6, 12.0, 10.0)
	label.add_theme_stylebox_override("normal", style)
	canvas_layer.add_child(label)
	_debug_label = label


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			_debug_visible = not _debug_visible
			if _debug_label != null:
				_debug_label.visible = _debug_visible
	if event.is_action_pressed("ui_cancel") and _race_root != null:
		_close_race_preview()


func _close_race_preview() -> void:
	if _race_root == null:
		return
	if is_inside_tree():
		get_tree().paused = false
	_play_ui_sfx("ui_back")
	_preview_player_car = null
	_preview_ai_cars.clear()
	_preview_ai_drivers.clear()
	_debug_label = null
	_race_root.queue_free()
	_race_root = null
	_navigation_layer.visible = true
	_sync_home_background_visibility()
	_sync_menu_music()
	_refresh_home_card()


func _is_audio_disabled() -> bool:
	return DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy"


func _init_menu_audio() -> void:
	RaceAudioController.ensure_master_limiter()
	_menu_music_player = AudioStreamPlayer.new()
	_menu_music_player.name = "MenuMusicPlayer"
	_menu_music_player.volume_db = -12.0
	_menu_music_player.stream = AssetRegistry.load_audio_stream("menu_theme", true)
	add_child(_menu_music_player)
	for sfx_key in ["ui_click", "ui_confirm", "ui_back"]:
		var p := AudioStreamPlayer.new()
		p.name = "UISfx_%s" % sfx_key
		p.volume_db = -9.0
		p.stream = AssetRegistry.load_audio_stream(sfx_key, false)
		add_child(p)
		_ui_sfx_players[sfx_key] = p
	_sync_menu_music()


func _sync_menu_music() -> void:
	if _menu_music_player == null or _menu_music_player.stream == null:
		return
	if _is_audio_disabled() or _music_muted or _race_root != null:
		if _menu_music_player.playing:
			_menu_music_player.stop()
	elif not _menu_music_player.playing:
		_menu_music_player.play()


func _refresh_home_audio_buttons() -> void:
	_style_home_audio_button(_home_sfx_button, "SFX", _sfx_muted)
	_style_home_audio_button(_home_music_button, "MUSIC", _music_muted)


func _style_home_audio_button(btn: Button, label_prefix: String, muted: bool) -> void:
	if btn == null:
		return
	btn.text = "%s OFF" % label_prefix if muted else "%s ON" % label_prefix
	btn.icon = AssetRegistry.load_icon("volume_off" if muted else "volume_on")
	UITheme.style_audio_pill(btn, muted, 16, 18)


func _set_sfx_muted(muted: bool) -> void:
	_sfx_muted = muted
	_refresh_home_audio_buttons()


func _set_music_muted(muted: bool) -> void:
	_music_muted = muted
	_refresh_home_audio_buttons()
	_sync_menu_music()


func _set_global_muted(muted: bool) -> void:
	_sfx_muted = muted
	_music_muted = muted
	_refresh_home_audio_buttons()
	_sync_menu_music()


func _play_ui_sfx(key: String) -> void:
	if _is_audio_disabled() or _sfx_muted:
		return
	var p: AudioStreamPlayer = _ui_sfx_players.get(key)
	if p != null and p.stream != null:
		p.play()


func _show_track_builder(edit_track: TrackDefinition = null) -> Control:
	var overlay := Control.new()
	overlay.name = "TrackBuilder"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_navigation_layer.add_child(overlay)
	_sync_home_background_visibility()
	overlay.tree_exiting.connect(func() -> void: _sync_home_background_visibility(overlay))

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = UITheme.BG_BACKDROP
	overlay.add_child(background)

	# Full-width top bar
	var top_bar := Panel.new()
	top_bar.name = "BuilderTopBar"
	top_bar.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TOPBAR_BG, 14, UITheme.BORDER_SUBTLE, 1, 8))
	background.add_child(top_bar)

	var close_button := Button.new()
	close_button.name = "BackToHomeButton"
	close_button.text = "BACK"
	close_button.icon = AssetRegistry.load_icon("chevron_left")
	close_button.add_theme_constant_override("icon_max_width", 18)
	UITheme.style_secondary_button(close_button, 17, 11)
	top_bar.add_child(close_button)

	var title := Label.new()
	title.text = "EDIT CIRCUIT" if edit_track != null else "TRACK BUILDER"
	title.position = Vector2(136.0, 11.0)
	title.size = Vector2(250.0, 34.0)
	UITheme.style_label(title, 25, UITheme.TEXT_PRIMARY, true, false)
	top_bar.add_child(title)

	var mode_sketch_btn := Button.new()
	mode_sketch_btn.name = "ModeSketchButton"
	mode_sketch_btn.text = "1. SKETCH"
	UITheme.style_gold_pill(mode_sketch_btn, true, 15, 11)
	top_bar.add_child(mode_sketch_btn)

	var mode_preview_btn := Button.new()
	mode_preview_btn.name = "ModePreviewButton"
	mode_preview_btn.text = "2. 3D PREVIEW"
	mode_preview_btn.disabled = true
	UITheme.style_gold_pill(mode_preview_btn, false, 15, 11)
	top_bar.add_child(mode_preview_btn)

	var undo_btn := Button.new()
	undo_btn.name = "UndoStrokeButton"
	undo_btn.text = "UNDO"
	undo_btn.icon = AssetRegistry.load_icon("rotate_ccw")
	undo_btn.add_theme_constant_override("icon_max_width", 16)
	undo_btn.disabled = true
	UITheme.style_secondary_button(undo_btn, 15, 11)
	top_bar.add_child(undo_btn)

	var close_loop_btn := Button.new()
	close_loop_btn.name = "CloseLoopButton"
	close_loop_btn.text = "CLOSE LOOP"
	close_loop_btn.icon = AssetRegistry.load_icon("check")
	close_loop_btn.add_theme_constant_override("icon_max_width", 16)
	close_loop_btn.disabled = true
	UITheme.style_rim_pill(close_loop_btn, false, 15, 11)
	top_bar.add_child(close_loop_btn)

	var clear_button := Button.new()
	clear_button.name = "ClearCanvasButton"
	clear_button.text = "CLEAR"
	clear_button.icon = AssetRegistry.load_icon("trash")
	clear_button.add_theme_constant_override("icon_max_width", 16)
	UITheme.style_danger_button(clear_button, 15, 11)
	top_bar.add_child(clear_button)

	# Left Drafting Canvas + 3D/2D Preview Stage + Live Telemetry Footer
	var canvas_frame := Panel.new()
	canvas_frame.name = "BuilderCanvasFrame"
	canvas_frame.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.CANVAS_BG, 16, UITheme.BORDER_GOLD, 2, 10))
	background.add_child(canvas_frame)

	var canvas := TrackDrawingCanvas.new()
	canvas.name = "DrawingCanvas"
	canvas_frame.add_child(canvas)

	var builder_preview := TrackPreviewWidget.new()
	builder_preview.name = "BuilderTrackPreview"
	builder_preview.visible = false
	canvas_frame.add_child(builder_preview)

	var telemetry_bar := Panel.new()
	telemetry_bar.name = "BuilderTelemetryBar"
	telemetry_bar.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TOPBAR_BG, 12, UITheme.BORDER_SUBTLE, 1, 0))
	canvas_frame.add_child(telemetry_bar)

	var preview_label := Label.new()
	preview_label.name = "TelemetrySummaryLabel"
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.text = "Draw a loop on the drafting grid — release anytime to continue stroking, or close back on the gold start ring."
	UITheme.style_label(preview_label, 16, UITheme.TEXT_SECONDARY, false, true)
	telemetry_bar.add_child(preview_label)

	# Right Smoked-Glass Inspector Card
	var preview_card := Panel.new()
	preview_card.name = "BuilderControlCard"
	preview_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_DARK, 18, UITheme.BORDER_SUBTLE, 2, 12))
	background.add_child(preview_card)

	var builder_state := {
		"track_id": edit_track.track_id if edit_track != null else "",
		"editing_existing": edit_track != null,
		"surface": edit_track.surface if edit_track != null else "asphalt",
		"road_width": edit_track.road_width if edit_track != null else "wide",
		"theme": edit_track.theme if edit_track != null else "forest",
		"valid": edit_track != null,
		"points": edit_track.centerline_points.duplicate() if edit_track != null else PackedVector2Array(),
		"suggested_name": edit_track.display_name if edit_track != null else "Custom Rally",
		"name_edited": edit_track != null,
	}

	var name_label := Label.new()
	name_label.position = Vector2(20.0, 14.0)
	name_label.size = Vector2(352.0, 20.0)
	name_label.text = "TRACK NAME"
	UITheme.style_label(name_label, 14, UITheme.GOLD, true, false)
	preview_card.add_child(name_label)

	var name_input := LineEdit.new()
	name_input.name = "TrackNameEdit"
	name_input.position = Vector2(20.0, 36.0)
	name_input.size = Vector2(352.0, 40.0)
	name_input.max_length = TrackDefinition.MAX_NAME_LENGTH
	name_input.text = "Custom Rally"
	name_input.placeholder_text = "Enter circuit name..."
	UITheme.style_line_edit(name_input, 18)
	name_input.text_changed.connect(func(_new_text: String) -> void:
		builder_state.name_edited = true
	)
	preview_card.add_child(name_input)

	var build_current_track := func() -> TrackDefinition:
		var chosen_name := name_input.text.strip_edges()
		if chosen_name.is_empty():
			chosen_name = str(builder_state.suggested_name)
		var custom_track := TrackDefinition.create_custom(chosen_name, builder_state.points)
		if not str(builder_state.track_id).is_empty():
			custom_track.track_id = str(builder_state.track_id)
		else:
			builder_state.track_id = custom_track.track_id
		custom_track.road_width = str(builder_state.road_width)
		custom_track.surface = str(builder_state.surface)
		custom_track.theme = str(builder_state.theme)
		return custom_track

	var refresh_builder_preview := func() -> void:
		if not builder_state.valid:
			return
		var t: TrackDefinition = build_current_track.call()
		builder_preview.configure_track(t)

	# Surface selector
	var surface_label := Label.new()
	surface_label.position = Vector2(20.0, 86.0)
	surface_label.size = Vector2(352.0, 20.0)
	surface_label.text = "SURFACE: ASPHALT"
	UITheme.style_label(surface_label, 14, UITheme.TEXT_MUTED, true, false)
	preview_card.add_child(surface_label)

	var asphalt_btn := Button.new()
	asphalt_btn.text = "Asphalt"
	asphalt_btn.position = Vector2(20.0, 108.0)
	asphalt_btn.size = Vector2(170.0, 38.0)
	UITheme.style_rim_pill(asphalt_btn, true, 16, 11)
	preview_card.add_child(asphalt_btn)

	var dirt_btn := Button.new()
	dirt_btn.text = "Dirt"
	dirt_btn.position = Vector2(202.0, 108.0)
	dirt_btn.size = Vector2(170.0, 38.0)
	UITheme.style_rim_pill(dirt_btn, false, 16, 11)
	preview_card.add_child(dirt_btn)

	asphalt_btn.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		builder_state.surface = "asphalt"
		surface_label.text = "SURFACE: ASPHALT"
		UITheme.style_rim_pill(asphalt_btn, true, 16, 11)
		UITheme.style_rim_pill(dirt_btn, false, 16, 11)
		refresh_builder_preview.call()
	)
	dirt_btn.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		builder_state.surface = "dirt"
		surface_label.text = "SURFACE: DIRT"
		UITheme.style_rim_pill(asphalt_btn, false, 16, 11)
		UITheme.style_rim_pill(dirt_btn, true, 16, 11)
		refresh_builder_preview.call()
	)

	# Road Width selector
	var width_label := Label.new()
	width_label.position = Vector2(20.0, 156.0)
	width_label.size = Vector2(352.0, 20.0)
	width_label.text = "ROAD WIDTH: WIDE"
	UITheme.style_label(width_label, 14, UITheme.TEXT_MUTED, true, false)
	preview_card.add_child(width_label)

	var width_buttons: Dictionary = {}
	var widths := ["narrow", "standard", "wide"]
	for i in widths.size():
		var w_name: String = widths[i]
		var w_btn := Button.new()
		w_btn.text = w_name.capitalize()
		w_btn.position = Vector2(20.0 + float(i) * 120.5, 178.0)
		w_btn.size = Vector2(111.0, 38.0)
		UITheme.style_rim_pill(w_btn, w_name == "wide", 15, 11)
		preview_card.add_child(w_btn)
		width_buttons[w_name] = w_btn
		w_btn.pressed.connect(func() -> void:
			_play_ui_sfx("ui_click")
			builder_state.road_width = w_name
			width_label.text = "ROAD WIDTH: %s" % w_name.to_upper()
			for k in width_buttons.keys():
				UITheme.style_rim_pill(width_buttons[k], k == w_name, 15, 11)
			refresh_builder_preview.call()
		)

	# 6-Biome Theme selector (2x3 card grid)
	var theme_label := Label.new()
	theme_label.position = Vector2(20.0, 226.0)
	theme_label.size = Vector2(352.0, 20.0)
	theme_label.text = "BIOME THEME: FOREST"
	UITheme.style_label(theme_label, 14, UITheme.TEXT_MUTED, true, false)
	preview_card.add_child(theme_label)

	var theme_buttons: Dictionary = {}
	var theme_specs := [
		["forest", "Forest"],
		["desert", "Desert"],
		["alpine", "Alpine"],
		["spa_forest", "Spa Forest"],
		["parkland", "Parkland"],
		["open_grassland", "Grassland"],
	]
	for i in theme_specs.size():
		var t_id: String = theme_specs[i][0]
		var t_title: String = theme_specs[i][1]
		var col := i % 2
		var row := i / 2
		var t_btn := Button.new()
		t_btn.name = "Theme_%s_Button" % t_id
		t_btn.text = t_title
		t_btn.position = Vector2(20.0 + float(col) * 182.0, 248.0 + float(row) * 44.0)
		t_btn.size = Vector2(170.0, 38.0)
		UITheme.style_rim_pill(t_btn, t_id == "forest", 15, 11)
		preview_card.add_child(t_btn)
		theme_buttons[t_id] = t_btn
		t_btn.pressed.connect(func() -> void:
			_play_ui_sfx("ui_click")
			builder_state.theme = t_id
			theme_label.text = "BIOME THEME: %s" % t_title.to_upper()
			for k in theme_buttons.keys():
				UITheme.style_rim_pill(theme_buttons[k], k == t_id, 15, 11)
			refresh_builder_preview.call()
		)

	var save_status_label := Label.new()
	save_status_label.name = "SaveStatusLabel"
	save_status_label.position = Vector2(20.0, 384.0)
	save_status_label.size = Vector2(352.0, 26.0)
	save_status_label.clip_text = true
	UITheme.style_label(save_status_label, 15, UITheme.EMERALD, false, false)
	preview_card.add_child(save_status_label)

	var inspect_3d_btn := Button.new()
	inspect_3d_btn.name = "InspectPreviewButton"
	inspect_3d_btn.text = "INSPECT 3D / 2D PREVIEW"
	inspect_3d_btn.icon = AssetRegistry.load_icon("route")
	inspect_3d_btn.add_theme_constant_override("icon_max_width", 18)
	inspect_3d_btn.disabled = true
	UITheme.style_secondary_button(inspect_3d_btn, 16, 12)
	preview_card.add_child(inspect_3d_btn)

	var save_button := Button.new()
	save_button.name = "SaveTrackButton"
	save_button.text = "SAVE TO LIBRARY"
	save_button.icon = AssetRegistry.load_icon("download")
	save_button.add_theme_constant_override("icon_max_width", 18)
	save_button.disabled = true
	UITheme.style_secondary_button(save_button, 17, 12)
	preview_card.add_child(save_button)

	var race_button := Button.new()
	race_button.name = "RaceTrackButton"
	race_button.text = "RACE THIS TRACK"
	race_button.icon = AssetRegistry.load_icon("flag")
	race_button.add_theme_constant_override("icon_max_width", 20)
	race_button.disabled = true
	UITheme.style_primary_button(race_button, 20, 14)
	preview_card.add_child(race_button)

	var layout_builder := func() -> void:
		if not is_instance_valid(overlay):
			return
		var vp := overlay.get_viewport_rect().size
		if vp.x <= 1.0 or vp.y <= 1.0:
			vp = Vector2(1280.0, 720.0)
		var top_w := vp.x - 48.0
		top_bar.position = Vector2(24.0, 14.0)
		top_bar.size = Vector2(top_w, 56.0)
		close_button.position = Vector2(12.0, 9.0)
		close_button.size = Vector2(112.0, 38.0)

		clear_button.position = Vector2(top_w - 118.0, 9.0)
		clear_button.size = Vector2(106.0, 38.0)
		close_loop_btn.position = Vector2(top_w - 266.0, 9.0)
		close_loop_btn.size = Vector2(140.0, 38.0)
		undo_btn.position = Vector2(top_w - 376.0, 9.0)
		undo_btn.size = Vector2(102.0, 38.0)
		mode_preview_btn.position = Vector2(top_w - 538.0, 9.0)
		mode_preview_btn.size = Vector2(152.0, 38.0)
		mode_sketch_btn.position = Vector2(top_w - 672.0, 9.0)
		mode_sketch_btn.size = Vector2(126.0, 38.0)

		var right_w := 392.0
		var dock_h := vp.y - 104.0
		var left_w := vp.x - right_w - 64.0
		canvas_frame.position = Vector2(24.0, 84.0)
		canvas_frame.size = Vector2(left_w, dock_h)

		var telemetry_h := 76.0
		var stage_h := dock_h - telemetry_h - 14.0
		canvas.position = Vector2(4.0, 4.0)
		canvas.size = Vector2(left_w - 8.0, stage_h)
		builder_preview.position = Vector2(4.0, 4.0)
		builder_preview.size = Vector2(left_w - 8.0, stage_h)

		telemetry_bar.position = Vector2(8.0, dock_h - telemetry_h - 6.0)
		telemetry_bar.size = Vector2(left_w - 16.0, telemetry_h)
		preview_label.position = Vector2(14.0, 8.0)
		preview_label.size = Vector2(left_w - 44.0, telemetry_h - 16.0)

		preview_card.position = Vector2(vp.x - right_w - 24.0, 84.0)
		preview_card.size = Vector2(right_w, dock_h)

		var cta_start_y := maxf(414.0, dock_h - 178.0)
		inspect_3d_btn.position = Vector2(20.0, cta_start_y)
		inspect_3d_btn.size = Vector2(352.0, 46.0)
		save_button.position = Vector2(20.0, cta_start_y + 52.0)
		save_button.size = Vector2(352.0, 46.0)
		race_button.position = Vector2(20.0, cta_start_y + 104.0)
		race_button.size = Vector2(352.0, 54.0)

	layout_builder.call()
	if get_viewport() != null:
		get_viewport().size_changed.connect(layout_builder)
		overlay.tree_exiting.connect(func() -> void:
			if is_instance_valid(get_viewport()) and get_viewport().size_changed.is_connected(layout_builder):
				get_viewport().size_changed.disconnect(layout_builder)
		)

	var sync_canvas_tool_buttons := func(is_closed: bool, point_count: int) -> void:
		undo_btn.disabled = not canvas.can_undo()
		close_loop_btn.disabled = is_closed or point_count < TrackPathProcessor.MIN_INPUT_POINTS

	var show_left_pane := func(show_preview: bool) -> void:
		canvas.visible = not show_preview
		builder_preview.visible = show_preview
		UITheme.style_gold_pill(mode_sketch_btn, not show_preview, 15, 11)
		UITheme.style_gold_pill(mode_preview_btn, show_preview, 15, 11)
		if show_preview:
			refresh_builder_preview.call()
			builder_preview.set_view_mode(TrackPreviewWidget.VIEW_3D)
			inspect_3d_btn.text = "BACK TO SKETCH"
		else:
			inspect_3d_btn.text = "INSPECT 3D / 2D PREVIEW"

	mode_sketch_btn.pressed.connect(func() -> void: show_left_pane.call(false))
	mode_preview_btn.pressed.connect(func() -> void:
		if builder_state.valid:
			show_left_pane.call(true)
	)
	inspect_3d_btn.pressed.connect(func() -> void:
		if not builder_state.valid:
			return
		show_left_pane.call(not builder_preview.visible)
	)
	undo_btn.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		canvas.undo_last_action()
	)
	close_loop_btn.pressed.connect(func() -> void:
		_play_ui_sfx("ui_confirm")
		canvas.close_loop_now()
	)

	canvas.path_status_changed.connect(func(is_closed: bool, point_count: int, bridge_count: int) -> void:
		sync_canvas_tool_buttons.call(is_closed, point_count)
		if not is_closed and point_count > 0:
			var b_str := "" if bridge_count == 0 else ("  •  %d overpass crossing%s detected" % [bridge_count, "" if bridge_count == 1 else "s"])
			preview_label.text = "Open sketch: %d points%s. Keep sketching, tap CLOSE LOOP, or snap near the gold start ring." % [point_count, b_str]
	)

	canvas.drawing_processed.connect(func(result: Dictionary) -> void:
		save_status_label.text = ""
		if not result.get("ok", false):
			builder_state.valid = false
			race_button.disabled = true
			save_button.disabled = true
			inspect_3d_btn.disabled = true
			mode_preview_btn.disabled = true
			UITheme.style_primary_button(race_button, 20, 14)
			UITheme.style_secondary_button(save_button, 17, 12)
			UITheme.style_secondary_button(inspect_3d_btn, 16, 12)
			preview_label.text = "Drawing needs attention: " + " • ".join(result.errors)
			return
		var preview: Dictionary = result.preview
		var bounds: Rect2 = preview.get("bounds", Rect2())
		var bridges := int(preview.get("bridge_count", 0))
		var bridge_str := "Flat (0 bridges)" if bridges == 0 else ("%d Overpass Bridge%s" % [bridges, "" if bridges == 1 else "s"])
		builder_state.valid = true
		if not bool(builder_state.get("editing_existing", false)):
			builder_state.track_id = ""
		builder_state.points = result.points
		builder_state.suggested_name = str(preview.get("suggested_name", "Custom Rally"))
		if not builder_state.name_edited:
			name_input.text = str(builder_state.suggested_name)
		race_button.disabled = false
		save_button.disabled = false
		inspect_3d_btn.disabled = false
		mode_preview_btn.disabled = false
		UITheme.style_primary_button(race_button, 20, 14)
		UITheme.style_secondary_button(save_button, 17, 12)
		UITheme.style_secondary_button(inspect_3d_btn, 16, 12)
		refresh_builder_preview.call()
		preview_label.text = (
			"Length: %.0f m  •  Est. Lap ~%ds  •  %.0f × %.0f m\n" % [float(preview.length), int(preview.get("estimated_lap_seconds", 20)), bounds.size.x, bounds.size.y] +
			"Layout: %d turns  •  %d pts  •  %s  •  Drag any curve edge to reshape." % [int(preview.get("corner_count", 4)), int(preview.point_count), bridge_str]
		)
	)

	save_button.pressed.connect(func() -> void:
		if not builder_state.valid:
			return
		var custom_track: TrackDefinition = build_current_track.call()
		var save_res := TrackStore.new().save_custom_track(custom_track)
		if not save_res.ok:
			save_status_label.text = "Save failed: %s" % ", ".join(save_res.errors)
			return
		_active_track = custom_track
		_status_label.text = "Saved custom track: %s" % custom_track.display_name
		_refresh_home_card()
		save_status_label.text = "Saved '%s' to local library!" % custom_track.display_name
	)

	race_button.pressed.connect(func() -> void:
		if not builder_state.valid:
			return
		var custom_track: TrackDefinition = build_current_track.call()
		if str(builder_state.track_id).is_empty():
			custom_track.track_id = "custom_drawn_preview"
		overlay.queue_free()
		_show_quick_play_picker(custom_track)
	)

	clear_button.pressed.connect(func() -> void:
		_play_ui_sfx("ui_back")
		show_left_pane.call(false)
		canvas.clear_drawing()
		builder_state.valid = false
		builder_state.track_id = ""
		builder_state.name_edited = false
		name_input.text = "Custom Rally"
		save_status_label.text = ""
		race_button.disabled = true
		save_button.disabled = true
		inspect_3d_btn.disabled = true
		mode_preview_btn.disabled = true
		sync_canvas_tool_buttons.call(false, 0)
		preview_label.text = "Draw a loop on the drafting grid — release anytime to continue stroking, or close back on the gold start ring."
	)

	close_button.pressed.connect(func() -> void:
		_play_ui_sfx("ui_back")
		_refresh_home_card()
		overlay.queue_free()
	)

	# Pre-populate UI state when editing an existing custom track
	if edit_track != null:
		name_input.text = edit_track.display_name
		surface_label.text = "SURFACE: %s" % edit_track.surface.to_upper()
		UITheme.style_rim_pill(asphalt_btn, edit_track.surface == "asphalt", 16, 11)
		UITheme.style_rim_pill(dirt_btn, edit_track.surface == "dirt", 16, 11)
		width_label.text = "ROAD WIDTH: %s" % edit_track.road_width.to_upper()
		for k in width_buttons.keys():
			UITheme.style_rim_pill(width_buttons[k], k == edit_track.road_width, 15, 11)
		theme_label.text = "BIOME THEME: %s" % str(BiomePresets.get_preset(edit_track.theme).display_name).to_upper()
		for k in theme_buttons.keys():
			UITheme.style_rim_pill(theme_buttons[k], k == edit_track.theme, 15, 11)
		canvas.load_preset_points(edit_track.centerline_points)
		builder_state.track_id = edit_track.track_id
		builder_state.valid = true
		builder_state.points = edit_track.centerline_points.duplicate()
		canvas._preview = edit_track.centerline_points.duplicate()
		canvas.queue_redraw()
		race_button.disabled = false
		save_button.disabled = false
		inspect_3d_btn.disabled = false
		mode_preview_btn.disabled = false
		sync_canvas_tool_buttons.call(true, canvas._drawing.size())
		var compiled_edit := TrackCompiler.compile(edit_track)
		preview_label.text = (
			"Editing '%s' (%s)  •  Length: %.0f m  •  %d pts\n" % [edit_track.display_name, edit_track.track_id, float(compiled_edit.get("length", 0.0)), edit_track.centerline_points.size()] +
			"Drag any curve edge on the canvas to reshape, adjust biome settings, or Save."
		)
		refresh_builder_preview.call()

	return overlay
