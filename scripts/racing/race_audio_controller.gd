extends Node
class_name RaceAudioController

const MASTER_BUS_EFFECT_NAME := "RallyCraftLimiter"
const BASE_MUSIC_DB := -14.0
const BASE_ENGINE_IDLE_DB := -19.5
const BASE_ENGINE_PEAK_DB := -14.5
const BASE_SKID_MIN_DB := -26.0
const BASE_SKID_PEAK_DB := -10.0

var _car: RallyCar
var _race_manager: RaceManager
var _headless := false
var _muted := false
var _sfx_muted := false
var _music_muted := false
var _paused := false
var _finished := false

var _engine_player: AudioStreamPlayer
var _skid_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _sfx_boost_pickup: AudioStreamPlayer
var _sfx_boost_engage: AudioStreamPlayer
var _sfx_lap: AudioStreamPlayer
var _sfx_finish: AudioStreamPlayer
var _sfx_impact: AudioStreamPlayer

var _prev_boost_remaining := 0.0
var _prev_lap := 1
var _prev_contact_cooldown := 0.0
var _engine_pitch := 0.86
var _engine_ratio := 0.0
var _skid_blend := 0.0
var _duck_timer := 0.0


static func ensure_master_limiter() -> void:
	var bus_idx := 0
	for i in AudioServer.get_bus_effect_count(bus_idx):
		var fx := AudioServer.get_bus_effect(bus_idx, i)
		if fx is AudioEffectLimiter and fx.resource_name == MASTER_BUS_EFFECT_NAME:
			return
	var limiter := AudioEffectLimiter.new()
	limiter.resource_name = MASTER_BUS_EFFECT_NAME
	limiter.ceiling_db = -1.0
	limiter.threshold_db = -2.5
	limiter.soft_clip_db = 1.5
	AudioServer.add_bus_effect(bus_idx, limiter)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy"
	ensure_master_limiter()
	_build_players()


func configure(car: RallyCar, race_manager: RaceManager) -> void:
	ensure_master_limiter()
	_car = car
	_race_manager = race_manager
	_paused = false
	_finished = false
	_prev_boost_remaining = 0.0
	_prev_lap = 1
	_prev_contact_cooldown = 0.0
	_engine_pitch = 0.86
	_engine_ratio = 0.0
	_skid_blend = 0.0
	_duck_timer = 0.0
	if _race_manager != null:
		if not _race_manager.boost_collected.is_connected(_on_boost_collected):
			_race_manager.boost_collected.connect(_on_boost_collected)
		if not _race_manager.race_finished.is_connected(_on_race_finished):
			_race_manager.race_finished.connect(_on_race_finished)


func set_muted(muted: bool) -> void:
	_sfx_muted = muted
	_music_muted = muted
	_muted = muted
	if _muted:
		_skid_blend = 0.0
		_stop_continuous_players()


func is_muted() -> bool:
	return _sfx_muted and _music_muted


func set_sfx_muted(muted: bool) -> void:
	_sfx_muted = muted
	_muted = _sfx_muted and _music_muted
	if _sfx_muted:
		_skid_blend = 0.0
		_stop_sfx_players()
		if _engine_player != null:
			_engine_player.volume_db = -80.0
		if _skid_player != null:
			_skid_player.volume_db = -80.0


func is_sfx_muted() -> bool:
	return _sfx_muted


func set_music_muted(muted: bool) -> void:
	_music_muted = muted
	_muted = _sfx_muted and _music_muted
	if _music_muted:
		if _music_player != null:
			if _music_player.playing:
				_music_player.stop()
			_music_player.volume_db = -80.0


func is_music_muted() -> bool:
	return _music_muted


func set_paused(paused: bool) -> void:
	_paused = paused
	if _paused:
		_stop_continuous_players()


func get_mix_snapshot() -> Dictionary:
	return {
		"sfx_muted": _sfx_muted,
		"music_muted": _music_muted,
		"music_db": _music_player.volume_db if _music_player != null else -80.0,
		"engine_db": _engine_player.volume_db if _engine_player != null else -80.0,
		"engine_pitch": _engine_pitch,
		"skid_db": _skid_player.volume_db if _skid_player != null else -80.0,
		"skid_blend": _skid_blend,
		"duck_timer": _duck_timer,
		"boost_pickup_db": _sfx_boost_pickup.volume_db if _sfx_boost_pickup != null else -80.0,
		"boost_engage_db": _sfx_boost_engage.volume_db if _sfx_boost_engage != null else -80.0,
		"lap_db": _sfx_lap.volume_db if _sfx_lap != null else -80.0,
		"finish_db": _sfx_finish.volume_db if _sfx_finish != null else -80.0,
		"impact_db": _sfx_impact.volume_db if _sfx_impact != null else -80.0,
	}


func _build_players() -> void:
	_engine_player = _add_player("engine_loop", true, BASE_ENGINE_IDLE_DB)
	_skid_player = _add_player("tire_skid", true, -48.0)
	_music_player = _add_player("race_theme", true, BASE_MUSIC_DB)
	_sfx_boost_pickup = _add_player("boost_pickup", false, -4.5)
	_sfx_boost_engage = _add_player("boost_engage", false, -2.0)
	_sfx_lap = _add_player("lap_complete", false, -2.5)
	_sfx_finish = _add_player("finish_fanfare", false, -5.5)
	_sfx_impact = _add_player("impact_bump", false, -2.5)


func _add_player(audio_key: String, looping: bool, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "Audio_%s" % audio_key
	player.volume_db = volume_db
	var stream := AssetRegistry.load_audio_stream(audio_key, looping)
	if stream != null:
		player.stream = stream
	add_child(player)
	return player


func _process(delta: float) -> void:
	update_mix(delta)


func update_mix(delta: float) -> void:
	var step := clampf(delta, 0.0, 0.1)
	if _duck_timer > 0.0:
		_duck_timer = maxf(0.0, _duck_timer - step)

	var inactive := _paused or _finished or (is_inside_tree() and get_tree().paused) or _car == null or not is_instance_valid(_car)
	if inactive:
		_skid_blend = 0.0
		_stop_continuous_players()
		return

	var ds := _car.get_drive_state()
	var speed := float(ds.get("speed", 0.0))
	var braking := bool(ds.get("braking", false))
	var boost_rem := float(ds.get("boost_remaining", 0.0))

	var boost_just_engaged := boost_rem > 0.01 and _prev_boost_remaining <= 0.01
	_prev_boost_remaining = boost_rem

	var impact_just_hit := _car._contact_cooldown > 0.05 and _prev_contact_cooldown <= 0.05
	_prev_contact_cooldown = _car._contact_cooldown

	var lap_just_crossed := false
	if _race_manager != null and is_instance_valid(_race_manager):
		var status := _race_manager.get_status()
		var lap := int(status.get("lap", 1))
		lap_just_crossed = lap > _prev_lap and not bool(status.get("finished", false))
		_prev_lap = lap

	if not _sfx_muted:
		if boost_just_engaged:
			_trigger_duck(0.32)
			_play_one_shot(_sfx_boost_engage)
		if impact_just_hit:
			_trigger_duck(0.30)
			_play_one_shot(_sfx_impact)
		if lap_just_crossed:
			_trigger_duck(0.35)
			_play_one_shot(_sfx_lap)

	var duck_t := clampf(_duck_timer / 0.32, 0.0, 1.0)
	if _music_player != null and _music_player.stream != null:
		if _music_muted:
			if _music_player.playing:
				_music_player.stop()
			_music_player.volume_db = -80.0
		else:
			_music_player.volume_db = BASE_MUSIC_DB - duck_t * 3.5
			if not _headless and not _music_player.playing:
				_music_player.play()

	var target_ratio := clampf(speed / RallyDriveModel.BOOST_SPEED, 0.0, 1.0)
	var smoothing := 1.0 - exp(-10.0 * step)
	_engine_ratio = lerpf(_engine_ratio, target_ratio, smoothing)
	_engine_pitch = lerpf(0.86, 1.54, _engine_ratio)

	if _sfx_muted:
		_skid_blend = 0.0
		_stop_sfx_players()
		if _engine_player != null:
			_engine_player.volume_db = -80.0
		if _skid_player != null:
			_skid_player.volume_db = -80.0
	else:
		if _engine_player != null and _engine_player.stream != null:
			_engine_player.pitch_scale = _engine_pitch
			_engine_player.volume_db = lerpf(BASE_ENGINE_IDLE_DB, BASE_ENGINE_PEAK_DB, _engine_ratio) - duck_t * 2.0
			if not _headless and not _engine_player.playing:
				_engine_player.play()

		var skidding := braking and speed > 8.0
		if skidding:
			_skid_blend = minf(1.0, _skid_blend + step * 12.0)
		else:
			_skid_blend = maxf(0.0, _skid_blend - step * 7.5)

		if _skid_player != null and _skid_player.stream != null:
			if _skid_blend > 0.01:
				var intensity := clampf((speed - 8.0) / 18.0, 0.2, 1.0)
				var active_db := lerpf(BASE_SKID_MIN_DB, BASE_SKID_PEAK_DB, intensity)
				_skid_player.volume_db = lerpf(-48.0, active_db, _skid_blend)
				if not _headless and not _skid_player.playing:
					_skid_player.play()
			elif _skid_player.playing:
				_skid_player.stop()


func _trigger_duck(duration: float) -> void:
	_duck_timer = maxf(_duck_timer, duration)


func _on_boost_collected(_pickup_index: int, by_player: bool) -> void:
	if by_player and not _sfx_muted:
		_trigger_duck(0.28)
		_play_one_shot(_sfx_boost_pickup)


func _on_race_finished(_result: Dictionary) -> void:
	_finished = true
	_skid_blend = 0.0
	_stop_continuous_players()
	_play_one_shot(_sfx_finish)


func _play_one_shot(player: AudioStreamPlayer) -> void:
	if _headless or _sfx_muted or player == null or player.stream == null:
		return
	player.play()


func _stop_sfx_players() -> void:
	for p in [_engine_player, _skid_player]:
		if p != null and p.playing:
			p.stop()


func _stop_continuous_players() -> void:
	_stop_sfx_players()
	if _music_player != null and _music_player.playing:
		_music_player.stop()
