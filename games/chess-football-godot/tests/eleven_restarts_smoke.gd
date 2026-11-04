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
