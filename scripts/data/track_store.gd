extends RefCounted
class_name TrackStore

const TRACKS_DIRECTORY := "user://tracks"
const RECORDS_DIRECTORY := "user://records"
const IMPORTS_DIRECTORY := "user://imports"
const TRACK_FILE_EXTENSION := ".rallycraft"


func ensure_storage() -> Error:
	for directory in [TRACKS_DIRECTORY, RECORDS_DIRECTORY, IMPORTS_DIRECTORY]:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if error != OK:
			return error
	return OK


func save_custom_track(track: TrackDefinition) -> Dictionary:
	var errors := track.validate()
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	if track.source != TrackDefinition.SOURCE_CUSTOM:
		return {"ok": false, "errors": PackedStringArray(["Only custom tracks may be saved to the local library."])}

	var storage_error := ensure_storage()
	if storage_error != OK:
		return {"ok": false, "errors": PackedStringArray(["Unable to create local track storage."])}

	var target_path := get_track_path(track.track_id)
	var temporary_path := "%s.tmp" % target_path
	var backup_path := "%s.bak" % target_path
	var payload := JSON.stringify(track.to_dictionary(), "\t")
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": PackedStringArray(["Unable to write the temporary track file."])}
	file.store_string(payload)
	file.flush()
	file.close()

	var target_absolute := ProjectSettings.globalize_path(target_path)
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	if FileAccess.file_exists(target_path):
		var backup_error := DirAccess.rename_absolute(target_absolute, backup_absolute)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_absolute)
			return {"ok": false, "errors": PackedStringArray(["Unable to safely replace the existing track file."])}

	var replace_error := DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_absolute, target_absolute)
		DirAccess.remove_absolute(temporary_absolute)
		return {"ok": false, "errors": PackedStringArray(["Unable to finalize the saved track file."])}
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	return {"ok": true, "errors": PackedStringArray()}


func load_custom_track(track_id: String) -> Dictionary:
	if track_id.is_empty() or not track_id.is_valid_filename():
		return {"track": null, "errors": PackedStringArray(["Track ID is invalid."])}
	var primary_result := _load_from_path(get_track_path(track_id))
	if primary_result.track != null:
		return primary_result
	var backup_result := _load_from_path("%s.bak" % get_track_path(track_id))
	if backup_result.track != null:
		return backup_result
	return primary_result


func get_track_path(track_id: String) -> String:
	return "%s/%s%s" % [TRACKS_DIRECTORY, track_id, TRACK_FILE_EXTENSION]


func list_custom_tracks() -> Array[TrackDefinition]:
	var tracks: Array[TrackDefinition] = []
	var storage_error := ensure_storage()
	if storage_error != OK:
		return tracks
	var dir := DirAccess.open(TRACKS_DIRECTORY)
	if dir == null:
		return tracks
	var file_names := dir.get_files()
	for file_name in file_names:
		if not file_name.ends_with(TRACK_FILE_EXTENSION):
			continue
		var track_id := file_name.trim_suffix(TRACK_FILE_EXTENSION)
		var loaded := load_custom_track(track_id)
		if loaded.track != null:
			tracks.append(loaded.track)
	tracks.sort_custom(func(a: TrackDefinition, b: TrackDefinition) -> bool:
		var ta := int(a.metadata.get("created_unix_time", 0))
		var tb := int(b.metadata.get("created_unix_time", 0))
		if ta != tb:
			return ta > tb
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return tracks


func delete_custom_track(track_id: String) -> Dictionary:
	if track_id.is_empty() or not track_id.is_valid_filename():
		return {"ok": false, "errors": PackedStringArray(["Track ID is invalid."])}
	var target_path := get_track_path(track_id)
	var backup_path := "%s.bak" % target_path
	var existed := false
	if FileAccess.file_exists(target_path):
		existed = true
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))
		if err != OK:
			return {"ok": false, "errors": PackedStringArray(["Unable to delete track file."])}
	if FileAccess.file_exists(backup_path):
		existed = true
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	if not existed:
		return {"ok": false, "errors": PackedStringArray(["Track file does not exist."])}
	return {"ok": true, "errors": PackedStringArray()}


func _load_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"track": null, "errors": PackedStringArray(["Track file does not exist."])}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"track": null, "errors": PackedStringArray(["Unable to read track file."])}
	var raw_payload := file.get_as_text()
	file.close()
	var parsed_payload: Variant = JSON.parse_string(raw_payload)
	if not parsed_payload is Dictionary:
		return {"track": null, "errors": PackedStringArray(["Track file does not contain a JSON object."])}
	return TrackDefinition.try_from_dictionary(parsed_payload)
