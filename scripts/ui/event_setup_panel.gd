extends Control
class_name EventSetupPanel

signal start_requested(config: Dictionary)
signal cancelled()

var _config := {
	"track_id": "preview_circuit",
	"track_name": "Preview Circuit",
	"surface": "asphalt",
	"road_width": "wide",
	"theme": "forest",
	"mode": RaceResult.MODE_CIRCUIT,
	"laps": 3,
	"ai_count": 3,
}

var _panel: Panel
var _mode_circuit_btn: Button
var _mode_tt_btn: Button
var _circuit_options: Control
var _tt_info: Control
var _tt_desc: Label
var _laps_label: Label
var _ai_label: Label
var _track_title_label: Label
var _track_meta_label: Label
var _record_label: Label
var _ghost_badge_label: Label
var _lap_buttons: Array[Button] = []
var _ai_buttons: Array[Button] = []


func configure(track: TrackDefinition, initial_config: Dictionary = {}, record: Dictionary = {}) -> void:
	if track != null:
		_config["track_id"] = track.track_id
		_config["track_name"] = track.display_name
		_config["surface"] = track.surface
		_config["road_width"] = track.road_width
		_config["theme"] = track.theme
	if initial_config.has("mode"):
		_config["mode"] = str(initial_config["mode"])
	if initial_config.has("laps"):
		_config["laps"] = clampi(int(initial_config["laps"]), 1, 5)
	if initial_config.has("ai_count"):
		_config["ai_count"] = clampi(int(initial_config["ai_count"]), 0, 7)
	_refresh_track_header(record)
	_refresh_controls()


func get_config() -> Dictionary:
	var out := _config.duplicate(true)
	if out["mode"] == RaceResult.MODE_TIME_TRIAL:
		out["effective_laps"] = 1
		out["effective_ai_count"] = 0
	else:
		out["effective_laps"] = int(out["laps"])
		out["effective_ai_count"] = int(out["ai_count"])
	return out


func set_mode(mode: String) -> void:
	if mode != RaceResult.MODE_CIRCUIT and mode != RaceResult.MODE_TIME_TRIAL:
		return
	_config["mode"] = mode
	_refresh_controls()


func set_laps(laps: int) -> void:
	_config["laps"] = clampi(laps, 1, 5)
	_refresh_controls()


func set_ai_count(ai_count: int) -> void:
	_config["ai_count"] = clampi(ai_count, 0, 7)
	_refresh_controls()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = UITheme.DIMMER_BG
	add_child(dimmer)

	_panel = Panel.new()
	_panel.size = Vector2(760.0, 548.0)
	_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_MODAL, 20, UITheme.BORDER_GOLD_BRIGHT, 2, 18))
	dimmer.add_child(_panel)

	var title := Label.new()
	title.text = "EVENT SETUP"
	title.position = Vector2(0.0, 14.0)
	title.size = Vector2(760.0, 38.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, 30, UITheme.TEXT_PRIMARY, true, false)
	_panel.add_child(title)

	var close_x_btn := Button.new()
	close_x_btn.name = "CancelEventButton"
	close_x_btn.icon = AssetRegistry.load_icon("close")
	close_x_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_x_btn.expand_icon = false
	close_x_btn.add_theme_constant_override("icon_max_width", 18)
	close_x_btn.position = Vector2(704.0, 12.0)
	close_x_btn.size = Vector2(40.0, 40.0)
	close_x_btn.custom_minimum_size = Vector2(40.0, 40.0)
	UITheme.style_secondary_button(close_x_btn, 10, 20)
	for sb_name in ["normal", "hover", "pressed", "focus"]:
		var sb := (close_x_btn.get_theme_stylebox(sb_name) as StyleBoxFlat).duplicate()
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		close_x_btn.add_theme_stylebox_override(sb_name, sb)
	close_x_btn.pressed.connect(func() -> void: cancelled.emit())
	_panel.add_child(close_x_btn)

	# Selected Track Summary Card
	var track_card := Panel.new()
	track_card.position = Vector2(36.0, 66.0)
	track_card.size = Vector2(688.0, 82.0)
	track_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TILE_BG, 14, UITheme.BORDER_SUBTLE, 1, 0))
	_panel.add_child(track_card)

	var summary_kicker := Label.new()
	summary_kicker.text = "SELECTED CIRCUIT"
	summary_kicker.position = Vector2(18.0, 8.0)
	summary_kicker.size = Vector2(320.0, 18.0)
	UITheme.style_label(summary_kicker, 14, UITheme.GOLD, true, false)
	track_card.add_child(summary_kicker)

	_track_title_label = Label.new()
	_track_title_label.position = Vector2(18.0, 26.0)
	_track_title_label.size = Vector2(380.0, 28.0)
	_track_title_label.clip_text = true
	UITheme.style_label(_track_title_label, 24, UITheme.TEXT_PRIMARY, true, false)
	track_card.add_child(_track_title_label)

	_track_meta_label = Label.new()
	_track_meta_label.position = Vector2(18.0, 55.0)
	_track_meta_label.size = Vector2(400.0, 22.0)
	UITheme.style_label(_track_meta_label, 16, UITheme.TEXT_SECONDARY, false, false)
	track_card.add_child(_track_meta_label)

	_record_label = Label.new()
	_record_label.position = Vector2(390.0, 14.0)
	_record_label.size = Vector2(280.0, 28.0)
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(_record_label, 17, UITheme.GOLD, false, true)
	track_card.add_child(_record_label)

	_ghost_badge_label = Label.new()
	_ghost_badge_label.position = Vector2(390.0, 46.0)
	_ghost_badge_label.size = Vector2(280.0, 24.0)
	_ghost_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(_ghost_badge_label, 15, UITheme.TEXT_SECONDARY, true, false)
	track_card.add_child(_ghost_badge_label)

	# Rim-Highlighted Mode Toggle Pills
	_mode_circuit_btn = Button.new()
	_mode_circuit_btn.text = "CIRCUIT RACE"
	_mode_circuit_btn.icon = AssetRegistry.load_icon("flag")
	_mode_circuit_btn.add_theme_constant_override("icon_max_width", 18)
	_mode_circuit_btn.position = Vector2(36.0, 162.0)
	_mode_circuit_btn.size = Vector2(334.0, 54.0)
	_mode_circuit_btn.pressed.connect(func() -> void: set_mode(RaceResult.MODE_CIRCUIT))
	_panel.add_child(_mode_circuit_btn)

	_mode_tt_btn = Button.new()
	_mode_tt_btn.text = "TIME TRIAL"
	_mode_tt_btn.icon = AssetRegistry.load_icon("timer")
	_mode_tt_btn.add_theme_constant_override("icon_max_width", 18)
	_mode_tt_btn.position = Vector2(390.0, 162.0)
	_mode_tt_btn.size = Vector2(334.0, 54.0)
	_mode_tt_btn.pressed.connect(func() -> void: set_mode(RaceResult.MODE_TIME_TRIAL))
	_panel.add_child(_mode_tt_btn)

	# Circuit Race Options
	_circuit_options = Control.new()
	_circuit_options.position = Vector2(36.0, 230.0)
	_circuit_options.size = Vector2(688.0, 214.0)
	_panel.add_child(_circuit_options)

	_laps_label = Label.new()
	_laps_label.position = Vector2(0.0, 0.0)
	_laps_label.size = Vector2(688.0, 26.0)
	UITheme.style_label(_laps_label, 16, UITheme.TEXT_SECONDARY, true, false)
	_circuit_options.add_child(_laps_label)

	_lap_buttons.clear()
	for i in range(1, 6):
		var btn := Button.new()
		btn.text = "%d %s" % [i, "Lap" if i == 1 else "Laps"]
		btn.position = Vector2(float((i - 1) * 139), 32.0)
		btn.size = Vector2(130.0, 50.0)
		var lap_val := i
		btn.pressed.connect(func() -> void: set_laps(lap_val))
		_circuit_options.add_child(btn)
		_lap_buttons.append(btn)

	_ai_label = Label.new()
	_ai_label.position = Vector2(0.0, 98.0)
	_ai_label.size = Vector2(688.0, 26.0)
	UITheme.style_label(_ai_label, 16, UITheme.TEXT_SECONDARY, true, false)
	_circuit_options.add_child(_ai_label)

	_ai_buttons.clear()
	for i in 8:
		var btn := Button.new()
		btn.text = "%d" % i
		btn.position = Vector2(float(i * 87), 130.0)
		btn.size = Vector2(78.0, 52.0)
		var ai_val := i
		btn.pressed.connect(func() -> void: set_ai_count(ai_val))
		_circuit_options.add_child(btn)
		_ai_buttons.append(btn)

	# Time Trial Description Card
	_tt_info = Panel.new()
	_tt_info.position = Vector2(36.0, 230.0)
	_tt_info.size = Vector2(688.0, 206.0)
	_tt_info.visible = false
	(_tt_info as Panel).add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TILE_BG, 14, UITheme.BORDER_GOLD, 1, 0))
	_panel.add_child(_tt_info)

	_tt_desc = Label.new()
	_tt_desc.text = "SOLO HOTLAP  •  1 FLYING LAP  •  GHOST REPLAY\n\nRace the clock with zero traffic.\nFaster clean laps automatically update your personal best record and recorded ghost line."
	_tt_desc.position = Vector2(28.0, 28.0)
	_tt_desc.size = Vector2(632.0, 150.0)
	_tt_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tt_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tt_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_tt_desc, 19, UITheme.TEXT_PRIMARY, false, false)
	_tt_info.add_child(_tt_desc)

	# Action Footer Buttons
	var cancel_btn := Button.new()
	cancel_btn.text = "BACK"
	cancel_btn.icon = AssetRegistry.load_icon("chevron_left")
	cancel_btn.add_theme_constant_override("icon_max_width", 18)
	cancel_btn.position = Vector2(36.0, 466.0)
	cancel_btn.size = Vector2(260.0, 58.0)
	UITheme.style_secondary_button(cancel_btn, 20, 14)
	cancel_btn.pressed.connect(func() -> void: cancelled.emit())
	_panel.add_child(cancel_btn)

	var start_btn := Button.new()
	start_btn.name = "StartEventButton"
	start_btn.text = "START EVENT"
	start_btn.icon = AssetRegistry.load_icon("play")
	start_btn.add_theme_constant_override("icon_max_width", 20)
	start_btn.position = Vector2(314.0, 466.0)
	start_btn.size = Vector2(410.0, 58.0)
	UITheme.style_primary_button(start_btn, 23, 14)
	start_btn.pressed.connect(func() -> void: start_requested.emit(get_config()))
	_panel.add_child(start_btn)

	if is_inside_tree() and get_viewport() != null:
		get_viewport().size_changed.connect(_layout_modal)
	_layout_modal()
	_refresh_track_header({})
	_refresh_controls()


func _layout_modal() -> void:
	if _panel == null:
		return
	var vp := Vector2(1280.0, 720.0)
	if is_inside_tree() and get_viewport() != null:
		var vs := get_viewport().get_visible_rect().size
		if vs.x >= 640.0 and vs.y >= 360.0:
			vp = vs
	_panel.position = (vp - _panel.size) * 0.5


func _refresh_track_header(record: Dictionary) -> void:
	if _track_title_label == null:
		return
	_track_title_label.text = str(_config.get("track_name", "Preview Circuit")).to_upper()
	var surface := str(_config.get("surface", "asphalt")).capitalize()
	var width := str(_config.get("road_width", "wide")).capitalize()
	var theme_key := str(_config.get("theme", "forest"))
	var theme_str := str(BiomePresets.get_preset(theme_key).display_name)
	_track_meta_label.text = "%s Surface  •  %s Road  •  %s" % [surface, width, theme_str]

	var best_lap_ms := int(record.get("best_lap_ms", 0))
	var ghost_samples: Array = record.get("ghost_samples", [])
	var lap_str := RaceResult.format_time(float(best_lap_ms) / 1000.0) if best_lap_ms > 0 else "--:--.---"
	_record_label.text = "BEST LAP: %s" % lap_str
	if ghost_samples.is_empty():
		_ghost_badge_label.text = "TIME TRIAL: NO GHOST SAVED"
		UITheme.style_label(_ghost_badge_label, 15, UITheme.TEXT_MUTED, true, false)
	else:
		_ghost_badge_label.text = "GHOST READY (%d PTS)" % ghost_samples.size()
		UITheme.style_label(_ghost_badge_label, 15, UITheme.EMERALD, true, false)


func _refresh_controls() -> void:
	if _mode_circuit_btn == null:
		return
	var is_circuit := str(_config.get("mode", RaceResult.MODE_CIRCUIT)) == RaceResult.MODE_CIRCUIT
	UITheme.style_rim_pill(_mode_circuit_btn, is_circuit, 20, 14)
	UITheme.style_rim_pill(_mode_tt_btn, not is_circuit, 20, 14)
	_circuit_options.visible = is_circuit
	_tt_info.visible = not is_circuit

	var laps := int(_config.get("laps", 3))
	_laps_label.text = "RACE DISTANCE:  %d %s" % [laps, "LAP" if laps == 1 else "LAPS"]
	for i in _lap_buttons.size():
		UITheme.style_rim_pill(_lap_buttons[i], (i + 1) == laps, 18, 12)

	var ai_count := int(_config.get("ai_count", 3))
	var grid_desc := "SOLO GRID (1 CAR)" if ai_count == 0 else "%d AI OPPONENTS (%d CARS ON GRID)" % [ai_count, ai_count + 1]
	_ai_label.text = "AI OPPONENTS:  %s" % grid_desc
	for i in _ai_buttons.size():
		UITheme.style_rim_pill(_ai_buttons[i], i == ai_count, 20, 12)
