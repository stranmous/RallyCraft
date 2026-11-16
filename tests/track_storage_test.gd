extends SceneTree

const TEST_TRACK_ID := "track_storage_test"

var _failed := false


func _init() -> void:
	var store := TrackStore.new()
	_expect(store.ensure_storage() == OK, "Storage directories should be created.")
	_expect(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TrackStore.TRACKS_DIRECTORY)), "Track storage directory should exist.")
	_expect(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TrackStore.RECORDS_DIRECTORY)), "Record storage directory should exist.")
	_expect(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TrackStore.IMPORTS_DIRECTORY)), "Import storage directory should exist.")

	var points := PackedVector2Array([
		Vector2(-80.0, -30.0), Vector2(-25.0, -65.0), Vector2(45.0, -55.0),
		Vector2(85.0, 0.0), Vector2(35.0, 65.0), Vector2(-55.0, 50.0),
	])
	var track := TrackDefinition.create_custom("Storage Test", points)
	track.track_id = TEST_TRACK_ID
	track.road_width = "wide"
	track.surface = "asphalt"
	track.theme = "forest"
	track.elevation_profile = PackedFloat32Array([0.0, 0.5, 1.0])

	_expect(track.validate().is_empty(), "A valid custom track should pass validation.")
	var save_result := store.save_custom_track(track)
	_expect(save_result.ok, "A valid custom track should save.")
	var load_result := store.load_custom_track(TEST_TRACK_ID)
	_expect(load_result.track != null, "A saved custom track should load.")
	var loaded_track: TrackDefinition = load_result.track
	_expect(loaded_track.display_name == "Storage Test", "The saved name should round-trip.")
	_expect(loaded_track.centerline_points == points, "Centerline points should round-trip.")
	_expect(loaded_track.surface == "asphalt" and loaded_track.theme == "forest", "Track settings should round-trip.")

	var malformed_result := TrackDefinition.try_from_dictionary({"format_version": 999})
	_expect(malformed_result.track == null and not malformed_result.errors.is_empty(), "Unsupported or incomplete data should be rejected.")
	var non_finite_payload := track.to_dictionary()
	var non_finite_points: Array = non_finite_payload["centerline_points"]
	non_finite_points[0] = [NAN, 0.0]
	non_finite_payload["centerline_points"] = non_finite_points
	var non_finite_result := TrackDefinition.try_from_dictionary(non_finite_payload)
	_expect(non_finite_result.track == null and not non_finite_result.errors.is_empty(), "Non-finite coordinates should be rejected.")

	var oversized_payload := track.to_dictionary()
	var oversized_points: Array = oversized_payload["centerline_points"]
	while oversized_points.size() <= TrackDefinition.MAX_CENTERLINE_POINTS:
		oversized_points.append([float(oversized_points.size()), 0.0])
	oversized_payload["centerline_points"] = oversized_points
	var oversized_result := TrackDefinition.try_from_dictionary(oversized_payload)
	_expect(oversized_result.track == null and not oversized_result.errors.is_empty(), "Oversized centerline data should be rejected.")

	var saved_path := store.get_track_path(TEST_TRACK_ID)
	if FileAccess.file_exists(saved_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
