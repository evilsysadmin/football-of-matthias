extends SceneTree

# XI match-camera evidence. The turquoise ring is PRESENTATION ONLY; it
# follows the exact real-input Space recipient and vanishes on release,
# no valid lane, possession loss or a restart. No forced pass or pickup.
const DT := 1.0 / 60.0

func _ring(stage: ChessFootball3DPresenter, player: Footballer) -> MeshInstance3D:
	var proxy: Node3D = stage.player_nodes[player.get_instance_id()]
	return proxy.get_node("SetPieceReceiverDisc") as MeshInstance3D

func _initialize() -> void:
	Input.action_release("pass_ball")
	Input.action_release("move_right")
	Input.action_release("move_left")
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game: Node2D = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	for i in range(8):
		await process_frame
		await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.velocity = Vector2.ZERO
			actor.global_position = Vector2(-9999.0, -9999.0)
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	var carrier: Footballer = game.teams[0][10]
	var target: Footballer = game.teams[0][6]
	var decoy: Footballer = game.teams[0][5]
	var defender: Footballer = game.teams[1][5]
	var center: Vector2 = game.match_pitch.get_center()
	carrier.global_position = center + Vector2(-180.0, 0.0)
	target.global_position = center + Vector2(100.0, -40.0)
	decoy.global_position = center + Vector2(45.0, 260.0)
	defender.global_position = center + Vector2(260.0, 180.0)
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	assert(game.debug_team_counts() == [11, 11])
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	var initial_score: Array = game.score.duplicate()
	var initial_time: float = game.match_seconds

	Input.action_press("move_right")
	Input.action_press("pass_ball")
	game._handle_human(DT)
	assert(game.pass_charging and game.pass_target == target)
	assert(game._xi_pass_charge_receiver() == target)
	assert(game._xi_pass_charge_label().contains(target.scouting_player_name.left(18)))
	for mode in ["broadcast", "tactical"]:
		stage.sync_presentation(0.0, mode)
		assert(_ring(stage, target).visible)
		assert(not _ring(stage, carrier).visible)
		assert(not _ring(stage, decoy).visible)
		assert(not _ring(stage, defender).visible)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = game.get_viewport().get_texture().get_image()
		assert(image != null and image.get_size() == Vector2i(1280, 720))
		var path: String = "user://xi-pass-recipient-" + mode + ".png"
		assert(image.save_png(path) == OK)
		print("FOOTBALL_XI_PASS_RING_CAPTURE_" + mode.to_upper() + "=" +
			ProjectSettings.globalize_path(path))

	# Rotating the real pass intent outside the target cone must hide
	# the same ring as the caption; no ghost teammate is highlighted.
	game.pass_aim_direction = Vector2.LEFT
	assert(game._xi_pass_charge_receiver() == null)
	assert(game._xi_pass_charge_label().contains("LIBRE"))
	stage.sync_presentation(0.0, "broadcast")
	assert(not _ring(stage, target).visible)
	game.pass_aim_direction = Vector2.RIGHT
	assert(game._xi_pass_charge_receiver() == target)
	game.pause_menu_open = true
	stage.sync_presentation(0.0, "broadcast")
	assert(not _ring(stage, target).visible)
	game.pause_menu_open = false
	game.set_piece_active = true
	stage.sync_presentation(0.0, "broadcast")
	assert(not _ring(stage, target).visible)
	game.set_piece_active = false
	Input.action_release("pass_ball")
	game._handle_human(DT)
	assert(not game.pass_charging and game.ball.carrier == null)
	stage.sync_presentation(0.0, "broadcast")
	assert(not _ring(stage, target).visible)
	assert(game.score == initial_score)
	assert(is_equal_approx(game.match_seconds, initial_time))
	Input.action_release("move_right")
	print("FOOTBALL_XI_PASS_RING_OK modes=2 frames=2 actors=22 only_selected=1 invalid_aim_hidden=1 pause_hidden=1 restart_hidden=1 release_hidden=1 authority_unchanged=1")
	quit(0)
