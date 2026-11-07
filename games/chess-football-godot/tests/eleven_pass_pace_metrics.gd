extends SceneTree

# CI-only observational baseline: 4 seeded, equally staged 20s XI trials.
# All movements, kickoffs, ball contacts and interceptions use REAL Godot
# match physics/AI. The human-controlled player receives no keyboard input,
# so these are NOT live-user match analytics or competitive pass percentages.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI := Formation.ELEVEN_PITCH_RECT
const STEP := 1.0 / 60.0
const TICKS_PER_LEVEL := 1200
const FIXED_SEED := 73129
const LEVELS := ["easy", "normal", "hard", "expert"]


func _initialize() -> void:
	var trials: Array[Dictionary] = []
	for level in LEVELS:
		var trial: Dictionary = await _run_trial(level)
		trials.append(trial)
	assert(trials.size() == 4)
	var total_attempts: int = 0
	for trial in trials:
		assert(trial["in_play_seconds"] > 1.0)
		assert(trial["cpu_carrier_seconds"] >= 0.0)
		assert(trial["cpu_carrier_seconds"] <= trial["in_play_seconds"] + STEP)
		assert(trial["attempts"] == (
			trial["completed_intended"] + trial["completed_other_cpu"]
			+ trial["intercepted"] + trial["unclaimed"]
			+ trial["stopped_play"] + trial["pending_at_end"]
		))
		assert(trial["attempts"] >= trial["completed_intended"])
		total_attempts += int(trial["attempts"])
	# No arbitrary pass-accuracy or win-rate target: establish the baseline
	# before claiming a given difficulty is too perfect or tuning physics.
	var report := {
		"kind": "seeded_godot_xi_20s_per_level_not_live_match_telemetry",
		"seed": FIXED_SEED,
		"ticks_per_level": TICKS_PER_LEVEL,
		"levels": trials,
		"observed_attempts": total_attempts,
	}
	print("FOOTBALL_XI_PASS_PACE_METRICS " + JSON.stringify(report))
	print("FOOTBALL_XI_PASS_PACE_METRICS_OK")
	quit(0)


func _run_trial(level: String) -> Dictionary:
	# Rebuild players for each difficulty. Identical RNG seed and setup,
	# no teleport or forced outcome while the 20s observation runs.
	seed(FIXED_SEED)
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._set_quick_difficulty(level)
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	assert(game.match_pitch == XI and game.debug_team_counts() == [11, 11])

	# Kick off from the same in-pitch CPU possession in each trial;
	# everything after this touch runs unmodified through _physics_process.
	var start_owner: Footballer = game.teams[1][10]
	start_owner.global_position = XI.get_center() + Vector2(380.0, 0.0)
	game.ball.attach_to(start_owner)

	var active_ticks: int = 0
	var cpu_ticks: int = 0
	var attempts: int = 0
	var intended: int = 0
	var other_cpu: int = 0
	var intercepted: int = 0
	var unclaimed: int = 0
	var stopped_play: int = 0
	var max_chain: int = 0
	var chain: int = 0
	var turnovers: int = 0
	var prior_last_claimed_team: int = -1
	var previous_pass_until: float = float(game.ai_intended_pass_until)
	var pending_target: Footballer = null
	var pending: bool = false
	var pending_deadline: float = 0.0
	var hold_owner: Footballer = null
	var hold_seconds: float = 0.0
	var max_hold_seconds: float = 0.0

	for tick in range(TICKS_PER_LEVEL):
		game._physics_process(STEP)
		var open_play: bool = not (
			game.kickoff_active or game.goal_restart_active
			or game.set_piece_active
		)
		var owner: Footballer = game.ball.carrier
		if open_play:
			active_ticks += 1
			if owner != null and owner.team_id == 1:
				cpu_ticks += 1
		if owner != hold_owner or not open_play:
			max_hold_seconds = maxf(max_hold_seconds, hold_seconds)
			hold_seconds = 0.0
			hold_owner = owner if open_play else null
		if owner != null and owner.team_id == 1 and open_play:
			hold_seconds += STEP

		# Count only confirmed physical CPU releases with a new intended
		# receiver; do not confuse a shot, clearance or scripted restart
		# with a pass. The backend stays authoritative about launches.
		var new_pass_until: float = float(game.ai_intended_pass_until)
		var started_pass: bool = (
			open_play and new_pass_until > previous_pass_until + 0.0001
			and game.ball.carrier == null
			and game.ball.last_touch_team_id == 1
			and game.ai_intended_pass_receiver != null
		)
		previous_pass_until = new_pass_until

		# A pass can complete at the next actual player contact, go dead
		# or outrun the bounded receiver window. We do NOT infer success
		# merely because the intended player was selected by the AI.
		if pending:
			if not open_play:
				stopped_play += 1
				chain = 0
				pending = false
			elif owner != null:
				if owner.team_id == 1 and owner == pending_target:
					intended += 1
					chain += 1
					max_chain = maxi(max_chain, chain)
				elif owner.team_id == 1:
					other_cpu += 1
					chain = 0
				else:
					intercepted += 1
					chain = 0
				pending = false
			elif game.match_seconds >= pending_deadline:
				unclaimed += 1
				chain = 0
				pending = false

		if started_pass:
			# A second kick must not erase the previous unresolved pass.
			# This is defensive accounting; normally a new carrier touch
			# resolves the first kick before another could occur.
			if pending:
				unclaimed += 1
				chain = 0
			pending = true
			pending_target = game.ai_intended_pass_receiver
			pending_deadline = game.match_seconds + game.AI_XI_PASS_RECEIVER_SECONDS
			attempts += 1

		if not open_play:
			prior_last_claimed_team = -1
			chain = 0
		elif owner != null:
			if owner.team_id == 0 and prior_last_claimed_team == 1:
				turnovers += 1
				chain = 0
			prior_last_claimed_team = owner.team_id

	max_hold_seconds = maxf(max_hold_seconds, hold_seconds)
	var pending_at_end: int = 1 if pending else 0
	var in_play_seconds: float = float(active_ticks) * STEP
	var cpu_seconds: float = float(cpu_ticks) * STEP
	var result: Dictionary = {
		"difficulty": level,
		"in_play_seconds": snappedf(in_play_seconds, 0.01),
		"cpu_carrier_seconds": snappedf(cpu_seconds, 0.01),
		"cpu_carrier_pct": snappedf(100.0 * cpu_seconds / maxf(in_play_seconds, STEP), 0.1),
		"attempts": attempts,
		"passes_per_in_play_min": snappedf(60.0 * float(attempts) / maxf(in_play_seconds, STEP), 0.1),
		"completed_intended": intended,
		"completed_other_cpu": other_cpu,
		"intercepted": intercepted,
		"unclaimed": unclaimed,
		"stopped_play": stopped_play,
		"pending_at_end": pending_at_end,
		"intended_completion_pct": snappedf(100.0 * float(intended) / float(maxi(attempts, 1)), 0.1),
		"max_consecutive_intended_passes": max_chain,
		"cpu_to_human_possession_changes": turnovers,
		"longest_single_cpu_touch_seconds": snappedf(max_hold_seconds, 0.01),
	}
	root.remove_child(game)
	game.queue_free()
	await process_frame
	return result
