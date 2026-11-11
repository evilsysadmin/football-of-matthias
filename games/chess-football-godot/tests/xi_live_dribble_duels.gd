extends SceneTree

# Deterministic one-on-one XI duel laboratory. Uses the actual 22-player
# match scene, Footballer.move_human/move_ai, match._update_ai (including real
# presser selection and tackle commits), ball physics and first-touch claims.
# This is a controlled 0.8s local duel, NOT a simulated league win rate.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI: Rect2 = Formation.ELEVEN_PITCH_RECT
const DT := 1.0 / 60.0
const FRAMES := 48
const ACTIONS := ["run", "feint", "cut", "burst"]
const DISTANCES := ["close", "far"]

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
	game.kickoff_active = false
	assert(game.match_pitch == XI and game.debug_team_counts() == [11, 11])
	var carrier: Footballer = game.teams[0][10]
	var presser: Footballer = game.teams[1][5]
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
			actor.set_physics_process(false)
	var rows: Array[Dictionary] = []
	for difficulty in ["normal", "hard"]:
		for distance_id in DISTANCES:
			for action in ACTIONS:
				_reset_duel(game, carrier, presser, difficulty, distance_id)
				var lane_sign := -1.0 if distance_id == "close" else 1.0
				var input_direction := Vector2(1.0, lane_sign * 0.76).normalized()
				if action == "feint":
					carrier.velocity = Vector2.ZERO
				if action != "run":
					assert(carrier.start_dribble(input_direction, action))
					assert(carrier.dribble_mode == action)
					assert(game.ball.carrier == carrier)
				var origin: Vector2 = carrier.global_position
				var first_gap := carrier.global_position.distance_to(presser.global_position)
				var minimum_gap := first_gap
				var tackle_attempts := 0
				var contact_frame := -1
				var foul := false
				var loose_frames := 0
				var played := 0
				var prior_tackle: float = 0.0
				for frame_index in range(FRAMES):
					await physics_frame
					var previous_carrier: Vector2 = carrier.global_position
					var previous_defender: Vector2 = presser.global_position
					# Keep the same normal running command after the short
					# dribble action. No custom motion/physics implementation.
					carrier.move_human(DT, Vector2.RIGHT, false)
					game._update_ai(DT)
					if presser.tackle_cooldown_seconds > prior_tackle + 0.25:
						tackle_attempts += 1
					prior_tackle = presser.tackle_cooldown_seconds
					game._update_active_tackle_contacts()
					game.ball.tick_ball(DT)
					game._update_pending_tackle_claim(DT)
					game._try_claim_loose_ball()
					if game.ball.carrier == null:
						loose_frames += 1
					if contact_frame < 0 and (
						carrier.contact_stun_seconds > 0.0
						or game.ball.carrier != carrier
					):
						contact_frame = frame_index
					foul = game.set_piece_active
					played += 1
					# Actual physical movement is bounded; collisions may
					# displace the victim 24 units on a real tackle.
					if not foul:
						assert(carrier.global_position.distance_to(previous_carrier) < 41.0)
						assert(presser.global_position.distance_to(previous_defender) < 18.0)
						assert(XI.has_point(carrier.global_position))
						assert(XI.has_point(presser.global_position))
					minimum_gap = minf(
						minimum_gap,
						carrier.global_position.distance_to(presser.global_position)
					)
					carrier._process(DT)
					presser._process(DT)
					if foul or (game.ball.carrier != null and game.ball.carrier != carrier):
						break
				var outcome := "foul" if foul else (
					"retained" if game.ball.carrier == carrier else
					"loose" if game.ball.carrier == null else "recovered"
				)
				# A clean physical contact cannot be manufactured by a
				# presentation-only animation or by reading a helper value.
				if contact_frame >= 0:
					assert(tackle_attempts > 0 or game.ball.carrier != carrier)
				assert(played >= 1 and played <= FRAMES)
				assert(not is_nan(minimum_gap))
				rows.append({
					"difficulty": difficulty,
					"approach": distance_id,
					"action": action,
					"frames": played,
					"result": outcome,
					"tackle_attempts": tackle_attempts,
					"contact_frame": contact_frame,
					"loose_frames": loose_frames,
					"first_gap": snappedf(first_gap, 0.1),
					"minimum_gap": snappedf(minimum_gap, 0.1),
					"attacker_advance": snappedf(carrier.global_position.x - origin.x, 0.1),
					"attacker_lateral": snappedf(carrier.global_position.y - origin.y, 0.1)
				})
				if rows.size() % 4 == 0:
					print("FOOTBALL_XI_DUEL_LAB_PROGRESS completed=%d/16" % rows.size())
	# All three real E/F actions plus a neutral run, in two approach
	# distances and two difficulty settings; no inferred win percentages.
	assert(rows.size() == 16)
	# Guard a useful range for this fixed, isolated XI laboratory only.
	# Not a claim about match win rates: Normal must leave several real
	# opportunities to beat a defender AND real consequences for mistakes.
	var outcome_counts: Dictionary = {
		"normal": {"retained": 0, "loose": 0, "recovered": 0, "foul": 0},
		"hard": {"retained": 0, "loose": 0, "recovered": 0, "foul": 0}
	}
	for item in rows:
		var level: String = String(item["difficulty"])
		var result: String = String(item["result"])
		var counts: Dictionary = outcome_counts[level]
		counts[result] = int(counts[result]) + 1
		outcome_counts[level] = counts
	var normal: Dictionary = outcome_counts["normal"]
	assert(int(normal["retained"]) >= 3 and int(normal["retained"]) <= 6,
		"Normal XI fixed 1v1 matrix must reward some skill without gifting all balls")
	assert(int(normal["loose"]) + int(normal["recovered"]) >= 2,
		"Normal XI must still be able to contest a human dribble")
	assert(int(normal["recovered"]) >= 1,
		"At least one poorly timed action must remain defensible by the CPU")
	var matrix: Dictionary = {}
	for item in rows:
		var key := String(item["difficulty"]) + "/" + String(item["approach"])
		if not matrix.has(key):
			matrix[key] = {}
		var row: Dictionary = matrix[key]
		row[String(item["action"])] = item["result"]
		matrix[key] = row
	for key in matrix:
		assert((matrix[key] as Dictionary).size() == ACTIONS.size())
	# Gameplay regression: the first false plant should buy a real escape in
	# the fixed near-presser XI duel. Do not count a merely loose ball as a win.
	var close_normal: Dictionary = matrix["normal/close"]
	assert(String(close_normal["feint"]) == "retained",
		"Normal XI close feint must beat one real presser without immunity")
	print("FOOTBALL_XI_LIVE_DRIBBLE_DUELS " + JSON.stringify({
		"mode": "isolated_deterministic_60hz_real_godot_physics_not_live_matches",
		"scenarios": rows.size(),
		"frames_per_scenario": FRAMES,
		"matrix": matrix,
		"outcome_counts": outcome_counts,
		"rows": rows
	}))
	print("FOOTBALL_XI_LIVE_DRIBBLE_DUELS_OK")
	quit(0)


func _reset_duel(
	game: Node, carrier: Footballer, presser: Footballer,
	difficulty: String, distance_id: String
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
	var offset := (
		Vector2(74.0, -24.0) if distance_id == "close"
		else Vector2(220.0, 52.0)
	)
	presser.global_position = carrier.global_position + offset
	presser.velocity = Vector2(-160.0, 0.0)
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	assert(game._ai_primary_presser(1) == presser)
	assert(game.ball.carrier == carrier and carrier.has_ball)
