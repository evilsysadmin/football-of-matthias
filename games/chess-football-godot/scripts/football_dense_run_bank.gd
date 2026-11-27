extends RefCounted

# Locomotion-only bank transaction. No live activation until the complete
# generation (including idle/actions) is approved. Both clubs are prepared
# before any driver is touched; no await, requests or gameplay mutation.
const VIEWS := ["side", "front", "front_diagonal", "back", "back_diagonal"]

static func expected_count(view: String, compare_v5: bool = false) -> int:
	return 16 if view == "front" and compare_v5 else 24

static func build_bank(original: SpriteFrames, rows: Dictionary, compare_v5: bool = false, kicks: Dictionary = {}) -> SpriteFrames:
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
	# Live Dense uses one generation for all outfield poses. Dedicated
	# idle/tackle/celebration art is still outstanding: use explicit
	# same-generation temporary holds/sequences, as the legacy bank did.
	# No action timing, gameplay or input is changed.
	if not kicks.is_empty():
		if compare_v5 or kicks.size() != 2:
			return null
		for action in [&"pass", &"shoot"]:
			var poses: Variant = kicks.get(action)
			if not poses is Array or poses.size() != 16 or not result.has_animation(action) or result.get_frame_count(action) < 1:
				return null
			for texture in poses:
				if not texture is Texture2D or texture.get_size() != Vector2(128, 144):
					return null
		for view in VIEWS:
			var idle := ChessFootballRunDirection.animation_for(&"idle", view)
			if not result.has_animation(idle):
				return null
			result.clear(idle)
			result.add_frame(idle, rows[view][0])
		for action in [&"pass", &"shoot"]:
			var speed := result.get_animation_speed(action)
			var count := result.get_frame_count(action)
			result.clear(action)
			result.set_animation_speed(action, speed * 16.0 / float(count))
			result.set_animation_loop(action, false)
			for texture in kicks[action]:
				result.add_frame(action, texture)
		# Keep the existing canonical temporary action pose schedule, but
		# source its poses from Dense side gait rather than legacy art.
		for action in [&"tackle", &"slide_tackle", &"celebrate"]:
			if not result.has_animation(action):
				return null
			var schedule: Array = ChessFootballSpriteBank.CANONICAL_ACTION_POSES["tackle" if action == &"slide_tackle" else String(action)]
			var count := result.get_frame_count(action)
			if count < 1:
				return null
			result.clear(action)
			for i in range(count):
				result.add_frame(action, rows["side"][int(schedule[i % schedule.size()]) * 3])
		# Fresh canonical banks contain only these families. Never quietly
		# keep an unknown old-style animation in a live Dense bank.
		var allowed: Array[StringName] = [&"pass", &"shoot", &"tackle", &"slide_tackle", &"celebrate"]
		for view in VIEWS:
			for base in [&"idle", &"run", &"sprint"]:
				allowed.append(ChessFootballRunDirection.animation_for(base, view))
		for animation in result.get_animation_names():
			if StringName(animation) not in allowed:
				return null
	return result


static func install_all(teams: Array, drivers: Dictionary, phases: Dictionary,
	names: Dictionary, rows_by_club: Dictionary, compare_v5: bool = false, kicks_by_club: Dictionary = {}) -> bool:
	if teams.size() != 2 or rows_by_club.size() != 2:
		return false
	if not kicks_by_club.is_empty() and (kicks_by_club.size() != 2 or not kicks_by_club.has(0) or not kicks_by_club.has(1)):
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
			var kicks: Dictionary = kicks_by_club.get(club, {})
			if not kicks_by_club.is_empty() and kicks.is_empty():
				return false
			var bank := build_bank(driver.sprite_frames, rows_by_club[club], compare_v5, kicks)
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
