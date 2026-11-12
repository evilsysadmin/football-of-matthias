extends SceneTree

# CI-only, deterministic duel matrix. Same initial real Godot actors are
# exercised twice: the previous unguarded tackle decision and the current
# XI Hard guarded commit/contain decision. This is NOT live match telemetry or
# evidence of aggregate win rates; it prevents specific regressions.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI := Formation.ELEVEN_PITCH_RECT

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
	game._set_quick_difficulty("normal")
	assert(game.match_pitch == XI)

	var owner: Footballer = game.teams[0][10]
	var defender: Footballer = game.teams[1][5]
	# Normal must let the human settle a real first touch and must not
	# dispatch a second automated tackle. After the read, the first
	# defender still uses the same physically valid clean hitbox.
	owner.global_position = XI.get_center()
	defender.global_position = owner.global_position + Vector2(31.0, -8.0)
	defender.velocity = Vector2(-175.0, 0.0)
	game.ball.attach_to(owner)
	assert(not game._ai_xi_tackle_commit_ready(defender, owner, false))
	assert(not game._ai_xi_tackle_commit_ready(defender, owner, true))
	assert(not game._ai_cpu_second_press_active(defender, owner.global_position))
	game.ball.tick_ball(game.AI_XI_NORMAL_FIRST_TOUCH_REACTION + 0.02)
	assert(game._ai_xi_tackle_commit_ready(defender, owner, false))
	assert(not game._ai_xi_tackle_commit_ready(defender, owner, true))
	# Preserve the original guarded/unguarded tackle matrix on Hard;
	# that level explicitly retains coordinated second-man challenges.
	game._set_quick_difficulty("hard")
	assert(game._ai_xi_tackle_commit_ready(defender, owner, true))
	# Explicitly exclude every other actor from the local duel.
	for team in game.teams:
		for player: Footballer in team:
			if player != owner and player != defender:
				player.global_position = XI.position + Vector2(70.0, 70.0)
	var scenarios: Array[Dictionary] = [
		{"id":"first_far", "offset":Vector2(82.0, 0.0), "cover":false,
			"unguarded":"wasted", "guarded":"contain"},
		{"id":"first_side_outside_hitbox", "offset":Vector2(45.0, 33.0), "cover":false,
			"unguarded":"loose", "guarded":"contain"},
		{"id":"first_glancing", "offset":Vector2(38.0, -25.0), "cover":false,
			"unguarded":"loose", "guarded":"loose"},
		{"id":"first_clean", "offset":Vector2(31.0, -8.0), "cover":false,
			"unguarded":"recovered", "guarded":"recovered"},
		{"id":"first_rear_foul", "offset":Vector2(-18.0, 0.0), "cover":false,
			"unguarded":"foul", "guarded":"contain"},
		{"id":"cover_glancing", "offset":Vector2(38.0, -25.0), "cover":true,
			"unguarded":"loose", "guarded":"contain"},
		{"id":"cover_clean", "offset":Vector2(31.0, -8.0), "cover":true,
			"unguarded":"recovered", "guarded":"recovered"},
		{"id":"cover_rear_foul", "offset":Vector2(-18.0, 0.0), "cover":true,
			"unguarded":"foul", "guarded":"contain"},
	]
	var result: Dictionary = {
		"mode":"deterministic_scenarios_not_live_matches",
		"scenario_count":scenarios.size(),
		"unguarded":_empty_metrics(),
		"guarded":_empty_metrics(),
	}
	for item in scenarios:
		for mode in ["unguarded", "guarded"]:
			var outcome: String = _run_duel(
				game, owner, defender, item, mode == "guarded"
			)
			assert(
				outcome == String(item[mode]),
				"unexpected %s for %s: %s" % [mode, item["id"], outcome]
			)
			var counters: Dictionary = result[mode]
			counters["decisions"] += 1
			counters[outcome] += 1
			if outcome != "contain":
				counters["attempts"] += 1
			if outcome in ["recovered", "loose", "foul"]:
				counters["contacts"] += 1
			result[mode] = counters

	var ung: Dictionary = result["unguarded"]
	var guarded: Dictionary = result["guarded"]
	assert(ung["decisions"] == guarded["decisions"])
	assert(ung["attempts"] > guarded["attempts"])
	assert(ung["wasted"] > guarded["wasted"])
	assert(ung["foul"] > guarded["foul"])
	assert(guarded["foul"] == 0 and guarded["wasted"] == 0)
	assert(guarded["recovered"] == ung["recovered"] and guarded["recovered"] >= 2)
	assert(guarded["loose"] >= 1)
	print("FOOTBALL_XI_DEFENSE_DUEL_METRICS " + JSON.stringify(result))
	print("FOOTBALL_XI_DEFENSE_DUEL_METRICS_OK")
	quit(0)


func _empty_metrics() -> Dictionary:
	return {
		"decisions":0,
		"attempts":0,
		"contacts":0,
		"recovered":0,
		"loose":0,
		"foul":0,
		"wasted":0,
		"contain":0,
	}


func _run_duel(
	game: Node, owner: Footballer, defender: Footballer,
	item: Dictionary, guarded: bool
) -> String:
	# Fully reset both real footballers and the game's transient restart /
	# pending-steal state. No player is spawned or teleported DURING a duel.
	var origin: Vector2 = XI.get_center()
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	game.set_piece_player = null
	game.pending_tackle_player = null
	game.pending_tackle_seconds = 0.0
	owner.global_position = origin
	owner.velocity = Vector2(220.0, 130.0)
	owner.contact_stun_seconds = 0.0
	owner.tackle_recovery_seconds = 0.0
	defender.global_position = origin + item["offset"]
	defender.velocity = Vector2(-175.0, 0.0)
	defender.tackle_cooldown_seconds = 0.0
	defender.tackle_recovery_seconds = 0.0
	defender.tackle_active_seconds = 0.0
	defender.tackle_launch_speed_ratio = 0.0
	defender.tackle_aggressive = false
	defender.action_lock_seconds = 0.0
	game.ball.attach_to(owner)
	# Compare identical post-read decisions without moving the ball from
	# the fixture's original boot anchor. This is a static contact geometry
	# test; the live 60 Hz duel lab separately exercises the full clock.
	game.ball.possession_seconds = game.AI_XI_HARD_FIRST_TOUCH_READ + 0.01

	var is_cover: bool = bool(item["cover"])
	# Mirror the production secondary defender's 0.72 * attempt range.
	var close_enough: bool = (
		not is_cover
		or defender.global_position.distance_to(owner.global_position)
			< game.TACKLE_ATTEMPT_RANGE * 0.72
	)
	var commit: bool = close_enough and (
		not guarded or game._ai_xi_tackle_commit_ready(defender, owner, is_cover)
	)
	if not commit:
		assert(defender.tackle_cooldown_seconds == 0.0)
		return "contain"
	game._try_tackle(defender)
	if defender.tackle_cooldown_seconds <= 0.0:
		return "contain"
	if game.set_piece_active:
		return "foul"
	if game.pending_tackle_player == defender:
		# Let the physical ball travel before its ordinary delayed claim.
		game.ball.tick_ball(game.TACKLE_STEAL_DELAY)
		game._update_pending_tackle_claim(game.TACKLE_STEAL_DELAY)
		if game.ball.carrier == defender:
			return "recovered"
		return "loose"
	if game.ball.carrier == null:
		return "loose"
	return "wasted"
