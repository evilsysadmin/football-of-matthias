extends SceneTree

# Exercise actual out-of-play rules through the match scene. A human restart
# must stay on screen for an intentional pass/aim, while CPU and unattended
# restarts still progress without changing goals or match authority.
func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var match_node = packed.instantiate()
	root.add_child(match_node)
	await process_frame
	await process_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	match_node.debug_force_kickoff_ready()
	var original_score: Array = match_node.score.duplicate()
	var pitch := ChessFootballMath.PITCH_RECT

	# FC Matthias earns a throw-in after the rival touched the touchline.
	match_node.ball.attach_to(match_node.teams[1][2])
	match_node.ball.release(Vector2.UP, 480.0)
	match_node.ball.global_position = Vector2(pitch.get_center().x, pitch.position.y - 24.0)
	match_node.debug_check_ball_out()
	assert(match_node.debug_set_piece_kind() == "SAQUE DE BANDA")
	assert(match_node.debug_set_piece_team() == 0)
	var thrower: Footballer = match_node.ball.carrier
	assert(thrower != null and thrower.team_id == 0)
	match_node.debug_force_set_piece_ready()
	assert(match_node.debug_set_piece_active())
	assert(match_node.human_set_piece_available())
	assert(match_node.ball.carrier == thrower)
	match_node._update_set_piece(0.60)
	assert(match_node.debug_set_piece_active())
	match_node.debug_refresh_hud()
	assert("ESPACIO" in match_node.help_label.text)
	assert("SAQUE DE BANDA" in match_node.last_goal_text)
	assert(match_node._release_outfield_set_piece(null, Vector2.DOWN))
	assert(not match_node.debug_set_piece_active())
	assert(match_node.ball.carrier == null)
	assert(match_node.ball.velocity.dot(Vector2.DOWN) > 490.0)
	assert(match_node.ball.last_touch_team_id == 0)
	assert(not match_node._release_outfield_set_piece())
	assert(match_node.score == original_score)

	# A human corner can be aimed at one exact teammate with mobile touch.
	match_node.ball.attach_to(match_node.teams[1][1])
	match_node.ball.release(Vector2.RIGHT, 520.0)
	match_node.ball.global_position = Vector2(pitch.end.x + 24.0, pitch.position.y + 44.0)
	match_node.debug_check_ball_out()
	assert(match_node.debug_set_piece_kind() == "CÓRNER")
	assert(match_node.debug_set_piece_team() == 0)
	match_node.debug_force_set_piece_ready()
	assert(match_node.human_set_piece_available())
	var corner_taker: Footballer = match_node.ball.carrier
	var target: Footballer = null
	for teammate in match_node.teams[0]:
		if teammate != corner_taker and teammate.role != "keeper" and not teammate.sent_off:
			target = teammate
			break
	assert(target != null and target != corner_taker)
	assert(not match_node.mobile_begin_context_pass(match_node.teams[1][2]))
	assert(match_node.ball.carrier == corner_taker)
	assert(match_node.mobile_begin_context_pass(target))
	var intended_direction: Vector2 = target.global_position - corner_taker.global_position
	assert(match_node.mobile_release_context_pass())
	assert(not match_node.debug_set_piece_active())
	assert(match_node.ball.carrier == null)
	assert(match_node.ball.vertical_velocity > 0.0)
	assert(match_node.ball.velocity.dot(intended_direction) > 0.0)
	assert(match_node.ball.last_touch_team_id == 0)
	assert(not match_node.mobile_release_context_pass())
	assert(match_node.score == original_score)

	# The same human corner must never deadlock when nobody presses anything.
	match_node.ball.attach_to(match_node.teams[1][1])
	match_node.ball.release(Vector2.RIGHT, 520.0)
	match_node.ball.global_position = Vector2(pitch.end.x + 24.0, pitch.end.y - 44.0)
	match_node.debug_check_ball_out()
	match_node.debug_force_set_piece_ready()
	assert(match_node.human_set_piece_available())
	match_node._update_set_piece(9.0)
	assert(not match_node.debug_set_piece_active())
	assert(match_node.ball.carrier == null)
	assert(match_node.ball.velocity.length() > 0.0)

	# Rival throw-ins stay automatic after the existing whistle pause.
	match_node.ball.attach_to(match_node.teams[0][2])
	match_node.ball.release(Vector2.DOWN, 420.0)
	match_node.ball.global_position = Vector2(pitch.get_center().x, pitch.end.y + 24.0)
	match_node.debug_check_ball_out()
	assert(match_node.debug_set_piece_kind() == "SAQUE DE BANDA")
	assert(match_node.debug_set_piece_team() == 1)
	match_node.debug_force_set_piece_ready()
	assert(not match_node.debug_set_piece_active())
	assert(match_node.ball.carrier == null)
	assert(match_node.ball.velocity.length() > 0.0)

	# A human penalty still waits for the charge/release action; not an
	# automatic corner or throw-in, and not subject to the 8-second timeout.
	match_node.debug_prepare_penalty(0)
	match_node.debug_force_set_piece_ready()
	assert(match_node.debug_set_piece_kind() == "PENALTI")
	assert(match_node.debug_human_penalty_ready())
	assert(match_node.debug_set_piece_active())
	assert(not match_node.human_set_piece_available())
	assert(match_node.ball.carrier == match_node.teams[0][3] or match_node.ball.carrier.team_id == 0)
	assert(match_node.score == original_score)
	print("FOOTBALL_PLAYABLE_RESTARTS_OK throw_corner_touch_timeout_cpu_penalty")
	quit(0)
