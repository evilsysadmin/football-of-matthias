extends SceneTree

# 11v11 goal-line slice: a full-size pitch must use its own nets, posts
# and crossbar, not score or rebound at the former 5v5 boundaries.
# This is a headless real-match regression, not a public mode switch.
const Formation = preload("res://scripts/football_match_formation.gd")

func _initialize() -> void:
	var five: Rect2 = ChessFootballMath.PITCH_RECT
	var eleven: Rect2 = Formation.ELEVEN_PITCH_RECT
	var center_y: float = eleven.get_center().y
	var old_x: float = five.end.x
	var right_x: float = eleven.end.x
	var left_x: float = eleven.position.x
	assert(eleven.get_center() == five.get_center())
	assert(ChessFootballMath.goal_center(0) == Vector2(old_x, center_y))
	assert(ChessFootballMath.goal_center(1) == Vector2(five.position.x, center_y))
	assert(ChessFootballMath.goal_center(0, eleven) == Vector2(right_x, center_y))
	assert(ChessFootballMath.goal_center(1, eleven) == Vector2(left_x, center_y))
	assert(ChessFootballMath.in_goal_mouth(Vector2(right_x, center_y), eleven))
	assert(not ChessFootballMath.in_goal_mouth(
		Vector2(right_x, center_y + ChessFootballMath.GOAL_HALF_HEIGHT + 1.0), eleven))
	# The old goal-plane crossing must not register as XI woodwork.
	var old_post_y: float = center_y + ChessFootballMath.GOAL_HALF_HEIGHT
	assert(ChessFootballMath.goal_frame_collision(
		Vector2(old_x - 22.0, old_post_y),
		Vector2(old_x + 22.0, old_post_y),
		20.0, 20.0, eleven).is_empty())
	assert(String(ChessFootballMath.goal_frame_collision(
		Vector2(old_x - 22.0, old_post_y),
		Vector2(old_x + 22.0, old_post_y),
		20.0, 20.0)["kind"]) == "post")
	# Real 3D-mapped XI actor match, with the match physics paused only
	# while we place the ball at controlled test positions.
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	assert(game.match_pitch == eleven)
	assert(game.debug_team_counts() == [11, 11])
	game.kickoff_active = false
	game.set_piece_active = false
	game.goal_restart_active = false
	game.ball.release(Vector2.RIGHT, 0.0)
	game.ball.flight_height = 0.0
	game.ball.global_position = Vector2(old_x + 22.0, center_y)
	game._check_goal()
	assert(game.score == [0, 0])
	assert(not game.goal_restart_active)
	# A ball over the expanded crossbar or outside the posts cannot score.
	game.ball.global_position = Vector2(right_x + 22.0, center_y)
	game.ball.flight_height = ChessFootballMath.GOAL_MAX_FLIGHT_HEIGHT + 5.0
	game._check_goal()
	assert(game.score == [0, 0])
	game.ball.flight_height = 0.0
	game.ball.global_position.y = center_y + ChessFootballMath.GOAL_HALF_HEIGHT + 30.0
	game._check_goal()
	assert(game.score == [0, 0])
	game.ball.global_position.y = center_y
	game._check_goal()
	assert(game.score == [1, 0] and game.goal_restart_active)
	assert(game.pending_restart_team_id == 1)
	# Same exact full-size geometry on the left side.
	game.goal_restart_active = false
	game.ball.global_position = Vector2(left_x - 22.0, center_y)
	game.ball.flight_height = 0.0
	game._check_goal()
	assert(game.score == [1, 1] and game.pending_restart_team_id == 0)
	# A true right post hit must rebound *before* the full-size goal line.
	game.goal_restart_active = false
	game.ball.attach_to(game.teams[0][10])
	game.ball.release(Vector2.RIGHT, 930.0)
	var previous := Vector2(right_x - 22.0, old_post_y)
	game.ball.global_position = Vector2(right_x + 15.0, old_post_y)
	game.ball.flight_height = 20.0
	assert(game._resolve_goal_frame_collision(previous, 20.0) == "post")
	assert(game.ball.global_position.x < right_x)
	assert(game.ball.velocity.x < 0.0)
	# The other goal's crossbar uses the same selected pitch as the posts.
	var left_bar: Dictionary = ChessFootballMath.goal_frame_collision(
		Vector2(left_x + 25.0, center_y), Vector2(left_x - 25.0, center_y),
		ChessFootballMath.GOAL_FRAME_CROSSBAR_HEIGHT,
		ChessFootballMath.GOAL_FRAME_CROSSBAR_HEIGHT, eleven)
	assert(String(left_bar.get("kind", "")) == "crossbar")
	assert(is_equal_approx(float(left_bar["goal_x"]), left_x))
	print("FOOTBALL_XI_GOAL_LINE_OK full_pitch=1 no_old_goal=1 woodwork=1 both_sides=1 legacy=unchanged")
	quit(0)
