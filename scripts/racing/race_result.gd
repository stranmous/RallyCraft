extends RefCounted
class_name RaceResult

const MODE_CIRCUIT := "circuit"
const MODE_TIME_TRIAL := "time_trial"


static func build(mode: String, finish_seconds: float, laps: int, position: int = 1, total_racers: int = 1) -> Dictionary:
	var is_time_trial := mode == MODE_TIME_TRIAL
	var title := "TIME TRIAL COMPLETE" if is_time_trial else ("RACE COMPLETE" if total_racers <= 1 or position == 1 else "%s PLACE" % _ordinal(position).to_upper())
	var summary := ""
	if is_time_trial:
		summary = "Fastest clean lap saved in the next records milestone."
	elif total_racers > 1:
		summary = "Finished %s out of %d racers in a %d-lap circuit race." % [_ordinal(position), total_racers, laps]
	else:
		summary = "%d-lap circuit result recorded for this session." % laps
	return {
		"mode": mode,
		"title": title,
		"finish_seconds": finish_seconds,
		"laps": laps,
		"position": position,
		"total_racers": total_racers,
		"summary": summary,
	}


static func _ordinal(n: int) -> String:
	if n == 1:
		return "1st"
	elif n == 2:
		return "2nd"
	elif n == 3:
		return "3rd"
	else:
		return "%dth" % n


static func format_time(seconds: float) -> String:
	var whole_seconds := int(seconds)
	return "%02d:%02d.%03d" % [whole_seconds / 60, whole_seconds % 60, int((seconds - whole_seconds) * 1000.0)]
