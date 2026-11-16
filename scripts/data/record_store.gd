extends RefCounted
class_name RecordStore

const RECORD_FORMAT_VERSION := 1
const MAX_GHOST_SAMPLES := 3600


func save_best_lap(track_id: String, lap_ms: int, ghost_samples: Array[Dictionary]) -> Dictionary:
	if track_id.is_empty() or not track_id.is_valid_filename() or lap_ms <= 0:
		return {"ok": false, "improved": false, "errors": PackedStringArray(["Record data is invalid."])}
	if ghost_samples.is_empty() or ghost_samples.size() > MAX_GHOST_SAMPLES:
		return {"ok": false, "improved": false, "errors": PackedStringArray(["Ghost sample data is invalid."])}
	var existing := load_record(track_id)
	var record: Dictionary = existing.record if existing.record != null else _empty_record()
	var current_best: int = int(record.get("best_lap_ms", 0))
	if current_best > 0 and current_best <= lap_ms:
		return {"ok": true, "improved": false, "errors": PackedStringArray()}
	record["best_lap_ms"] = lap_ms
	record["ghost_version"] = RECORD_FORMAT_VERSION
	record["ghost_samples"] = ghost_samples.duplicate(true)
	var write_result := _save_record(track_id, record)
	write_result["improved"] = write_result.ok
	return write_result


func save_best_race(track_id: String, race_ms: int) -> Dictionary:
	if track_id.is_empty() or not track_id.is_valid_filename() or race_ms <= 0:
		return {"ok": false, "improved": false, "errors": PackedStringArray(["Record data is invalid."])}
	var existing := load_record(track_id)
	var record: Dictionary = existing.record if existing.record != null else _empty_record()
	var current_best: int = int(record.get("best_race_ms", 0))
	if current_best > 0 and current_best <= race_ms:
		return {"ok": true, "improved": false, "errors": PackedStringArray()}
	record["best_race_ms"] = race_ms
	var write_result := _save_record(track_id, record)
	write_result["improved"] = write_result.ok
	return write_result


func load_record(track_id: String) -> Dictionary:
	if track_id.is_empty() or not track_id.is_valid_filename():
		return {"record": null, "errors": PackedStringArray(["Track ID is invalid."])}
	var path := _get_record_path(track_id)
	if not FileAccess.file_exists(path):
		return {"record": null, "errors": PackedStringArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"record": null, "errors": PackedStringArray(["Unable to read the record file."])}
	var payload: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not payload is Dictionary or not _is_valid_record(payload):
		return {"record": null, "errors": PackedStringArray(["Record file is invalid."])}
	return {"record": payload, "errors": PackedStringArray()}


func _save_record(track_id: String, record: Dictionary) -> Dictionary:
	var storage_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TrackStore.RECORDS_DIRECTORY))
	if storage_error != OK:
		return {"ok": false, "errors": PackedStringArray(["Unable to create record storage."])}
	var target_path := _get_record_path(track_id)
	var temporary_path := "%s.tmp" % target_path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": PackedStringArray(["Unable to write record data."])}
	file.store_string(JSON.stringify(record))
	file.flush()
	file.close()
	var target_absolute := ProjectSettings.globalize_path(target_path)
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(target_absolute)
	var rename_error := DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_absolute)
		return {"ok": false, "errors": PackedStringArray(["Unable to finalize record data."])}
	return {"ok": true, "errors": PackedStringArray()}


func _get_record_path(track_id: String) -> String:
	return "%s/%s.record.json" % [TrackStore.RECORDS_DIRECTORY, track_id]


func _empty_record() -> Dictionary:
	return {"format_version": RECORD_FORMAT_VERSION, "best_lap_ms": 0, "best_race_ms": 0, "ghost_version": RECORD_FORMAT_VERSION, "ghost_samples": []}


func _is_valid_record(record: Dictionary) -> bool:
	if int(record.get("format_version", 0)) != RECORD_FORMAT_VERSION:
		return false
	if int(record.get("best_lap_ms", 0)) < 0 or int(record.get("best_race_ms", 0)) < 0:
		return false
	var samples: Variant = record.get("ghost_samples", [])
	return samples is Array and samples.size() <= MAX_GHOST_SAMPLES
