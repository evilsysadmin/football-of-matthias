extends SceneTree

# Genuine published V5 WebPs, not synthetic stand-ins: SHA-verified bytes are
# downloaded by CI before running this test and decoded through the exact
# browser atlas loader. Capture frames from BOTH real match lenses. The V5
# overlay must never create another ball or change match state.
const ACTIONS := ["feint", "cut"]
const FRACTIONS := [0.08, 0.31, 0.60, 0.92]
const CELL := Vector2i(300, 290)


func _initialize() -> void:
	print("FOOTBALL_V5_CAPTURE_PROBE_BEGIN")
	var input_dir := OS.get_environment("FOOTBALL_V5_ASSET_DIR")
	var output_dir := OS.get_environment("FOOTBALL_V5_CAPTURE_DIR")
	assert(not input_dir.is_empty() and not output_dir.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output_dir) == OK)
	var game_scene := load("res://main.tscn") as PackedScene
	assert(game_scene != null)
	var game = game_scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	for tick in range(8):
		await process_frame
		await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	for team in game.teams:
		for athlete: Footballer in team:
			athlete.set_process(false)
			athlete.set_physics_process(false)
			athlete.global_position = Vector2(-9999, -9999)
			athlete.velocity = Vector2.ZERO
			athlete.action_lock_seconds = 0.0
	game.ball.global_position = Vector2(-9999, -9999)
	print("FOOTBALL_V5_CAPTURE_PROBE_SCENE_READY")
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	var original_score: Array = game.score.duplicate()
	var original_seconds: float = game.match_seconds
	for club in range(2):
		for family in ChessFootballHeroV5R2.FAMILIES:
			var meta := ChessFootballHeroV5R2.sheet_meta(club, family)
			assert(not meta.is_empty())
			var filename: String = String(ChessFootballHeroV5R2.CLUBS[club]) + "_" + family + "_v5.webp"
			var file_path := input_dir.path_join(filename)
			assert(FileAccess.file_exists(file_path), "Missing verified public WebP: " + filename)
			var img := ChessFootballR2AtlasLoader.decode_verified_webp(
				FileAccess.get_file_as_bytes(file_path),
				meta, ChessFootballHeroV5R2.TRUSTED_ROOT
			)
			assert(img != null, "Public WebP SHA/dimensions/decoder mismatch for " + filename)
			stage._on_hero_v5_ready(img, club, family)
			assert(stage._hero_v5_loaded.has("%d:%s" % [club, family]))
	assert(stage._hero_v5_loaded.size() == 4)
	print("FOOTBALL_V5_CAPTURE_PROBE_ART_VERIFIED")

	for mode in ["broadcast", "tactical"]:
		print("FOOTBALL_V5_CAPTURE_PROBE_MODE_START " + mode)
		var sheet := Image.create(CELL.x * FRACTIONS.size(), CELL.y * 4, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("#15392f"))
		for club in range(2):
			for action_index in range(ACTIONS.size()):
				print("FOOTBALL_V5_CAPTURE_PROBE_ACTION club=%d action=%d mode=%s" % [club, action_index, mode])
				var action: String = ACTIONS[action_index]
				var athlete: Footballer = game.teams[club][1]
				var movement := Vector2.DOWN if action == "feint" else Vector2(1.0, 1.0).normalized()
				athlete.global_position = game.match_pitch.get_center()
				athlete.velocity = movement * maxf(athlete.base_speed, 70.0)
				athlete.dribble_mode = action
				athlete.dribble_direction = movement
				athlete.dribble_duration_seconds = (
					athlete.XI_DRIBBLE_FEINT_SECONDS if action == "feint"
					else athlete.XI_DRIBBLE_CUT_SECONDS
				)
				game.ball.attach_to(athlete)
				var initial_position: Vector2 = athlete.global_position
				var sprite: AnimatedSprite3D = stage.player_sprites[athlete.get_instance_id()]
				var expected: StringName = &"hero_feint" if action == "feint" else &"hero_cut"
				var row: int = club * ACTIONS.size() + action_index
				var first_frame: PackedByteArray = PackedByteArray()
				for index in range(FRACTIONS.size()):
					var progress: float = FRACTIONS[index]
					athlete.dribble_burst_seconds = athlete.dribble_duration_seconds * (1.0 - progress)
					game.ball.tick_ball(0.0)
					stage._sync_camera(10.0, mode)
					stage.sync_presentation(0.0, mode)
					assert(sprite.animation == expected,
						"V5 action not selected in 3D renderer: %s/%s" % [action, mode])
					assert(sprite.frame == clampi(int(floorf(progress * 16.0)), 0, 15))
					assert(game.ball.carrier == athlete)
					assert(athlete.global_position == initial_position)
					await process_frame
					await RenderingServer.frame_post_draw
					var img := game.get_viewport().get_texture().get_image()
					assert(img != null and img.get_size() == Vector2i(1280, 720))
					var camera_pos: Vector2 = stage.camera.unproject_position(sprite.global_position)
					var left := clampi(int(camera_pos.x) - CELL.x / 2, 0, 1280 - CELL.x)
					var top := clampi(int(camera_pos.y) - CELL.y / 2, 0, 720 - CELL.y)
					var crop := img.get_region(Rect2i(left, top, CELL.x, CELL.y))
					sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, CELL),
						Vector2i(index * CELL.x, row * CELL.y))
					if index == 0:
						first_frame = crop.get_data()
					elif index == 1:
						assert(crop.get_data() != first_frame,
							"V5 must visibly change the real Godot raster at game zoom")
				athlete.dribble_burst_seconds = 0.0
				game.ball.release(Vector2.RIGHT, 0.0)
				athlete.global_position = Vector2(-9999, -9999)
		var image_file := output_dir.path_join("football-v5-real-r2-" + mode + ".png")
		assert(sheet.save_png(image_file) == OK)
		print("FOOTBALL_V5_REAL_R2_CAPTURE_" + mode.to_upper() + "=" + image_file)

		# Five REAL moving-E moments, 4 physics frames apart (15 FPS).
		# Unlike the pose montage above, these frames use the live E
		# handler, CharacterBody movement and authoritative carried ball.
		var runner: Footballer = game.teams[0][1]
		var runner_key: int = runner.get_instance_id()
		var start_point: Vector2 = game.match_pitch.get_center()
		runner.global_position = start_point
		runner.velocity = Vector2.RIGHT * runner.base_speed
		runner.dribble_burst_seconds = 0.0
		runner.dribble_cooldown_seconds = 0.0
		runner.action_lock_seconds = 0.0
		runner.contact_stun_seconds = 0.0
		runner.tackle_recovery_seconds = 0.0
		var rival: Footballer = game.teams[1][5]
		rival.global_position = start_point + Vector2(140.0, -70.0)
		game._select_player(runner)
		game.ball.attach_to(runner)
		stage.player_run_views[runner_key] = "side"
		stage.outfield_visual_names.erase(runner_key)
		stage.outfield_visual_phases.erase(runner_key)
		game._handle_contextual_e(Vector2.RIGHT, false)
		assert(runner.dribble_mode == "cut" and runner.dribble_direction.y > 0.35)
		assert(is_equal_approx(runner.dribble_duration_seconds, runner.XI_DRIBBLE_CUT_SECONDS))
		var playback := Image.create(CELL.x * 5, CELL.y, false, Image.FORMAT_RGBA8)
		playback.fill(Color("#15392f"))
		var selected_frames: Array[int] = []
		var samples := [2, 6, 10, 14, 18]
		stage._sync_camera(10.0, mode)
		for tick_id in range(21):
			await physics_frame
			runner.move_human(1.0 / 60.0, Vector2.RIGHT, false)
			game.ball.tick_ball(1.0 / 60.0)
			stage.sync_presentation(1.0 / 60.0, mode)
			if tick_id in samples:
				var live_sprite: AnimatedSprite3D = stage.player_sprites[runner_key]
				assert(live_sprite.animation == &"hero_cut",
					"Live moving E must select the real V5 cut, not a run")
				selected_frames.append(live_sprite.frame)
				assert(game.ball.carrier == runner)
				await process_frame
				await RenderingServer.frame_post_draw
				var displayed: Image = game.get_viewport().get_texture().get_image()
				assert(displayed != null and displayed.get_size() == Vector2i(1280, 720))
				var pixel_center: Vector2 = stage.camera.unproject_position(live_sprite.global_position)
				assert(Rect2(Vector2.ZERO, Vector2(1280, 720)).has_point(pixel_center))
				var x: int = clampi(int(pixel_center.x) - CELL.x / 2, 0, 1280 - CELL.x)
				var y: int = clampi(int(pixel_center.y) - CELL.y / 2, 0, 720 - CELL.y)
				playback.blit_rect(
					displayed.get_region(Rect2i(x, y, CELL.x, CELL.y)),
					Rect2i(Vector2i.ZERO, CELL),
					Vector2i(selected_frames.size() - 1, 0) * CELL
				)
			runner._process(1.0 / 60.0)
		assert(selected_frames.size() == 5)
		assert(selected_frames[0] < selected_frames[2] and selected_frames[2] < selected_frames[4],
			"Real 15-FPS E samples must progress through V5 cut frames")
		assert(runner.global_position.y > start_point.y + 10.0,
			"Actual moving E must cross the lane, not only run forward")
		var playback_path := output_dir.path_join("football-v5-moving-e-live-" + mode + ".png")
		assert(playback.save_png(playback_path) == OK)
		print("FOOTBALL_V5_MOVING_E_LIVE_CAPTURE_" + mode.to_upper() + "=" + playback_path)
		game.ball.release(Vector2.RIGHT, 0.0)
		runner.global_position = Vector2(-9999, -9999)
		rival.global_position = Vector2(-9999, -9999)
	assert(game.score == original_score)
	assert(is_equal_approx(game.match_seconds, original_seconds))
	print("FOOTBALL_V5_REAL_R2_OK four_sha_verified=1 both_clubs=1 dribbles=2 cameras=2 no_physics_change=1")
	quit(0)
