extends SceneTree

# Real XI keyboard ownership after E: an UNAVAILABLE dribble must never
# silently consume the player's valid held Space pass. A successfully
# started E must still override Space. Pass recipient text reflects the
# current real aim, not a simulated or auto-completed pass.
const DT := 1.0 / 60.0
const KEYS := ["move_left", "move_right", "move_up", "move_down",
	"sprint", "tackle", "special_move", "pass_ball", "shoot_ball", "change_player"]


func _release_all() -> void:
	for key in KEYS:
		Input.action_release(key)


func _initialize() -> void:
	_release_all()
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
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	var start: Vector2 = game.match_pitch.get_center() + Vector2(-300.0, 0.0)
	for team in game.teams:
		for actor: Footballer in team:
			actor.velocity = Vector2.ZERO
			actor.global_position = game.match_pitch.position + Vector2(
				80.0 + actor.team_id * 3600.0,
				90.0 + actor.squad_index * 180.0
			)
	var passer: Footballer = game.teams[0][10]
	var receiver: Footballer = game.teams[0][6]
	passer.global_position = start
	receiver.global_position = start + Vector2(290.0, 0.0)
	game._select_player(passer)
	game.ball.attach_to(passer)
	assert(game.debug_team_counts() == [11, 11])
	assert(game.contextual_help_text(false).contains("E quieto"))

	# Real Space key edge followed by E during an unavailable-dribble
	# cooldown. No test-only call to _begin_directional_pass_charge.
	passer.dribble_cooldown_seconds = 0.50
	Input.action_press("move_right")
	Input.action_press("pass_ball")
	game._handle_human(DT)
	assert(game.pass_charging and game.pass_directional_charge)
	assert(game.pass_target == receiver)
	assert(game.desktop_pass_input_active)
	game._refresh_hud()
	var label_name: String = receiver.scouting_player_name.strip_edges().left(18)
	assert(not label_name.is_empty())
	assert(game.shot_meter_label.text.contains(label_name))
	assert(game.shot_meter_label.text.contains("PASE CORTO"))
	assert(game.contextual_help_text(false).contains("suelta Space"))
	var prior_charge: float = game.pass_charge_seconds
	await process_frame
	Input.action_press("tackle")
	game._handle_human(DT)
	assert(not passer.dribble_active(), "E with cooldown must not launch XI dribble")
	assert(game.pass_charging and game.pass_target == receiver,
		"Rejected E must preserve the intended Space pass")
	assert(game.pass_charge_seconds > prior_charge)
	assert(game.shot_charging == false)
	Input.action_release("tackle")
	await process_frame
	Input.action_release("pass_ball")
	game._handle_human(DT)
	assert(not game.pass_charging and not game.desktop_pass_input_active)
	assert(game.ball.carrier == null,
		"Releasing original held Space must still kick the real ball")
	assert(game.ball.velocity.length() > 400.0)
	assert(game.pending_human_pass_receiver == receiver)

	# A *successful* E press is a conscious alternative to Space. It
	# cancels the charge but never fabricates a pass or catches the ball.
	_release_all()
	await process_frame
	game.ball.attach_to(passer)
	passer.velocity = Vector2.ZERO
	passer.dribble_cooldown_seconds = 0.0
	passer.dribble_burst_seconds = 0.0
	passer.action_lock_seconds = 0.0
	passer.contact_stun_seconds = 0.0
	passer.xi_collision_down_seconds = 0.0
	game._select_player(passer)
	assert(passer.can_dribble())
	Input.action_press("pass_ball")
	game._handle_human(DT)
	assert(game.pass_charging)
	await process_frame
	Input.action_press("tackle")
	game._handle_human(DT)
	assert(passer.dribble_active() and passer.dribble_mode == "feint")
	assert(not game.pass_charging,
		"Accepted XI E must retain explicit priority over Space")
	assert(game.contextual_help_text(false).contains("orienta la salida"))
	Input.action_release("tackle")
	await process_frame
	Input.action_release("pass_ball")
	game._handle_human(DT)
	assert(game.ball.carrier == passer,
		"Releasing Space after a successful E must not kick a ghost pass")
	assert(not game.pass_charging)

	# Once targeting is no longer deliberate, the cue must not invent
	# a named receiver. 5v5 keeps the historical bare meter name.
	passer.dribble_burst_seconds = 0.0
	passer.dribble_cooldown_seconds = 0.0
	passer.action_lock_seconds = 0.0
	passer.contact_stun_seconds = 0.0
	game._cancel_pass_charge()
	game.pass_charging = true
	game.pass_directional_charge = true
	game.pass_target = null
	game._refresh_hud()
	assert(game.shot_meter_label.text.contains("LIBRE"))
	game.match_team_size = 5
	game._refresh_hud()
	assert(game.shot_meter_label.text == game._pass_profile_name(game._pass_charge_ratio()))
	_release_all()
	print("FOOTBALL_XI_E_PASS_CHARGE_INPUT_OK rejected_e_keeps_space=true real_release=true accepted_e_cancels=true live_target=true free_lane=true legacy_5v5=true")
	quit(0)
