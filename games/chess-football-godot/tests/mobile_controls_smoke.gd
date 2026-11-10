extends SceneTree

func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var match_node = packed.instantiate()
	root.add_child(match_node)

	for _frame in range(6):
		await process_frame
		await physics_frame

	var controls = match_node.get_node_or_null("MobileControls")
	assert(controls != null)
	controls.debug_force_controls_visible(true)
	await process_frame
	assert(controls.debug_controls_visible())
	assert(controls.debug_fixed_action_count() == 0)
	assert(not controls.debug_joystick_visible())
	# Historical 5v5 help remains unchanged, independently of XI cues.
	assert(match_node.contextual_help_text().begins_with("WASD/Flechas"))

	match_node.debug_prepare_kickoff(0)
	match_node.debug_force_kickoff_ready()
	match_node.controlled._process(2.0)
	match_node.debug_sync_presentation()

	# Floating joystick appears under the left thumb and auto-sprints near the rim.
	var joystick_start := Vector2(132.0, 600.0)
	assert(controls.debug_touch_down(11, joystick_start))
	assert(controls.debug_joystick_visible())
	assert(controls.debug_joystick_origin().distance_to(joystick_start) < 4.0)
	controls.debug_touch_move(11, joystick_start + Vector2(68.0, 0.0))
	assert(Input.get_action_strength("move_right") > 0.80)
	assert(Input.is_action_pressed("sprint"))
	var before: Vector2 = match_node.controlled.global_position
	match_node._handle_human(0.12)
	assert(match_node.controlled.global_position.x > before.x)
	controls.debug_touch_up(11, joystick_start + Vector2(68.0, 0.0))
	assert(not controls.debug_joystick_visible())
	assert(Input.get_action_strength("move_right") < 0.01)
	assert(not Input.is_action_pressed("sprint"))

	# Quick tap, then press-and-hold in the joystick zone arms sprint without
	# needing to shove the stick to the rim. Stamina still limits the sprint.
	var mobile_runner: Footballer = match_node.controlled
	mobile_runner.debug_set_stamina(100.0)
	assert(controls.debug_touch_down(12, joystick_start))
	assert(controls.debug_touch_up(12, joystick_start))
	assert(controls.debug_touch_down(13, joystick_start + Vector2(3.0, 2.0)))
	assert(controls.debug_sprint_latched())
	assert(Input.is_action_pressed("sprint"))
	controls.debug_touch_move(13, joystick_start + Vector2(34.0, 0.0))
	var mobile_stamina_before: float = mobile_runner.debug_stamina_ratio()
	match_node._handle_human(0.45)
	assert(mobile_runner.debug_stamina_ratio() < mobile_stamina_before)
	controls.debug_touch_up(13, joystick_start + Vector2(34.0, 0.0))
	assert(not Input.is_action_pressed("sprint"))
	mobile_runner.debug_set_stamina(100.0)

	# With possession, a tap on open grass on the right half is a contextual
	# dribble. No extra button: teammate/pass, rival/tackle and goal/shot keep
	# their existing meanings.
	var mobile_dribbler: Footballer = match_node.teams[0][3]
	match_node._select_player(mobile_dribbler)
	mobile_dribbler.global_position = ChessFootballMath.PITCH_RECT.get_center()
	mobile_dribbler.velocity = Vector2.ZERO
	for teammate in match_node.teams[0]:
		if teammate != mobile_dribbler:
			teammate.global_position = Vector2(
				ChessFootballMath.PITCH_RECT.position.x + 180.0,
				ChessFootballMath.PITCH_RECT.position.y + 180.0 + teammate.squad_index * 90.0,
			)
	for opponent in match_node.teams[1]:
		opponent.global_position = Vector2(
			ChessFootballMath.PITCH_RECT.end.x - 180.0,
			ChessFootballMath.PITCH_RECT.end.y - 180.0 - opponent.squad_index * 90.0,
		)
	match_node.ball.attach_to(mobile_dribbler)
	match_node.debug_focus_presentation()
	var dribble_world_target := mobile_dribbler.global_position + Vector2(180.0, -120.0)
	var dribble_screen_target: Vector2 = match_node.presentation_3d.screen_position_for_world(
		dribble_world_target,
		0.0,
	)
	assert(dribble_screen_target.x > 1280.0 * 0.48)
	assert(match_node.mobile_touch_target(dribble_screen_target).is_empty())
	var mobile_dribble_before := mobile_dribbler.global_position
	assert(controls.debug_touch_down(14, dribble_screen_target))
	assert(mobile_dribbler.debug_dribble_active())
	mobile_dribbler._process(0.10)
	mobile_dribbler.move_human(0.10, Vector2.ZERO, false)
	match_node.ball.tick_ball(0.0)
	assert(mobile_dribbler.velocity.x > mobile_dribbler.base_speed)
	assert(mobile_dribbler.velocity.y < -mobile_dribbler.base_speed * 0.45)
	assert(mobile_dribbler.global_position.x > mobile_dribble_before.x)
	assert(mobile_dribbler.global_position.y < mobile_dribble_before.y)
	assert(match_node.ball.carrier == mobile_dribbler)
	assert(match_node.ball.global_position.distance_to(mobile_dribbler.global_position) > 28.0)
	assert(controls.debug_touch_up(14, dribble_screen_target))
	mobile_dribbler._process(0.70)

	# A quick teammate tap is still useful, but holding charges the same visible
	# power meter used by shots and produces a materially stronger pass.
	var passer: Footballer = match_node.teams[0][2]
	var receiver: Footballer = match_node.teams[0][3]
	match_node._select_player(passer)
	match_node.ball.attach_to(passer)
	match_node.debug_sync_presentation()
	var receiver_screen: Vector2 = match_node.mobile_player_screen_position(receiver)
	assert(receiver_screen.x >= 0.0)
	assert(controls.debug_touch_down(20, receiver_screen))
	assert(match_node.debug_pass_charge_ratio() == 0.0)
	assert(controls.debug_touch_up(20, receiver_screen))
	var quick_pass_speed: float = match_node.ball.velocity.length()
	assert(quick_pass_speed >= 550.0)
	assert(match_node.ball.carrier == null)
	assert(match_node.controlled == receiver)
	assert(match_node.ball.velocity.dot(receiver.global_position - passer.global_position) > 0.0)

	passer._process(2.0)
	receiver._process(2.0)
	match_node._select_player(passer)
	match_node.ball.attach_to(passer)
	match_node.debug_sync_presentation()
	receiver_screen = match_node.mobile_player_screen_position(receiver)
	assert(controls.debug_touch_down(24, receiver_screen))
	match_node._handle_human(0.70)
	assert(match_node.debug_pass_charge_ratio() > 0.70)
	match_node.debug_refresh_hud()
	assert(match_node.shot_meter.visible)
	assert(match_node.shot_meter_label.text == "PASE LARGO")
	assert(controls.debug_touch_up(24, receiver_screen))
	var charged_pass_speed: float = match_node.ball.velocity.length()
	assert(charged_pass_speed > quick_pass_speed * 1.45)
	assert(match_node.controlled == receiver)
	assert(not match_node.shot_meter.visible or not match_node.pass_charging)

	# Without possession, tapping a teammate simply selects them.
	match_node.ball.attach_to(match_node.teams[1][3])
	match_node.debug_sync_presentation()
	var defender: Footballer = match_node.teams[0][1]
	var defender_screen: Vector2 = match_node.mobile_player_screen_position(defender)
	assert(controls.debug_touch_down(21, defender_screen))
	assert(controls.debug_touch_up(21, defender_screen))
	assert(match_node.controlled == defender)

	# Tap the rival ball-carrier: choose the best nearby defender and attempt a tackle.
	var victim: Footballer = match_node.teams[1][2]
	var tackler: Footballer = match_node.teams[0][1]
	tackler._process(2.0)
	tackler.global_position = Vector2(640.0, 520.0)
	tackler.velocity = Vector2.RIGHT * tackler.base_speed
	victim.global_position = Vector2(690.0, 520.0)
	match_node.ball.attach_to(victim)
	match_node._select_player(tackler)
	match_node.debug_sync_presentation()
	var victim_screen: Vector2 = match_node.mobile_player_screen_position(victim)
	assert(controls.debug_touch_down(22, victim_screen))
	assert(controls.debug_touch_up(22, victim_screen))
	assert(match_node.ball.carrier == null or match_node.debug_set_piece_active())

	# Touch/hold the attacking goal: charge and release a real shot.
	match_node.debug_force_set_piece_ready()
	var shooter: Footballer = match_node.teams[0][4]
	shooter._process(2.0)
	shooter.global_position = Vector2(
		ChessFootballMath.PITCH_RECT.end.x - 480.0,
		ChessFootballMath.PITCH_RECT.get_center().y,
	)
	match_node._select_player(shooter)
	match_node.ball.attach_to(shooter)
	match_node.debug_sync_presentation()
	var goal_screen: Vector2 = match_node.mobile_attack_goal_screen_position()
	assert(goal_screen.x >= 0.0)
	assert(controls.debug_touch_down(23, goal_screen))
	match_node._handle_human(0.42)
	assert(match_node.debug_shot_charge_ratio() > 0.35)
	controls.debug_touch_move(23, goal_screen + Vector2(0.0, -70.0))
	assert(controls.debug_touch_up(23, goal_screen + Vector2(0.0, -70.0)))
	assert(match_node.ball.carrier == null)
	assert(match_node.ball.velocity.x > 0.0)

	# Rival penalty still uses the same floating joystick for keeper movement.
	match_node.debug_prepare_penalty(1)
	var keeper_y_before: float = match_node.teams[0][0].global_position.y
	assert(controls.debug_touch_down(30, joystick_start))
	controls.debug_touch_move(30, joystick_start + Vector2(0.0, -64.0))
	match_node._update_set_piece(0.16)
	assert(match_node.teams[0][0].global_position.y < keeper_y_before)
	controls.debug_touch_up(30, joystick_start + Vector2(0.0, -64.0))

	controls.debug_force_controls_visible(false)
	assert(not controls.debug_controls_visible())
	match_node.queue_free()
	await process_frame

	# XI uses exactly the same mobile controls. Exercise the *real* 22-player
	# scene and full pitch, not a five-player mock, before public activation.
	var xi = packed.instantiate()
	xi.match_team_size = 11
	root.add_child(xi)
	for _frame in range(6):
		await process_frame
		await physics_frame
	xi.set_physics_process(false)
	assert(xi.debug_team_counts() == [11, 11])
	assert(xi.match_pitch.size == Vector2(4000.0, 2600.0))
	xi.debug_prepare_kickoff(0)
	xi.debug_force_kickoff_ready()
	# The active XI guide teaches the CURRENT situation instead of a
	# single instruction wall. Both keyboard and touch derive from the
	# same ball carrier; neither modifies that carrier or match state.
	xi.ball.attach_to(xi.controlled)
	xi.debug_refresh_hud()
	assert(xi.help_label.text.begins_with("ATACAS"))
	assert(xi.contextual_help_text(true).begins_with("ATACAS"))
	xi.ball.attach_to(xi.teams[1][10])
	xi.debug_refresh_hud()
	assert(xi.help_label.text.begins_with("DEFIENDES"))
	assert(xi.contextual_help_text(true).begins_with("DEFIENDES"))
	xi.ball.release(Vector2.RIGHT, 180.0)
	xi.debug_refresh_hud()
	assert(xi.help_label.text.begins_with("BALÓN SUELTO"))
	assert(xi.contextual_help_text(true).begins_with("BALÓN SUELTO"))
	xi.camera_mode = "tactical"
	xi.presentation_3d.sync_presentation(2.0, "tactical")
	var xi_touch = xi.get_node_or_null("MobileControls")
	assert(xi_touch != null)
	xi_touch.debug_force_controls_visible(true)
	assert(xi_touch.debug_controls_visible())
	var xi_before: Vector2 = xi.controlled.global_position
	assert(xi_touch.debug_touch_down(41, joystick_start))
	assert(xi_touch.debug_touch_move(41, joystick_start + Vector2(68.0, 0.0)))
	assert(Input.get_action_strength("move_right") > 0.80)
	xi._handle_human(0.12)
	assert(xi.controlled.global_position.x > xi_before.x)
	assert(xi_touch.debug_touch_up(41, joystick_start + Vector2(68.0, 0.0)))
	assert(Input.get_action_strength("move_right") < 0.01)

	# With no human possession, tapping one of ten outfield teammates
	# selects precisely that player, even on the wider tactical XI camera.
	xi.ball.attach_to(xi.teams[1][10])
	var xi_defender: Footballer = xi.teams[0][1]
	var xi_defender_screen: Vector2 = xi.mobile_player_screen_position(xi_defender)
	assert(xi_defender_screen.x > 0.0 and xi_defender_screen.x < 1280.0)
	assert(xi_touch.debug_touch_down(42, xi_defender_screen))
	assert(xi_touch.debug_touch_up(42, xi_defender_screen))
	assert(xi.controlled == xi_defender)

	# Real contextual teammate pass still hands off to the selected receiver.
	var xi_passer: Footballer = xi.teams[0][10]
	xi._select_player(xi_passer)
	xi.ball.attach_to(xi_passer)
	var xi_receiver_screen: Vector2 = xi.mobile_player_screen_position(xi_defender)
	assert(xi.mobile_touch_target(xi_receiver_screen).get("player") == xi_defender)
	assert(xi_touch.debug_touch_down(43, xi_receiver_screen))
	assert(xi_touch.debug_touch_up(43, xi_receiver_screen))
	assert(xi.ball.carrier == null and xi.controlled == xi_defender)
	xi.debug_refresh_hud()
	assert(xi.view_label.text == "PASE")
	assert(xi.action_feedback_seconds > 0.0)
	# An actual charged human shot produces a different receipt, using the
	# existing view label; neither text nor countdown manipulates the ball.
	xi.ball.attach_to(xi_defender)
	xi._begin_shot_charge(0.0)
	xi._release_charged_shot()
	xi.debug_refresh_hud()
	assert(xi.ball.carrier == null and xi.ball.last_release_was_shot)
	assert(xi.view_label.text == "TIRO")
	assert(xi.mobile_activate_teammate(xi_passer))
	xi.debug_refresh_hud()
	assert(xi.view_label.text == "CAMBIO DE JUGADOR")
	xi.action_feedback_seconds = 0.0
	xi.debug_refresh_hud()
	assert(xi.view_label.text != "CAMBIO DE JUGADOR")

	# A rival carrying the ball has a 1.24x magnet. Its former search
	# cutoff of 76px cancelled the promised 94px reach. Move other actors
	# away so this tests the *actual* 85px tap instead of an overlap.
	var xi_carrier: Footballer = xi.teams[1][10]
	var displaced := 0
	for team in xi.teams:
		for player: Footballer in team:
			if player != xi_carrier:
				player.global_position = xi.match_pitch.position + Vector2(
					160.0 + displaced * 11.0, 160.0 + displaced * 6.0
				)
				displaced += 1
	xi_carrier.global_position = xi.match_pitch.get_center()
	xi.ball.attach_to(xi_carrier)
	xi_touch._process(0.0)
	assert(xi.help_label.text.begins_with("DEFIENDES"))
	xi.presentation_3d.sync_presentation(2.0, "tactical")
	var xi_carrier_screen: Vector2 = xi.mobile_player_screen_position(xi_carrier)
	assert(xi_carrier_screen.x > 85.0 and xi_carrier_screen.x < 1190.0)
	var magnet_probe: Vector2 = xi_carrier_screen + Vector2(85.0, 0.0)
	assert(xi.mobile_touch_target(magnet_probe, 76.0).get("player") == xi_carrier)
	assert(xi.mobile_touch_target(xi_carrier_screen + Vector2(105.0, 0.0), 76.0).is_empty())
	xi_touch.debug_force_controls_visible(false)
	print("FOOTBALL_XI_TOUCH_OK players=22 joystick=1 teammate=1 pass=1 carrier_magnet=1")
	print("chess-football mobile touch smoke: OK")
	quit(0)
