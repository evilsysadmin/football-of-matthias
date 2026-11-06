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
	print("FOOTBALL_XI_ULTRAWIDE_OK viewport=%s fov=%.2f" % [str(size), stage.camera.fov])
	quit(0)
