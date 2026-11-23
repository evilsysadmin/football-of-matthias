extends SceneTree

# Diagnostic-only XI skill/timing sweep: a human holds the same chosen escape
# lane but presses E at 0/8/16 physics frames as the physical defender closes.
# Both arms start from the same seed, same formation, 22 real actors, original
# ball authority and normal 60 Hz match physics. No AI/gameplay overrides after
# the initial staged carrier/defender. This is NOT a match win rate.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI: Rect2 = Formation.ELEVEN_PITCH_RECT
const DT := 1.0 / 60.0
const MAX_FRAMES := 96
const FOLLOW_FRAMES := 72
const TRIGGERS := [0, 8, 16]
const DISTANCES := [148.0, 185.0]
const SIDES := [-1.0, 1.0]
const ACTIONS := ["feint", "cut"]
const KEYS := ["move_left", "move_right", "move_up", "move_down",
	"sprint", "tackle", "special_move", "pass_ball", "shoot_ball", "change_player"]


func _release_keys() -> void:
	for key in KEYS:
		Input.action_release(key)


func _hold(key: String, yes: bool) -> void:
	if yes:
		Input.action_press(key)
	else:
		Input.action_release(key)


func _input(direction: Vector2, press_e: bool) -> void:
	_hold("move_left", direction.x < -0.28)
	_hold("move_right", direction.x > 0.28)
	_hold("move_up", direction.y < -0.28)
	_hold("move_down", direction.y > 0.28)
	_hold("tackle", press_e)


func _outcome(game: Node2D, original: Footballer) -> String:
	if game.kickoff_active or game.goal_restart_active or game.set_piece_active:
		return "restart"
	if game.ball.carrier == original:
		return "retained"
	if game.ball.carrier == null:
		return "loose"
	return "teammate" if game.ball.carrier.team_id == 0 else "cpu_stolen"


func _play(spec: Dictionary, use_e: bool) -> Dictionary:
	_release_keys()
	seed(int(spec["seed"]))
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game: Node2D = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
			actor.set_physics_process(false)
	await process_frame
	await process_frame
	game._set_quick_difficulty("hard")
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	assert(game.match_pitch == XI and game.debug_team_counts() == [11, 11])
	var carrier: Footballer = game.teams[0][10]
	var presser: Footballer = game.teams[1][5]
	var side: float = float(spec["side"])
	var center: Vector2 = XI.get_center()
	carrier.global_position = center + Vector2(-220.0, side * 95.0)
	carrier.velocity = (
		Vector2.RIGHT * 170.0 if spec["action"] == "cut" else Vector2.ZERO
	)
	presser.global_position = carrier.global_position + Vector2(
		float(spec["distance"]), side * 18.0
	)
	presser.velocity = Vector2.LEFT * 125.0
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	assert(game.ball.carrier == carrier and carrier.can_dribble())
	var trigger: int = int(spec["trigger"])
	var original: Vector2 = carrier.global_position
	var start_rival_gap: float = carrier.global_position.distance_to(presser.global_position)
	# The human chooses the escape *opposite* the real defender's side
	# at entry; this held skill input is identical in both arms.
	var lane: Vector2 = Vector2(1.0, -side * 0.66).normalized()
	var e_executed := false
	var first_loss: int = -1
	var first_cause := ""
	var after: String = ""
	var forward: float = 0.0
	var lateral: float = 0.0
	var actual_tackles := 0
	var nearest_at_e: float = -1.0
	for tick in range(MAX_FRAMES):
		var holding: bool = game.ball.carrier == carrier
		var dir: Vector2 = Vector2.ZERO
		if holding:
			if tick < trigger:
				dir = Vector2.RIGHT if spec["action"] == "cut" else Vector2.ZERO
			elif tick == trigger and spec["action"] == "feint":
				# Both arms have the same zero-input first planted beat.
				dir = Vector2.ZERO
			else:
				dir = lane
		var press_e: bool = use_e and holding and tick == trigger
		if tick == trigger:
			nearest_at_e = carrier.global_position.distance_to(presser.global_position)
		var cooldowns: Array[float] = []
		for rival: Footballer in game.teams[1]:
			cooldowns.append(rival.tackle_cooldown_seconds)
		_input(dir, press_e)
		game._physics_process(DT)
		for team in game.teams:
			for actor: Footballer in team:
				actor._process(DT)
		for rival_index in range(game.teams[1].size()):
			var rival: Footballer = game.teams[1][rival_index]
			if rival.tackle_cooldown_seconds > cooldowns[rival_index] + 0.20:
				actual_tackles += 1
		if press_e:
			assert(carrier.dribble_active() and carrier.dribble_mode == spec["action"],
				"Real E input did not execute the requested XI physical action")
			e_executed = true
		if tick >= trigger and first_loss < 0 and game.ball.carrier != carrier:
			first_loss = tick - trigger
			first_cause = (
				"clean_tackle_pending_claim" if game.pending_tackle_player != null
				else "body_collision" if carrier.xi_collision_guard_seconds > 0.0
				else "tackle_stun" if carrier.contact_stun_seconds > 0.0
				else "other_ball_event"
			)
		if tick == trigger + FOLLOW_FRAMES - 1:
			after = _outcome(game, carrier)
			forward = snappedf(carrier.global_position.x - original.x, 0.1)
			lateral = snappedf(absf(carrier.global_position.y - original.y), 0.1)
		if tick % 24 == 0:
			assert(game.debug_team_counts() == [11, 11])
			assert(carrier.stamina >= 0.0 and carrier.stamina <= carrier.STAMINA_MAX)
		# Preserve the real input-edge processing between physics frames.
		await process_frame
	_release_keys()
	assert(after in ["retained", "loose", "cpu_stolen", "teammate", "restart"])
	assert((not e_executed) or use_e)
	var result: Dictionary = {
		"seed": int(spec["seed"]),
		"action": String(spec["action"]),
		"distance": float(spec["distance"]),
		"side": "upper" if side < 0.0 else "lower",
		"trigger_frame": trigger,
		"variant": "e" if use_e else "run_without_e",
		"e_executed": e_executed,
		"rival_distance_at_start": snappedf(start_rival_gap, 0.1),
		"rival_distance_at_trigger": snappedf(nearest_at_e, 0.1),
		"outcome_1_2s_after_trigger": after,
		"first_loss_after_trigger": first_loss,
		"first_loss_cause": first_cause,
		"forward_advance": forward,
		"lateral_advance": lateral,
		"cpu_tackle_attempts": actual_tackles
	}
	root.remove_child(game)
	game.queue_free()
	await process_frame
	return result


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for action in ACTIONS:
		for distance in DISTANCES:
			for side in SIDES:
				for trigger in TRIGGERS:
					var spec: Dictionary = {
						"seed": 68219 if action == "feint" else 68223,
						"action": action,
						"distance": distance,
						"side": side,
						"trigger": trigger
					}
					var e: Dictionary = await _play(spec, true)
					var no_e: Dictionary = await _play(spec, false)
					assert(e["variant"] == "e" and no_e["variant"] == "run_without_e")
					assert(e["seed"] == no_e["seed"])
					assert(e["action"] == no_e["action"])
					assert(e["trigger_frame"] == no_e["trigger_frame"])
					# Identical starting pressure is required; after 8/16 real
					# frames unrelated XI actor/AI state can drift between
					# identical seeds. Record that drift rather than
					# falsifying a counterfactual or aborting the scout.
					assert(absf(
						float(e["rival_distance_at_start"]) -
						float(no_e["rival_distance_at_start"])
					) < 0.1, "E/no-E arms must begin with identical pressure")
					assert(e["cpu_tackle_attempts"] >= 0 and no_e["cpu_tackle_attempts"] >= 0)
					rows.append(e)
					rows.append(no_e)
					if rows.size() % 12 == 0:
						print("FOOTBALL_XI_E_TIMING_PROGRESS completed=%d/48" % rows.size())
	assert(rows.size() == 48)
	print("FOOTBALL_XI_E_TIMING_SCOUT " + JSON.stringify({
		"kind": "observational_22_player_real_input_60hz_e_timing_vs_control_not_match_win_rate",
		"fixtures": 24,
		"arms": rows.size(),
		"followthrough_frames": FOLLOW_FRAMES,
		"sampled_trigger_frames": TRIGGERS,
		"distances": DISTANCES,
		"rows": rows
	}))
	print("FOOTBALL_XI_E_TIMING_SCOUT_OK fixtures=24 arms=48 e_input=real cpu=full")
	quit(0)
