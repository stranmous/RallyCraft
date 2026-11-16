extends SceneTree

const TrackCompilerScript = preload("res://scripts/track/track_compiler.gd")

var _failed := false


func _init() -> void:
	var oval := TrackDefinition.create_custom("Compiler Oval", PackedVector2Array([
		Vector2(-100, -50), Vector2(0, -85), Vector2(105, -45), Vector2(120, 40), Vector2(20, 85), Vector2(-105, 45),
	]))
	oval.track_id = "track_compiler_oval"
	oval.road_width = "wide"
	var oval_result := TrackCompilerScript.compile(oval)
	_expect(oval_result.ok, "A valid track should compile.")
	_expect(oval_result.road_mesh != null and oval_result.road_mesh.get_surface_count() == 1, "Compiler should create one road mesh surface.")
	_expect(oval_result.curb_mesh != null and oval_result.curb_mesh.get_surface_count() == 1, "Compiler should create curb mesh surfaces.")
	_expect(oval_result.collision_faces.size() >= oval.centerline_points.size() * 6, "Compiler should create explicit collision triangles.")
	_expect(oval_result.length > 0.0, "Compiled track should have a positive route length.")
	_expect(oval_result.checkpoints.size() >= 2, "Compiler should create ordered route checkpoints.")
	_expect(oval_result.start_grid.size() == 8, "Compiler should create an eight-car start grid.")
	_expect(oval_result.minimap.points.size() == oval_result.centerline.size(), "Compiler should create minimap points for the full loop.")
	_expect(not oval_result.boost_anchors.is_empty(), "Compiler should find safe boost anchors on an oval.")

	var crossing := TrackDefinition.create_custom("Compiler Crossing", PackedVector2Array([
		Vector2(-60, -40), Vector2(60, 40), Vector2(120, 60), Vector2(140, 0),
		Vector2(120, -60), Vector2(60, -40), Vector2(-60, 40), Vector2(-120, 60),
		Vector2(-140, 0), Vector2(-120, -60),
	]))
	crossing.track_id = "track_compiler_crossing"
	var crossing_result := TrackCompilerScript.build_runtime(crossing)
	_expect(crossing_result.ok, "A crossing track should compile into runtime nodes.")
	_expect(not crossing_result.bridge_segments.is_empty(), "A crossing should create a bridge segment.")
	_expect(crossing_result.bridge_mesh != null, "Compiler should generate bridge support pillar mesh.")
	_expect(crossing_result.runtime.get_node_or_null("RoadCollision") != null, "Runtime track should own static collision.")
	_expect(crossing_result.runtime.get_node_or_null("BridgeSupports") != null, "Runtime track should own bridge support node.")
	crossing_result.runtime.free()
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
