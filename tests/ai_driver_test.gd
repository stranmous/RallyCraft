extends SceneTree

const AIDriverScript = preload("res://scripts/racing/ai_driver.gd")

var _failed := false


func _init() -> void:
	var route := PackedVector3Array([
		Vector3(0, 0, 40),
		Vector3(0, 0, 20),
		Vector3(0, 0, 0),
		Vector3(0, 0, -20),
		Vector3(0, 0, -40),
		Vector3(40, 0, -40),
		Vector3(40, 0, 0),
		Vector3(40, 0, 40),
	])
	# At index 1 on the straight, looking ahead 2 points (index 3) is collinear (curvature = 0.0)
	var straight := AIDriverScript.compute_control(route, 1, Vector3(0, 0, 20), Vector3(0, 0, -1))
	_expect(not straight.braking, "AI should not brake on a straight route segment.")
	# At index 3 approaching the corner, looking ahead 2 points (index 5) is a 90-degree turn
	var corner := AIDriverScript.compute_control(route, 3, Vector3(0, 0, -20), Vector3(0, 0, -1))
	_expect(corner.braking, "AI should brake before a sharp route corner.")
	_expect(corner.pace_multiplier < straight.pace_multiplier, "Curvature should lower the AI pace target.")
	_expect(absf(float(corner.steering)) <= 1.0, "AI steering must stay bounded for rally-car control.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
