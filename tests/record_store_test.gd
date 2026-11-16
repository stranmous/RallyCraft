extends SceneTree

const RecordStoreScript = preload("res://scripts/data/record_store.gd")

var _failed := false


func _init() -> void:
	var store := RecordStoreScript.new()
	var samples: Array[Dictionary] = [
		{"time": 0.1, "position": [0.0, 1.0, 0.0], "rotation_y": 0.0},
		{"time": 0.2, "position": [2.0, 1.0, 0.0], "rotation_y": 0.2},
	]
	var first := store.save_best_lap("record_store_test", 65000, samples)
	_expect(first.ok and first.improved, "The first Time Trial lap should create a ghost record.")
	var slower := store.save_best_lap("record_store_test", 66000, samples)
	_expect(slower.ok and not slower.improved, "A slower lap must not replace the best ghost.")
	var faster := store.save_best_lap("record_store_test", 64000, samples)
	_expect(faster.ok and faster.improved, "A faster lap should replace the saved ghost.")
	var loaded := store.load_record("record_store_test")
	_expect(loaded.record != null and loaded.record.best_lap_ms == 64000, "The best lap should round-trip from local record storage.")
	_expect(loaded.record.ghost_samples.size() == 2, "Ghost samples should round-trip from local record storage.")
	var race_first := store.save_best_race("record_store_test", 195000)
	_expect(race_first.ok and race_first.improved, "First circuit race time should save as best_race_ms.")
	var race_slower := store.save_best_race("record_store_test", 205000)
	_expect(race_slower.ok and not race_slower.improved, "Slower circuit race time must not overwrite best_race_ms.")
	var race_faster := store.save_best_race("record_store_test", 188000)
	_expect(race_faster.ok and race_faster.improved, "Faster circuit race time should update best_race_ms.")
	var loaded_after_race := store.load_record("record_store_test")
	_expect(loaded_after_race.record.best_race_ms == 188000 and loaded_after_race.record.best_lap_ms == 64000, "Saving best race must preserve existing best lap and ghost.")
	var path := "user://records/record_store_test.record.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
