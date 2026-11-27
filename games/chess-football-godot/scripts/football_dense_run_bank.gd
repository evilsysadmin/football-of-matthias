extends RefCounted

# Locomotion-only bank transaction. No live activation until the complete
# generation (including idle/actions) is approved. Both clubs are prepared
# before any driver is touched; no await, requests or gameplay mutation.
const VIEWS := ["side", "front", "front_diagonal", "back", "back_diagonal"]

static func expected_count(view: String, compare_v5: bool = false) -> int:
	return 16 if view == "front" and compare_v5 else 24

static func build_bank(original: SpriteFrames, rows: Dictionary, compare_v5: bool = false) -> SpriteFrames:
	# Build the entire replacement on a copy. Any missing/invalid view leaves
	# the original untouched. This helper is not an approval or release gate.
	if original == null or rows.size() != VIEWS.size():
		return null
	for i in range(VIEWS.size()):
		var view: String = VIEWS[i]
		var row: Variant = rows.get(view)
		if not row is Array or row.size() != expected_count(view, compare_v5):
			return null
		for texture in row:
			if not texture is Texture2D or texture.get_size() != Vector2(128, 144):
				return null
		for base in [&"run", &"sprint"]:
			var name := ChessFootballRunDirection.animation_for(base, view)
			if not original.has_animation(name) or original.get_frame_count(name) < 1:
				return null
	var result := original.duplicate() as SpriteFrames
	for view in VIEWS:
		var row: Array = rows[view]
		for base in [&"run", &"sprint"]:
			var name := ChessFootballRunDirection.animation_for(base, view)
			var fps := original.get_animation_speed(name)
			var old_count := original.get_frame_count(name)
			result.clear(name)
			result.set_animation_loop(name, true)
			result.set_animation_speed(name, fps * float(row.size()) / float(old_count))
			for texture in row:
				result.add_frame(name, texture)
	return result



static func install_all(teams: Array, drivers: Dictionary, phases: Dictionary,
	names: Dictionary, rows_by_club: Dictionary, compare_v5: bool = false) -> bool:
	if teams.size() != 2 or rows_by_club.size() != 2:
		return false
	var prepared := {}
	for club in range(2):
		if teams[club].size() != 11 or not rows_by_club.has(club):
			return false
		var outfield := 0
		for athlete: Footballer in teams[club]:
			if athlete == null or athlete.team_id != club:
				return false
			if athlete.role == "keeper":
				continue
			var id: int = athlete.get_instance_id()
			var driver: AnimatedSprite3D = drivers.get(id)
			if driver == null or prepared.has(id):
				return false
			var bank := build_bank(driver.sprite_frames, rows_by_club[club], compare_v5)
			if bank == null:
				return false
			var animation: StringName = driver.animation
			if not bank.has_animation(animation) or not driver.sprite_frames.has_animation(animation):
				return false
			var old_count := driver.sprite_frames.get_frame_count(animation)
			var new_count := bank.get_frame_count(animation)
			if old_count < 1 or new_count < 1:
				return false
			var phase := float(driver.frame)
			if names.get(id, &"") == animation:
				phase = float(phases.get(id, driver.frame))
			if bank.get_animation_loop(animation):
				phase = fposmod(phase, float(old_count)) * float(new_count) / float(old_count)
			else:
				phase = clampf(phase, 0.0, float(new_count - 1))
			prepared[id] = {"bank": bank, "animation": animation, "phase": phase}
			outfield += 1
		if outfield != 10:
			return false
	if prepared.size() != 20:
		return false
	# No mutation until every actor, both clubs and all five views validated.
	for id in prepared:
		var driver: AnimatedSprite3D = drivers[id]
		var entry: Dictionary = prepared[id]
		driver.sprite_frames = entry["bank"]
		driver.play(entry["animation"])
		driver.pause()
		driver.frame = floori(float(entry["phase"]))
		names[id] = entry["animation"]
		phases[id] = entry["phase"]
	return true
