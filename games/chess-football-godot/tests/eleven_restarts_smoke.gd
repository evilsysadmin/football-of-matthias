extends SceneTree

# 11v11 real ball-out and restart contracts on the 4,000 x 2,600 pitch.
# The default public 5v5 rules remain unchanged.
const Formation = preload("res://scripts/football_match_formation.gd")
const FIVE := ChessFootballMath.PITCH_RECT
const XI := Formation.ELEVEN_PITCH_RECT

func _deliver(game: Node, last_team: int, point: Vector2) -> void:
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	game.set_piece_player = null
	game.ball.attach_to(game.teams[last_team][1])
	game.ball.release(Vector2.RIGHT, 540.0)
	game.ball.global_position = point
	game.ball.flight_height = 0.0
	game._check_ball_out()

func _verify_spread(game: Node) -> void:
	for team_id in range(2):
		var positions: Array[Vector2] = []
		for player in game.teams[team_id]:
			assert(XI.has_point(player.global_position))
			if player.sent_off:
				continue
			for other in positions:
				assert(player.global_position.distance_to(other) >= 28.0,
					"Two XI teammates overlap during a restart")
			positions.append(player.global_position)

func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	assert(game.match_pitch == XI)
	assert(game.debug_team_counts() == [11, 11])
	assert(XI.get_center() == FIVE.get_center())
	# Crossing an OLD five-a-side line is still inside the expanded pitch.
	_deliver(game, 1, Vector2(XI.get_center().x, FIVE.position.y - 30.0))
	assert(not game.set_piece_active)
	_deliver(game, 0, Vector2(XI.get_center().x, FIVE.end.y + 30.0))
	assert(not game.set_piece_active)
	_deliver(game, 1, Vector2(FIVE.end.x + 30.0, XI.get_center().y + 450.0))
	assert(not game.set_piece_active)
	_deliver(game, 0, Vector2(FIVE.position.x - 30.0, XI.get_center().y - 450.0))
	assert(not game.set_piece_active)
	# Touchline on either side; the OTHER team takes the throw.
	_deliver(game, 1, Vector2(XI.get_center().x - 220.0, XI.position.y - 32.0))
	assert(game.set_piece_kind == "SAQUE DE BANDA" and game.set_piece_team_id == 0)
	assert(is_equal_approx(game.set_piece_spot.y, XI.position.y + game.RESTART_TOUCHLINE_INSET))
	assert(game.ball.carrier != null and game.ball.carrier.team_id == 0)
	_verify_spread(game)
	var nearby := 0
	for teammate in game.teams[0]:
		if teammate != game.set_piece_player and teammate.role != "keeper":
			if teammate.global_position.distance_to(game.set_piece_spot) < 425.0:
				nearby += 1
	assert(nearby >= 2)
	game.debug_force_set_piece_ready()
	assert(game.human_set_piece_available())
	assert(game._release_outfield_set_piece(null, Vector2.DOWN))
	assert(game.ball.carrier == null and not game.set_piece_active)
	assert(game.ball.velocity.y > 0.0)
	_deliver(game, 0, Vector2(XI.get_center().x + 300.0, XI.end.y + 32.0))
	assert(game.set_piece_kind == "SAQUE DE BANDA" and game.set_piece_team_id == 1)
	assert(is_equal_approx(game.set_piece_spot.y, XI.end.y - game.RESTART_TOUCHLINE_INSET))
	_verify_spread(game)
	game.debug_force_set_piece_ready()
	assert(not game.set_piece_active and game.ball.carrier == null)
	# Right corner after defender touches; 11 starters must NOT collapse
	# onto the four 5v5 slots.
	_deliver(game, 1, Vector2(XI.end.x + 32.0, XI.position.y + 55.0))
	assert(game.set_piece_kind == "CÓRNER" and game.set_piece_team_id == 0)
	assert(is_equal_approx(game.set_piece_spot.x, XI.end.x - game.RESTART_GOAL_LINE_INSET))
	assert(game.ball.carrier.team_id == 0)
	_verify_spread(game)
	game.debug_force_set_piece_ready()
	assert(game.human_set_piece_available())
	assert(game._release_outfield_set_piece())
	assert(game.ball.vertical_velocity > 0.0)
	# Left corner after the opposing defender touches.
	_deliver(game, 0, Vector2(XI.position.x - 32.0, XI.end.y - 55.0))
	assert(game.set_piece_kind == "CÓRNER" and game.set_piece_team_id == 1)
	assert(is_equal_approx(game.set_piece_spot.x, XI.position.x + game.RESTART_GOAL_LINE_INSET))
	_verify_spread(game)
	game.debug_force_set_piece_ready()
	assert(not game.set_piece_active)
	# An attacking last touch produces a keeper goal kick.
	_deliver(game, 0, Vector2(XI.end.x + 32.0, XI.get_center().y + 260.0))
	assert(game.set_piece_kind == "SAQUE DE PUERTA" and game.set_piece_team_id == 1)
	assert(game.ball.carrier == game.teams[1][0])
	assert(is_equal_approx(game.set_piece_spot.x, XI.end.x - 120.0))
	_verify_spread(game)
	game.debug_force_set_piece_ready()
	assert(not game.set_piece_active and game.ball.velocity.length() > 0.0)
	_deliver(game, 1, Vector2(XI.position.x - 32.0, XI.get_center().y - 260.0))
	assert(game.set_piece_kind == "SAQUE DE PUERTA" and game.set_piece_team_id == 0)
	assert(game.ball.carrier == game.teams[0][0])
	assert(is_equal_approx(game.set_piece_spot.x, XI.position.x + 120.0))
	_verify_spread(game)
	game.debug_force_set_piece_ready()
	assert(not game.set_piece_active)
	# Five deterministic roll samples exercise the XI taker's genuinely
	# precommitted left/centre/right distribution without probabilistic tests.
	assert(is_equal_approx(game.ai_penalty_aim_from_roll(0.0), -0.90))
	assert(is_equal_approx(game.ai_penalty_aim_from_roll(0.2), -0.71))
	assert(is_equal_approx(game.ai_penalty_aim_from_roll(0.5), 0.0))
	assert(is_equal_approx(game.ai_penalty_aim_from_roll(0.8), 0.71))
	assert(is_equal_approx(game.ai_penalty_aim_from_roll(1.0), 0.90))
	# A penalty is also a full-XI restart. The historical five-a-side
	# penalty geometry put the goalkeeper several hundred units from the
	# actual XI goal and stacked ten outfielders on four recycled slots.
	for attacking_team in [0, 1]:
		var defending_team: int = 1 - attacking_team
		var attacking_direction: float = 1.0 if attacking_team == 0 else -1.0
		var goal: Vector2 = ChessFootballMath.goal_center(attacking_team, XI)
		var mark: Vector2 = goal - Vector2(
			attacking_direction * ChessFootballMath.PENALTY_SPOT_DEPTH, 0.0
		)
		assert(game.debug_penalty_area_contains(
			attacking_team, goal - Vector2(attacking_direction * 120.0, 0.0)
		), "XI referee missed a foul inside the REAL penalty area")
		assert(not game.debug_penalty_area_contains(
			attacking_team, FIVE.get_center()
		), "XI penalty area must not be measured on the old 5v5 pitch")
		game.debug_prepare_penalty(attacking_team)
		var committed_aim: float = game.penalty_ai_committed_aim_y
		assert(absf(committed_aim) <= 0.91)
		if attacking_team == 0:
			assert(is_zero_approx(committed_aim),
				"The CPU's hidden decision must not leak into a human penalty")
		assert(game.debug_set_piece_spot().is_equal_approx(mark),
			"XI penalty mark does not match the painted spot at the full-size goal")
		assert(game.ball.carrier == game.set_piece_player)
		assert(game.set_piece_player.team_id == attacking_team)
		assert(game.set_piece_player.role != "keeper")
		var defending_keeper: Footballer = game.teams[defending_team][0]
		assert(defending_keeper.global_position.distance_to(
			goal - Vector2(attacking_direction * 42.0, 0.0)
		) < 0.1, "XI penalty keeper is not stationed at its own goal line")
		var occupied: Array[Vector2] = []
		var outfielders := 0
		for team in game.teams:
			for player in team:
				if player.sent_off:
					continue
				assert(XI.has_point(player.global_position))
				for previous in occupied:
					assert(player.global_position.distance_to(previous) > 90.0,
						"XI penalty players overlap or obstruct the kicker")
				occupied.append(player.global_position)
				if player == game.set_piece_player or player.role == "keeper":
					continue
				outfielders += 1
				assert(
					(goal.x - player.global_position.x) * attacking_direction
					> ChessFootballMath.PENALTY_AREA_DEPTH + 135.0
				, "Non-kicking XI outfielder is inside the penalty area")
				assert(player.global_position.distance_to(mark) > 185.0,
					"Non-kicking XI outfielder is inside the penalty arc")
		assert(outfielders == 19, "11v11 needs 19 non-kicking outfield players")
		if attacking_team == 0:
			assert(game.debug_penalty_target(0.0).is_equal_approx(goal),
				"XI penalty shot target must be the full-size goal")
			game.debug_force_set_piece_ready()
			assert(game.debug_human_penalty_ready())
			# The aim marker is a 3D presentation object; sync the frozen
			# SceneTree before checking visibility, just like visual_capture.gd.
			game.debug_sync_presentation()
			assert(game.debug_penalty_aim_visible())
			game.debug_force_human_penalty_shot(0.65, 0.35)
			assert(not game.set_piece_active and game.ball.carrier == null)
			assert(game.ball.velocity.x > 0.0)
		else:
			var release_from: Vector2 = game.set_piece_player.global_position
			var chosen_target: Vector2 = game._penalty_target(1, committed_aim)
			var keeper_before: Vector2 = game.teams[0][0].global_position
			game.debug_move_penalty_keeper(1.0, 0.1)
			assert(game.teams[0][0].global_position.x == keeper_before.x,
				"Human keeper moved off the XI penalty goal line")
			assert(game.teams[0][0].global_position.y > keeper_before.y)
			game.debug_move_penalty_keeper(-1.0, 0.2)
			assert(game.teams[0][0].global_position.y < keeper_before.y,
				"Human keeper must be free to dive the other way before release")
			assert(is_equal_approx(game.penalty_ai_committed_aim_y, committed_aim),
				"The CPU must not switch target after seeing keeper movement")
			game.debug_force_set_piece_ready()
			assert(not game.set_piece_active and game.ball.carrier == null)
			assert(game.ball.velocity.x < 0.0)
			assert(game.ball.velocity.normalized().distance_to(
				(chosen_target - release_from).normalized()
			) < 0.01, "XI CPU penalty trajectory must follow its early choice")
	# Near-miss audio contract uses the new goal plane; old default stays.
	var old_near := Vector2(FIVE.end.x + 25.0, FIVE.get_center().y + ChessFootballMath.GOAL_HALF_HEIGHT + 22.0)
	assert(ChessFootballMath.close_shot_miss_at_goal_line(old_near, 0.0, 0))
	assert(not ChessFootballMath.close_shot_miss_at_goal_line(old_near, 0.0, 0, XI))
	var xi_near := Vector2(XI.end.x + 25.0, XI.get_center().y + ChessFootballMath.GOAL_HALF_HEIGHT + 22.0)
	assert(ChessFootballMath.close_shot_miss_at_goal_line(xi_near, 0.0, 0, XI))
	# The standard five-a-side match never inherits XI sizes.
	assert(ChessFootballMath.clamp_to_pitch(Vector2(0.0, 0.0)) == Vector2(100.0, 0.0))
	print("FOOTBALL_XI_RESTARTS_OK touchlines=2 corners=2 goal_kicks=2 no_phantom_5v5=1 unique_xi_lanes=1")
	quit(0)
