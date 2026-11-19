extends SceneTree

# XI-only, fixed-position *physical* 1v1 scouting matrix. Complements the
# existing 16-case regression gate; results are diagnostic, not win rates.
# Each scenario runs actual 60 Hz match AI, tackles, first touch and ball.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI: Rect2 = Formation.ELEVEN_PITCH_RECT
const DT := 1.0 / 60.0
const FRAMES := 48
const SKILLS := [45, 95]
const SIDES := [-1.0, 1.0]
const DISTANCES := ["close", "far"]
const ACTIONS := ["feint", "cut", "burst"]
# Conservative floors from the last green, reproducible #207 physical matrix:
# Normal cut 7/8, feint 3/8; Hard cut 3/8, feint 3/8.
# These are safety nets for this SAME fixture, not real-match win rates.
const XI_E_RETAINED_FLOORS := {
	"normal/cut": 5,
	"normal/feint": 2,
	"hard/cut": 2,
	"hard/feint": 2,
}

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

	# Keep raw measurements, but also reject a return to decorative E:
	# merely moving a sprite sideways must never be enough for green CI.
	# Floors are BELOW last green #207 fixed-physics outcomes, not arbitrary
	# match win percentages. Real CPU tackles and both cut flanks must remain.
	assert(rows.size() == 48)
	assert(outcomes.size() == 4)
	for group in outcomes:
		var counts: Dictionary = outcomes[group]
		assert(int(counts["retained"]) + int(counts["loose"]) +
			int(counts["recovered"]) + int(counts["foul"]) == 12)
	assert(actual_tackle_attempts > 0, "Duel matrix must exercise real CPU tackles")
	var playability_errors: Array[String] = _xi_regate_playability_errors(rows)
	assert(playability_errors.is_empty(),
		"XI E physical-playability regression: " + JSON.stringify(playability_errors))
	# Prove the gate detects deliberately broken gameplay, not just valid JSON.
	var never_tackles_rows: Array[Dictionary] = []
	var cut_always_loses_rows: Array[Dictionary] = []
	for original in rows:
		var no_tackle: Dictionary = original.duplicate()
		no_tackle["tackle_attempts"] = 0
		never_tackles_rows.append(no_tackle)
		var fake_loss: Dictionary = original.duplicate()
		if fake_loss["difficulty"] == "normal" and fake_loss["action"] == "cut":
			fake_loss["result"] = "recovered"
		cut_always_loses_rows.append(fake_loss)
	assert(not _xi_regate_playability_errors(never_tackles_rows).is_empty(),
		"An unplugged CPU must never pass the XI regate gate")
	assert(not _xi_regate_playability_errors(cut_always_loses_rows).is_empty(),
		"A cosmetic-only E cut must never pass the XI regate gate")
	print("FOOTBALL_XI_REGATE_PLAYABILITY_OK physical=48 real_tackles=1 " +
		"normal_cut_floor=5 normal_feint_floor=2 hard_cut_floor=2 hard_feint_floor=2")
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


# Checks how much the actual in-engine XI E earns against a real CPU.
# A bad human E still loses; no unit tests may claim a fixed league win rate.
# Grouping by action, BOTH flanks and skill prevents one lucky direction or
# a disabled tackle system from faking progress.
func _xi_regate_playability_errors(duels: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	var summary: Dictionary = {}
	var flank_wins: Dictionary = {}
	var skill_wins: Dictionary = {}
	for duel in duels:
		var key: String = "%s/%s" % [String(duel["difficulty"]), String(duel["action"])]
		if not summary.has(key):
			summary[key] = {"total": 0, "retained": 0, "attempts": 0}
		var item: Dictionary = summary[key]
		item["total"] = int(item["total"]) + 1
		item["attempts"] = int(item["attempts"]) + int(duel["tackle_attempts"])
		if duel["result"] == "retained":
			item["retained"] = int(item["retained"]) + 1
			var flank: String = "%s/%s" % [key, String(duel["side"])]
			flank_wins[flank] = int(flank_wins.get(flank, 0)) + 1
			var skill: String = "%s/%d" % [key, int(duel["technique"])]
			skill_wins[skill] = int(skill_wins.get(skill, 0)) + 1
		summary[key] = item
	for difficulty in ["normal", "hard"]:
		for action in ACTIONS:
			var key: String = "%s/%s" % [difficulty, action]
			if not summary.has(key):
				errors.append("%s missing from 48 actual physical duels" % key)
				continue
			var item: Dictionary = summary[key]
			if int(item["total"]) != 8:
				errors.append("%s covers %d/8 duels" % [key, int(item["total"])])
			if int(item["attempts"]) < 1:
				errors.append("%s CPU never attempts a real tackle" % key)
		for action in ["cut", "feint"]:
			var key: String = "%s/%s" % [difficulty, action]
			if not summary.has(key):
				continue
			var retained: int = int((summary[key] as Dictionary)["retained"])
			var floor_value: int = int(XI_E_RETAINED_FLOORS[key])
			if retained < floor_value:
				errors.append("%s retains %d/8; verified regression floor is %d" %
					[key, retained, floor_value])
			for side in ["up", "down"]:
				if int(flank_wins.get("%s/%s" % [key, side], 0)) < 1:
					errors.append("%s no earned retention on %s flank" % [key, side])
			# In the green #207 baseline Normal cut/feint and Hard cut
			# improve with technique; Hard feint is an actual counterexample
			# (low=2/4, high=1/4) due to collision geometry, so NEVER fake
			# a global monotonic-skill contract that the physics does not obey.
			if key != "hard/feint" and (
				int(skill_wins.get(key + "/95", 0)) <
				int(skill_wins.get(key + "/45", 0))
			):
				errors.append("%s lost its measured high-technique advantage" % key)
	if summary.has("normal/cut") and summary.has("normal/burst"):
		if int((summary["normal/cut"] as Dictionary)["retained"]) < (
			int((summary["normal/burst"] as Dictionary)["retained"]) + 2
		):
			errors.append("Normal E cut must outperform the risky straight F touch")
	if summary.has("hard/cut") and summary.has("hard/burst"):
		if int((summary["hard/cut"] as Dictionary)["retained"]) <= (
			int((summary["hard/burst"] as Dictionary)["retained"])
		):
			errors.append("Hard E cut must remain useful versus the straight F touch")
	return errors


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
