extends SceneTree

# Native 1766x832 visual evidence, matching the reported ultrawide desktop.
# Verify the actual expanded Godot viewport and XI camera, then save real pixels.
func _initialize() -> void:
	# The CI Xvfb display does not inherit --resolution reliably when Godot
	# starts from a project configured for fullscreen. Resize the actual root
	# Window before instantiating the match, not just the render assertion.
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1766, 832)
	await process_frame
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	for _frame in range(4):
		await process_frame
	game._prepare_kickoff(0, true)
	game.kickoff_seconds_remaining = 15.0
	game.set_process(false)
	game.set_physics_process(false)

	var viewport := root.get_viewport()
	var size: Vector2 = viewport.get_visible_rect().size
	print("FOOTBALL_XI_ULTRAWIDE_GEOMETRY window=%s viewport=%s" % [
		str(root.size), str(size)
	])
	if size.y <= 0.0 or size.x / size.y <= 2.08:
		push_error("Ultrawide viewport was pillarboxed instead of expanded")
		quit(1)
		return
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and game.debug_team_counts() == [11, 11])
	stage.sync_presentation(8.0, "broadcast")
	var focus_fov: float = ChessFootball3DPresenter.xi_broadcast_live_fov(
		size, game.ball.global_position, game.match_pitch
	)
	assert(absf(stage.camera.fov - focus_fov) < 0.08,
		"Ultrawide XI camera failed to use the central-play close-follow lens")
	assert(focus_fov < ChessFootball3DPresenter.XI_BROADCAST_WIDE_FOV - 3.0,
		"Ultrawide central-play lens should be closer than the safe baseline")
	var ball_screen: Vector2 = stage.screen_position_for_world(game.ball.global_position, 0.02)
	assert(ball_screen.x > 70.0 and ball_screen.x < size.x - 70.0)
	assert(ball_screen.y > 145.0 and ball_screen.y < size.y - 35.0)

	for _settle in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
	var capture: Image = viewport.get_texture().get_image()
	assert(capture.get_width() > 1600 and capture.get_height() > 760,
		"Ultrawide capture resolution is wrong")
	var path := "user://chess-football-xi-ultrawide.png"
	assert(capture.save_png(path) == OK)
	print("FOOTBALL_XI_ULTRAWIDE_CAPTURE=" + ProjectSettings.globalize_path(path))

	# The actual wide-screen penalty must keep its correct XI goal/keeper
	# composition. Preserve the initial kickoff PNG as its own regression.
	game.kickoff_active = false
	game.debug_prepare_penalty(0)
	game.debug_force_set_piece_ready()
	game.debug_set_penalty_aim(0.45)
	game.debug_refresh_hud()
	stage.sync_presentation(8.0, "broadcast")
	var cinematic_pose: Dictionary = ChessFootball3DPresenter.xi_penalty_camera_pose(
		game.set_piece_spot, 0, game.match_pitch
	)
	assert(stage.camera.position.distance_to(cinematic_pose["position"]) < 0.08,
		"Ultrawide penalty must use the new behind-the-kicker perspective")
	assert(absf(stage.camera.fov - ChessFootball3DPresenter.XI_PENALTY_CAMERA_FOV) < 0.08)
	assert(stage.penalty_camera_mix > 0.999)
	var goal: Vector2 = ChessFootballMath.goal_center(0, game.match_pitch)
	var goalkeeper: Footballer = game.teams[1][0]
	assert(goalkeeper.global_position.distance_to(goal - Vector2(42.0, 0.0)) < 0.1,
		"Ultrawide goalkeeper is not at the right-hand XI goal")
	var kicker_pixel: Vector2 = stage.screen_position_for_world(game.set_piece_spot, 0.03)
	var keeper_pixel: Vector2 = stage.screen_position_for_player(goalkeeper)
	var goal_pixel: Vector2 = stage.screen_position_for_world(goal, 0.03)
	assert(kicker_pixel.x > 50.0 and kicker_pixel.x < size.x - 50.0)
	assert(keeper_pixel.x > 50.0 and keeper_pixel.x < size.x - 50.0)
	assert(goal_pixel.x > 50.0 and goal_pixel.x < size.x - 50.0)
	assert(kicker_pixel.y > 145.0 and kicker_pixel.y < size.y - 35.0)
	assert(stage.debug_penalty_aim_visible())
	for _penalty_frame in range(5):
		stage.sync_presentation(0.0, "broadcast")
		await process_frame
		await RenderingServer.frame_post_draw
	var penalty_capture: Image = viewport.get_texture().get_image()
	var penalty_path := "user://chess-football-xi-penalty-ultrawide.png"
	assert(penalty_capture.save_png(penalty_path) == OK)
	print("FOOTBALL_XI_ULTRAWIDE_PENALTY_CAPTURE=" +
		ProjectSettings.globalize_path(penalty_path))
	print("FOOTBALL_XI_ULTRAWIDE_OK viewport=%s fov=%.2f" % [str(size), stage.camera.fov])
	quit(0)
