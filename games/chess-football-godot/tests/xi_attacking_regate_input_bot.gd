extends SceneTree

# Attack-side companion to eleven_autoplay_player_bot.gd. Eight PAIRS of
# real 12-second 22-player open-play windows: same initial seed and defender,
# one E action arm versus a directional-movement-only control arm.
# The E arm presses the SAME XI E/movement keys
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
	var use_e: bool = bool(spec["use_e"])
	_release_keys()
	seed(int(spec["seed"]))
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game: Node2D = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	# _ready() has completed synchronously after add_child. Stop native
	# match/player ticks BEFORE yielding the two initialization frames:
	# otherwise startup may contain unaccounted physics/AI updates that
	# depend on the runner timing, despite the later seeded 1/60s loop.
	game.set_process(false)
	game.set_physics_process(false)
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
			actor.set_physics_process(false)
	await process_frame
	await process_frame
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
	var start_stamina: float = player.stamina
	var initial_rival_distance: float = float(_nearest_rival(game, player)["distance"])
	var opening_outcome: String = ""
	var opening_loss_frame: int = -1
	var opening_loss_cause: String = ""
	var opening_forward_gain: float = 0.0
	var opening_lateral_gain: float = 0.0
	var opening_stamina_spent: float = 0.0
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
			# The control arm preserves the first-frame feint pause, then
			# follows the SAME live directional policy but never presses E.
			press_e = use_e
			mode = String(spec["opening"])
			if mode == "feint":
				input_direction = Vector2.ZERO
		elif (
			use_e and playing and holding and pending.is_empty()
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
					var active_tacklers: Array[Dictionary] = []
					# At the first real loss, identify the physical launching
					# defender. Hard can challenge with BOTH primary + cover;
					# a first-presser-only fake may be irrelevant if cover
					# executes the decisive tackle. Read current role caches,
					# never call a role selector that could mutate the AI.
					var primary: Footballer = game.ai_primary_presser_cache[1]
					var cover: Footballer = game.ai_secondary_presser_cache[1]
					for rival: Footballer in game.teams[1]:
						if rival.tackle_active():
							rivals_tackling += 1
							active_tacklers.append({
								"index": rival.squad_index,
								"assignment": (
									"primary" if rival == primary
									else "cover" if rival == cover
									else "other"
								),
								"distance_to_ball": snappedf(
									rival.global_position.distance_to(game.ball.global_position), 0.1
								),
								"clean_ball_hitbox": bool(game._tackle_hitbox(
									rival, game.ball.global_position
								)["clean"]),
							})
					var nearest_at_loss: Dictionary = _nearest_rival(game, original)
					pending["first_loss"] = {
						"frame": tick - int(pending["tick"]),
						"cause_hint": source,
						"nearest_rival": snappedf(float(nearest_at_loss["distance"]), 0.1),
						"active_cpu_tackles": rivals_tackling,
						"active_tacklers": active_tacklers,
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
		if tick < RESULT_AFTER_FRAMES:
			if game.ball.carrier != player and opening_loss_frame < 0:
				opening_loss_frame = tick
				opening_loss_cause = (
					"clean_tackle_pending_claim" if game.pending_tackle_player != null
					else "body_contact" if player.xi_collision_guard_seconds > 0.0
					else "tackle_or_contact_stun" if player.contact_stun_seconds > 0.0
					else "other_ball_event"
				)
			if tick + 1 == RESULT_AFTER_FRAMES:
				opening_outcome = _outcome(game, player)
				opening_forward_gain = snappedf(player.global_position.x - origin.x, 0.1)
				opening_lateral_gain = snappedf(absf(player.global_position.y - origin.y), 0.1)
				opening_stamina_spent = snappedf(start_stamina - player.stamina, 0.1)
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
	if use_e:
		assert(attempted >= 1 and accepted == attempted)
		assert(pressured_attempts >= 1, "The opening E must face a live rival")
		assert(events.size() >= 1 and events.size() == accepted,
			"Every issued real E must have a complete 0.8s physical observation")
	else:
		assert(attempted == 0 and accepted == 0 and pressured_attempts == 0,
			"No-E control must never press a dribble key")
		assert(events.is_empty(), "No-E control must not invent regate outcomes")
	assert(opening_outcome in ["retained", "loose", "cpu_stolen", "teammate", "restart"],
		"Each pair arm needs a real 48-frame opening ball outcome")
	assert(moving_frames > 240)
	assert(possession["human"] + possession["cpu"] + possession["loose"] == TICKS)
	var result: Dictionary = {
		"seed": int(spec["seed"]),
		"variant": "e" if use_e else "run_without_e",
		"opening_outcome": opening_outcome,
		"opening_first_loss_frame": opening_loss_frame,
		"opening_first_loss_cause_hint": opening_loss_cause,
		"opening_forward_gain": opening_forward_gain,
		"opening_lateral_gain": opening_lateral_gain,
		"opening_stamina_spent": opening_stamina_spent,
		"nearest_rival_at_start": snappedf(initial_rival_distance, 0.1),
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
		# Re-seed/re-create the complete scene for both arms. Start state
		# is matched, but later AI decisions can diverge naturally.
		for use_e in [true, false]:
			var paired_spec: Dictionary = spec.duplicate()
			paired_spec["use_e"] = use_e
			reports.append(await _play(paired_spec))
	var total_events := 0
	var real_tackles := 0
	var actual_outcomes: Dictionary = {"retained": 0, "loose": 0, "teammate": 0,
		"cpu_stolen": 0, "restart": 0}
	for report in reports:
		assert(report["e_pressed"] == report["e_executed"])
		assert(bool(report["variant"] == "e") == bool(report["e_pressed"] >= 1))
		total_events += int(report["e_executed"])
		real_tackles += int(report["cpu_tackles"])
		for event in report["events"]:
			var outcome: String = String(event["outcome_at_0_8s"])
			assert(actual_outcomes.has(outcome))
			actual_outcomes[outcome] = int(actual_outcomes[outcome]) + 1
	assert(reports.size() == 16 and total_events >= 8)
	assert(total_events == (
		int(actual_outcomes["retained"]) + int(actual_outcomes["loose"]) +
		int(actual_outcomes["teammate"]) + int(actual_outcomes["cpu_stolen"]) +
		int(actual_outcomes["restart"])
	))
	# Compare ONLY a matched starting state. A live 22-player run can
	# diverge after the first step, so this measures real consequences,
	# not a guaranteed counterfactual or a fixed success percentage.
	var pairs: Array[Dictionary] = []
	for i in range(0, reports.size(), 2):
		var e: Dictionary = reports[i]
		var control: Dictionary = reports[i + 1]
		assert(e["variant"] == "e" and control["variant"] == "run_without_e")
		assert(e["seed"] == control["seed"]
			and e["difficulty"] == control["difficulty"]
			and e["opening"] == control["opening"]
			and e["approach"] == control["approach"])
		assert(absf(float(e["nearest_rival_at_start"]) -
			float(control["nearest_rival_at_start"])) < 1.0,
			"Paired trials must begin under the same physical pressure")
		pairs.append({
			"seed": e["seed"],
			"difficulty": e["difficulty"],
			"opening": e["opening"],
			"approach": e["approach"],
			"e_outcome": e["opening_outcome"],
			"run_outcome": control["opening_outcome"],
			"e_first_loss_frame": e["opening_first_loss_frame"],
			"run_first_loss_frame": control["opening_first_loss_frame"],
			"e_forward_gain": e["opening_forward_gain"],
			"run_forward_gain": control["opening_forward_gain"],
			"e_lateral_gain": e["opening_lateral_gain"],
			"run_lateral_gain": control["opening_lateral_gain"],
			"e_stamina_spent": e["opening_stamina_spent"],
			"run_stamina_spent": control["opening_stamina_spent"],
		})
	assert(pairs.size() == 8)
	# A repeat AFTER 16 other runs checks how much the complete, seeded
	# match startup/AI drifts over time. Hard/cut/early previously flipped
	# its 48-frame outcome across CI runs despite no cut-rule changes.
	# Report discrepancies rather than hiding them or claiming bitwise
	# determinism where the engine has not yet established it.
	var replay_audit: Array[Dictionary] = []
	for use_e in [true, false]:
		var spec: Dictionary = SPECS[5].duplicate()
		spec["use_e"] = use_e
		var repeat: Dictionary = await _play(spec)
		var original: Dictionary = reports[10 + (0 if use_e else 1)]
		assert(original["seed"] == repeat["seed"]
			and original["variant"] == repeat["variant"]
			and absf(float(original["nearest_rival_at_start"])
				- float(repeat["nearest_rival_at_start"])) < 1.0)
		var mismatched: Array[String] = []
		var fields: Array[String] = [
			"opening_outcome", "opening_first_loss_frame",
			"opening_first_loss_cause_hint", "opening_forward_gain",
			"opening_lateral_gain", "opening_stamina_spent",
			"cpu_tackles", "possession_frames", "e_executed",
		]
		for field in fields:
			if original[field] != repeat[field]:
				mismatched.append(field)
		replay_audit.append({
			"seed": repeat["seed"],
			"variant": repeat["variant"],
			"difficulty": repeat["difficulty"],
			"opening": repeat["opening"],
			"approach": repeat["approach"],
			"identical": mismatched.is_empty(),
			"mismatched_fields": mismatched,
			"first_outcome": original["opening_outcome"],
			"repeat_outcome": repeat["opening_outcome"],
			"first_loss_frame": original["opening_first_loss_frame"],
			"repeat_loss_frame": repeat["opening_first_loss_frame"],
			"opening_forward_drift": snappedf(
				absf(float(original["opening_forward_gain"]) -
					float(repeat["opening_forward_gain"])), 0.1
			),
		})
	assert(replay_audit.size() == 2)
	print("FOOTBALL_XI_ATTACK_REPLAY_AUDIT " + JSON.stringify(replay_audit))
	# Baseline only: the isolated #208 matrix has robust floors; the
	# live full XI A/B bot currently reports, it does not fake a pass rate.
	var payload := {
		"kind": "seeded_paired_real_input_xi_open_play_12s_not_full_matches",
		"frames_per_trial": TICKS,
		"result_after_frames": RESULT_AFTER_FRAMES,
		"cases": reports,
		"pairs": pairs,
		"replay_audit": replay_audit,
		"outcomes": actual_outcomes,
		"e_events": total_events,
		"cpu_tackles": real_tackles,
	}
	print("FOOTBALL_XI_ATTACK_REGATE_INPUT " + JSON.stringify(payload))
	print("FOOTBALL_XI_ATTACK_REGATE_INPUT_OK cases=16 pairs=8 input=keyboard ai=full xi=22")
	quit(0)
