extends RefCounted
class_name ShareCodec

const SHARE_CODE_PREFIX := "RC3D1:"
const MAX_SHARE_CODE_LENGTH := 16384
const MAX_DOCUMENT_BYTES := 65536
const MAX_DECOMPRESSED_BYTES := 65536
const ALLOWED_PORTABLE_KEYS := [
	"format_version",
	"name",
	"centerline_points",
	"elevation_profile",
	"road_width",
	"surface",
	"theme",
	"metadata",
]
const FORBIDDEN_PAYLOAD_KEYS := [
	"best_lap_ms",
	"best_race_ms",
	"ghost_samples",
	"ghost_version",
	"device_path",
	"script",
	"gdscript",
]


static func build_portable_dictionary(track: TrackDefinition) -> Dictionary:
	var errors := track.validate()
	if not errors.is_empty():
		return {"ok": false, "payload": {}, "errors": errors}

	var rounded_points: Array[Array] = []
	for pt in track.centerline_points:
		rounded_points.append([snappedf(pt.x, 0.01), snappedf(pt.y, 0.01)])

	var rounded_elevations: Array[float] = []
	for elev in track.elevation_profile:
		rounded_elevations.append(snappedf(elev, 0.01))

	var safe_meta := {}
	if track.metadata.has("created_unix_time"):
		safe_meta["created_unix_time"] = int(track.metadata["created_unix_time"])
	if track.metadata.has("description"):
		safe_meta["description"] = str(track.metadata["description"]).left(160)

	var payload := {
		"format_version": TrackDefinition.FORMAT_VERSION,
		"name": track.display_name.strip_edges(),
		"centerline_points": rounded_points,
		"elevation_profile": rounded_elevations,
		"road_width": track.road_width,
		"surface": track.surface,
		"theme": track.theme,
		"metadata": safe_meta,
	}
	return {"ok": true, "payload": payload, "errors": PackedStringArray()}


static func encode_share_code(track: TrackDefinition) -> Dictionary:
	var portable := build_portable_dictionary(track)
	if not portable.ok:
		return {"ok": false, "share_code": "", "errors": portable.errors}
	var json_str := JSON.stringify(portable.payload)
	var raw_bytes := json_str.to_utf8_buffer()
	if raw_bytes.size() > MAX_DECOMPRESSED_BYTES:
		return {"ok": false, "share_code": "", "errors": PackedStringArray(["Track payload exceeds portable size limit."])}
	var compressed := raw_bytes.compress(FileAccess.COMPRESSION_DEFLATE)
	var encoded := "%s%d:%s" % [SHARE_CODE_PREFIX, raw_bytes.size(), Marshalls.raw_to_base64(compressed)]
	if encoded.length() > MAX_SHARE_CODE_LENGTH:
		return {"ok": false, "share_code": "", "errors": PackedStringArray(["Encoded share code exceeds maximum length."])}
	return {"ok": true, "share_code": encoded, "errors": PackedStringArray()}


static func encode_document(track: TrackDefinition) -> Dictionary:
	var portable := build_portable_dictionary(track)
	if not portable.ok:
		return {"ok": false, "document": "", "errors": portable.errors}
	var doc_text := JSON.stringify(portable.payload, "\t")
	if doc_text.to_utf8_buffer().size() > MAX_DOCUMENT_BYTES:
		return {"ok": false, "document": "", "errors": PackedStringArray(["Document payload exceeds maximum byte size."])}
	return {"ok": true, "document": doc_text, "errors": PackedStringArray()}


static func export_document_to_file(track: TrackDefinition, target_path: String = "") -> Dictionary:
	var encoded := encode_document(track)
	if not encoded.ok:
		return {"ok": false, "path": "", "errors": encoded.errors}
	var store := TrackStore.new()
	var storage_err := store.ensure_storage()
	if storage_err != OK:
		return {"ok": false, "path": "", "errors": PackedStringArray(["Unable to initialize export directory."])}

	var resolved_path := target_path.strip_edges()
	if resolved_path.is_empty():
		var safe_slug := _sanitize_filename(track.display_name)
		resolved_path = "%s/%s%s" % [TrackStore.IMPORTS_DIRECTORY, safe_slug, TrackStore.TRACK_FILE_EXTENSION]
	elif not resolved_path.ends_with(TrackStore.TRACK_FILE_EXTENSION):
		resolved_path += TrackStore.TRACK_FILE_EXTENSION

	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": "", "errors": PackedStringArray(["Unable to write .rallycraft export file."])}
	file.store_string(encoded.document)
	file.flush()
	file.close()
	return {"ok": true, "path": resolved_path, "document": encoded.document, "errors": PackedStringArray()}


static func decode_share_code(share_code: String) -> Dictionary:
	var trimmed := share_code.strip_edges()
	if trimmed.is_empty():
		return _fail_import("Share code is empty.")
	if trimmed.length() > MAX_SHARE_CODE_LENGTH:
		return _fail_import("Share code exceeds maximum allowed length (%d chars)." % MAX_SHARE_CODE_LENGTH)
	if not trimmed.begins_with(SHARE_CODE_PREFIX):
		return _fail_import("Invalid or unsupported share code prefix.")

	var body := trimmed.trim_prefix(SHARE_CODE_PREFIX)
	var colon_idx := body.find(":")
	if colon_idx <= 0:
		return _fail_import("Malformed share code header.")
	var size_str := body.substr(0, colon_idx)
	if not size_str.is_valid_int():
		return _fail_import("Share code byte size header is invalid.")
	var expected_size := int(size_str)
	if expected_size <= 2 or expected_size > MAX_DECOMPRESSED_BYTES:
		return _fail_import("Share code uncompressed size is out of bounds.")

	var b64_part := body.substr(colon_idx + 1).strip_edges()
	if not _is_valid_base64(b64_part):
		return _fail_import("Share code base64 data is malformed.")

	var compressed := Marshalls.base64_to_raw(b64_part)
	if compressed.is_empty():
		return _fail_import("Share code base64 data could not be decoded.")

	var decompressed := compressed.decompress(expected_size, FileAccess.COMPRESSION_DEFLATE)
	if decompressed.size() != expected_size:
		return _fail_import("Share code decompression failed or size mismatch.")

	var json_text := decompressed.get_string_from_utf8()
	return decode_document(json_text)


static func decode_document(raw_json: String) -> Dictionary:
	if raw_json.is_empty():
		return _fail_import("Document payload is empty.")
	var utf8_size := raw_json.to_utf8_buffer().size()
	if utf8_size > MAX_DOCUMENT_BYTES:
		return _fail_import("Document payload exceeds maximum allowed size (%d bytes)." % MAX_DOCUMENT_BYTES)

	# Reject explicit NaN / Infinity tokens that JSON.parse_string might coerce
	if raw_json.find("NaN") != -1 or raw_json.find("Infinity") != -1 or raw_json.find("-Infinity") != -1:
		return _fail_import("Document contains non-finite number tokens.")

	var parsed: Variant = JSON.parse_string(raw_json)
	if not parsed is Dictionary:
		return _fail_import("Document does not contain a valid JSON object.")
	var dict: Dictionary = parsed

	for forbidden in FORBIDDEN_PAYLOAD_KEYS:
		if dict.has(forbidden):
			return _fail_import("Payload contains non-portable or forbidden field: '%s'." % forbidden)

	for key in dict.keys():
		var k_str := str(key)
		if k_str != "track_id" and k_str != "source" and not ALLOWED_PORTABLE_KEYS.has(k_str):
			return _fail_import("Payload contains unknown schema field: '%s'." % k_str)

	# Force a fresh local track_id and custom source so imports NEVER overwrite existing tracks
	var candidate_dict := dict.duplicate(true)
	var original_id := str(dict.get("track_id", ""))
	candidate_dict["track_id"] = "import_%d_%08x" % [Time.get_unix_time_from_system(), randi()]
	candidate_dict["source"] = TrackDefinition.SOURCE_CUSTOM

	var parsed_track := TrackDefinition.try_from_dictionary(candidate_dict)
	if parsed_track.track == null or not parsed_track.errors.is_empty():
		return {
			"ok": false,
			"track": null,
			"compiled": {},
			"staging_id": "",
			"errors": parsed_track.errors,
		}

	var candidate: TrackDefinition = parsed_track.track
	candidate.metadata["imported_unix_time"] = Time.get_unix_time_from_system()
	if not original_id.is_empty():
		candidate.metadata["imported_from_id"] = original_id

	# Compile candidate in memory to guarantee geometry & checkpoints are valid before preview/save
	var compiled := TrackCompiler.compile(candidate)
	if not compiled.ok:
		return {
			"ok": false,
			"track": null,
			"compiled": {},
			"staging_id": "",
			"errors": compiled.errors,
		}

	var staging_id := _write_staging_payload(candidate)
	return {
		"ok": true,
		"track": candidate,
		"compiled": compiled,
		"staging_id": staging_id,
		"errors": PackedStringArray(),
	}


static func stage_import_from_file(path: String) -> Dictionary:
	var cleaned := path.strip_edges()
	if cleaned.is_empty() or not FileAccess.file_exists(cleaned):
		return _fail_import("Import file does not exist: %s" % cleaned)
	var file := FileAccess.open(cleaned, FileAccess.READ)
	if file == null:
		return _fail_import("Unable to open import file.")
	if file.get_length() > MAX_DOCUMENT_BYTES:
		file.close()
		return _fail_import("Import file exceeds maximum allowed byte size (%d bytes)." % MAX_DOCUMENT_BYTES)
	var content := file.get_as_text()
	file.close()
	if content.strip_edges().begins_with(SHARE_CODE_PREFIX):
		return decode_share_code(content)
	return decode_document(content)


static func confirm_staged_import(staging_id: String, override_name: String = "") -> Dictionary:
	if staging_id.is_empty() or not staging_id.is_valid_filename():
		return {"ok": false, "track": null, "errors": PackedStringArray(["Staging ID is invalid."])}
	var staging_path := _get_staging_path(staging_id)
	if not FileAccess.file_exists(staging_path):
		return {"ok": false, "track": null, "errors": PackedStringArray(["Staged import file does not exist."])}
	var file := FileAccess.open(staging_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "track": null, "errors": PackedStringArray(["Unable to read staged import file."])}
	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		cancel_staged_import(staging_id)
		return {"ok": false, "track": null, "errors": PackedStringArray(["Staged import data is corrupted."])}

	var track_res := TrackDefinition.try_from_dictionary(parsed)
	if track_res.track == null:
		cancel_staged_import(staging_id)
		return {"ok": false, "track": null, "errors": track_res.errors}

	var track: TrackDefinition = track_res.track
	# Ensure a brand-new unique ID that does not collide with any existing track in user://tracks
	var store := TrackStore.new()
	while FileAccess.file_exists(store.get_track_path(track.track_id)):
		track.track_id = "import_%d_%08x" % [Time.get_unix_time_from_system(), randi()]

	var cleaned_name := override_name.strip_edges()
	if not cleaned_name.is_empty():
		track.display_name = cleaned_name.left(TrackDefinition.MAX_NAME_LENGTH)

	var save_res := store.save_custom_track(track)
	cancel_staged_import(staging_id)
	if not save_res.ok:
		return {"ok": false, "track": null, "errors": save_res.errors}
	return {"ok": true, "track": track, "errors": PackedStringArray()}


static func cancel_staged_import(staging_id: String) -> void:
	if staging_id.is_empty() or not staging_id.is_valid_filename():
		return
	var staging_path := _get_staging_path(staging_id)
	if FileAccess.file_exists(staging_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staging_path))


static func _write_staging_payload(candidate: TrackDefinition) -> String:
	var store := TrackStore.new()
	store.ensure_storage()
	var staging_id := "staged_%s" % candidate.track_id
	var path := _get_staging_path(staging_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(candidate.to_dictionary(), "\t"))
	file.flush()
	file.close()
	return staging_id


static func _get_staging_path(staging_id: String) -> String:
	return "%s/%s.tmp" % [TrackStore.IMPORTS_DIRECTORY, staging_id]


static func _sanitize_filename(raw_name: String) -> String:
	var lowered := raw_name.strip_edges().to_lower()
	var out := ""
	for i in lowered.length():
		var c := lowered.unicode_at(i)
		var is_alnum := (c >= 97 and c <= 122) or (c >= 48 and c <= 57)
		if is_alnum:
			out += char(c)
		elif not out.ends_with("_"):
			out += "_"
	out = out.trim_prefix("_").trim_suffix("_")
	if out.is_empty():
		out = "custom_track"
	return out.left(36)


static func _is_valid_base64(text: String) -> bool:
	if text.is_empty() or (text.length() % 4) != 0:
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		var is_upper := c >= 65 and c <= 90
		var is_lower := c >= 97 and c <= 122
		var is_digit := c >= 48 and c <= 57
		var is_plus_slash := c == 43 or c == 47
		var is_pad := c == 61 and i >= text.length() - 2
		if not (is_upper or is_lower or is_digit or is_plus_slash or is_pad):
			return false
	return true


static func _fail_import(reason: String) -> Dictionary:
	return {
		"ok": false,
		"track": null,
		"compiled": {},
		"staging_id": "",
		"errors": PackedStringArray([reason]),
	}
