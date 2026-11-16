extends RefCounted
class_name TrackPathProcessor

const MIN_INPUT_POINTS := 3
const MIN_OUTPUT_POINTS := 6
const MAX_OUTPUT_POINTS := 256
const MIN_POINT_SPACING := 3.0
const RESAMPLE_POINT_SPACING := 14.0
const MIN_NORMALIZED_EXTENT := 65.0
const MAX_NORMALIZED_EXTENT := 200.0
const PIXEL_TO_METER_SCALE := 0.55
const CLOSE_ENOUGH_DISTANCE := 72.0
const SMOOTHING_PASSES := 2
const MAX_SMOOTHING_DISPLACEMENT := 12.0


static func process_drawing(input_points: PackedVector2Array) -> Dictionary:
	var errors := PackedStringArray()
	var cleaned := _remove_invalid_and_near_duplicates(input_points)
	if cleaned.size() < MIN_INPUT_POINTS:
		errors.append("Draw a larger loop with at least %d points." % MIN_INPUT_POINTS)
		return {"ok": false, "errors": errors}

	var closed_distance := cleaned[0].distance_to(cleaned[cleaned.size() - 1])
	var was_closed := closed_distance <= CLOSE_ENOUGH_DISTANCE
	if was_closed:
		cleaned.remove_at(cleaned.size() - 1)
	cleaned = _remove_cyclic_near_duplicates(cleaned)
	if cleaned.size() < MIN_INPUT_POINTS:
		errors.append("The loop is too small to create a safe road.")
		return {"ok": false, "errors": errors}

	var normalized := _normalize(cleaned)
	var resampled := _resample_closed(normalized, RESAMPLE_POINT_SPACING)
	if resampled.size() < MIN_OUTPUT_POINTS:
		resampled = _resample_closed(normalized, MIN_POINT_SPACING)
	if resampled.size() < MIN_OUTPUT_POINTS:
		resampled = normalized
	var smoothed := _safe_smooth(resampled)
	var smoothed_changed := not _points_equal(smoothed, resampled)
	var preview := _build_preview(smoothed)
	preview["source_points"] = input_points
	preview["normalized_points"] = smoothed
	preview["was_closed"] = was_closed
	preview["smoothing_applied"] = smoothed_changed
	preview["optimization_notice"] = _optimization_notice(was_closed, smoothed_changed, input_points.size(), smoothed.size())
	return {"ok": true, "errors": errors, "points": smoothed, "preview": preview}


static func _remove_invalid_and_near_duplicates(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		if is_nan(point.x) or is_inf(point.x) or is_nan(point.y) or is_inf(point.y):
			continue
		if result.is_empty() or result[result.size() - 1].distance_to(point) >= MIN_POINT_SPACING:
			result.append(point)
	return result


static func _remove_cyclic_near_duplicates(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	var changed := true
	while changed and result.size() >= MIN_INPUT_POINTS:
		changed = false
		for index in result.size():
			var next_index := (index + 1) % result.size()
			if result[index].distance_to(result[next_index]) < MIN_POINT_SPACING:
				result.remove_at(next_index)
				changed = true
				break
	return result


static func _normalize(points: PackedVector2Array) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= points.size()
	var centered := PackedVector2Array()
	var extent := 1.0
	for point in points:
		var value := point - center
		centered.append(value)
		extent = maxf(extent, maxf(absf(value.x), absf(value.y)))
	var target_extent := clampf(extent * PIXEL_TO_METER_SCALE, MIN_NORMALIZED_EXTENT, MAX_NORMALIZED_EXTENT)
	var scale := target_extent / extent
	for index in centered.size():
		centered[index] *= scale
	return centered


static func _resample_closed(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var lengths: Array[float] = []
	var total_length := 0.0
	for index in points.size():
		var length := points[index].distance_to(points[(index + 1) % points.size()])
		lengths.append(length)
		total_length += length
	if total_length <= 0.0:
		return points
	var count := clampi(int(ceil(total_length / spacing)), MIN_OUTPUT_POINTS, MAX_OUTPUT_POINTS)
	var result := PackedVector2Array()
	var segment := 0
	var distance_target := 0.0
	for sample_index in count:
		var target := distance_target
		var traversed := 0.0
		segment = 0
		while segment < lengths.size() - 1 and traversed + lengths[segment] < target:
			traversed += lengths[segment]
			segment += 1
		var segment_length: float = max(lengths[segment], 0.001)
		var ratio := clampf((target - traversed) / segment_length, 0.0, 1.0)
		result.append(points[segment].lerp(points[(segment + 1) % points.size()], ratio))
		distance_target += total_length / count
	return result


static func _safe_smooth(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	for _pass in SMOOTHING_PASSES:
		var next := PackedVector2Array()
		for index in result.size():
			var previous: Vector2 = result[(index - 1 + result.size()) % result.size()]
			var current: Vector2 = result[index]
			var following: Vector2 = result[(index + 1) % result.size()]
			var candidate := (previous + current * 2.0 + following) / 4.0
			var delta := candidate - current
			if delta.length() > MAX_SMOOTHING_DISPLACEMENT:
				delta = delta.normalized() * MAX_SMOOTHING_DISPLACEMENT
			next.append(current + delta)
		result = next
	return result


static func _build_preview(points: PackedVector2Array) -> Dictionary:
	var bounds := Rect2(points[0], Vector2.ZERO)
	var length := 0.0
	for index in points.size():
		bounds = bounds.expand(points[index])
		length += points[index].distance_to(points[(index + 1) % points.size()])
	var corner_count := _count_corners(points)
	var intersections := detect_self_intersections(points)
	var bridge_count := intersections.size()
	return {
		"points": points,
		"bounds": bounds,
		"length": length,
		"point_count": points.size(),
		"corner_count": corner_count,
		"bridge_count": bridge_count,
		"intersections": intersections,
		"estimated_lap_seconds": max(8, roundi(length / 26.0)),
		"suggested_name": "Custom Rally %02d" % (int(round(length)) % 100),
	}


static func detect_self_intersections(points: PackedVector2Array) -> Array[Dictionary]:
	var intersections: Array[Dictionary] = []
	var n := points.size()
	if n < 4:
		return intersections
	for i in n:
		var i_next := (i + 1) % n
		for j in range(i + 2, n):
			var j_next := (j + 1) % n
			if i == j_next or i_next == j:
				continue
			var crossing: Variant = Geometry2D.segment_intersects_segment(points[i], points[i_next], points[j], points[j_next])
			if crossing is Vector2:
				var seg_dir := points[j_next] - points[j]
				var tangent := seg_dir.normalized() if seg_dir.length_squared() > 0.0001 else Vector2.RIGHT
				intersections.append({
					"point": crossing,
					"lower_index": i,
					"upper_index": j,
					"tangent": tangent,
				})
	return intersections


static func _count_corners(points: PackedVector2Array) -> int:
	if points.size() < 6:
		return 0
	var corners := 0
	var cooldown := 0
	var n := points.size()
	for i in n:
		if cooldown > 0:
			cooldown -= 1
			continue
		var prev := points[(i - 1 + n) % n]
		var curr := points[i]
		var next := points[(i + 1) % n]
		var dir_in := (curr - prev).normalized()
		var dir_out := (next - curr).normalized()
		var angle := absf(dir_in.angle_to(dir_out))
		if angle >= 0.26:
			corners += 1
			cooldown = 2
	return max(corners, 2)


static func _count_self_crossings(points: PackedVector2Array) -> int:
	return detect_self_intersections(points).size()


static func _optimization_notice(was_closed: bool, smoothed: bool, input_count: int, output_count: int) -> String:
	var notices := PackedStringArray()
	if not was_closed:
		notices.append("Ends joined to close loop.")
	if smoothed:
		notices.append("Sharp turns smoothed for racing.")
	if input_count != output_count:
		notices.append("Resampled to %d control points." % output_count)
	return " ".join(notices)


static func _points_equal(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if first.size() != second.size():
		return false
	for index in first.size():
		if first[index].distance_to(second[index]) > 0.01:
			return false
	return true
