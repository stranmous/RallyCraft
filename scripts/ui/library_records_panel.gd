extends Control
class_name LibraryRecordsPanel

signal race_track_requested(track: TrackDefinition)
signal edit_track_requested(track: TrackDefinition)
signal track_deleted(track_id: String)
signal cancelled()

const TAB_LIBRARY := "library"
const TAB_RECORDS := "records"

var _active_tab := TAB_LIBRARY
var _custom_tracks: Array[TrackDefinition] = []
var _all_tracks: Array[TrackDefinition] = []
var _selected_track: TrackDefinition
var _item_buttons: Dictionary = {} # track_id -> Button

var _preview_widget: TrackPreviewWidget
var _top_bar: Panel
var _back_top_btn: Button
var _tab_library_btn: Button
var _tab_records_btn: Button
var _import_open_btn: Button
var _mode_2d_btn: Button
var _mode_3d_btn: Button

var _list_panel: Panel
var _list_title_label: Label
var _list_scroll: ScrollContainer
var _list_vbox: VBoxContainer
var _empty_label: Label

var _detail_panel: Panel
var _detail_content: Control
var _detail_empty_label: Label
var _title_label: Label
var _badge_label: Label
var _rename_input: LineEdit
var _rename_btn: Button
var _stat_length_val: Label
var _stat_surface_val: Label
var _stat_width_val: Label
var _stat_biome_val: Label
var _record_card: Panel
var _records_label: Label
var _status_label: Label
var _edit_btn: Button
var _export_btn: Button
var _delete_btn: Button
var _race_btn: Button

# Import & Export Modal state
var _modal_overlay: Control
var _modal_card: Panel
var _import_input: TextEdit
var _import_name_edit: LineEdit
var _import_status_label: Label
var _import_preview_widget: TrackPreviewWidget
var _import_confirm_btn: Button
var _staged_import_id := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.BG_BACKDROP
	add_child(bg)

	# Full-bleed live 3D/2D preview backdrop behind floating glass docks
	_preview_widget = TrackPreviewWidget.new()
	_preview_widget.name = "LibraryTrackPreview"
	_preview_widget.set_full_bleed_mode(true)
	_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_3D)
	bg.add_child(_preview_widget)

	# Full-Width Unified Top Bar
	_top_bar = Panel.new()
	_top_bar.name = "LibraryTopBar"
	_top_bar.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TOPBAR_BG, 14, UITheme.BORDER_SUBTLE, 1, 8))
	add_child(_top_bar)

	_back_top_btn = Button.new()
	_back_top_btn.name = "BackButton"
	_back_top_btn.text = "BACK"
	_back_top_btn.icon = AssetRegistry.load_icon("chevron_left")
	_back_top_btn.add_theme_constant_override("icon_max_width", 18)
	UITheme.style_secondary_button(_back_top_btn, 17, 11)
	_back_top_btn.pressed.connect(func() -> void:
		cancel_current_import()
		cancelled.emit()
	)
	_top_bar.add_child(_back_top_btn)

	_tab_library_btn = Button.new()
	_tab_library_btn.name = "TabLibraryButton"
	_tab_library_btn.text = "CUSTOM LIBRARY"
	_tab_library_btn.pressed.connect(func() -> void: set_tab(TAB_LIBRARY))
	_top_bar.add_child(_tab_library_btn)

	_tab_records_btn = Button.new()
	_tab_records_btn.name = "TabRecordsButton"
	_tab_records_btn.text = "RECORDS HALL"
	_tab_records_btn.pressed.connect(func() -> void: set_tab(TAB_RECORDS))
	_top_bar.add_child(_tab_records_btn)

	_import_open_btn = Button.new()
	_import_open_btn.name = "ImportTrackButton"
	_import_open_btn.text = "IMPORT"
	_import_open_btn.icon = AssetRegistry.load_icon("upload")
	_import_open_btn.add_theme_constant_override("icon_max_width", 18)
	UITheme.style_secondary_button(_import_open_btn, 16, 11)
	_import_open_btn.pressed.connect(open_import_modal)
	_top_bar.add_child(_import_open_btn)

	_mode_2d_btn = Button.new()
	_mode_2d_btn.name = "Library2DModeButton"
	_mode_2d_btn.text = "2D Map"
	_mode_2d_btn.pressed.connect(func() -> void:
		_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_2D)
		_refresh_view_toggle_buttons()
	)
	_top_bar.add_child(_mode_2d_btn)

	_mode_3d_btn = Button.new()
	_mode_3d_btn.name = "Library3DModeButton"
	_mode_3d_btn.text = "3D Orbit"
	_mode_3d_btn.pressed.connect(func() -> void:
		_preview_widget.set_view_mode(TrackPreviewWidget.VIEW_3D)
		_refresh_view_toggle_buttons()
	)
	_top_bar.add_child(_mode_3d_btn)

	# Left Floating Track / Record List Dock
	_list_panel = Panel.new()
	_list_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_DARK, 16, UITheme.BORDER_GOLD, 2, 12))
	add_child(_list_panel)

	_list_title_label = Label.new()
	UITheme.style_label(_list_title_label, 16, UITheme.GOLD, true, false)
	_list_panel.add_child(_list_title_label)

	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_panel.add_child(_list_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 10)
	_list_scroll.add_child(_list_vbox)

	_empty_label = Label.new()
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_empty_label, 18, UITheme.TEXT_SECONDARY, false, false)
	_list_panel.add_child(_empty_label)

	# Right Floating Detail & Actions Dock
	_detail_panel = Panel.new()
	_detail_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_DARK, 16, UITheme.BORDER_GOLD, 2, 12))
	add_child(_detail_panel)

	_detail_empty_label = Label.new()
	_detail_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_empty_label.text = "No custom track selected.\nCreate a circuit in the Track Builder, import a share code above, or switch to the Records Hall tab."
	UITheme.style_label(_detail_empty_label, 18, UITheme.TEXT_SECONDARY, false, false)
	_detail_panel.add_child(_detail_empty_label)

	_detail_content = Control.new()
	_detail_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_panel.add_child(_detail_content)

	_badge_label = Label.new()
	UITheme.style_label(_badge_label, 14, UITheme.GOLD, true, false)
	_detail_content.add_child(_badge_label)

	_title_label = Label.new()
	_title_label.clip_text = true
	UITheme.style_label(_title_label, 28, UITheme.TEXT_PRIMARY, true, false)
	_detail_content.add_child(_title_label)

	_rename_input = LineEdit.new()
	_rename_input.name = "RenameLineEdit"
	_rename_input.max_length = TrackDefinition.MAX_NAME_LENGTH
	_rename_input.placeholder_text = "Rename custom track..."
	UITheme.style_line_edit(_rename_input, 17)
	_detail_content.add_child(_rename_input)

	_rename_btn = Button.new()
	_rename_btn.name = "RenameSaveButton"
	_rename_btn.text = "RENAME"
	UITheme.style_secondary_button(_rename_btn, 16, 10)
	_rename_btn.pressed.connect(_on_rename_pressed)
	_detail_content.add_child(_rename_btn)

	_stat_length_val = UITheme.make_stat_tile(_detail_content, Vector2(20.0, 128.0), Vector2(190.0, 70.0), "LENGTH", "--")
	_stat_surface_val = UITheme.make_stat_tile(_detail_content, Vector2(222.0, 128.0), Vector2(190.0, 70.0), "SURFACE", "--")
	_stat_width_val = UITheme.make_stat_tile(_detail_content, Vector2(20.0, 206.0), Vector2(190.0, 70.0), "ROAD WIDTH", "--")
	_stat_biome_val = UITheme.make_stat_tile(_detail_content, Vector2(222.0, 206.0), Vector2(190.0, 70.0), "BIOME", "--")

	_record_card = Panel.new()
	_record_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.TILE_BG, 12, UITheme.BORDER_SUBTLE, 1, 0))
	_detail_content.add_child(_record_card)

	_records_label = Label.new()
	_records_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_records_label, 16, UITheme.TEXT_PRIMARY, false, true)
	_record_card.add_child(_records_label)

	_status_label = Label.new()
	_status_label.name = "LibraryStatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.clip_text = true
	UITheme.style_label(_status_label, 15, UITheme.EMERALD, false, false)
	_detail_content.add_child(_status_label)

	_edit_btn = Button.new()
	_edit_btn.name = "EditTrackButton"
	_edit_btn.text = "EDIT"
	_edit_btn.icon = AssetRegistry.load_icon("pencil")
	_edit_btn.add_theme_constant_override("icon_max_width", 16)
	UITheme.style_secondary_button(_edit_btn, 16, 12)
	_edit_btn.pressed.connect(edit_selected_track)
	_detail_content.add_child(_edit_btn)

	_export_btn = Button.new()
	_export_btn.name = "ExportTrackButton"
	_export_btn.text = "EXPORT"
	_export_btn.icon = AssetRegistry.load_icon("share")
	_export_btn.add_theme_constant_override("icon_max_width", 16)
	UITheme.style_secondary_button(_export_btn, 16, 12)
	_export_btn.pressed.connect(func() -> void: export_selected_track(true))
	_detail_content.add_child(_export_btn)

	_delete_btn = Button.new()
	_delete_btn.name = "DeleteTrackButton"
	_delete_btn.text = "DELETE"
	_delete_btn.icon = AssetRegistry.load_icon("trash")
	_delete_btn.add_theme_constant_override("icon_max_width", 16)
	UITheme.style_danger_button(_delete_btn, 16, 12)
	_delete_btn.pressed.connect(delete_selected_track)
	_detail_content.add_child(_delete_btn)

	_race_btn = Button.new()
	_race_btn.name = "RaceTrackButton"
	_race_btn.text = "RACE TRACK"
	_race_btn.icon = AssetRegistry.load_icon("play")
	_race_btn.add_theme_constant_override("icon_max_width", 18)
	UITheme.style_primary_button(_race_btn, 20, 14)
	_race_btn.pressed.connect(race_selected_track)
	_detail_content.add_child(_race_btn)

	if is_inside_tree() and get_viewport() != null:
		get_viewport().size_changed.connect(_layout_screen)
	_layout_screen()
	_refresh_view_toggle_buttons()
	refresh_data()


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
		_preview_widget.set_2d_safe_margins(452.0, 92.0, 472.0, 28.0)

	if _top_bar != null:
		_top_bar.position = Vector2(24.0, 14.0)
		_top_bar.size = Vector2(vp.x - 48.0, 56.0)
		var bar_w := _top_bar.size.x
		_back_top_btn.position = Vector2(10.0, 9.0)
		_back_top_btn.size = Vector2(114.0, 38.0)

		var tab_start := clampf(bar_w * 0.5 - 230.0, 136.0, bar_w - 772.0)
		_tab_library_btn.position = Vector2(tab_start, 9.0)
		_tab_library_btn.size = Vector2(196.0, 38.0)
		_tab_records_btn.position = Vector2(tab_start + 204.0, 9.0)
		_tab_records_btn.size = Vector2(186.0, 38.0)

		_import_open_btn.position = Vector2(bar_w - 372.0, 9.0)
		_import_open_btn.size = Vector2(138.0, 38.0)
		_mode_2d_btn.position = Vector2(bar_w - 224.0, 9.0)
		_mode_2d_btn.size = Vector2(100.0, 38.0)
		_mode_3d_btn.position = Vector2(bar_w - 116.0, 9.0)
		_mode_3d_btn.size = Vector2(106.0, 38.0)

	if _list_panel != null:
		_list_panel.position = Vector2(24.0, 84.0)
		_list_panel.size = Vector2(412.0, vp.y - 104.0)
		_list_title_label.position = Vector2(20.0, 16.0)
		_list_title_label.size = Vector2(372.0, 24.0)
		_list_scroll.position = Vector2(16.0, 48.0)
		_list_scroll.size = Vector2(380.0, _list_panel.size.y - 64.0)
		_empty_label.position = Vector2(26.0, 140.0)
		_empty_label.size = Vector2(360.0, 220.0)

	if _detail_panel != null:
		_detail_panel.position = Vector2(vp.x - 456.0, 84.0)
		_detail_panel.size = Vector2(432.0, vp.y - 104.0)
		var dh := _detail_panel.size.y
		_detail_empty_label.position = Vector2(36.0, dh * 0.5 - 64.0)
		_detail_empty_label.size = Vector2(360.0, 128.0)

		_badge_label.position = Vector2(20.0, 14.0)
		_badge_label.size = Vector2(392.0, 20.0)
		_title_label.position = Vector2(20.0, 36.0)
		_title_label.size = Vector2(392.0, 36.0)

		_rename_input.position = Vector2(20.0, 76.0)
		_rename_input.size = Vector2(274.0, 42.0)
		_rename_btn.position = Vector2(302.0, 76.0)
		_rename_btn.size = Vector2(110.0, 42.0)

		_record_card.position = Vector2(20.0, 286.0)
		_record_card.size = Vector2(392.0, maxf(96.0, dh - 446.0))
		_records_label.position = Vector2(16.0, 12.0)
		_records_label.size = Vector2(360.0, _record_card.size.y - 24.0)

		_status_label.position = Vector2(20.0, dh - 150.0)
		_status_label.size = Vector2(392.0, 28.0)

		var btn_y := dh - 118.0
		_edit_btn.position = Vector2(20.0, btn_y)
		_edit_btn.size = Vector2(124.0, 44.0)
		_export_btn.position = Vector2(152.0, btn_y)
		_export_btn.size = Vector2(128.0, 44.0)
		_delete_btn.position = Vector2(288.0, btn_y)
		_delete_btn.size = Vector2(124.0, 44.0)

		_race_btn.position = Vector2(20.0, dh - 66.0)
		_race_btn.size = Vector2(392.0, 52.0)

	if _modal_card != null and is_instance_valid(_modal_card):
		_modal_card.position = (vp - _modal_card.size) * 0.5


func set_tab(tab_name: String) -> void:
	if tab_name != TAB_LIBRARY and tab_name != TAB_RECORDS:
		return
	_active_tab = tab_name
	if _status_label != null:
		_status_label.text = ""
	refresh_data()


func get_active_tab() -> String:
	return _active_tab


func refresh_data(prefer_track_id: String = "") -> void:
	var store := TrackStore.new()
	_custom_tracks = store.list_custom_tracks()
	_all_tracks = CuratedTrackCatalog.get_all_tracks()

	if _tab_library_btn != null and _tab_records_btn != null:
		UITheme.style_gold_pill(_tab_library_btn, _active_tab == TAB_LIBRARY, 16, 11)
		UITheme.style_gold_pill(_tab_records_btn, _active_tab == TAB_RECORDS, 16, 11)

	var list_tracks: Array[TrackDefinition] = _custom_tracks if _active_tab == TAB_LIBRARY else _all_tracks
	if _list_title_label != null:
		_list_title_label.text = (
			"SAVED CUSTOM TRACKS (%d)" % _custom_tracks.size()
			if _active_tab == TAB_LIBRARY
			else "ALL CIRCUIT RECORDS (%d)" % _all_tracks.size()
		)

	_item_buttons.clear()
	if _list_vbox != null:
		for child in _list_vbox.get_children():
			child.queue_free()

	if _empty_label != null:
		_empty_label.visible = list_tracks.is_empty()
		_empty_label.text = "No saved custom tracks yet.\n\nOpen 'Create Track' from Home or tap 'Import' above to add a shared circuit."

	var record_store := RecordStore.new()
	for track in list_tracks:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(362.0, 72.0)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		var rec_res := record_store.load_record(track.track_id)
		var rec: Dictionary = rec_res.record if rec_res.record != null else {}
		var best_lap_ms := int(rec.get("best_lap_ms", 0))
		var lap_badge := RaceResult.format_time(float(best_lap_ms) / 1000.0) if best_lap_ms > 0 else "--:--.---"
		if _active_tab == TAB_RECORDS:
			btn.text = "%s\nBest Lap: %s  •  %s" % [track.display_name, lap_badge, track.surface.capitalize()]
		else:
			btn.text = "%s\n%s  •  %s" % [track.display_name, track.surface.capitalize(), str(BiomePresets.get_preset(track.theme).display_name)]
		var tid := track.track_id
		btn.pressed.connect(func() -> void: select_track_by_id(tid))
		if _list_vbox != null:
			_list_vbox.add_child(btn)
		_item_buttons[tid] = btn

	if list_tracks.is_empty():
		_selected_track = null
		_update_detail_ui()
		return

	if not prefer_track_id.is_empty() and _item_buttons.has(prefer_track_id):
		select_track_by_id(prefer_track_id)
	elif _selected_track != null and _item_buttons.has(_selected_track.track_id):
		select_track_by_id(_selected_track.track_id)
	else:
		select_track_by_id(list_tracks[0].track_id)


func select_track_by_id(track_id: String) -> bool:
	var pool: Array[TrackDefinition] = _custom_tracks if _active_tab == TAB_LIBRARY else _all_tracks
	for track in pool:
		if track.track_id == track_id:
			_selected_track = track
			_update_detail_ui()
			return true
	return false


func get_selected_track() -> TrackDefinition:
	return _selected_track


func get_custom_track_count() -> int:
	return _custom_tracks.size()


func rename_selected_track(new_name: String) -> bool:
	if _selected_track == null or _selected_track.source != TrackDefinition.SOURCE_CUSTOM:
		return false
	var cleaned := new_name.strip_edges()
	if cleaned.is_empty() or cleaned.length() > TrackDefinition.MAX_NAME_LENGTH:
		if _status_label != null:
			_status_label.text = "Name must be 1 to %d characters." % TrackDefinition.MAX_NAME_LENGTH
			UITheme.style_label(_status_label, 15, UITheme.CRIMSON, false, false)
		return false
	_selected_track.display_name = cleaned
	var save_res := TrackStore.new().save_custom_track(_selected_track)
	if not save_res.ok:
		if _status_label != null:
			_status_label.text = "Unable to rename track."
			UITheme.style_label(_status_label, 15, UITheme.CRIMSON, false, false)
		return false
	if _status_label != null:
		_status_label.text = "Renamed track to '%s'." % cleaned
		UITheme.style_label(_status_label, 15, UITheme.EMERALD, false, false)
	refresh_data(_selected_track.track_id)
	return true


func edit_selected_track() -> void:
	if _selected_track != null and _selected_track.source == TrackDefinition.SOURCE_CUSTOM:
		edit_track_requested.emit(_selected_track)


func export_selected_track(show_dialog: bool = false) -> Dictionary:
	if _selected_track == null:
		return {"ok": false, "errors": PackedStringArray(["No track selected."])}
	var code_res := ShareCodec.encode_share_code(_selected_track)
	var file_res := ShareCodec.export_document_to_file(_selected_track)
	if not code_res.ok or not file_res.ok:
		if _status_label != null:
			_status_label.text = "Export failed."
			UITheme.style_label(_status_label, 15, UITheme.CRIMSON, false, false)
		return {"ok": false, "errors": code_res.errors if not code_res.ok else file_res.errors}

	var share_code: String = code_res.share_code
	var file_path: String = file_res.path
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(share_code)
	if _status_label != null:
		_status_label.text = "Copied share code & saved %s" % file_path.get_file()
		UITheme.style_label(_status_label, 15, UITheme.EMERALD, false, false)
	if show_dialog:
		_show_export_modal(share_code, file_path)
	return {
		"ok": true,
		"share_code": share_code,
		"file_path": file_path,
		"document": file_res.document,
	}


func open_import_modal() -> Control:
	_close_modal()
	_staged_import_id = ""
	var vp := _current_vp_size()

	_modal_overlay = Control.new()
	_modal_overlay.name = "ImportModalOverlay"
	_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal_overlay)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = UITheme.DIMMER_BG
	_modal_overlay.add_child(dimmer)

	var card := Panel.new()
	card.size = Vector2(960.0, 560.0)
	card.position = (vp - card.size) * 0.5
	card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_MODAL, 18, UITheme.BORDER_GOLD_BRIGHT, 2, 18))
	dimmer.add_child(card)
	_modal_card = card

	var title := Label.new()
	title.text = "IMPORT & PREVIEW CIRCUIT"
	title.position = Vector2(28.0, 14.0)
	UITheme.style_label(title, 25, UITheme.TEXT_PRIMARY, true, false)
	card.add_child(title)

	var hint := Label.new()
	hint.text = "Paste an RC3D1:... share code, raw .rallycraft JSON, or file path (user://imports/track.rallycraft)."
	hint.position = Vector2(28.0, 48.0)
	UITheme.style_label(hint, 16, UITheme.TEXT_SECONDARY, false, false)
	card.add_child(hint)

	_import_input = TextEdit.new()
	_import_input.name = "ImportPayloadInput"
	_import_input.position = Vector2(28.0, 76.0)
	_import_input.size = Vector2(436.0, 294.0)
	_import_input.placeholder_text = "Paste RC3D1:... share code, .rallycraft JSON, or path here..."
	_import_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	UITheme.style_text_edit(_import_input, 15)
	card.add_child(_import_input)

	var paste_btn := Button.new()
	paste_btn.text = "PASTE CLIPBOARD"
	paste_btn.position = Vector2(28.0, 380.0)
	paste_btn.size = Vector2(210.0, 40.0)
	UITheme.style_secondary_button(paste_btn, 16, 11)
	paste_btn.pressed.connect(func() -> void:
		_import_input.text = DisplayServer.clipboard_get()
	)
	card.add_child(paste_btn)

	var validate_btn := Button.new()
	validate_btn.name = "ValidateImportButton"
	validate_btn.text = "VALIDATE & PREVIEW"
	validate_btn.position = Vector2(254.0, 380.0)
	validate_btn.size = Vector2(210.0, 40.0)
	UITheme.style_primary_button(validate_btn, 16, 11)
	validate_btn.pressed.connect(func() -> void:
		preview_import_payload(_import_input.text)
	)
	card.add_child(validate_btn)

	var name_lbl := Label.new()
	name_lbl.text = "IMPORTED TRACK NAME"
	name_lbl.position = Vector2(28.0, 430.0)
	UITheme.style_label(name_lbl, 14, UITheme.GOLD, true, false)
	card.add_child(name_lbl)

	_import_name_edit = LineEdit.new()
	_import_name_edit.name = "ImportNameEdit"
	_import_name_edit.position = Vector2(28.0, 454.0)
	_import_name_edit.size = Vector2(436.0, 40.0)
	_import_name_edit.max_length = TrackDefinition.MAX_NAME_LENGTH
	_import_name_edit.placeholder_text = "Validated track name..."
	UITheme.style_line_edit(_import_name_edit, 17)
	card.add_child(_import_name_edit)

	_import_preview_widget = TrackPreviewWidget.new()
	_import_preview_widget.name = "ImportTrackPreview"
	_import_preview_widget.position = Vector2(488.0, 76.0)
	_import_preview_widget.size = Vector2(444.0, 344.0)
	card.add_child(_import_preview_widget)

	_import_status_label = Label.new()
	_import_status_label.name = "ImportStatusLabel"
	_import_status_label.position = Vector2(488.0, 428.0)
	_import_status_label.size = Vector2(444.0, 68.0)
	_import_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_import_status_label.text = "Awaiting share code or .rallycraft payload..."
	UITheme.style_label(_import_status_label, 16, UITheme.TEXT_SECONDARY, false, false)
	card.add_child(_import_status_label)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelImportButton"
	cancel_btn.text = "CANCEL"
	cancel_btn.position = Vector2(28.0, 502.0)
	cancel_btn.size = Vector2(210.0, 44.0)
	UITheme.style_secondary_button(cancel_btn, 17, 12)
	cancel_btn.pressed.connect(cancel_current_import)
	card.add_child(cancel_btn)

	_import_confirm_btn = Button.new()
	_import_confirm_btn.name = "ConfirmImportButton"
	_import_confirm_btn.text = "CONFIRM & SAVE TO LIBRARY"
	_import_confirm_btn.position = Vector2(488.0, 502.0)
	_import_confirm_btn.size = Vector2(444.0, 44.0)
	_import_confirm_btn.disabled = true
	UITheme.style_secondary_button(_import_confirm_btn, 18, 12)
	_import_confirm_btn.pressed.connect(func() -> void:
		confirm_current_import(_import_name_edit.text if _import_name_edit != null else "")
	)
	card.add_child(_import_confirm_btn)

	return _modal_overlay


func preview_import_payload(raw_input: String) -> Dictionary:
	if not _staged_import_id.is_empty():
		ShareCodec.cancel_staged_import(_staged_import_id)
		_staged_import_id = ""

	var trimmed := raw_input.strip_edges()
	var res: Dictionary
	if trimmed.begins_with(ShareCodec.SHARE_CODE_PREFIX):
		res = ShareCodec.decode_share_code(trimmed)
	elif trimmed.begins_with("user://") or trimmed.begins_with("res://") or trimmed.ends_with(TrackStore.TRACK_FILE_EXTENSION):
		res = ShareCodec.stage_import_from_file(trimmed)
	else:
		res = ShareCodec.decode_document(trimmed)

	if not res.get("ok", false):
		if _import_confirm_btn != null:
			_import_confirm_btn.disabled = true
			UITheme.style_secondary_button(_import_confirm_btn, 18, 12)
		if _import_status_label != null:
			var errs: PackedStringArray = res.get("errors", PackedStringArray(["Invalid import payload."]))
			_import_status_label.text = "Import rejected: " + "; ".join(errs)
			UITheme.style_label(_import_status_label, 16, UITheme.CRIMSON, false, false)
		return res

	var candidate: TrackDefinition = res.track
	_staged_import_id = str(res.staging_id)
	if _import_name_edit != null:
		_import_name_edit.text = candidate.display_name
	if _import_preview_widget != null:
		_import_preview_widget.configure_track(candidate)
	if _import_confirm_btn != null:
		_import_confirm_btn.disabled = false
		UITheme.style_primary_button(_import_confirm_btn, 18, 12)
	if _import_status_label != null:
		var length_m := float(res.compiled.get("length", 0.0))
		_import_status_label.text = (
			"Validated '%s' (%.0f m • %s • %s road).\nAssigned safe new ID: %s" % [
				candidate.display_name,
				length_m,
				candidate.surface.capitalize(),
				candidate.road_width.capitalize(),
				candidate.track_id,
			]
		)
		UITheme.style_label(_import_status_label, 16, UITheme.EMERALD, false, false)
	return res


func confirm_current_import(override_name: String = "") -> Dictionary:
	if _staged_import_id.is_empty():
		return {"ok": false, "track": null, "errors": PackedStringArray(["No staged import to confirm."])}
	var final_name := override_name
	if final_name.is_empty() and _import_name_edit != null:
		final_name = _import_name_edit.text
	var confirm_res := ShareCodec.confirm_staged_import(_staged_import_id, final_name)
	_staged_import_id = ""
	_close_modal()
	if confirm_res.ok and confirm_res.track != null:
		var saved: TrackDefinition = confirm_res.track
		_active_tab = TAB_LIBRARY
		refresh_data(saved.track_id)
		if _status_label != null:
			_status_label.text = "Imported '%s' into local library!" % saved.display_name
			UITheme.style_label(_status_label, 15, UITheme.EMERALD, false, false)
	return confirm_res


func cancel_current_import() -> void:
	if not _staged_import_id.is_empty():
		ShareCodec.cancel_staged_import(_staged_import_id)
		_staged_import_id = ""
	_close_modal()


func _show_export_modal(share_code: String, file_path: String) -> void:
	_close_modal()
	var vp := _current_vp_size()

	_modal_overlay = Control.new()
	_modal_overlay.name = "ExportModalOverlay"
	_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal_overlay)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = UITheme.DIMMER_BG
	_modal_overlay.add_child(dimmer)

	var card := Panel.new()
	card.size = Vector2(820.0, 456.0)
	card.position = (vp - card.size) * 0.5
	card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.GLASS_MODAL, 18, UITheme.BORDER_GOLD_BRIGHT, 2, 18))
	dimmer.add_child(card)
	_modal_card = card

	var title := Label.new()
	title.text = "TRACK EXPORTED — SHARE CODE & .RALLYCRAFT"
	title.position = Vector2(28.0, 18.0)
	UITheme.style_label(title, 25, UITheme.TEXT_PRIMARY, true, false)
	card.add_child(title)

	var path_label := Label.new()
	path_label.text = "Saved file: %s  (Share code copied to clipboard)" % file_path
	path_label.position = Vector2(28.0, 58.0)
	path_label.size = Vector2(764.0, 26.0)
	path_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	path_label.clip_text = true
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UITheme.style_label(path_label, 16, UITheme.EMERALD, false, false)
	card.add_child(path_label)

	var code_box := TextEdit.new()
	code_box.name = "ExportShareCodeBox"
	code_box.position = Vector2(28.0, 94.0)
	code_box.size = Vector2(764.0, 276.0)
	code_box.editable = false
	code_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code_box.text = share_code
	UITheme.style_text_edit(code_box, 15)
	card.add_child(code_box)

	var close_btn := Button.new()
	close_btn.text = "DONE"
	close_btn.position = Vector2(270.0, 390.0)
	close_btn.size = Vector2(280.0, 46.0)
	UITheme.style_primary_button(close_btn, 19, 13)
	close_btn.pressed.connect(_close_modal)
	card.add_child(close_btn)


func _close_modal() -> void:
	if _modal_overlay != null and is_instance_valid(_modal_overlay):
		_modal_overlay.free()
	_modal_overlay = null
	_modal_card = null


func delete_selected_track() -> bool:
	if _selected_track == null or _selected_track.source != TrackDefinition.SOURCE_CUSTOM:
		return false
	var deleted_id := _selected_track.track_id
	var deleted_name := _selected_track.display_name
	var del_res := TrackStore.new().delete_custom_track(deleted_id)
	if not del_res.ok:
		if _status_label != null:
			_status_label.text = "Could not delete track."
			UITheme.style_label(_status_label, 15, UITheme.CRIMSON, false, false)
		return false
	_selected_track = null
	if _status_label != null:
		_status_label.text = "Deleted '%s' from library." % deleted_name
		UITheme.style_label(_status_label, 15, UITheme.COPPER, false, false)
	track_deleted.emit(deleted_id)
	refresh_data()
	return true


func race_selected_track() -> void:
	if _selected_track != null:
		race_track_requested.emit(_selected_track)


func _on_rename_pressed() -> void:
	if _rename_input != null:
		rename_selected_track(_rename_input.text)


func _refresh_view_toggle_buttons() -> void:
	if _mode_2d_btn == null or _mode_3d_btn == null or _preview_widget == null:
		return
	var mode := _preview_widget.get_view_mode()
	UITheme.style_gold_pill(_mode_2d_btn, mode == TrackPreviewWidget.VIEW_2D, 15, 10)
	UITheme.style_gold_pill(_mode_3d_btn, mode == TrackPreviewWidget.VIEW_3D, 15, 10)


func _update_detail_ui() -> void:
	for tid in _item_buttons.keys():
		var btn: Button = _item_buttons[tid]
		UITheme.style_rim_pill(btn, _selected_track != null and tid == _selected_track.track_id, 17, 12)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	_refresh_view_toggle_buttons()
	var has_selection := _selected_track != null
	if _detail_content != null:
		_detail_content.visible = has_selection
	if _detail_empty_label != null:
		_detail_empty_label.visible = not has_selection
	if not has_selection or _title_label == null:
		return

	var is_custom := _selected_track.source == TrackDefinition.SOURCE_CUSTOM
	_badge_label.text = "SAVED CUSTOM TRACK" if is_custom else "CURATED CHAMPIONSHIP CIRCUIT"
	_title_label.text = _selected_track.display_name.to_upper()

	_rename_input.visible = is_custom
	_rename_btn.visible = is_custom
	if is_custom:
		_rename_input.text = _selected_track.display_name
	_edit_btn.visible = is_custom
	_export_btn.visible = is_custom
	_delete_btn.visible = is_custom
	_race_btn.text = "RACE TRACK" if is_custom else "TIME TRIAL / RACE"

	var compiled := _preview_widget.configure_track(_selected_track)
	var length_m := float(compiled.get("length", 0.0))
	var boost_count := (compiled.get("boost_anchors", []) as Array).size()
	_stat_length_val.text = "%.0f m" % length_m
	_stat_surface_val.text = _selected_track.surface.to_upper()
	_stat_width_val.text = _selected_track.road_width.to_upper()
	_stat_biome_val.text = str(BiomePresets.get_preset(_selected_track.theme).display_name).to_upper()

	var rec_res := RecordStore.new().load_record(_selected_track.track_id)
	var rec: Dictionary = rec_res.record if rec_res.record != null else {}
	var best_lap_ms := int(rec.get("best_lap_ms", 0))
	var best_race_ms := int(rec.get("best_race_ms", 0))
	var ghost_samples: Array = rec.get("ghost_samples", [])
	var lap_str := RaceResult.format_time(float(best_lap_ms) / 1000.0) if best_lap_ms > 0 else "--:--.---"
	var race_str := RaceResult.format_time(float(best_race_ms) / 1000.0) if best_race_ms > 0 else "--:--.---"
	var ghost_str := "GHOST SAVED (%d PTS)" % ghost_samples.size() if not ghost_samples.is_empty() else "NO GHOST RECORDED"
	_records_label.text = (
		"PERSONAL RECORDS   •   %d BOOST PADS\n" % boost_count +
		"BEST LAP:     %s\n" % lap_str +
		"BEST RACE:    %s\n" % race_str +
		"TIME TRIAL:   %s" % ghost_str
	)
