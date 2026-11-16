extends SceneTree

var _failures := 0
var _main: MainController
var _step := 0


func _initialize() -> void:
	_test_share_codec_roundtrip_and_security()
	_main = MainController.new()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_step += 1
	if _step == 1:
		_test_edit_and_import_ui_flow()
		if _main != null:
			_main.free()
		if _failures > 0:
			printerr("share_codec_and_import_test failed with %d error(s)." % _failures)
			quit(1)
			return true
		print("share_codec_and_import_test passed.")
		quit(0)
		return true
	return false


func _test_share_codec_roundtrip_and_security() -> void:
	var store := TrackStore.new()
	store.ensure_storage()

	var pts := PackedVector2Array([
		Vector2(-110.0, -50.0),
		Vector2(-20.0, -100.0),
		Vector2(80.0, -75.0),
		Vector2(125.0, 10.0),
		Vector2(55.0, 95.0),
		Vector2(-70.0, 80.0),
	])
	var original := TrackDefinition.create_custom("Portable Canyon", pts)
	original.track_id = "track_codec_original"
	original.road_width = "narrow"
	original.surface = "dirt"
	original.theme = "desert"

	var save_orig := store.save_custom_track(original)
	_expect(save_orig.ok, "Original custom track should save to TrackStore.")

	# 1. Share Code encode -> decode -> stage -> confirm
	var encoded_code := ShareCodec.encode_share_code(original)
	_expect(encoded_code.ok and str(encoded_code.share_code).begins_with(ShareCodec.SHARE_CODE_PREFIX), "ShareCodec should encode valid RC3D1: share code.")

	var decoded_code := ShareCodec.decode_share_code(encoded_code.share_code)
	_expect(decoded_code.ok and decoded_code.track != null, "ShareCodec should decode valid share code.")
	var candidate: TrackDefinition = decoded_code.track
	_expect(candidate.track_id != original.track_id, "Decoded import candidate must receive a new local track_id.")
	_expect(candidate.display_name == "Portable Canyon" and candidate.road_width == "narrow" and candidate.surface == "dirt" and candidate.theme == "desert", "Portable track properties must round-trip through share code.")
	_expect(not str(decoded_code.staging_id).is_empty(), "Decoded candidate should create a temporary staging entry.")

	# Cancel staged import and verify temporary file is removed
	var staging_id_cancel := str(decoded_code.staging_id)
	ShareCodec.cancel_staged_import(staging_id_cancel)
	var after_cancel := ShareCodec.confirm_staged_import(staging_id_cancel)
	_expect(not after_cancel.ok, "Cancelled staged import must not be confirmable.")

	# 2. .rallycraft document export -> file import -> confirm without overwriting original
	var exported_file := ShareCodec.export_document_to_file(original, "user://imports/test_portable_canyon.rallycraft")
	_expect(exported_file.ok and FileAccess.file_exists(exported_file.path), ".rallycraft document should export to user://imports/.")

	var staged_from_file := ShareCodec.stage_import_from_file(exported_file.path)
	_expect(staged_from_file.ok and staged_from_file.track != null, "Staging from .rallycraft file should succeed.")
	var confirmed := ShareCodec.confirm_staged_import(str(staged_from_file.staging_id), "Imported Canyon Copy")
	_expect(confirmed.ok and confirmed.track != null, "Confirming staged file import should save to library.")
	var imported_track: TrackDefinition = confirmed.track
	_expect(imported_track.track_id != original.track_id, "Confirmed import must have a distinct track_id from original.")
	_expect(imported_track.display_name == "Imported Canyon Copy", "Confirming import should apply override name.")

	# Verify original track was NOT overwritten
	var reloaded_orig := store.load_custom_track(original.track_id)
	_expect(reloaded_orig.track != null and reloaded_orig.track.display_name == "Portable Canyon", "Original local track must remain untouched after importing a copy.")

	# Clean up test files
	store.delete_custom_track(original.track_id)
	store.delete_custom_track(imported_track.track_id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(exported_file.path))

	# 3. Malformed, oversized, non-finite, and forbidden-field rejections
	_expect(not ShareCodec.decode_share_code("").ok, "Empty share code must be rejected.")
	_expect(not ShareCodec.decode_share_code("INVALID:123:abc").ok, "Invalid prefix must be rejected.")
	_expect(not ShareCodec.decode_share_code("RC3D1:9999999:abc").ok, "Out-of-bounds uncompressed byte count must be rejected.")
	_expect(not ShareCodec.decode_share_code("RC3D1:40:!!!not_base64!!!").ok, "Corrupted base64 payload must be rejected.")

	var bad_version_json := JSON.stringify({"format_version": 99, "name": "Bad", "centerline_points": [[0, 0]], "road_width": "wide", "surface": "asphalt", "theme": "forest"})
	_expect(not ShareCodec.decode_document(bad_version_json).ok, "Unsupported format_version must be rejected.")

	var nan_json := '{"format_version": 1, "name": "NaN Track", "centerline_points": [[NaN, 0.0]], "road_width": "wide", "surface": "asphalt", "theme": "forest"}'
	_expect(not ShareCodec.decode_document(nan_json).ok, "Non-finite NaN token must be rejected.")

	var forbidden_dict: Dictionary = ShareCodec.build_portable_dictionary(original).payload
	forbidden_dict["ghost_samples"] = [{"t": 0.0}]
	_expect(not ShareCodec.decode_document(JSON.stringify(forbidden_dict)).ok, "Payloads containing ghost_samples must be rejected.")

	var unknown_key_dict: Dictionary = ShareCodec.build_portable_dictionary(original).payload
	unknown_key_dict["executable_payload"] = "evil"
	_expect(not ShareCodec.decode_document(JSON.stringify(unknown_key_dict)).ok, "Payloads containing unknown schema keys must be rejected.")


func _test_edit_and_import_ui_flow() -> void:
	var store := TrackStore.new()
	var pts := PackedVector2Array([
		Vector2(-120.0, -55.0),
		Vector2(-30.0, -105.0),
		Vector2(85.0, -75.0),
		Vector2(130.0, 15.0),
		Vector2(60.0, 100.0),
		Vector2(-75.0, 88.0),
	])
	var base_track := TrackDefinition.create_custom("Initial Loop", pts)
	base_track.road_width = "wide"
	base_track.surface = "asphalt"
	base_track.theme = "forest"
	store.save_custom_track(base_track)
	var base_id := base_track.track_id

	# 1. Open Library, select track, and trigger Edit Track
	var lib := _main._show_library_and_records()
	_expect(lib.select_track_by_id(base_id), "Saved track should be selectable in Library.")
	lib.edit_selected_track()

	var builder := _main._navigation_layer.get_node_or_null("TrackBuilder") as Control
	_expect(builder != null, "Clicking Edit in Library should open TrackBuilder pre-populated with the track.")
	var name_edit := builder.find_child("TrackNameEdit", true, false) as LineEdit
	var save_btn := builder.find_child("SaveTrackButton", true, false) as Button
	_expect(name_edit != null and name_edit.text == "Initial Loop", "TrackBuilder should pre-fill existing track name.")
	_expect(save_btn != null and not save_btn.disabled, "TrackBuilder should enable Save immediately when editing an existing track.")

	# Change name in builder and save back to the same track_id
	name_edit.text = "Edited Loop V2"
	name_edit.text_changed.emit(name_edit.text)
	save_btn.pressed.emit()
	_expect(_main._active_track.track_id == base_id and _main._active_track.display_name == "Edited Loop V2", "Saving edited track must update the existing track_id in place.")
	builder.free()

	# 2. Re-open Library, export share code, and import a copy via the Import Modal
	lib = _main._show_library_and_records()
	_expect(lib.select_track_by_id(base_id), "Edited track should be selectable in Library.")
	var export_res := lib.export_selected_track(false)
	_expect(export_res.ok and not str(export_res.share_code).is_empty(), "Exporting selected track should return share code and file path.")

	var modal := lib.open_import_modal()
	_expect(modal != null, "Import modal should open.")
	var preview_res := lib.preview_import_payload(str(export_res.share_code))
	_expect(preview_res.ok, "Previewing exported share code in Import Modal should succeed.")
	var confirm_res := lib.confirm_current_import("Shared Copy Loop")
	_expect(confirm_res.ok and confirm_res.track != null, "Confirming import in modal should save new track.")
	var imported_id: String = confirm_res.track.track_id
	_expect(imported_id != base_id, "Imported track from modal must have a new track_id.")

	# Clean up both tracks and exported file
	store.delete_custom_track(base_id)
	store.delete_custom_track(imported_id)
	if FileAccess.file_exists(str(export_res.file_path)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(export_res.file_path)))
	lib.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("ERROR: %s" % message)
