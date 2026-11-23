extends SceneTree

# Diagnostic-only 22-player pass-after-dribble scout. Both arms attempt the
# SAME real Space charge/release on the SAME match frame after E or no E;
# the intended receiver and input policy remain the same. A pass only counts
# after a real first touch by the intended teammate. No direct pass methods,
# possession gifts, physics overrides or scripted CPU mistakes during play.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI: Rect2 = Formation.ELEVEN_PITCH_RECT
const DT := 1.0 / 60.0
const FRAMES := 170
const CHARGE_FRAMES := 7
const PASS_STARTS := [8, 14, 20]
const DISTANCES := [148.0, 185.0]
const SIDES := [-1.0, 1.0]
const MODES := ["feint", "cut"]
const KEYS := ["move_left", "move_right", "move_up", "move_down",
	"sprint", "tackle", "special_move", "pass_ball", "shoot_ball", "change_player"]


func _keys_off() -> void:
	for key in KEYS:
		Input.action_release(key)


func _hold(key: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(key)
	else:
		Input.action_release(key)


func _input(direction: Vector2, do_e: bool, do_pass: bool) -> void:
	_hold("move_left", direction.x < -0.28)
	_hold("move_right", direction.x > 0.28)
	_hold("move_up", direction.y < -0.28)
	_hold("move_down", direction.y > 0.28)
	_hold("tackle", do_e)
	_hold("pass_ball", do_pass)


func _play(spec: Dictionary, use_e: bool) -> Dictionary:
	_keys_off()
	seed(int(spec["seed"]))
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game: Node2D = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	# Stop ALL native ticks before yielding: authoritative 1/60s below.
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
	var receiver: Footballer = game.teams[0][6]
	var presser: Footballer = game.teams[1][5]
	var side: float = float(spec["side"])
	var mode: String = String(spec["mode"])
	var start: Vector2 = XI.get_center() + Vector2(-220.0, side * 95.0)
	carrier.global_position = start
	carrier.velocity = Vector2.RIGHT * 170.0 if mode == "cut" else Vector2.ZERO
	# Deliberately stage ONLY the two players involved in the opening
	# pressure and a plausible XI passing outlet; the other 19 remain real.
	receiver.global_position = start + Vector2(275.0, -side * 185.0)
	receiver.velocity = Vector2.ZERO
	presser.global_position = start + Vector2(float(spec["distance"]), side * 18.0)
	presser.velocity = Vector2.LEFT * 125.0
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	assert(game.ball.carrier == carrier and carrier.can_dribble())
	var original_gap: float = carrier.global_position.distance_to(presser.global_position)
	var lane: Vector2 = Vector2(1.0, -side * 0.66).normalized()
	var pass_start: int = int(spec["pass_frame"])
	var e_executed := false
	var pass_charged := false
	var pass_released := false
	var pass_release_frame := -1
	var target_at_release := -1
	var released_power := 0.0
	var first_loss_before_pass := -1
	var first_touch_team := -1
	var first_touch_index := -1
	var first_touch_frame := -1
	var cpu_tackles := 0
	var was_pass_held := false
	var ever_restart := false
	for tick in range(FRAMES):
		var still_ours: bool = game.ball.carrier == carrier
		var before_possession: Footballer = game.ball.carrier
		var before_charging: bool = game.pass_charging
		var intended_aim: Vector2 = (receiver.global_position - carrier.global_position).normalized()
		var movement: Vector2 = Vector2.ZERO
		var do_e: bool = use_e and tick == 0 and still_ours
		var pass_held: bool = (
			still_ours and tick >= pass_start
			and tick < pass_start + CHARGE_FRAMES
		)
		if still_ours and not pass_released:
			if tick == 0 and mode == "feint":
				# Both E and control must have the same stationary first beat.
				movement = Vector2.ZERO
			elif tick >= pass_start:
				# Same human intention for both arms: aim Space at a real XI
				# teammate, not the carrier's movement vector or CPU data.
				movement = intended_aim
			else:
				movement = lane
		var before_cooldowns: Array[float] = []
		for rival: Footballer in game.teams[1]:
			before_cooldowns.append(rival.tackle_cooldown_seconds)
		_input(movement, do_e, pass_held)
		game._physics_process(DT)
		for team in game.teams:
			for actor: Footballer in team:
				actor._process(DT)
		for rival_index in range(game.teams[1].size()):
			var rival: Footballer = game.teams[1][rival_index]
			if rival.tackle_cooldown_seconds > before_cooldowns[rival_index] + 0.20:
				cpu_tackles += 1
		if do_e:
			assert(carrier.dribble_active() and carrier.dribble_mode == mode,
				"Space/E scout must launch the actual XI cut or feint")
			e_executed = true
		if pass_held and game.pass_charging:
			pass_charged = true
		# The desktop pass is released ONLY through Input.action_release;
		# count it only if the actual game produced a real pass ball.
		if (
			was_pass_held and not pass_held and before_charging
			and before_possession == carrier and game.ball.carrier == null
			and game.action_feedback_text in ["PASE", "PASE ATRÁS"]
		):
			pass_released = true
			pass_release_frame = tick
			target_at_release = (
				game.xi_one_two_receiver.squad_index
				if game.xi_one_two_receiver != null else -1
			)
			released_power = snappedf(game.ball.velocity.length(), 0.1)
			assert(released_power >= game.PASS_MIN_POWER * 0.8)
		was_pass_held = pass_held
		if not pass_released and first_loss_before_pass < 0 and game.ball.carrier != carrier:
			first_loss_before_pass = tick
		if pass_released and first_touch_team < 0 and game.ball.carrier != null:
			first_touch_team = game.ball.carrier.team_id
			first_touch_index = game.ball.carrier.squad_index
			first_touch_frame = tick
		if game.kickoff_active or game.goal_restart_active or game.set_piece_active:
			ever_restart = true
		if tick % 24 == 0:
			assert(game.debug_team_counts() == [11, 11])
			assert(carrier.stamina >= 0.0 and carrier.stamina <= carrier.STAMINA_MAX)
		await process_frame
	_keys_off()
	# A pass into an untouched empty lane is NOT successful. A recovery
	# after an earlier steal is NOT an earned E-to-pass combination.
	var clean_pass: bool = (
		pass_released and first_loss_before_pass == -1
		and first_touch_team == 0 and first_touch_index == receiver.squad_index
		and not ever_restart
	)
	var result: Dictionary = {
		"seed": int(spec["seed"]),
		"mode": mode,
		"side": "upper" if side < 0.0 else "lower",
		"distance": float(spec["distance"]),
		"pass_start_frame": pass_start,
		"variant": "e" if use_e else "run_without_e",
		"e_executed": e_executed,
		"start_rival_distance": snappedf(original_gap, 0.1),
		"pass_charge_started": pass_charged,
		"pass_released": pass_released,
		"pass_release_frame": pass_release_frame,
		"target_at_release": target_at_release,
		"released_power": released_power,
		"first_loss_before_pass": first_loss_before_pass,
		"first_touch_team": first_touch_team,
		"first_touch_index": first_touch_index,
		"first_touch_frame": first_touch_frame,
		"intended_receiver_index": receiver.squad_index,
		"clean_intended_pass": clean_pass,
		"cpu_tackles": cpu_tackles,
		"had_restart": ever_restart,
	}
	root.remove_child(game)
	game.queue_free()
	await process_frame
	return result


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for mode in MODES:
		for distance in DISTANCES:
			for side in SIDES:
				for pass_frame in PASS_STARTS:
					var spec: Dictionary = {
						"seed": 69219 if mode == "feint" else 69223,
						"mode": mode,
						"distance": distance,
						"side": side,
						"pass_frame": pass_frame,
					}
					var e: Dictionary = await _play(spec, true)
					var no_e: Dictionary = await _play(spec, false)
					assert(e["variant"] == "e" and no_e["variant"] == "run_without_e")
					assert(is_equal_approx(
						float(e["start_rival_distance"]),
						float(no_e["start_rival_distance"])
					), "Paired XI sequence must start against the same pressure")
					rows.append(e)
					rows.append(no_e)
					if rows.size() % 12 == 0:
						print("FOOTBALL_XI_E_PASS_PROGRESS arms=%d/48" % rows.size())
	assert(rows.size() == 48)
	print("FOOTBALL_XI_E_PASS_SCOUT " + JSON.stringify({
		"kind": "paired_real_xi_22_player_e_or_run_then_actual_space_pass_not_human_win_rate",
		"arms": rows.size(),
		"pairs": rows.size() / 2,
		"pass_start_frames": PASS_STARTS,
		"charge_frames": CHARGE_FRAMES,
		"simulation_frames": FRAMES,
		"rows": rows,
	}))
	print("FOOTBALL_XI_E_PASS_SCOUT_OK pairs=24 arms=48 real_space=true")
	quit(0)
