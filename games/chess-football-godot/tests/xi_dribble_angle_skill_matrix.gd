extends SceneTree

# XI-only, fixed-position *physical* 1v1 scouting matrix. Complements the
# existing 16-case regression gate; results are diagnostic, not win rates.
# Each scenario runs actual 60 Hz match AI, tackles, first touch and ball.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI: Rect2 = Formation.ELEVEN_PITCH_RECT
const DT := 1.0 / 60.0
const FRAMES := 32
const SKILLS := [45, 95]
const SIDES := [-1.0, 1.0]
const DISTANCES := ["close", "far"]
const ACTIONS := ["feint", "cut", "burst"]

func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	assert(game.match_pitch == XI and game.debug_team_counts() == [11, 11])
	game.kickoff_active = false
	var carrier: Footballer = game.teams[0][10]
	var presser: Footballer = game.teams[1][5]
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
			actor.set_physics_process(false)

	var rows: Array[Dictionary] = []
	var outcomes: Dictionary = {}
	var actual_tackle_attempts := 0
	for difficulty in ["normal", "hard"]:
		for distance_id in DISTANCES:
			for side in SIDES:
				for technique in SKILLS:
					for action in ACTIONS:
						_reset_duel(game, carrier, presser, difficulty, distance_id, int(technique))
						var input_direction := Vector2(1.0, float(side) * 0.76).normalized()
						if action == "feint":
							carrier.velocity = Vector2.ZERO
						assert(carrier.start_dribble(input_direction, action))
						assert(game.ball.carrier == carrier)
						var origin: Vector2 = carrier.global_position
						var minimum_gap: float = carrier.global_position.distance_to(presser.global_position)
						var attempts := 0
						var prior_tackle := 0.0
						var loose_frames := 0
						var contact_frame := -1
						var frames_played := 0
						for frame_index in range(FRAMES):
							await physics_frame
							var previous_carrier: Vector2 = carrier.global_position
							var previous_defender: Vector2 = presser.global_position
							# Hold an actual angled human command, so E's late exit
							# steering (and F's committed touch) face both flanks.
							carrier.move_human(DT, input_direction, false)
							game._update_ai(DT)
							if presser.tackle_cooldown_seconds > prior_tackle + 0.25:
								attempts += 1
							prior_tackle = presser.tackle_cooldown_seconds
							game._update_active_tackle_contacts()
							game.ball.tick_ball(DT)
							game._update_pending_tackle_claim(DT)
							game._try_claim_loose_ball()
							if game.ball.carrier == null:
								loose_frames += 1
							if contact_frame < 0 and (
								carrier.contact_stun_seconds > 0.0 or game.ball.carrier != carrier
							):
								contact_frame = frame_index
							frames_played += 1
							if not game.set_piece_active:
								assert(carrier.global_position.distance_to(previous_carrier) < 41.0)
								assert(presser.global_position.distance_to(previous_defender) < 18.0)
								assert(XI.has_point(carrier.global_position))
								assert(XI.has_point(presser.global_position))
							minimum_gap = minf(
								minimum_gap, carrier.global_position.distance_to(presser.global_position)
							)
							carrier._process(DT)
							presser._process(DT)
							if game.set_piece_active or (
								game.ball.carrier != null and game.ball.carrier != carrier
							):
								break
						var outcome := "foul" if game.set_piece_active else (
							"retained" if game.ball.carrier == carrier else
							"loose" if game.ball.carrier == null else "recovered"
						)
						assert(frames_played >= 1 and frames_played <= FRAMES)
						assert(not is_nan(minimum_gap))
						if contact_frame >= 0:
							assert(attempts > 0 or game.ball.carrier != carrier)
						actual_tackle_attempts += attempts
						var group: String = "%s/%d" % [difficulty, int(technique)]
						if not outcomes.has(group):
							outcomes[group] = {"retained": 0, "loose": 0, "recovered": 0, "foul": 0}
						var counts: Dictionary = outcomes[group]
						counts[outcome] = int(counts[outcome]) + 1
						outcomes[group] = counts
						rows.append({
							"difficulty": difficulty,
							"approach": distance_id,
							"side": "up" if float(side) < 0.0 else "down",
							"technique": int(technique),
							"action": action,
							"result": outcome,
							"frames": frames_played,
							"tackle_attempts": attempts,
							"contact_frame": contact_frame,
							"loose_frames": loose_frames,
							"minimum_gap": snappedf(minimum_gap, 0.1),
							"advance": snappedf(carrier.global_position.x - origin.x, 0.1),
							"lateral": snappedf(carrier.global_position.y - origin.y, 0.1)
						})
						if rows.size() % 12 == 0:
							print("FOOTBALL_XI_DRIBBLE_MATRIX_PROGRESS completed=%d/48" % rows.size())

	# No arbitrary target percentages: this fixture is for repeatable *data*.
	# But it must exercise a real duel rather than silently disable AI contact.
	assert(rows.size() == 48)
	assert(outcomes.size() == 4)
	for group in outcomes:
		var counts: Dictionary = outcomes[group]
		assert(int(counts["retained"]) + int(counts["loose"]) +
			int(counts["recovered"]) + int(counts["foul"]) == 12)
	assert(actual_tackle_attempts > 0, "Duel matrix must exercise real CPU tackles")
	print("FOOTBALL_XI_DRIBBLE_ANGLE_SKILL_MATRIX " + JSON.stringify({
		"mode": "isolated_deterministic_60hz_real_godot_physics_not_live_matches",
		"scenarios": rows.size(),
		"frames_per_scenario": FRAMES,
		"tackle_attempts": actual_tackle_attempts,
		"outcomes": outcomes,
		"rows": rows
	}))
	print("FOOTBALL_XI_DRIBBLE_ANGLE_SKILL_MATRIX_OK")
	quit(0)


func _reset_duel(
	game: Node, carrier: Footballer, presser: Footballer,
	difficulty: String, distance_id: String, technique: int
) -> void:
	game._set_quick_difficulty(difficulty)
	game.match_seconds = 0.0
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	game.set_piece_player = null
	game.pending_tackle_player = null
	game.pending_tackle_seconds = 0.0
	game.ai_primary_presser_cache = [null, null]
	game.ai_secondary_presser_cache = [null, null]
	game.ai_xi_defensive_role_owner = null
	game.ai_adaptive_level = 0
	for team in game.teams:
		for actor: Footballer in team:
			actor.global_position = XI.position + Vector2(
				80.0 + float(actor.squad_index) * 60.0,
				90.0 + float(actor.team_id) * 210.0
			)
			actor.velocity = Vector2.ZERO
			actor.tackle_cooldown_seconds = 0.0
			actor.tackle_recovery_seconds = 0.0
			actor.tackle_active_seconds = 0.0
			actor.tackle_aggressive = false
			actor.action_lock_seconds = 0.0
			actor.dribble_cooldown_seconds = 0.0
			actor.dribble_burst_seconds = 0.0
			actor.contact_stun_seconds = 0.0
			actor.stamina = actor.STAMINA_MAX
			actor.sprint_exhausted = false
	var center := XI.get_center()
	carrier.global_position = center + Vector2(-200.0, 0.0)
	carrier.velocity = Vector2(200.0, 0.0)
	presser.global_position = carrier.global_position + (
		Vector2(74.0, -24.0) if distance_id == "close"
		else Vector2(220.0, 52.0)
	)
	presser.velocity = Vector2(-160.0, 0.0)
	# Real scouting technique affects carrier pace and gesture cooldown.
	# No randomized chance or forced tackle result.
	carrier.scouting_technique = technique
	carrier.technique_control_multiplier = clampf(
		1.0 + float(technique - 75) * 0.0025, 0.93, 1.06
	)
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	assert(game._ai_primary_presser(1) == presser)
	assert(game.ball.carrier == carrier and carrier.has_ball)
