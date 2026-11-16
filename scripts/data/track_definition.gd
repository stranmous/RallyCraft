extends RefCounted
class_name TrackDefinition

const FORMAT_VERSION := 1
const MIN_CENTERLINE_POINTS := 6
const MAX_CENTERLINE_POINTS := 256
const MAX_NAME_LENGTH := 48

const SOURCE_CURATED := "curated"
const SOURCE_CUSTOM := "custom"

const ROAD_WIDTHS := ["narrow", "standard", "wide"]
const SURFACES := ["dirt", "asphalt"]
const THEMES := ["desert", "forest", "spa_forest", "alpine", "parkland", "open_grassland"]

var format_version: int = FORMAT_VERSION
var track_id := ""
var display_name := ""
var source := SOURCE_CUSTOM
var centerline_points: PackedVector2Array = PackedVector2Array()
var elevation_profile: PackedFloat32Array = PackedFloat32Array()
var road_width := "standard"
var surface := "dirt"
var theme := "desert"
var metadata: Dictionary = {}


static func create_custom(name: String, points: PackedVector2Array) -> TrackDefinition:
	var definition := TrackDefinition.new()
	definition.track_id = _create_track_id()
	definition.display_name = name.strip_edges()
	definition.centerline_points = points
	definition.metadata = {
		"created_unix_time": Time.get_unix_time_from_system(),
	}
	return definition


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if format_version != FORMAT_VERSION:
		errors.append("Unsupported track format version.")
	if track_id.is_empty() or not track_id.is_valid_filename():
		errors.append("Track ID is missing or contains invalid filename characters.")
	if display_name.strip_edges().is_empty() or display_name.length() > MAX_NAME_LENGTH:
		errors.append("Track name must contain 1 to %d characters." % MAX_NAME_LENGTH)
	if source != SOURCE_CURATED and source != SOURCE_CUSTOM:
		errors.append("Track source must be curated or custom.")
	if centerline_points.size() < MIN_CENTERLINE_POINTS or centerline_points.size() > MAX_CENTERLINE_POINTS:
		errors.append("Track must contain %d to %d centerline points." % [MIN_CENTERLINE_POINTS, MAX_CENTERLINE_POINTS])
	for point in centerline_points:
		if not _is_finite_number(point.x) or not _is_finite_number(point.y):
			errors.append("Track centerline contains a non-finite point.")
			break
	for elevation in elevation_profile:
		if not _is_finite_number(elevation):
			errors.append("Track elevation profile contains a non-finite value.")
			break
	if not ROAD_WIDTHS.has(road_width):
		errors.append("Track road width is invalid.")
	if not SURFACES.has(surface):
		errors.append("Track surface is invalid.")
	if not THEMES.has(theme):
		errors.append("Track theme is invalid.")
	if not metadata is Dictionary:
		errors.append("Track metadata must be a dictionary.")
	return errors


func to_dictionary() -> Dictionary:
	var points: Array[Array] = []
	for point in centerline_points:
		points.append([point.x, point.y])
	return {
		"format_version": format_version,
		"track_id": track_id,
		"name": display_name,
		"source": source,
		"centerline_points": points,
		"elevation_profile": Array(elevation_profile),
		"road_width": road_width,
		"surface": surface,
		"theme": theme,
		"metadata": metadata.duplicate(true),
	}


static func try_from_dictionary(data: Dictionary) -> Dictionary:
	var definition := TrackDefinition.new()
	var parse_errors := PackedStringArray()
	definition.format_version = int(data.get("format_version", 0))
	definition.track_id = str(data.get("track_id", ""))
	definition.display_name = str(data.get("name", ""))
	definition.source = str(data.get("source", ""))
	definition.road_width = str(data.get("road_width", ""))
	definition.surface = str(data.get("surface", ""))
	definition.theme = str(data.get("theme", ""))

	var raw_metadata: Variant = data.get("metadata", {})
	if raw_metadata is Dictionary:
		definition.metadata = raw_metadata.duplicate(true)
	else:
		parse_errors.append("Track metadata must be a dictionary.")

	var points_result := _parse_points(data.get("centerline_points", []))
	if not points_result.errors.is_empty():
		return {"track": null, "errors": points_result.errors}
	definition.centerline_points = points_result.points

	var elevations_result := _parse_elevations(data.get("elevation_profile", []))
	if not elevations_result.errors.is_empty():
		return {"track": null, "errors": elevations_result.errors}
	definition.elevation_profile = elevations_result.elevations

	var errors := definition.validate()
	for parse_error in parse_errors:
		errors.append(parse_error)
	return {"track": definition if errors.is_empty() else null, "errors": errors}


static func _parse_points(raw_points: Variant) -> Dictionary:
	var errors := PackedStringArray()
	var points := PackedVector2Array()
	if not raw_points is Array:
		errors.append("Track centerline points must be an array.")
		return {"points": points, "errors": errors}
	for raw_point in raw_points:
		if not raw_point is Array or raw_point.size() != 2:
			errors.append("Each centerline point must contain exactly two coordinates.")
			break
		if not _is_json_number(raw_point[0]) or not _is_json_number(raw_point[1]):
			errors.append("Track centerline coordinates must be numbers.")
			break
		var x: float = raw_point[0]
		var y: float = raw_point[1]
		if not _is_finite_number(x) or not _is_finite_number(y):
			errors.append("Track centerline contains a non-finite point.")
			break
		points.append(Vector2(x, y))
	return {"points": points, "errors": errors}


static func _parse_elevations(raw_elevations: Variant) -> Dictionary:
	var errors := PackedStringArray()
	var elevations := PackedFloat32Array()
	if not raw_elevations is Array:
		errors.append("Track elevation profile must be an array.")
		return {"elevations": elevations, "errors": errors}
	for raw_elevation in raw_elevations:
		if not _is_json_number(raw_elevation):
			errors.append("Track elevation profile values must be numbers.")
			break
		var elevation: float = raw_elevation
		if not _is_finite_number(elevation):
			errors.append("Track elevation profile contains a non-finite value.")
			break
		elevations.append(elevation)
	return {"elevations": elevations, "errors": errors}


static func _create_track_id() -> String:
	return "track_%d_%08x" % [Time.get_unix_time_from_system(), randi()]


static func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_json_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
