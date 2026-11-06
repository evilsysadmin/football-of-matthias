extends SceneTree

# Native 1766x832 visual evidence, matching the reported ultrawide desktop.
# Verify the actual expanded Godot viewport and XI camera, then save real pixels.
func _initialize() -> void:
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
	assert(size.y > 0.0 and size.x / size.y > 2.08,
		"Ultrawide viewport was pillarboxed instead of expanded")
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and game.debug_team_counts() == [11, 11])
	stage.sync_presentation(8.0, "broadcast")
	assert(stage.camera.fov <= ChessFootball3DPresenter.XI_BROADCAST_WIDE_FOV + 0.08,
		"Ultrawide XI camera failed to approach the players")
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
