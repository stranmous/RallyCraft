extends SceneTree

var _failed := false


func _init() -> void:
	var open_loop := PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(120, 80), Vector2(50, 140), Vector2(-30, 100), Vector2(-120, 30)
	])
	var result := TrackPathProcessor.process_drawing(open_loop)
	_expect(result.ok, "A valid open drawing should be processed.")
	_expect(result.points.size() >= TrackPathProcessor.MIN_OUTPUT_POINTS, "Processed drawing should have enough preview points.")
	_expect(result.preview.length > 0.0, "Preview should include a positive loop length.")
	_expect(result.preview.was_closed == false, "An open drawing should report that its ends were joined.")
	_expect(not result.preview.optimization_notice.is_empty(), "Optimization notice should explain normalization changes.")

	var closed_loop := open_loop
	closed_loop.append(open_loop[0])
	var closed_result := TrackPathProcessor.process_drawing(closed_loop)
	_expect(closed_result.ok and closed_result.preview.was_closed, "A drawing ending near its start should be recognized as closed.")

	var tiny := PackedVector2Array([Vector2.ZERO, Vector2(1, 1), Vector2(2, 2)])
	var tiny_result := TrackPathProcessor.process_drawing(tiny)
	_expect(not tiny_result.ok and not tiny_result.errors.is_empty(), "A tiny drawing should be rejected with an error.")

	var small_loop := PackedVector2Array([
		Vector2(0, 0), Vector2(120, 0), Vector2(120, 90), Vector2(0, 90)
	])
	var large_loop := PackedVector2Array([
		Vector2(0, 0), Vector2(640, 0), Vector2(680, 220), Vector2(580, 440),
		Vector2(220, 460), Vector2(-40, 300)
	])
	var small_res := TrackPathProcessor.process_drawing(small_loop)
	var large_res := TrackPathProcessor.process_drawing(large_loop)
	_expect(small_res.ok and large_res.ok, "Both small and large loops should process cleanly.")
	_expect(large_res.preview.length > small_res.preview.length * 1.4, "Larger drawings must produce meaningfully longer tracks than small drawings (small=%.1f, large=%.1f)." % [small_res.preview.length, large_res.preview.length])
	_expect(large_res.preview.point_count != small_res.preview.point_count, "Different-sized drawings must produce different control point counts (%d vs %d)." % [small_res.preview.point_count, large_res.preview.point_count])
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
