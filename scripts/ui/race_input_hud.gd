extends CanvasLayer
class_name RaceInputHud

signal retry_requested()
signal event_setup_requested()
signal exit_to_menu_requested()
signal pause_toggled(paused: bool)
signal mute_toggled(muted: bool)
signal sfx_mute_toggled(muted: bool)
signal music_mute_toggled(muted: bool)

var _car: RallyCar
var _race_manager: RaceManager
var _ai_colors: Array[Color] = []
var _left := false
var _right := false
var _brake := false
var _mouse_left := false
var _mouse_right := false
var _mouse_brake := false
var _mouse_brake_left := false
var _touch_fingers: Dictionary = {}
var _touch_left := false
var _touch_right := false
var _touch_brake := false
var _touch_boost := false
var _vis_left := false
var _vis_right := false
var _vis_brake := false

# Top-left frameless floating telemetry
var _telemetry_card: Control
var _pos_rank_label: Label
var _pos_sub_label: Label
var _lap_label: Label
var _timer_label: Label
var _mode_label: Label

# Top-center banner (recovery / boost pickup notices)
var _banner_panel: Panel
var _banner_label: Label
var _banner_fill: ColorRect
var _flash_message := ""
var _flash_timer := 0.0
var _flash_color := UITheme.GOLD

# Top-right circular utilities & frameless minimap
var _minimap: RaceMinimap
var _pause_button: Button
var _sfx_mute_button: Button
var _music_mute_button: Button
var _sfx_muted := false
var _music_muted := false
var _muted := false

var _modal_dimmer: ColorRect
var _pause_card: Panel
var _pause_sfx_button: Button
var _pause_music_button: Button

# Bottom-center frameless speedometer & slim boost bar
var _gauge_card: Control
var _speed_value_label: Label
var _drift_badge: Panel
var _drift_label: Label
var _boost_bar_fill: ColorRect
var _boost_bar_label: Label

# Circular smoked-glass touch controls (no corner steer buttons)
var _left_button: Button = null
var _right_button: Button = null
var _brake_left_button: Button
var _brake_button: Button
var _boost_button: Button
var _last_boost_visual_state := ""
var _last_drift_visual_state := ""
var _last_pos_badge_key := ""
var _last_speed_kmh := -1
var _last_lap_text := ""
var _last_timer_text := ""
var _last_mode_text := ""
var _last_boost_bar_state := ""
var _last_boost_active_str := ""
var _last_banner_mode := ""
var _minimap_refresh_timer := 0.08

# Post-race results modal
var _result_card: Panel
var _result_title_label: Label
var _result_time_label: Label
var _result_badge_label: Label
var _result_summary_label: Label


func configure(car: RallyCar, race_manager: RaceManager = null, ai_colors: Array[Color] = []) -> void:
	_car = car
	_race_manager = race_manager
	_ai_colors = ai_colors.duplicate()
	_last_drift_visual_state = ""
	_last_pos_badge_key = ""
	_last_speed_kmh = -1
	_last_lap_text = ""
	_last_timer_text = ""
	_last_mode_text = ""
	_last_boost_bar_state = ""
	_last_boost_active_str = ""
	_last_banner_mode = ""
	_minimap_refresh_timer = 0.08
	if _race_manager != null:
		if not _race_manager.car_recovered.is_connected(_on_car_recovered):
			_race_manager.car_recovered.connect(_on_car_recovered)
		if not _race_manager.boost_collected.is_connected(_on_boost_collected):
			_race_manager.boost_collected.connect(_on_boost_collected)
	if _minimap != null and _race_manager != null:
		_minimap.configure(_race_manager.get_minimap_data(), _ai_colors)


func _ready() -> void:
	_build_top_left_telemetry()
	_build_top_center_banner()
	_build_top_right_minimap_and_pause()
	_build_bottom_center_gauge()
	_build_touch_pedals()
	_build_modal_dimmer()
	_build_pause_modal()
	_build_result_modal()
	_layout_hud()
	if is_inside_tree() and get_viewport() != null:
		get_viewport().size_changed.connect(_layout_hud)
	if _race_manager != null and _minimap != null:
		_minimap.configure(_race_manager.get_minimap_data(), _ai_colors)


func _current_vp_size() -> Vector2:
	var vp := Vector2(1280.0, 720.0)
	if is_inside_tree() and get_viewport() != null:
		var visible_size := get_viewport().get_visible_rect().size
		if visible_size.x >= 640.0 and visible_size.y >= 360.0:
			vp = visible_size
	return vp


func _layout_hud() -> void:
	var vp := _current_vp_size()
	if _telemetry_card != null:
		_telemetry_card.position = Vector2(28.0, 18.0)
	if _banner_panel != null:
		_banner_panel.position = Vector2((vp.x - 460.0) * 0.5, 18.0)
	# Top-right circular row: SFX | BGM | ||
	if _sfx_mute_button != null:
		_sfx_mute_button.position = Vector2(vp.x - 214.0, 18.0)
	if _music_mute_button != null:
		_music_mute_button.position = Vector2(vp.x - 150.0, 18.0)
	if _pause_button != null:
		_pause_button.position = Vector2(vp.x - 86.0, 18.0)
	if _minimap != null:
		_minimap.position = Vector2(vp.x - 214.0, 82.0)
	if _gauge_card != null:
		_gauge_card.position = Vector2((vp.x - 310.0) * 0.5, vp.y - 114.0)
	if _brake_left_button != null:
		_brake_left_button.position = Vector2(24.0, vp.y - 178.0)
	if _brake_button != null:
		_brake_button.position = Vector2(vp.x - 188.0, vp.y - 178.0)
	if _boost_button != null:
		_boost_button.position = Vector2(vp.x - 188.0, vp.y - 332.0)
	if _modal_dimmer != null:
		_modal_dimmer.position = Vector2.ZERO
		_modal_dimmer.size = vp
	if _pause_card != null:
		_pause_card.position = (vp - _pause_card.size) * 0.5
	if _result_card != null:
		_result_card.position = (vp - _result_card.size) * 0.5


func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	if _pause_card != null and _pause_card.visible:
		return
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
	if _car == null:
		return
	var drive_state := _car.get_drive_state()
	var raw_speed := float(drive_state.get("speed", 0.0))
	var speed_kmh := 0 if raw_speed < 0.15 else roundi(raw_speed * 5.8)
	var is_braking: bool = drive_state.get("braking", false)
	var is_reversing: bool = drive_state.get("reversing", false)
	var boost_charged: bool = drive_state.get("boost_charged", false)
	var boost_remaining: float = float(drive_state.get("boost_remaining", 0.0))

	# Speedometer & Drift / Reverse pill
	if speed_kmh != _last_speed_kmh:
		_last_speed_kmh = speed_kmh
		_speed_value_label.text = "%03d" % speed_kmh
	var drifting := is_braking and not is_reversing and speed_kmh > 35
	var drift_key := "REV" if is_reversing else ("DRIFT_ON" if drifting else "DRIFT_OFF")
	if _last_drift_visual_state != drift_key:
		_last_drift_visual_state = drift_key
		if is_reversing:
			_drift_badge.visible = true
			_drift_label.text = "REV"
			_drift_badge.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COPPER_GLOW, 10, UITheme.GOLD, 1, 0))
		elif drifting:
			_drift_badge.visible = true
			_drift_label.text = "DRIFT"
			_drift_badge.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.CRIMSON_BG, 10, UITheme.CRIMSON, 1, 0))
		else:
			_drift_badge.visible = false

	# Slim Boost gauge & circular Boost button state
	var boost_visual := "EMPTY"
	if boost_remaining > 0.0:
		boost_visual = "ACTIVE"
		var ratio := clampf(boost_remaining / RallyDriveModel.BOOST_DURATION, 0.0, 1.0)
		_boost_bar_fill.size.x = 256.0 * ratio
		var active_str := "BOOSTING  %.1fs" % boost_remaining
		if active_str != _last_boost_active_str:
			_last_boost_active_str = active_str
			_boost_bar_label.text = active_str
		if _last_boost_bar_state != boost_visual:
			_last_boost_bar_state = boost_visual
			_boost_bar_fill.color = UITheme.EMERALD
			_boost_bar_label.add_theme_color_override("font_color", UITheme.EMERALD)
	elif boost_charged:
		boost_visual = "READY"
		if _last_boost_bar_state != boost_visual:
			_last_boost_bar_state = boost_visual
			_last_boost_active_str = ""
			_boost_bar_fill.size.x = 256.0
			_boost_bar_fill.color = UITheme.GOLD
			_boost_bar_label.text = "BOOST READY"
			_boost_bar_label.add_theme_color_override("font_color", UITheme.GOLD)
	else:
		if _last_boost_bar_state != boost_visual:
			_last_boost_bar_state = boost_visual
			_last_boost_active_str = ""
			_boost_bar_fill.size.x = 0.0
			_boost_bar_label.text = "BOOST EMPTY"
			_boost_bar_label.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	_update_boost_button_visual(boost_visual)

	# Race status, floating position rank, banner, minimap, and finish overlay
	if _race_manager != null:
		var status := _race_manager.get_status()
		var total_racers := int(status.get("total_racers", 1))
		var pos := int(status.get("position", 1))
		var mode := str(status.get("mode", RaceResult.MODE_CIRCUIT))
		if mode == RaceResult.MODE_TIME_TRIAL or total_racers <= 1:
			var solo_key := "SOLO:%s" % mode
			if _last_pos_badge_key != solo_key:
				_last_pos_badge_key = solo_key
				_pos_rank_label.text = "SOLO"
				_pos_sub_label.text = "HOTLAP" if mode == RaceResult.MODE_TIME_TRIAL else "1 CAR"
				_pos_rank_label.add_theme_font_size_override("font_size", 44)
				_pos_rank_label.add_theme_color_override("font_color", UITheme.GOLD)
		else:
			var pos_key := "%d:%d" % [pos, total_racers]
			if _last_pos_badge_key != pos_key:
				_last_pos_badge_key = pos_key
				_pos_rank_label.text = _ordinal_upper(pos)
				_pos_sub_label.text = "OF %d" % total_racers
				_pos_rank_label.add_theme_font_size_override("font_size", 48)
				_pos_rank_label.add_theme_color_override("font_color", _rank_color(pos))

		var lap_str := "LAP %d / %d" % [int(status.get("lap", 1)), int(status.get("lap_target", 1))]
		if lap_str != _last_lap_text:
			_last_lap_text = lap_str
			_lap_label.text = lap_str
		var display_seconds: float = float(status.get("finish_seconds", 0.0)) if status.get("finished", false) else float(status.get("elapsed_seconds", 0.0))
		var timer_str := _format_time(display_seconds)
		if timer_str != _last_timer_text:
			_last_timer_text = timer_str
			_timer_label.text = timer_str
		var mode_str := "TIME TRIAL • GHOST ACTIVE" if mode == RaceResult.MODE_TIME_TRIAL else "CIRCUIT RACE"
		if mode_str != _last_mode_text:
			_last_mode_text = mode_str
			_mode_label.text = mode_str

		_update_banner(float(status.get("recovery_seconds", 0.0)))
		_minimap_refresh_timer += delta
		if _minimap_refresh_timer >= 0.08:
			_minimap_refresh_timer = 0.0
			var markers := _race_manager.get_racer_map_markers()
			_minimap.update_state(
				markers.get("player_point", Vector2.ZERO),
				markers.get("player_heading", Vector2(0.0, -1.0)),
				markers.get("ai_points", []),
				_race_manager.get_boost_pickups_state()
			)
		if status.get("finished", false):
			_clear_touch_inputs()
			_show_result()
	else:
		if _last_pos_badge_key != "PREVIEW":
			_last_pos_badge_key = "PREVIEW"
			_pos_rank_label.text = "TEST"
			_pos_sub_label.text = "DRIVE"
			_lap_label.text = "LAP 1 / 1"
			_timer_label.text = "00:00.000"
			_mode_label.text = "RACE PREVIEW"


func get_hud_snapshot() -> Dictionary:
	return {
		"position_text": _pos_rank_label.text if _pos_rank_label != null else "",
		"position_sub_text": _pos_sub_label.text if _pos_sub_label != null else "",
		"lap_text": _lap_label.text if _lap_label != null else "",
		"timer_text": _timer_label.text if _timer_label != null else "",
		"speed_text": _speed_value_label.text if _speed_value_label != null else "",
		"boost_state": _last_boost_visual_state,
		"banner_visible": _banner_panel.visible if _banner_panel != null else false,
		"banner_text": _banner_label.text if _banner_label != null else "",
		"result_visible": _result_card.visible if _result_card != null else false,
		"pause_visible": _pause_card.visible if _pause_card != null else false,
		"sfx_muted": _sfx_muted,
		"music_muted": _music_muted,
	}


func _build_top_left_telemetry() -> void:
	var container := Control.new()
	container.name = "TelemetryCard"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.position = Vector2(28.0, 18.0)
	container.size = Vector2(320.0, 148.0)
	add_child(container)
	_telemetry_card = container

	_pos_rank_label = Label.new()
	_pos_rank_label.position = Vector2(0.0, 0.0)
	_pos_rank_label.size = Vector2(124.0, 54.0)
	UITheme.style_hud_outlined_label(_pos_rank_label, 48, UITheme.GOLD, 7, false)
	container.add_child(_pos_rank_label)

	_pos_sub_label = Label.new()
	_pos_sub_label.position = Vector2(126.0, 16.0)
	_pos_sub_label.size = Vector2(140.0, 32.0)
	UITheme.style_hud_outlined_label(_pos_sub_label, 26, UITheme.TEXT_PRIMARY, 6, false)
	container.add_child(_pos_sub_label)

	_lap_label = Label.new()
	_lap_label.position = Vector2(2.0, 54.0)
	_lap_label.size = Vector2(280.0, 32.0)
	UITheme.style_hud_outlined_label(_lap_label, 25, UITheme.TEXT_PRIMARY, 6, false)
	container.add_child(_lap_label)

	_timer_label = Label.new()
	_timer_label.position = Vector2(2.0, 86.0)
	_timer_label.size = Vector2(280.0, 32.0)
	UITheme.style_hud_outlined_label(_timer_label, 25, UITheme.TEXT_PRIMARY, 5, true)
	container.add_child(_timer_label)

	_mode_label = Label.new()
	_mode_label.position = Vector2(2.0, 120.0)
	_mode_label.size = Vector2(300.0, 24.0)
	UITheme.style_hud_outlined_label(_mode_label, 15, UITheme.GOLD, 4, false)
	container.add_child(_mode_label)


func _build_top_center_banner() -> void:
	_banner_panel = Panel.new()
	_banner_panel.name = "StatusBanner"
	_banner_panel.position = Vector2(410.0, 18.0)
	_banner_panel.size = Vector2(460.0, 58.0)
	_banner_panel.visible = false
	_banner_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_MODAL, 14, UITheme.BORDER_GOLD_BRIGHT, 2, 10))
	add_child(_banner_panel)

	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(16.0, 42.0)
	bar_bg.size = Vector2(428.0, 7.0)
	bar_bg.color = UITheme.CANVAS_BG
	_banner_panel.add_child(bar_bg)

	_banner_fill = ColorRect.new()
	_banner_fill.position = Vector2(16.0, 42.0)
	_banner_fill.size = Vector2(0.0, 7.0)
	_banner_fill.color = UITheme.GOLD
	_banner_panel.add_child(_banner_fill)

	_banner_label = Label.new()
	_banner_label.position = Vector2(12.0, 7.0)
	_banner_label.size = Vector2(436.0, 28.0)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_banner_label, 18, UITheme.GOLD, true, false)
	_banner_panel.add_child(_banner_label)


func _build_top_right_minimap_and_pause() -> void:
	_sfx_mute_button = Button.new()
	_sfx_mute_button.name = "SfxMuteButton"
	_sfx_mute_button.text = "SFX"
	_sfx_mute_button.position = Vector2(1066.0, 18.0)
	_sfx_mute_button.size = Vector2(56.0, 56.0)
	_sfx_mute_button.pressed.connect(_on_sfx_mute_pressed)
	add_child(_sfx_mute_button)

	_music_mute_button = Button.new()
	_music_mute_button.name = "MusicMuteButton"
	_music_mute_button.text = "BGM"
	_music_mute_button.position = Vector2(1130.0, 18.0)
	_music_mute_button.size = Vector2(56.0, 56.0)
	_music_mute_button.pressed.connect(_on_music_mute_pressed)
	add_child(_music_mute_button)

	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.text = ""
	_pause_button.icon = AssetRegistry.load_icon("pause")
	_pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_button.add_theme_constant_override("icon_max_width", 22)
	_pause_button.position = Vector2(1194.0, 18.0)
	_pause_button.size = Vector2(56.0, 56.0)
	UITheme.style_secondary_button(_pause_button, 15, 28)
	_pause_button.pressed.connect(_toggle_pause_modal)
	add_child(_pause_button)

	_minimap = RaceMinimap.new()
	_minimap.name = "RaceMinimap"
	_minimap.set_hud_frameless_mode(true)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.position = Vector2(1066.0, 82.0)
	_minimap.size = Vector2(184.0, 140.0)
	add_child(_minimap)

	_refresh_audio_toggle_visuals()


func _build_bottom_center_gauge() -> void:
	var gauge := Control.new()
	gauge.name = "SpeedBoostGauge"
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.position = Vector2(485.0, 606.0)
	gauge.size = Vector2(310.0, 106.0)
	add_child(gauge)
	_gauge_card = gauge

	_speed_value_label = Label.new()
	_speed_value_label.position = Vector2(40.0, 0.0)
	_speed_value_label.size = Vector2(144.0, 56.0)
	_speed_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed_value_label.text = "000"
	UITheme.style_hud_outlined_label(_speed_value_label, 48, UITheme.TEXT_PRIMARY, 7, true)
	gauge.add_child(_speed_value_label)

	var unit_label := Label.new()
	unit_label.position = Vector2(190.0, 24.0)
	unit_label.size = Vector2(84.0, 26.0)
	unit_label.text = "KM/H"
	UITheme.style_hud_outlined_label(unit_label, 18, UITheme.GOLD, 4, false)
	gauge.add_child(unit_label)

	_drift_badge = Panel.new()
	_drift_badge.position = Vector2(104.0, -28.0)
	_drift_badge.size = Vector2(102.0, 28.0)
	_drift_badge.visible = false
	_drift_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(_drift_badge)

	_drift_label = Label.new()
	_drift_label.position = Vector2(0.0, 2.0)
	_drift_label.size = Vector2(102.0, 24.0)
	_drift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drift_label.text = "DRIFT"
	UITheme.style_label(_drift_label, 15, UITheme.TEXT_PRIMARY, true, false)
	_drift_badge.add_child(_drift_label)

	var bar_bg_panel := Panel.new()
	bar_bg_panel.position = Vector2(25.0, 60.0)
	bar_bg_panel.size = Vector2(260.0, 14.0)
	bar_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.02, 0.05, 0.04, 0.78), 7, UITheme.BORDER_GOLD, 1, 2))
	gauge.add_child(bar_bg_panel)

	_boost_bar_fill = ColorRect.new()
	_boost_bar_fill.position = Vector2(27.0, 62.0)
	_boost_bar_fill.size = Vector2(256.0, 10.0)
	_boost_bar_fill.color = UITheme.GOLD
	_boost_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(_boost_bar_fill)

	_boost_bar_label = Label.new()
	_boost_bar_label.position = Vector2(0.0, 78.0)
	_boost_bar_label.size = Vector2(310.0, 24.0)
	_boost_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boost_bar_label.text = "BOOST READY"
	UITheme.style_hud_outlined_label(_boost_bar_label, 15, UITheme.GOLD, 4, false)
	gauge.add_child(_boost_bar_label)


func _build_touch_pedals() -> void:
	_left_button = null
	_right_button = null

	var brake_fill := Color(0.059, 0.141, 0.110, 0.62)
	var boost_fill := Color(0.059, 0.141, 0.110, 0.68)

	_brake_left_button = _create_control_button("DRIFT\nBRAKE", Vector2(24.0, 542.0), Vector2(164.0, 156.0), brake_fill, UITheme.COPPER_GLOW, 78)
	_brake_left_button.name = "DriftBrakeLeftButton"
	_brake_left_button.button_down.connect(func() -> void: _mouse_brake_left = true; _sync_input())
	_brake_left_button.button_up.connect(func() -> void: _mouse_brake_left = false; _sync_input())
	add_child(_brake_left_button)

	_brake_button = _create_control_button("DRIFT\nBRAKE", Vector2(1092.0, 542.0), Vector2(164.0, 156.0), brake_fill, UITheme.COPPER_GLOW, 78)
	_brake_button.name = "DriftBrakeButton"
	_brake_button.button_down.connect(func() -> void: _mouse_brake = true; _sync_input())
	_brake_button.button_up.connect(func() -> void: _mouse_brake = false; _sync_input())
	add_child(_brake_button)

	_boost_button = _create_control_button("BOOST", Vector2(1092.0, 388.0), Vector2(164.0, 138.0), boost_fill, UITheme.BORDER_GOLD_BRIGHT, 69, "zap")
	_boost_button.name = "BoostButton"
	_boost_button.pressed.connect(func() -> void:
		if _car != null:
			_car.request_touch_boost()
	)
	add_child(_boost_button)
	_update_boost_button_visual("READY")


func _build_modal_dimmer() -> void:
	_modal_dimmer = ColorRect.new()
	_modal_dimmer.name = "HudModalDimmer"
	_modal_dimmer.color = UITheme.DIMMER_BG
	_modal_dimmer.visible = false
	_modal_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal_dimmer)


func _sync_modal_dimmer() -> void:
	if _modal_dimmer == null:
		return
	var pause_open := _pause_card != null and _pause_card.visible
	var res_open := _result_card != null and _result_card.visible
	_modal_dimmer.visible = pause_open or res_open


func _build_pause_modal() -> void:
	_pause_card = Panel.new()
	_pause_card.name = "PauseModal"
	_pause_card.size = Vector2(480.0, 436.0)
	_pause_card.visible = false
	_pause_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_MODAL, 20, UITheme.BORDER_GOLD_BRIGHT, 2, 18))
	add_child(_pause_card)

	var title := Label.new()
	title.text = "RACE PAUSED"
	title.position = Vector2(0.0, 20.0)
	title.size = Vector2(480.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, 30, UITheme.TEXT_PRIMARY, true, false)
	_pause_card.add_child(title)

	_pause_sfx_button = _create_modal_button("SFX: ON", Vector2(46.0, 76.0), Vector2(186.0, 48.0), false)
	_pause_sfx_button.name = "PauseSfxButton"
	_pause_sfx_button.add_theme_constant_override("icon_max_width", 18)
	_pause_sfx_button.pressed.connect(_on_sfx_mute_pressed)
	_pause_card.add_child(_pause_sfx_button)

	_pause_music_button = _create_modal_button("MUSIC: ON", Vector2(248.0, 76.0), Vector2(186.0, 48.0), false)
	_pause_music_button.name = "PauseMusicButton"
	_pause_music_button.add_theme_constant_override("icon_max_width", 18)
	_pause_music_button.pressed.connect(_on_music_mute_pressed)
	_pause_card.add_child(_pause_music_button)
	_refresh_audio_toggle_visuals()

	var resume_btn := _create_modal_button("RESUME RACE", Vector2(46.0, 140.0), Vector2(388.0, 56.0), true)
	resume_btn.icon = AssetRegistry.load_icon("play")
	resume_btn.add_theme_constant_override("icon_max_width", 20)
	UITheme.style_primary_button(resume_btn, 21, 14)
	resume_btn.pressed.connect(func() -> void:
		_pause_card.visible = false
		_sync_modal_dimmer()
		pause_toggled.emit(false)
	)
	_pause_card.add_child(resume_btn)

	var retry_btn := _create_modal_button("RESTART EVENT", Vector2(46.0, 208.0), Vector2(388.0, 52.0), false)
	retry_btn.icon = AssetRegistry.load_icon("rotate_ccw")
	retry_btn.add_theme_constant_override("icon_max_width", 18)
	retry_btn.pressed.connect(func() -> void:
		_pause_card.visible = false
		_sync_modal_dimmer()
		retry_requested.emit()
	)
	_pause_card.add_child(retry_btn)

	var setup_btn := _create_modal_button("EVENT SETUP", Vector2(46.0, 272.0), Vector2(388.0, 52.0), false)
	setup_btn.icon = AssetRegistry.load_icon("sliders")
	setup_btn.add_theme_constant_override("icon_max_width", 18)
	setup_btn.pressed.connect(func() -> void:
		_pause_card.visible = false
		_sync_modal_dimmer()
		event_setup_requested.emit()
	)
	_pause_card.add_child(setup_btn)

	var menu_btn := _create_modal_button("MAIN MENU", Vector2(46.0, 336.0), Vector2(388.0, 52.0), false)
	menu_btn.icon = AssetRegistry.load_icon("house")
	menu_btn.add_theme_constant_override("icon_max_width", 18)
	menu_btn.pressed.connect(func() -> void:
		_pause_card.visible = false
		_sync_modal_dimmer()
		exit_to_menu_requested.emit()
	)
	_pause_card.add_child(menu_btn)


func _build_result_modal() -> void:
	_result_card = Panel.new()
	_result_card.name = "ResultModal"
	_result_card.size = Vector2(680.0, 436.0)
	_result_card.visible = false
	_result_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_MODAL, 22, UITheme.BORDER_GOLD_BRIGHT, 2, 20))
	add_child(_result_card)

	var trophy_icon := TextureRect.new()
	trophy_icon.texture = AssetRegistry.load_icon("trophy")
	trophy_icon.modulate = UITheme.GOLD
	trophy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy_icon.position = Vector2(312.0, 18.0)
	trophy_icon.size = Vector2(56.0, 56.0)
	_result_card.add_child(trophy_icon)

	_result_title_label = Label.new()
	_result_title_label.position = Vector2(30.0, 78.0)
	_result_title_label.size = Vector2(620.0, 42.0)
	_result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_result_title_label, 32, UITheme.TEXT_PRIMARY, true, false)
	_result_card.add_child(_result_title_label)

	var time_tile := Panel.new()
	time_tile.position = Vector2(44.0, 130.0)
	time_tile.size = Vector2(592.0, 104.0)
	time_tile.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TILE_BG, 14, UITheme.BORDER_GOLD, 1, 0))
	_result_card.add_child(time_tile)

	_result_time_label = Label.new()
	_result_time_label.position = Vector2(16.0, 8.0)
	_result_time_label.size = Vector2(560.0, 56.0)
	_result_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_result_time_label, 44, UITheme.GOLD, false, true)
	time_tile.add_child(_result_time_label)

	_result_badge_label = Label.new()
	_result_badge_label.position = Vector2(16.0, 68.0)
	_result_badge_label.size = Vector2(560.0, 28.0)
	_result_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_result_badge_label, 17, UITheme.EMERALD, true, false)
	time_tile.add_child(_result_badge_label)

	_result_summary_label = Label.new()
	_result_summary_label.position = Vector2(44.0, 246.0)
	_result_summary_label.size = Vector2(592.0, 82.0)
	_result_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_result_summary_label, 20, UITheme.TEXT_SECONDARY, false, false)
	_result_card.add_child(_result_summary_label)

	var menu_btn := _create_modal_button("MAIN MENU", Vector2(44.0, 346.0), Vector2(184.0, 58.0), false)
	menu_btn.pressed.connect(func() -> void: exit_to_menu_requested.emit())
	_result_card.add_child(menu_btn)

	var setup_btn := _create_modal_button("EVENT SETUP", Vector2(240.0, 346.0), Vector2(184.0, 58.0), false)
	setup_btn.pressed.connect(func() -> void: event_setup_requested.emit())
	_result_card.add_child(setup_btn)

	var retry_btn := _create_modal_button("RACE AGAIN", Vector2(436.0, 346.0), Vector2(200.0, 58.0), true)
	retry_btn.pressed.connect(func() -> void: retry_requested.emit())
	_result_card.add_child(retry_btn)


func set_muted(muted: bool) -> void:
	_sfx_muted = muted
	_music_muted = muted
	_muted = muted
	_refresh_audio_toggle_visuals()


func set_sfx_muted(muted: bool) -> void:
	_sfx_muted = muted
	_muted = _sfx_muted and _music_muted
	_refresh_audio_toggle_visuals()


func set_music_muted(muted: bool) -> void:
	_music_muted = muted
	_muted = _sfx_muted and _music_muted
	_refresh_audio_toggle_visuals()


func _refresh_audio_toggle_visuals() -> void:
	_apply_audio_circle_style(_sfx_mute_button, "SFX", _sfx_muted)
	_apply_audio_circle_style(_music_mute_button, "BGM", _music_muted)
	_apply_modal_audio_style(_pause_sfx_button, "SFX", _sfx_muted)
	_apply_modal_audio_style(_pause_music_button, "MUSIC", _music_muted)


func _apply_modal_audio_style(btn: Button, prefix: String, muted: bool) -> void:
	if btn == null:
		return
	btn.text = "%s: OFF" % prefix if muted else "%s: ON" % prefix
	btn.icon = AssetRegistry.load_icon("volume_off" if muted else "volume_on")
	UITheme.style_audio_pill(btn, muted, 17, 12)


func _apply_audio_circle_style(btn: Button, label_text: String, muted: bool) -> void:
	if btn == null:
		return
	btn.text = label_text
	UITheme.style_audio_pill(btn, muted, 15, 28)


func _on_sfx_mute_pressed() -> void:
	set_sfx_muted(not _sfx_muted)
	sfx_mute_toggled.emit(_sfx_muted)
	mute_toggled.emit(_sfx_muted and _music_muted)


func _on_music_mute_pressed() -> void:
	set_music_muted(not _music_muted)
	music_mute_toggled.emit(_music_muted)
	mute_toggled.emit(_sfx_muted and _music_muted)


func _on_mute_pressed() -> void:
	var target := not (_sfx_muted and _music_muted)
	set_muted(target)
	sfx_mute_toggled.emit(target)
	music_mute_toggled.emit(target)
	mute_toggled.emit(target)


func _toggle_pause_modal() -> void:
	if _result_card != null and _result_card.visible:
		return
	_pause_card.visible = not _pause_card.visible
	if _pause_card.visible:
		_clear_touch_inputs()
	_sync_modal_dimmer()
	pause_toggled.emit(_pause_card.visible)


func _update_banner(recovery_seconds: float) -> void:
	if _banner_panel == null:
		return
	if recovery_seconds >= 0.08:
		_banner_panel.visible = true
		var remaining := maxf(0.0, RaceRecoveryMonitor.RECOVERY_DELAY - recovery_seconds)
		var progress := clampf(recovery_seconds / RaceRecoveryMonitor.RECOVERY_DELAY, 0.0, 1.0)
		_banner_label.text = "OFF ROUTE / STUCK — RESET IN %.1fs" % remaining
		_banner_fill.size.x = 428.0 * progress
		if _last_banner_mode != "RECOVERY":
			_last_banner_mode = "RECOVERY"
			_banner_label.add_theme_color_override("font_color", UITheme.GOLD)
			_banner_fill.color = UITheme.COPPER
	elif _flash_timer > 0.0:
		_banner_panel.visible = true
		_banner_label.text = _flash_message
		var flash_key := "FLASH:" + _flash_color.to_html()
		if _last_banner_mode != flash_key:
			_last_banner_mode = flash_key
			_banner_label.add_theme_color_override("font_color", _flash_color)
			_banner_fill.size.x = 428.0
			_banner_fill.color = _flash_color
	else:
		_banner_panel.visible = false
		_last_banner_mode = ""


func _on_car_recovered(_checkpoint_index: int) -> void:
	_flash_message = "RETURNED TO LAST CHECKPOINT"
	_flash_color = UITheme.GOLD
	_flash_timer = 1.2


func _on_boost_collected(_pickup_index: int, by_player: bool) -> void:
	if by_player:
		_flash_message = "BOOST PAD COLLECTED — READY!"
		_flash_color = UITheme.EMERALD
		_flash_timer = 1.1


func _update_boost_button_visual(state_name: String) -> void:
	if _boost_button == null or _last_boost_visual_state == state_name:
		return
	_last_boost_visual_state = state_name
	var fill := Color(0.059, 0.141, 0.110, 0.70)
	var border := UITheme.BORDER_GOLD_BRIGHT
	var fg := UITheme.GOLD
	if state_name == "ACTIVE":
		fill = Color(0.086, 0.247, 0.165, 0.84)
		border = UITheme.EMERALD
		fg = UITheme.EMERALD
		_boost_button.text = "ACTIVE"
	elif state_name == "READY":
		_boost_button.text = "BOOST"
	else:
		fill = Color(0.04, 0.09, 0.07, 0.50)
		border = UITheme.BORDER_SUBTLE
		fg = UITheme.TEXT_MUTED
		_boost_button.text = "EMPTY"
	UITheme.apply_button_theme(
		_boost_button,
		fill,
		fill.lightened(0.08),
		fill.darkened(0.16),
		fg,
		border,
		69,
		3,
		fg,
		6
	)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var modal_open := (_pause_card != null and _pause_card.visible) or (_result_card != null and _result_card.visible)
	if modal_open:
		if not _touch_fingers.is_empty():
			_clear_touch_inputs()
		return
	var vp_ref := get_viewport() if is_inside_tree() else null
	if event is InputEventScreenTouch:
		var touch_ev := event as InputEventScreenTouch
		var local_pos: Vector2 = transform.affine_inverse() * touch_ev.position
		if touch_ev.pressed and not touch_ev.canceled:
			var hit := _pedal_hit_test(local_pos)
			if not hit.is_empty():
				_touch_fingers[touch_ev.index] = hit
				_recompute_touch_inputs()
				if vp_ref != null:
					vp_ref.set_input_as_handled()
		elif _touch_fingers.has(touch_ev.index):
			_touch_fingers.erase(touch_ev.index)
			_recompute_touch_inputs()
			if vp_ref != null:
				vp_ref.set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag_ev := event as InputEventScreenDrag
		if _touch_fingers.has(drag_ev.index):
			var local_pos: Vector2 = transform.affine_inverse() * drag_ev.position
			_touch_fingers[drag_ev.index] = _pedal_hit_test(local_pos)
			_recompute_touch_inputs()
			if vp_ref != null:
				vp_ref.set_input_as_handled()


func _pedal_hit_test(pos: Vector2) -> String:
	for utility in [_pause_button, _sfx_mute_button, _music_mute_button, _minimap]:
		var ctrl := utility as Control
		if ctrl != null and ctrl.visible and ctrl.get_global_rect().grow(6.0).has_point(pos):
			return ""
	var buttons: Array = [
		["brake", _brake_button],
		["brake", _brake_left_button],
		["boost", _boost_button],
	]
	for pair in buttons:
		var btn := pair[1] as Button
		if btn != null and btn.visible and btn.get_global_rect().grow(6.0).has_point(pos):
			return str(pair[0])
	# BBR2-style touch steering: left half of screen steers left, right half steers right.
	var vp := _current_vp_size()
	return "left" if pos.x < vp.x * 0.5 else "right"


func _recompute_touch_inputs() -> void:
	var was_boost := _touch_boost
	_touch_left = false
	_touch_right = false
	_touch_brake = false
	_touch_boost = false
	for action_var in _touch_fingers.values():
		var action_name := str(action_var)
		if action_name == "left":
			_touch_left = true
		elif action_name == "right":
			_touch_right = true
		elif action_name == "brake":
			_touch_brake = true
		elif action_name == "boost":
			_touch_boost = true
	if _touch_boost and not was_boost and _car != null:
		_car.request_touch_boost()
	_sync_input()


func _clear_touch_inputs() -> void:
	_touch_fingers.clear()
	_touch_left = false
	_touch_right = false
	_touch_brake = false
	_touch_boost = false
	_mouse_left = false
	_mouse_right = false
	_mouse_brake = false
	_mouse_brake_left = false
	_sync_input()


func _set_pedal_visual_pressed(btn: Button, active: bool) -> void:
	if btn == null:
		return
	var fill := Color(0.11, 0.24, 0.18, 0.88) if active else Color(0.059, 0.141, 0.110, 0.62)
	var border := UITheme.GOLD if active else UITheme.COPPER_GLOW
	var fg := UITheme.GOLD if active else UITheme.TEXT_PRIMARY
	UITheme.apply_button_theme(btn, fill, fill.lightened(0.08), fill, fg, border, 78, 3, fg, 6)


func _sync_input() -> void:
	_left = _mouse_left or _touch_left
	_right = _mouse_right or _touch_right
	_brake = _mouse_brake or _mouse_brake_left or _touch_brake
	if _brake != _vis_brake:
		_vis_brake = _brake
		_set_pedal_visual_pressed(_brake_button, _vis_brake)
		_set_pedal_visual_pressed(_brake_left_button, _vis_brake)
	if _car != null:
		_car.set_touch_input(_left, _right, _brake)


func _create_control_button(
	text: String,
	pos: Vector2,
	btn_size: Vector2,
	fill_color: Color,
	border_color: Color,
	corner_radius: int,
	icon_key: String = ""
) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = btn_size
	button.add_theme_font_size_override("font_size", 21)
	if not icon_key.is_empty():
		var ic := AssetRegistry.load_icon(icon_key)
		if ic != null:
			button.icon = ic
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override("icon_max_width", 30)
	UITheme.apply_button_theme(
		button,
		fill_color,
		fill_color.lightened(0.08),
		fill_color.darkened(0.18),
		UITheme.TEXT_PRIMARY,
		border_color,
		corner_radius,
		3,
		UITheme.TEXT_PRIMARY,
		6
	)
	return button


func _create_modal_button(text: String, pos: Vector2, btn_size: Vector2, is_primary: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = btn_size
	if is_primary:
		UITheme.style_primary_button(btn, 21, 14)
	else:
		UITheme.style_secondary_button(btn, 19, 12)
	return btn


func _rank_color(position: int) -> Color:
	if position == 1:
		return UITheme.GOLD
	elif position == 2:
		return UITheme.TEXT_PRIMARY
	elif position == 3:
		return UITheme.COPPER
	return UITheme.TEXT_SECONDARY


func _ordinal_upper(n: int) -> String:
	if n == 1:
		return "1ST"
	elif n == 2:
		return "2ND"
	elif n == 3:
		return "3RD"
	return "%dTH" % n


func _format_time(seconds: float) -> String:
	var whole_seconds := int(seconds)
	return "%02d:%02d.%03d" % [whole_seconds / 60, whole_seconds % 60, int((seconds - whole_seconds) * 1000.0)]


func _show_result() -> void:
	if _result_card.visible or _race_manager == null:
		return
	var result := _race_manager.get_result()
	if result.is_empty():
		return
	_pause_card.visible = false
	_result_title_label.text = str(result.get("title", "RACE COMPLETE")).to_upper()
	_result_time_label.text = RaceResult.format_time(float(result.get("finish_seconds", 0.0)))
	if result.get("new_best", false):
		_result_badge_label.text = "NEW TRACK RECORD!"
		UITheme.style_label(_result_badge_label, 17, UITheme.EMERALD, true, false)
	else:
		_result_badge_label.text = "EVENT COMPLETE"
		UITheme.style_label(_result_badge_label, 17, UITheme.GOLD, true, false)
	var summary: String = str(result.get("summary", ""))
	if result.get("new_best", false) and str(result.get("mode", "")) == RaceResult.MODE_TIME_TRIAL:
		summary = "New fastest clean lap! Best-lap ghost updated."
	_result_summary_label.text = summary
	_result_card.visible = true
	_sync_modal_dimmer()
