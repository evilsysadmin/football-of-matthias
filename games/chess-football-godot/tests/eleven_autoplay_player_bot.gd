extends SceneTree

# Deterministic REAL-input QA bot. Uses Input actions through the same
# _physics_process that the browser plays; no direct AI/tackle shortcuts.
# Two seed-matched 24-second open-play sessions, not 90-minute telemetry.
# The bot uses the established real Godot Input edge path. A separate
# physics_frame experiment broke Q action edges; compare same-seed replays
# first, before changing how browser-equivalent controls reach the engine.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI := Formation.ELEVEN_PITCH_RECT
const STEP := 1.0 / 60.0
const TICKS := 1440
# This is a separation monitor, NOT a new tackle radius or AI difficulty.
# Only contiguous live possession by the SAME CPU actor counts as an
# exposed defensive gap. Brief passes, set pieces and loose balls split it.
const PRESSURE_GAP_DISTANCE := 240.0
const SCENARIOS := [
	{"seed": 65113, "difficulty": "normal"},
	{"seed": 65117, "difficulty": "hard"},
]
const KEYS := ["move_left", "move_right", "move_up", "move_down",
	"sprint", "tackle", "change_player", "shoot_ball"]


func _initialize() -> void:
	var runs: Array[Dictionary] = []
	for spec in SCENARIOS:
		runs.append(await _play(int(spec["seed"]), String(spec["difficulty"])))
	# Replay the exact SAME scenario after a different difficulty has been
	# instantiated/played and released. It must not inherit RNG, cooldowns,
	# a stale input edge, player identities or asynchronous scene activity.
	var replay: Dictionary = await _play(int(SCENARIOS[0]["seed"]), String(SCENARIOS[0]["difficulty"]))
	_release_keys()
	assert(runs.size() == 2)
	var replay_fields: Array[String] = [
		"cpu_possession_frames", "human_possession_frames", "loose_ball_frames",
		"control_change_timeline", "control_change_causes", "manual_q_inputs",
		"manual_q_effective", "automatic_reassignments", "tackles_launched",
		"shot_inputs", "shot_releases", "strict_gap_frames_240",
		"pressure_gap_episodes", "score", "physics_checkpoints",
	]
	var replay_mismatches: Array[String] = []
	for field in replay_fields:
		if runs[0][field] != replay[field]:
			replay_mismatches.append(field)
	print("FOOTBALL_XI_REPLAY_AUDIT " + JSON.stringify({
		"seed": int(SCENARIOS[0]["seed"]),
		"difficulty": String(SCENARIOS[0]["difficulty"]),
		"fields_compared": replay_fields.size(),
		"mismatches": replay_mismatches,
		"baseline_checkpoints": runs[0]["physics_checkpoints"],
		"replay_checkpoints": replay["physics_checkpoints"],
	}))
	assert(replay_mismatches.is_empty(),
		"Same seed at real 60 Hz must reproduce possession, controls and pressure episodes")
	var all_auto := 0
	for run in runs:
		assert(int(run["ticks"]) == TICKS)
		assert(int(run["movement_frames"]) > 120,
			"Autoplay bot must really steer the human-controlled character")
		assert(int(run["cpu_possession_frames"]) > 0)
		assert(int(run["defensive_samples"]) > 0)
		assert(int(run["illegal_auto_handoffs"]) == 0)
		assert(int(run["manual_q_inputs"]) >= 1,
			"Each live XI trial must actually press Q after an automatic handoff")
		assert(int(run["manual_q_effective"]) == int(run["manual_q_inputs"]),
			"Manual Q must select another eligible defender when CPU carries")
		assert(int(run["manual_q_chase_cancelled"]) == int(run["manual_q_inputs"]),
			"Q must cancel the inherited AI pursuit on the same physics tick")
		assert(int(run["manual_q_grace_frames"]) >= 30,
			"Exercise at least half a second of live play under manual-Q priority")
		assert(int(run["manual_q_grace_auto_handoffs"]) == 0,
			"Never autoselect during the real 1.25-second Q grace window")
		assert(int(run["uncommanded_stable_cpu_switches"]) == 0,
			"Do not steal human control while the SAME CPU player still carries")
		var episode_frames := 0
		var observed_max := 0
		for episode in run["pressure_gap_episodes"]:
			assert(int(episode["frames"]) > 0 and int(episode["end_tick"]) <= TICKS)
			assert(float(episode["max_distance"]) >= PRESSURE_GAP_DISTANCE)
			assert(String(episode["ended_by"]) in ["closed_to_240", "possession_changed", "restart", "simulation_end"])
			assert(int(episode["closing_frames"]) <= int(episode["frames"]))
			episode_frames += int(episode["frames"])
			observed_max = maxi(observed_max, int(episode["frames"]))
		assert(episode_frames == int(run["strict_gap_frames_240"]),
			"Sum every consecutive same-carrier pressure gap exactly once")
		assert(int(run["strict_gap_frames_240"]) <= int(run["defensive_samples"]),
			"Every strict pressure gap must be part of observed live CPU possession")
		assert(observed_max == int(run["max_pressure_gap_frames"]),
			"Reported longest defensive gap must match measured episodes")
		assert(int(run["control_change_frames"]) == run["control_change_timeline"].size(),
			"Record the reason for EVERY change of player")
		var classified_total := 0
		for classification in run["control_change_causes"]:
			classified_total += int(run["control_change_causes"][classification])
		assert(classified_total == int(run["control_change_frames"]))
		assert(int(run["control_change_causes"]["auto_defense"]) == int(run["automatic_reassignments"]))
		assert(int(run["control_change_causes"]["manual_q"]) == int(run["manual_q_effective"]))
		assert(int(run["shot_inputs"]) <= 12,
			"Autoplay bot must not spam shoot every few game frames")
		assert(int(run["shot_releases"]) <= int(run["shot_inputs"]))
		assert(int(run["control_change_frames"]) <= 120,
			"Runaway XI auto-switch loop: excessive control changes")
		all_auto += int(run["automatic_reassignments"])
	assert(all_auto >= 1, "Real-input bot must exercise XI auto-select at least once")
	var report := {
		"kind": "seeded_24s_real_godot_input_bot_not_live_players",
		"ticks_per_trial": TICKS,
		"cases": runs,
		"observed_automatic_reassignments": all_auto,
		"replay_verified": true,
		"replay_seed": int(SCENARIOS[0]["seed"]),
		"replay_fields_compared": replay_fields.size(),
	}
	print("FOOTBALL_XI_AUTOPLAY_METRICS " + JSON.stringify(report))
	print("FOOTBALL_XI_AUTOPLAY_OK cases=2 input=real xi=22 manual_q=effective grace=no_auto control_audit=clean pressure_gaps=episodes physics_replay=identical")
	quit(0)


func _release_keys() -> void:
	for key in KEYS:
		Input.action_release(key)


func _hold(key: String, value: bool) -> void:
	if value:
		Input.action_press(key)
	else:
		Input.action_release(key)


func _act(direction: Vector2, sprint: bool, tackle: bool, change: bool, shoot: bool) -> void:
	_hold("move_right", direction.x > 0.28)
	_hold("move_left", direction.x < -0.28)
	_hold("move_down", direction.y > 0.28)
	_hold("move_up", direction.y < -0.28)
	_hold("sprint", sprint)
	_hold("tackle", tackle)
	_hold("change_player", change)
	_hold("shoot_ball", shoot)


# Close a strictly observed gap. Keep the entire episode and its ending
# reason in the CI artifact rather than reporting a misleading aggregate.
func _finish_pressure_gap(episodes: Array[Dictionary], gap: Dictionary, end_tick: int, reason: String) -> void:
	if gap.is_empty():
		return
	var frames: int = end_tick - int(gap["start_tick"])
	assert(frames > 0)
	episodes.append({
		"carrier_index": int(gap["carrier_index"]),
		"nearest_defender_index": int(gap["nearest_defender_index"]),
		"nearest_was_controlled": bool(gap["nearest_was_controlled"]),
		"start_tick": int(gap["start_tick"]),
		"end_tick": end_tick,
		"frames": frames,
		"seconds": snappedf(float(frames) * STEP, 0.001),
		"start_distance": snappedf(float(gap["start_distance"]), 0.1),
		"end_distance": snappedf(float(gap["last_distance"]), 0.1),
		"max_distance": snappedf(float(gap["max_distance"]), 0.1),
		"closing_frames": int(gap["closing_frames"]),
		"carrier_path": snappedf(float(gap["carrier_path"]), 0.1),
		"ended_by": reason,
	})


func _validate_real_match(game: Node2D) -> void:
	assert(game.debug_team_counts() == [11, 11])
	var holders := 0
	for team in game.teams:
		for player: Footballer in team:
			assert(not is_nan(player.global_position.x) and not is_nan(player.global_position.y))
			assert(not is_inf(player.global_position.x) and not is_inf(player.global_position.y))
			assert(XI.grow(70.0).has_point(player.global_position))
			assert(player.stamina >= 0.0 and player.stamina <= player.STAMINA_MAX)
			if player.has_ball:
				holders += 1
				assert(game.ball.carrier == player)
	assert(holders == (1 if game.ball.carrier != null else 0))


func _play(trial_seed: int, difficulty: String) -> Dictionary:
	_release_keys()
	seed(trial_seed)
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	# The player clocks are advanced by the simulated match step, not by
	# how quickly the CI host renders an otherwise headless frame.
	for team in game.teams:
		for player: Footballer in team:
			player.set_process(false)
	game._set_quick_difficulty(difficulty)
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	assert(game.match_pitch == XI)
	# One kick-off state only. No script repositions actors, scores or
	# grants possession after this point; AI and real collisions decide play.
	var cpu_owner: Footballer = game.teams[1][10]
	cpu_owner.global_position = XI.get_center() + Vector2(250.0, 0.0)
	var initial_human: Footballer = game.teams[0][10]
	initial_human.global_position = cpu_owner.global_position + Vector2(-370.0, -95.0)
	var approaching: Footballer = game.teams[0][6]
	approaching.global_position = cpu_owner.global_position + Vector2(-81.0, 8.0)
	game._select_player(initial_human)
	game.ball.attach_to(cpu_owner)
	game.xi_human_auto_switch_block_until = 0.0

	var movement_frames := 0
	var cpu_frames := 0
	var human_frames := 0
	var loose_frames := 0
	var defending_frames := 0
	var within_120_frames := 0
	var unattended_240_frames := 0
	var strict_gap_frames_240 := 0
	var pressure_gap_episodes: Array[Dictionary] = []
	var active_pressure_gap: Dictionary = {}
	var auto_reassignments := 0
	var all_control_changes := 0
	var illegal_auto_handoffs := 0
	var uncommanded_stable_cpu_switches := 0
	var control_change_causes := {
		"auto_defense": 0,
		"manual_q": 0,
		"forced_unavailable": 0,
		"possession_or_restart": 0,
		"uncommanded_stable_cpu": 0,
	}
	var control_change_timeline: Array[Dictionary] = []
	var max_control_gap := 0.0
	var min_defender_distance := INF
	var tackle_inputs := 0
	var actual_tackles := 0
	var manual_q_inputs := 0
	var manual_q_effective := 0
	var manual_q_chase_cancelled := 0
	var manual_q_grace_frames := 0
	var manual_q_grace_auto_handoffs := 0
	var pending_manual_q := false
	var manual_q_grace_until: float = 0.0
	var shot_inputs := 0
	var shot_releases := 0
	var previous_e := false
	var shooting_frames := 0
	var last_shot_attempt_at: float = -100.0
	var shot_attempted_owner: Footballer = null
	var physics_checkpoints: Array[Dictionary] = []

	for tick in range(TICKS):
		var playing: bool = not (game.kickoff_active or game.goal_restart_active or game.set_piece_active)
		var current: Footballer = game.controlled
		var carrier: Footballer = game.ball.carrier
		var goal: Vector2 = ChessFootballMath.goal_center(0, XI)
		var destination: Vector2 = game.ball.global_position
		if carrier != null:
			if carrier.team_id == 1:
				destination = carrier.global_position
			elif carrier == current:
				destination = goal
			else:
				destination = carrier.global_position
		var toward: Vector2 = destination - current.global_position
		var moving: bool = toward.length() > 32.0 and playing
		var direction: Vector2 = toward.normalized() if moving else Vector2.ZERO
		var sprint: bool = moving and toward.length() > 165.0

		var can_e := false
		if playing and carrier != null and carrier.team_id == 1 and current.can_tackle():
			var hitbox: Dictionary = game._tackle_hitbox(current, carrier.global_position)
			can_e = bool(hitbox.get("inside", false)) and not bool(hitbox.get("foul", true))
		var press_e: bool = can_e and not previous_e
		# Follow the FIRST naturally observed autonomous handoff with
		# an explicit Q on a live CPU possession. Fixed frame-number Q
		# probes sometimes pressed nothing at all, giving false confidence.
		# Keep the real player movement/input path; no direct selection.
		var press_q: bool = (
			playing and pending_manual_q and manual_q_inputs == 0
			and carrier != null and carrier.team_id == 1
		)
		if press_q:
			press_e = false
			pending_manual_q = false
		# Do not machine-gun fresh charges while a single possession still
		# belongs to the same shooter. Respect real loss/regain of possession
		# and a two-second tactical decision interval between shot attempts.
		if carrier != shot_attempted_owner:
			shot_attempted_owner = null
		if carrier == null or carrier != current:
			shooting_frames = 0
		elif (
			current.team_id == 0 and playing
			and shooting_frames == 0 and shot_attempted_owner == null
			and game.match_seconds - last_shot_attempt_at >= 2.0
			and current.global_position.x >= XI.get_center().x + 480.0
		):
			shooting_frames = 7
			shot_attempted_owner = current
			last_shot_attempt_at = game.match_seconds
		var press_shot: bool = shooting_frames > 0 and playing and carrier == current
		if shooting_frames > 0:
			shooting_frames -= 1

		_act(direction, sprint, press_e, press_q, press_shot)
		if moving and Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.2:
			movement_frames += 1
		if press_e:
			tackle_inputs += 1
		if press_q:
			manual_q_inputs += 1
		if press_shot and shooting_frames == 6:
			shot_inputs += 1
		var before_tackle: float = current.tackle_cooldown_seconds
		var before_shot_charge: bool = game.shot_charging
		var before_control: Footballer = current
		game._physics_process(STEP)
		# Only a real Godot shot charge followed by ball release counts as
		# a completed bot shot; issuing the key alone is not success.
		if before_shot_charge and not game.shot_charging and game.ball.carrier != current and game.ball.last_touch_team_id == 0:
			shot_releases += 1
		for team in game.teams:
			for player: Footballer in team:
				player._process(STEP)
		if press_e and before_tackle <= 0.0 and current.tackle_cooldown_seconds > 0.0:
			actual_tackles += 1

		# Distinguish true automatic handoffs from Q and from ordinary
		# possession-driven changes. Keep measuring while the clock runs
		# through collisions, turnovers, and legally restarted play.
		var auto_switched: bool = (
			game.controlled != before_control
			and game.xi_human_handoff_chase_actor == game.controlled
		)
		if game.controlled != before_control:
			all_control_changes += 1
			# Classify from actual before/after owners and real input edges,
			# never inferred from the mere identity of the new selected actor.
			# A CPU-to-CPU pass has a different owner and is NOT stable.
			var same_cpu_owner: bool = (
				playing and carrier != null and carrier.team_id == 1
				and game.ball.carrier == carrier
				and not game.kickoff_active and not game.goal_restart_active
				and not game.set_piece_active
			)
			var cause: String = "possession_or_restart"
			if auto_switched:
				cause = "auto_defense"
			elif press_q:
				cause = "manual_q"
			elif same_cpu_owner:
				if before_control.sent_off or before_control.xi_collision_down_seconds > 0.0 or before_control.role == "keeper":
					cause = "forced_unavailable"
				else:
					cause = "uncommanded_stable_cpu"
					uncommanded_stable_cpu_switches += 1
			control_change_causes[cause] = int(control_change_causes[cause]) + 1
			control_change_timeline.append({
				"tick": tick,
				"clock": snappedf(game.match_seconds, 0.01),
				"cause": cause,
				"from": game.teams[0].find(before_control),
				"to": game.teams[0].find(game.controlled),
				"carrier_before": carrier.team_id if carrier != null else -1,
				"carrier_after": game.ball.carrier.team_id if game.ball.carrier != null else -1,
			})
		if auto_switched:
			auto_reassignments += 1
			var switch_distance: float = game.controlled.global_position.distance_to(destination)
			max_control_gap = maxf(max_control_gap, switch_distance)
			if not playing or carrier == null or carrier.team_id != 1 or switch_distance > 135.0:
				illegal_auto_handoffs += 1
			if manual_q_inputs == 0:
				pending_manual_q = true
			if game.match_seconds < manual_q_grace_until:
				manual_q_grace_auto_handoffs += 1
		if press_q:
			# Q was pressed while the CPU carried the ball. Its real Godot
			# handling must reassign the selected outfielder, clear inherited
			# movement, and extend the grace beyond the automatic 0.9 s.
			if game.controlled != before_control and game.controlled.team_id == 0:
				manual_q_effective += 1
			if game.xi_human_handoff_chase_actor == null and game.xi_human_handoff_chase_owner == null:
				manual_q_chase_cancelled += 1
			manual_q_grace_until = game.xi_human_auto_switch_block_until
			assert(manual_q_grace_until - game.match_seconds > 1.20,
				"Q must override the automatic 0.9s cooldown with 1.25s manual priority")
		if manual_q_grace_until > game.match_seconds:
			manual_q_grace_frames += 1
		# Track episodes with a stable live CPU carrier. The legacy metric
		# above/below remains untouched for comparison; the strict version
		# excludes transfers, restarts and a carrier lost during physics.
		var same_live_cpu_carrier: bool = (
			playing and carrier != null and carrier.team_id == 1
			and game.ball.carrier == carrier
			and not game.kickoff_active and not game.goal_restart_active
			and not game.set_piece_active
		)
		var nearest_eligible: Footballer = null
		var nearest_eligible_distance := INF
		if same_live_cpu_carrier:
			for defender: Footballer in game.teams[0]:
				if defender.role == "keeper" or defender.sent_off or defender.xi_collision_down_seconds > 0.0:
					continue
				var separation: float = defender.global_position.distance_to(carrier.global_position)
				if separation < nearest_eligible_distance:
					nearest_eligible_distance = separation
					nearest_eligible = defender
			assert(nearest_eligible != null)
		if not active_pressure_gap.is_empty():
			var original_carrier: Footballer = active_pressure_gap["carrier"]
			if not same_live_cpu_carrier or carrier != original_carrier or nearest_eligible_distance <= PRESSURE_GAP_DISTANCE:
				var reason := "possession_changed"
				if game.kickoff_active or game.goal_restart_active or game.set_piece_active or not playing:
					reason = "restart"
				elif same_live_cpu_carrier and carrier == original_carrier:
					reason = "closed_to_240"
				_finish_pressure_gap(pressure_gap_episodes, active_pressure_gap, tick, reason)
				active_pressure_gap.clear()
		if same_live_cpu_carrier and nearest_eligible_distance > PRESSURE_GAP_DISTANCE:
			strict_gap_frames_240 += 1
			if active_pressure_gap.is_empty():
				active_pressure_gap = {
					"carrier": carrier,
					"carrier_index": game.teams[1].find(carrier),
					"nearest_defender_index": game.teams[0].find(nearest_eligible),
					"nearest_was_controlled": nearest_eligible == game.controlled,
					"start_tick": tick,
					"start_distance": nearest_eligible_distance,
					"last_distance": nearest_eligible_distance,
					"max_distance": nearest_eligible_distance,
					"last_carrier_position": carrier.global_position,
					"carrier_path": 0.0,
					"closing_frames": 0,
				}
			else:
				if nearest_eligible_distance < float(active_pressure_gap["last_distance"]) - 1.0:
					active_pressure_gap["closing_frames"] = int(active_pressure_gap["closing_frames"]) + 1
				active_pressure_gap["carrier_path"] = float(active_pressure_gap["carrier_path"]) + (
					carrier.global_position.distance_to(active_pressure_gap["last_carrier_position"])
				)
				active_pressure_gap["last_carrier_position"] = carrier.global_position
				active_pressure_gap["last_distance"] = nearest_eligible_distance
				active_pressure_gap["max_distance"] = maxf(float(active_pressure_gap["max_distance"]), nearest_eligible_distance)
		if playing:
			if carrier == null:
				loose_frames += 1
			elif carrier.team_id == 0:
				human_frames += 1
			else:
				cpu_frames += 1
				defending_frames += 1
				var closest := INF
				for teammate: Footballer in game.teams[0]:
					if teammate.role != "keeper" and not teammate.sent_off:
						closest = minf(closest, teammate.global_position.distance_to(carrier.global_position))
				assert(not is_inf(closest))
				min_defender_distance = minf(min_defender_distance, closest)
				if closest <= 120.0:
					within_120_frames += 1
				if closest > 240.0:
					unattended_240_frames += 1
		previous_e = press_e
		if tick % 60 == 0:
			_validate_real_match(game)
			# Stable roster indices and quantized positions: no instance IDs,
			# timing/performance statistics or visual state in the replay.
			physics_checkpoints.append({
				"tick": tick,
				"carrier_team": game.ball.carrier.team_id if game.ball.carrier != null else -1,
				"carrier_index": game.teams[game.ball.carrier.team_id].find(game.ball.carrier) if game.ball.carrier != null else -1,
				"controlled_index": game.teams[0].find(game.controlled),
				"ball_x": snappedf(game.ball.global_position.x, 0.1),
				"ball_y": snappedf(game.ball.global_position.y, 0.1),
				"score": [int(game.score[0]), int(game.score[1])],
			})
		# Keep action just_pressed/just_released edges on the existing proven
		# input path. Match physics advances explicitly by STEP = 1/60.
		await process_frame

	if not active_pressure_gap.is_empty():
		_finish_pressure_gap(pressure_gap_episodes, active_pressure_gap, TICKS, "simulation_end")
		active_pressure_gap.clear()
	var max_pressure_gap_frames := 0
	for episode in pressure_gap_episodes:
		max_pressure_gap_frames = maxi(max_pressure_gap_frames, int(episode["frames"]))
	_release_keys()
	assert(game.match_seconds >= float(TICKS) * STEP - STEP)
	_validate_real_match(game)
	var record: Dictionary = {
		"seed": trial_seed,
		"difficulty": difficulty,
		"ticks": TICKS,
		"movement_frames": movement_frames,
		"cpu_possession_frames": cpu_frames,
		"human_possession_frames": human_frames,
		"loose_ball_frames": loose_frames,
		"defensive_samples": defending_frames,
		"close_pressure_frames_120": within_120_frames,
		"unattended_frames_240": unattended_240_frames,
		"strict_gap_frames_240": strict_gap_frames_240,
		"max_pressure_gap_frames": max_pressure_gap_frames,
		"pressure_gap_episodes": pressure_gap_episodes,
		"min_defender_distance": snappedf(min_defender_distance, 0.1) if defending_frames > 0 else -1.0,
		"automatic_reassignments": auto_reassignments,
		"control_change_frames": all_control_changes,
		"physics_checkpoints": physics_checkpoints,
		"control_change_causes": control_change_causes,
		"control_change_timeline": control_change_timeline,
		"uncommanded_stable_cpu_switches": uncommanded_stable_cpu_switches,
		"illegal_auto_handoffs": illegal_auto_handoffs,
		"max_auto_handoff_distance": snappedf(max_control_gap, 0.1),
		"manual_q_inputs": manual_q_inputs,
		"manual_q_effective": manual_q_effective,
		"manual_q_chase_cancelled": manual_q_chase_cancelled,
		"manual_q_grace_frames": manual_q_grace_frames,
		"manual_q_grace_auto_handoffs": manual_q_grace_auto_handoffs,
		"e_inputs": tackle_inputs,
		"tackles_launched": actual_tackles,
		"shot_inputs": shot_inputs,
		"shot_releases": shot_releases,
		"score": [int(game.score[0]), int(game.score[1])],
	}
	root.remove_child(game)
	game.queue_free()
	await process_frame
	return record
