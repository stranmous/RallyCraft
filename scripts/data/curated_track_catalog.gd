extends RefCounted
class_name CuratedTrackCatalog

# Hand-authored educational-use arcade circuits (no official branding).
# Uses the exact same TrackDefinition pipeline as custom tracks, with authored
# 2D layouts, 3D elevation profiles, and sector metadata.


static func get_curated_tracks() -> Array[TrackDefinition]:
	return [
		_build_spa(),
		_build_red_bull_ring(),
		_build_monza(),
		_build_silverstone(),
	]


static func get_featured_track() -> TrackDefinition:
	return _build_spa()


static func find_by_id(track_id: String) -> TrackDefinition:
	for track in get_curated_tracks():
		if track.track_id == track_id:
			return track
	var store := TrackStore.new()
	var loaded := store.load_custom_track(track_id)
	if loaded.track != null:
		return loaded.track
	return null


static func get_all_tracks() -> Array[TrackDefinition]:
	var all_tracks := get_curated_tracks()
	var custom_tracks := TrackStore.new().list_custom_tracks()
	for custom in custom_tracks:
		all_tracks.append(custom)
	return all_tracks


static func _build_spa() -> TrackDefinition:
	var track := TrackDefinition.new()
	track.track_id = "curated_spa"
	track.display_name = "Spa Ardennes"
	track.source = TrackDefinition.SOURCE_CURATED
	track.road_width = "wide"
	track.surface = "asphalt"
	track.theme = "spa_forest"
	# Clockwise layout: Pit Straight -> La Source Hairpin -> Eau Rouge / Raidillon Climb
	# -> Kemmel Straight -> Les Combes -> Rivage -> Pouhon -> Fagnes -> Stavelot -> Blanchimont -> Bus Stop
	track.centerline_points = PackedVector2Array([
		Vector2(-108.0, 122.0),
		Vector2(-164.0, 112.0),
		Vector2(-194.0, 74.0),
		Vector2(-160.0, 32.0),
		Vector2(-110.0, 10.0),
		Vector2(-72.0, -18.0),
		Vector2(-88.0, -60.0),
		Vector2(-68.0, -114.0),
		Vector2(-20.0, -152.0),
		Vector2(45.0, -166.0),
		Vector2(106.0, -144.0),
		Vector2(134.0, -106.0),
		Vector2(178.0, -82.0),
		Vector2(198.0, -38.0),
		Vector2(154.0, -12.0),
		Vector2(96.0, -24.0),
		Vector2(66.0, 10.0),
		Vector2(106.0, 54.0),
		Vector2(160.0, 66.0),
		Vector2(174.0, 106.0),
		Vector2(114.0, 136.0),
		Vector2(34.0, 148.0),
		Vector2(-34.0, 128.0),
		Vector2(-66.0, 136.0),
	])
	track.elevation_profile = PackedFloat32Array([
		0.5, 0.5, 0.4, 0.35, 0.45, 2.5,
		5.8, 8.2, 8.4, 8.0, 6.8, 5.5,
		3.6, 2.2, 1.6, 1.2, 1.4, 2.4,
		3.2, 2.6, 1.8, 1.2, 0.6, 0.5,
	])
	track.metadata = {
		"region": "Ardennes Forest",
		"sectors": ["La Source", "Eau Rouge Climb", "Kemmel Straight", "Pouhon", "Blanchimont"],
		"elevation_gain_m": 8.4,
		"description": "Iconic Ardennes forest roller-coaster with Eau Rouge climb, Kemmel Straight, and Blanchimont.",
		"featured": true,
	}
	return track


static func _build_red_bull_ring() -> TrackDefinition:
	var track := TrackDefinition.new()
	track.track_id = "curated_red_bull_ring"
	track.display_name = "Red Bull Ring"
	track.source = TrackDefinition.SOURCE_CURATED
	track.road_width = "wide"
	track.surface = "asphalt"
	track.theme = "alpine"
	# Clockwise Styrian mountain loop: Uphill Main Straight -> T1 Hairpin -> Mountain Climb
	# -> Remus Crest Hairpin -> Rauch Downhill -> Infield Sweeper -> Rindt Bend -> Main Straight
	track.centerline_points = PackedVector2Array([
		Vector2(-64.0, 118.0),
		Vector2(-150.0, 104.0),
		Vector2(-190.0, 66.0),
		Vector2(-170.0, -6.0),
		Vector2(-136.0, -84.0),
		Vector2(-92.0, -136.0),
		Vector2(-40.0, -126.0),
		Vector2(22.0, -78.0),
		Vector2(94.0, -62.0),
		Vector2(124.0, -20.0),
		Vector2(66.0, 4.0),
		Vector2(48.0, 48.0),
		Vector2(100.0, 66.0),
		Vector2(166.0, 74.0),
		Vector2(154.0, 118.0),
		Vector2(54.0, 128.0),
	])
	track.elevation_profile = PackedFloat32Array([
		0.5, 2.4, 4.5, 7.0,
		9.2, 9.5, 8.2, 5.8,
		4.2, 3.0, 2.4, 1.8,
		1.4, 1.0, 0.4, 0.2,
	])
	track.metadata = {
		"region": "Styrian Alps",
		"sectors": ["Turn 1 Climb", "Remus Summit", "Rauch Hairpin", "Infield Sweep", "Rindt"],
		"elevation_gain_m": 9.5,
		"description": "High-altitude alpine circuit climbing to Remus summit before a fast downhill charge.",
		"featured": false,
	}
	return track


static func _build_monza() -> TrackDefinition:
	var track := TrackDefinition.new()
	track.track_id = "curated_monza"
	track.display_name = "Monza Park"
	track.source = TrackDefinition.SOURCE_CURATED
	track.road_width = "wide"
	track.surface = "asphalt"
	track.theme = "parkland"
	# Clockwise Temple of Speed: Long Pit Straight -> Rettifilo Entry -> Curva Grande
	# -> Roggia -> Lesmo 1 & 2 -> Serraglio -> Ascari S-Bend -> Parabolica Sweeper
	track.centerline_points = PackedVector2Array([
		Vector2(-106.0, 96.0),
		Vector2(-212.0, 96.0),
		Vector2(-244.0, 68.0),
		Vector2(-216.0, 18.0),
		Vector2(-180.0, -44.0),
		Vector2(-118.0, -98.0),
		Vector2(-58.0, -110.0),
		Vector2(14.0, -126.0),
		Vector2(78.0, -110.0),
		Vector2(118.0, -68.0),
		Vector2(110.0, -10.0),
		Vector2(144.0, 34.0),
		Vector2(198.0, 22.0),
		Vector2(238.0, 48.0),
		Vector2(224.0, 96.0),
		Vector2(148.0, 114.0),
		Vector2(30.0, 104.0),
	])
	track.elevation_profile = PackedFloat32Array([
		0.2, 0.2, 0.3, 0.5, 0.7, 0.9,
		1.0, 1.2, 1.0, 0.8, 0.6, 0.5,
		0.4, 0.3, 0.2, 0.2, 0.2,
	])
	track.metadata = {
		"region": "Royal Parkland",
		"sectors": ["Pit Straight", "Curva Grande", "Lesmos", "Ascari", "Parabolica"],
		"elevation_gain_m": 1.2,
		"description": "Ultra-fast parkland blast linking long boost straights, Lesmo bends, and Parabolica.",
		"featured": false,
	}
	return track


static func _build_silverstone() -> TrackDefinition:
	var track := TrackDefinition.new()
	track.track_id = "curated_silverstone"
	track.display_name = "Silverstone Airfield"
	track.source = TrackDefinition.SOURCE_CURATED
	track.road_width = "standard"
	track.surface = "asphalt"
	track.theme = "open_grassland"
	# Clockwise flowing multi-apex airfield circuit: Hamilton Straight -> Abbey -> Village Loop
	# -> Wellington Straight -> Brooklands / Luffield -> Copse -> Maggotts-Becketts-Chapel -> Hangar Straight -> Stowe -> Club
	track.centerline_points = PackedVector2Array([
		Vector2(-60.0, 128.0),
		Vector2(-148.0, 114.0),
		Vector2(-178.0, 66.0),
		Vector2(-134.0, 34.0),
		Vector2(-112.0, -2.0),
		Vector2(-176.0, -24.0),
		Vector2(-210.0, -86.0),
		Vector2(-168.0, -138.0),
		Vector2(-98.0, -118.0),
		Vector2(-18.0, -126.0),
		Vector2(58.0, -118.0),
		Vector2(98.0, -76.0),
		Vector2(142.0, -92.0),
		Vector2(194.0, -42.0),
		Vector2(210.0, 42.0),
		Vector2(174.0, 108.0),
		Vector2(102.0, 126.0),
		Vector2(34.0, 134.0),
	])
	track.elevation_profile = PackedFloat32Array([
		0.2, 0.3, 0.5, 0.8, 1.0, 1.1,
		1.2, 1.4, 1.2, 0.9, 0.8, 1.1,
		1.3, 1.0, 0.7, 0.5, 0.3, 0.2,
	])
	track.metadata = {
		"region": "Open Airfield",
		"sectors": ["Abbey", "Wellington", "Copse", "Maggotts-Becketts", "Hangar & Stowe"],
		"elevation_gain_m": 1.4,
		"description": "Flowing multi-apex airfield course linking Copse, Maggotts-Becketts S-curves, and Hangar Straight.",
		"featured": false,
	}
	return track
