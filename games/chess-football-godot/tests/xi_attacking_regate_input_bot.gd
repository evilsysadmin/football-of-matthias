extends SceneTree

# Attack-side companion to eleven_autoplay_player_bot.gd. Eight real 12-second
# 22-player open-play windows; the bot presses the SAME XI E/movement keys
# used by a human and the match executes its normal _physics_process.
# Only the starting possession and one approaching defender are staged.
# No manual placement, ball grants, direct _try_dribble or AI override
# is allowed after the clock starts. These are NOT 90-minute win rates.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI: Rect2 = Formation.ELEVEN_PITCH_RECT
const STEP := 1.0 / 60.0
const TICKS := 720
const RESULT_AFTER_FRAMES := 48
const SPECS := [
	{"seed": 67113, "difficulty": "normal", "opening": "cut", "side": -1.0, "approach": "late", "rival_offset": 148.0},
	{"seed": 67113, "difficulty": "normal", "opening": "cut", "side": -1.0, "approach": "early", "rival_offset": 225.0},
	{"seed": 67117, "difficulty": "normal", "opening": "feint", "side": 1.0, "approach": "late", "rival_offset": 148.0},
	{"seed": 67117, "difficulty": "normal", "opening": "feint", "side": 1.0, "approach": "early", "rival_offset": 225.0},
	{"seed": 67119, "difficulty": "hard", "opening": "cut", "side": 1.0, "approach": "late", "rival_offset": 148.0},
	{"seed": 67119, "difficulty": "hard", "opening": "cut", "side": 1.0, "approach": "early", "rival_offset": 225.0},
	{"seed": 67123, "difficulty": "hard", "opening": "feint", "side": -1.0, "approach": "late", "rival_offset": 148.0},
	{"seed": 67123, "difficulty": "hard", "opening": "feint", "side": -1.0, "approach": "early", "rival_offset": 225.0},
]
const KEYS := ["move_left", "move_right", "move_up", "move_down",
	"sprint", "tackle", "special_move", "change_player", "shoot_ball", "pass_ball"]


func _release_keys() -> void:
	for key in KEYS:
		Input.action_release(key)


func _hold(key: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(key)
	else:
		Input.action_release(key)


func _keyboard_move(direction: Vector2, press_e: bool, sprint: bool) -> void:
	_hold("move_right", direction.x > 0.28)
	_hold("move_left", direction.x < -0.28)
	_hold("move_down", direction.y > 0.28)
	_hold("move_up", direction.y < -0.28)
	_hold("tackle", press_e)
	_hold("sprint", sprint)


func _nearest_rival(game: Node2D, carrier: Footballer) -> Dictionary:
	var nearest: Footballer = null
	var distance := INF
	for rival: Footballer in game.teams[1]:
		if rival.sent_off or rival.role == "keeper":
			continue
		var current: float = carrier.global_position.distance_to(rival.global_position)
		if current < distance:
			distance = current
			nearest = rival
	return {"actor": nearest, "distance": distance}


func _outcome(game: Node2D, original: Footballer) -> String:
	if game.kickoff_active or game.goal_restart_active or game.set_piece_active:
		return "restart"
	if game.ball.carrier == original:
		return "retained"
	if game.ball.carrier == null:
		return "loose"
	return "teammate" if game.ball.carrier.team_id == 0 else "cpu_stolen"


func _play(spec: Dictionary) -> Dictionary:
	_release_keys()
	seed(int(spec["seed"]))
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game: Node2D = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
	game._set_quick_difficulty(String(spec["difficulty"]))
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	assert(game.match_pitch == XI and game.debug_team_counts() == [11, 11])
	var player: Footballer = game.teams[0][10]
	var opponent: Footballer = game.teams[1][5]
	var center: Vector2 = XI.get_center()
	# One realistic carrier and an oncoming defender near midfield.
	# The 20 other footballers remain in the real formation throughout.
	player.global_position = center + Vector2(-220.0, float(spec["side"]) * 95.0)
	player.velocity = Vector2.RIGHT * 170.0 if spec["opening"] == "cut" else Vector2.ZERO
	opponent.global_position = player.global_position + Vector2(float(spec["rival_offset"]), 18.0)
	opponent.velocity = Vector2.LEFT * 125.0
	game._select_player(player)
	game.ball.attach_to(player)
	assert(game.ball.carrier == player and player.can_dribble())
	var possession: Dictionary = {"human": 0, "cpu": 0, "loose": 0}
	var events: Array[Dictionary] = []
	var pending: Dictionary = {}
	var attempted := 0
	var accepted := 0
	var pressured_attempts := 0
	var real_cpu_tackles := 0
	var moving_frames := 0
	var next_e_tick := 110
	var prior_e := false
	var minimum_defender_distance := INF
	var max_advance: float = 0.0
	var origin: Vector2 = player.global_position
	for tick in range(TICKS):
		var playing: bool = not (
			game.kickoff_active or game.goal_restart_active or game.set_piece_active
		)
		var current: Footballer = game.controlled
		var holding: bool = game.ball.carrier == current and current.team_id == 0
		var nearest: Dictionary = _nearest_rival(game, current)
		var distance: float = float(nearest["distance"])
		var input_direction := Vector2.ZERO
		if holding:
			# Choose a plausible escape corridor using CURRENT defender
			# location only, not future engine moves or privileged outcomes.
			var side: float = -1.0 if (
				(nearest["actor"] as Footballer).global_position.y >= current.global_position.y
			) else 1.0
			input_direction = Vector2(1.0, side * 0.56).normalized()
		elif playing:
			var chase: Vector2 = game.ball.global_position - current.global_position
			if game.ball.carrier != null:
				chase = game.ball.carrier.global_position - current.global_position
			input_direction = chase.normalized() if chase.length() > 36.0 else Vector2.ZERO
		var press_e: bool = false
		var mode: String = ""
		if tick == 0:
			assert(holding and playing)
			press_e = true
			mode = String(spec["opening"])
			if mode == "feint":
				input_direction = Vector2.ZERO
		elif (
			playing and holding and pending.is_empty()
			and tick >= next_e_tick and tick <= TICKS - RESULT_AFTER_FRAMES
			and current.can_dribble()
			and distance < 190.0 and distance > 42.0 and not prior_e
		):
			press_e = true
			mode = "cut"
		if press_e:
			attempted += 1
			next_e_tick = tick + 110
			if distance <= 260.0:
				pressured_attempts += 1
		var before_tackles: Array[float] = []
		for rival: Footballer in game.teams[1]:
			before_tackles.append(rival.tackle_cooldown_seconds)
		_keyboard_move(input_direction if playing else Vector2.ZERO,
			press_e, not holding and playing and input_direction.length_squared() > 0.01)
		if input_direction.length_squared() > 0.01:
			moving_frames += 1
		game._physics_process(STEP)
		for team in game.teams:
			for actor: Footballer in team:
				actor._process(STEP)
		for rival_index in range(game.teams[1].size()):
			var rival: Footballer = game.teams[1][rival_index]
			if rival.tackle_cooldown_seconds > before_tackles[rival_index] + 0.20:
				real_cpu_tackles += 1
		if press_e:
			# Only count the gesture the real input pipeline actually started.
			assert(current.dribble_mode == mode and current.dribble_active(),
				"Bot pressed E but the game did not execute the requested XI gesture")
			accepted += 1
			assert(pending.is_empty())
			pending = {
				"tick": tick, "mode": mode,
				"nearest_rival_at_e": snappedf(distance, 0.1),
				"carrier": current, "lost_during_window": false,
				"first_loss": {},
			}
		if not pending.is_empty():
			var original: Footballer = pending["carrier"]
			if game.ball.carrier != original:
				pending["lost_during_window"] = true
				if (pending["first_loss"] as Dictionary).is_empty():
					var source: String = "other_ball_event"
					if game.pending_tackle_player != null:
						source = "clean_tackle_pending_claim"
					elif original.xi_collision_guard_seconds > 0.0:
						source = (
							"body_collision_fall" if original.xi_collision_down_seconds > 0.0
							else "body_collision_stumble"
						)
					elif original.contact_stun_seconds > 0.0:
						source = "tackle_or_contact_stun"
					var rivals_tackling := 0
					for rival: Footballer in game.teams[1]:
						if rival.tackle_active():
							rivals_tackling += 1
					var nearest_at_loss: Dictionary = _nearest_rival(game, original)
					pending["first_loss"] = {
						"frame": tick - int(pending["tick"]),
						"cause_hint": source,
						"nearest_rival": snappedf(float(nearest_at_loss["distance"]), 0.1),
						"active_cpu_tackles": rivals_tackling,
						"carrier_down": original.xi_collision_down_seconds > 0.0,
						"stun_seconds": snappedf(original.contact_stun_seconds, 0.01),
						"feedback": game.action_feedback_text,
					}
			if tick - int(pending["tick"]) + 1 >= RESULT_AFTER_FRAMES:
				var result: String = _outcome(game, original)
				events.append({
					"tick": int(pending["tick"]),
					"mode": String(pending["mode"]),
					"nearest_rival_at_e": pending["nearest_rival_at_e"],
					"outcome_at_0_8s": result,
					"lost_possession_at_any_point": bool(pending["lost_during_window"]),
					"first_loss": pending["first_loss"],
					"advance": snappedf(original.global_position.x - origin.x, 0.1),
				})
				pending.clear()
		if game.ball.carrier == null:
			possession["loose"] = int(possession["loose"]) + 1
		elif game.ball.carrier.team_id == 0:
			possession["human"] = int(possession["human"]) + 1
		else:
			possession["cpu"] = int(possession["cpu"]) + 1
		minimum_defender_distance = minf(minimum_defender_distance,
			float(_nearest_rival(game, player)["distance"]))
		max_advance = maxf(max_advance, player.global_position.x - origin.x)
		prior_e = press_e
		if tick % 120 == 0:
			assert(game.debug_team_counts() == [11, 11])
			assert(XI.grow(70.0).has_point(game.ball.global_position))
			assert(player.stamina >= 0.0 and player.stamina <= player.STAMINA_MAX)
		# Input edges must advance exactly as they do in the existing
		# browser-equivalent autoplay. Do not short-circuit to start_dribble.
		await process_frame
	_release_keys()
	assert(game.match_seconds >= TICKS * STEP - STEP)
	assert(attempted >= 1 and accepted == attempted)
	assert(pressured_attempts >= 1, "At least the kickoff E must face a live rival")
	assert(events.size() >= 1 and events.size() == accepted,
		"Every issued real E must have a complete 0.8s physical observation")
	assert(moving_frames > 240)
	assert(possession["human"] + possession["cpu"] + possession["loose"] == TICKS)
	var result: Dictionary = {
		"seed": int(spec["seed"]),
		"difficulty": String(spec["difficulty"]),
		"opening": String(spec["opening"]),
		"approach": String(spec["approach"]),
		"staged_rival_distance": float(spec["rival_offset"]),
		"ticks": TICKS,
		"e_pressed": attempted,
		"e_executed": accepted,
		"pressured_e": pressured_attempts,
		"cpu_tackles": real_cpu_tackles,
		"movement_frames": moving_frames,
		"possession_frames": possession,
		"min_defender_distance": snappedf(minimum_defender_distance, 0.1),
		"max_carrier_forward_gain": snappedf(max_advance, 0.1),
		"events": events,
	}
	root.remove_child(game)
	game.queue_free()
	await process_frame
	return result


func _initialize() -> void:
	var reports: Array[Dictionary] = []
	for spec in SPECS:
		reports.append(await _play(spec))
	var total_events := 0
	var real_tackles := 0
	var actual_outcomes: Dictionary = {"retained": 0, "loose": 0, "teammate": 0,
		"cpu_stolen": 0, "restart": 0}
	for report in reports:
		assert(report["e_pressed"] == report["e_executed"])
		total_events += int(report["e_executed"])
		real_tackles += int(report["cpu_tackles"])
		for event in report["events"]:
			var outcome: String = String(event["outcome_at_0_8s"])
			assert(actual_outcomes.has(outcome))
			actual_outcomes[outcome] = int(actual_outcomes[outcome]) + 1
	assert(reports.size() == 8 and total_events >= 8)
	assert(total_events == (
		int(actual_outcomes["retained"]) + int(actual_outcomes["loose"]) +
		int(actual_outcomes["teammate"]) + int(actual_outcomes["cpu_stolen"]) +
		int(actual_outcomes["restart"])
	))
	# First establish observed whole-XI gameplay baselines; do not invent
	# a pass-rate threshold from the separate isolated 1v1 fixture.
	var payload := {
		"kind": "seeded_real_input_xi_open_play_12s_windows_not_full_matches",
		"frames_per_trial": TICKS,
		"result_after_frames": RESULT_AFTER_FRAMES,
		"cases": reports,
		"outcomes": actual_outcomes,
		"e_events": total_events,
		"cpu_tackles": real_tackles,
	}
	print("FOOTBALL_XI_ATTACK_REGATE_INPUT " + JSON.stringify(payload))
	print("FOOTBALL_XI_ATTACK_REGATE_INPUT_OK cases=8 input=keyboard ai=full xi=22")
	quit(0)
