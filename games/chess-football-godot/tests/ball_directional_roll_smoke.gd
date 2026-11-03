extends SceneTree

# The real Godot renderer must roll its panelled 3D ball with the physical
# travel direction; all 2D physics, position, shot and score remain authoritative.
func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var match_node = packed.instantiate()
	root.add_child(match_node)
	await process_frame
	await process_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	var presenter: ChessFootball3DPresenter = match_node.presentation_3d
	var ball: FootballBall = match_node.ball
	var ball_mesh: MeshInstance3D = presenter.ball_node
	assert(ball_mesh != null and ball_mesh.mesh is SphereMesh)
	var original_score: Array = match_node.score.duplicate()
	var original_time: float = match_node.match_seconds

	# No axis on a stopped ball, proper X/Z orientation on each run direction.
	assert(ChessFootball3DPresenter.ball_roll_axis(Vector2.ZERO) == Vector3.ZERO)
	assert(ChessFootball3DPresenter.ball_roll_axis(Vector2.RIGHT) == Vector3(0.0, 0.0, -1.0))
	assert(ChessFootball3DPresenter.ball_roll_axis(Vector2.LEFT) == Vector3(0.0, 0.0, 1.0))
	assert(ChessFootball3DPresenter.ball_roll_axis(Vector2.DOWN) == Vector3(1.0, 0.0, 0.0))
	var diagonal_axis := ChessFootball3DPresenter.ball_roll_axis(Vector2(3.0, 4.0))
	assert(is_equal_approx(diagonal_axis.length(), 1.0))
	assert(is_zero_approx(diagonal_axis.y))

	ball.release(Vector2.RIGHT, 600.0)
	var position_before: Vector2 = ball.global_position
	ball_mesh.basis = Basis.IDENTITY
	presenter.sync_presentation(0.10, "broadcast")
	var across_field: Basis = ball_mesh.basis
	assert(absf(across_field.y.x) > 0.10)
	assert(absf(across_field.y.z) < 0.001)
	assert(ball.global_position == position_before)
	assert(ball.velocity == Vector2(600.0, 0.0))

	ball.velocity = Vector2(0.0, 600.0)
	ball_mesh.basis = Basis.IDENTITY
	presenter.sync_presentation(0.10, "broadcast")
	var along_field: Basis = ball_mesh.basis
	assert(absf(along_field.y.x) < 0.001)
	assert(absf(along_field.y.z) > 0.10)
	assert(ball.global_position == position_before)
	assert(ball.velocity == Vector2(0.0, 600.0))

	ball.velocity = Vector2(300.0, 400.0)
	ball_mesh.basis = Basis.IDENTITY
	presenter.sync_presentation(0.10, "broadcast")
	assert(absf(ball_mesh.basis.y.x) > 0.05)
	assert(absf(ball_mesh.basis.y.z) > 0.05)
	assert(ball.global_position == position_before)
	assert(ball.velocity == Vector2(300.0, 400.0))

	# A stopped game or ball must never introduce phantom spin.
	ball_mesh.basis = Basis.IDENTITY
	presenter.sync_presentation(0.0, "broadcast")
	assert(ball_mesh.basis.is_equal_approx(Basis.IDENTITY))
	presenter.sync_presentation(-0.10, "broadcast")
	assert(ball_mesh.basis.is_equal_approx(Basis.IDENTITY))
	ball.velocity = Vector2.ZERO
	presenter.sync_presentation(0.10, "broadcast")
	assert(ball_mesh.basis.is_equal_approx(Basis.IDENTITY))

	# Held possession must never rotate the ball, including an authored keeper catch.
	var keeper: Footballer = match_node.teams[0][0]
	ball.attach_to(keeper)
	ball_mesh.basis = Basis.IDENTITY
	presenter.sync_presentation(0.10, "broadcast")
	assert(ball_mesh.basis.is_equal_approx(Basis.IDENTITY))
	assert(ball.carrier == keeper)
	assert(match_node.score == original_score)
	assert(is_equal_approx(match_node.match_seconds, original_time))
	print("FOOTBALL_BALL_DIRECTIONAL_ROLL_OK axes=4 position_and_match_authority_unchanged")
	quit(0)
