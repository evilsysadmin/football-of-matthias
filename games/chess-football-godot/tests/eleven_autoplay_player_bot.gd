extends SceneTree

# Deterministic REAL-input QA bot. Uses Input actions through the same
# _physics_process that the browser plays; no direct AI/tackle shortcuts.
# Two seed-matched 24-second open-play sessions, not 90-minute telemetry.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI := Formation.ELEVEN_PITCH_RECT
const STEP := 1.0 / 60.0
const TICKS := 1440
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
	_release_keys()
	assert(runs.size() == 2)
	var all_auto := 0
	for run in runs:
		assert(int(run["ticks"]) == TICKS)
		assert(int(run["movement_frames"]) > 120,
			"Autoplay bot must really steer the human-controlled character")
		assert(int(run["cpu_possession_frames"]) > 0)
		assert(int(run["defensive_samples"]) > 0)
		assert(int(run["illegal_auto_handoffs"]) == 0)
		assert(int(run["control_change_frames"]) <= 120,
			"Runaway XI auto-switch loop: excessive control changes")
		all_auto += int(run["automatic_reassignments"])
	assert(all_auto >= 1, "Real-input bot must exercise XI auto-select at least once")
	var report := {
		"kind": "seeded_24s_real_godot_input_bot_not_live_players",
		"ticks_per_trial": TICKS,
		"cases": runs,
		"observed_automatic_reassignments": all_auto,
	}
	print("FOOTBALL_XI_AUTOPLAY_METRICS " + JSON.stringify(report))
	print("FOOTBALL_XI_AUTOPLAY_OK cases=2 input=real xi=22")
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
	var auto_reassignments := 0
	var all_control_changes := 0
	var illegal_auto_handoffs := 0
	var max_control_gap := 0.0
	var min_defender_distance := INF
	var tackle_inputs := 0
	var actual_tackles := 0
	var manual_q_inputs := 0
	var shot_inputs := 0
	var previous_e := false
	var previous_q := false
	var shooting_frames := 0

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
		# The bot occasionally requests a real manual Q while defending.
		# No direct _select_player call is used once the scenario begins.
		var press_q: bool = (
			playing and tick in [300, 825]
			and carrier != null and carrier.team_id == 1 and not press_e
		)
		if carrier != null and carrier == current and current.team_id == 0 and playing:
			if shooting_frames == 0 and current.global_position.x >= XI.get_center().x + 480.0:
				shooting_frames = 7
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
		var before_control: Footballer = current
		game._physics_process(STEP)
		for team in game.teams:
			for player: Footballer in team:
				player._process(STEP)
		if press_e and before_tackle <= 0.0 and current.tackle_cooldown_seconds > 0.0:
			actual_tackles += 1

		if game.controlled != before_control:
			all_control_changes += 1
			if game.xi_human_handoff_chase_actor == game.controlled:
				auto_reassignments += 1
				var switch_distance: float = game.controlled.global_position.distance_to(destination)
				max_control_gap = maxf(max_control_gap, switch_distance)
				if not playing or carrier == null or carrier.team_id != 1 or switch_distance > 135.0:
					illegal_auto_handoffs += 1
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
		previous_q = press_q
		if tick % 60 == 0:
			_validate_real_match(game)
		# Let input just_pressed edges expire between simulated 60-Hz ticks.
		await process_frame

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
		"min_defender_distance": snappedf(min_defender_distance, 0.1) if defending_frames > 0 else -1.0,
		"automatic_reassignments": auto_reassignments,
		"control_change_frames": all_control_changes,
		"illegal_auto_handoffs": illegal_auto_handoffs,
		"max_auto_handoff_distance": snappedf(max_control_gap, 0.1),
		"manual_q_inputs": manual_q_inputs,
		"e_inputs": tackle_inputs,
		"tackles_launched": actual_tackles,
		"shot_inputs": shot_inputs,
		"score": [int(game.score[0]), int(game.score[1])],
	}
	root.remove_child(game)
	game.queue_free()
	await process_frame
	return record
