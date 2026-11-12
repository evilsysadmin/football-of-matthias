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
			if family == "dribbles":
				# Forensic source: preserve the verified original decoded RGBA,
				# including ALL per-pixel alpha, before Godot/QuadMesh draws it.
				# Comparing this with the live motion MP4 locates any ghosting
				# at source versus runtime. These are review-only, never assets.
				var source_png := output_dir.path_join("football-v5-original-%s-dribbles.png" %
					String(ChessFootballHeroV5R2.CLUBS[club]))
				assert(img.save_png(source_png) == OK)
				print("FOOTBALL_V5_SOURCE_SHEET_CAPTURE=" + source_png)
			stage._on_hero_v5_ready(img, club, family)
			assert(stage._hero_v5_loaded.has("%d:%s" % [club, family]))
			if family == "dribbles":
				var actor: Footballer = game.teams[club][1]
				var checked_sprite: AnimatedSprite3D = stage.player_sprites[actor.get_instance_id()]
				for anim in [&"hero_feint", &"hero_cut"]:
					for odd in range(1, 16, 2):
						assert(checked_sprite.sprite_frames.get_frame_texture(anim, odd) ==
							checked_sprite.sprite_frames.get_frame_texture(anim, odd - 1),
							"Live V5 must not render baked ghost silhouettes in either club")
				print("FOOTBALL_V5_GHOST_FREE_SOURCE_OK club=%d modes=2 opaque_poses=8" % club)
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
		# The same verified public V5 banks now drive an uninterrupted
		# 1.4-second clip at 20 captured FPS (60 Hz authoritative physics).
		# Full 1280x720 match lens + native pixels from the SAME framebuffer.
		await _capture_actual_e_video(game, stage, mode, output_dir)
		await _capture_xi_contact_fall(game, stage, mode, output_dir)
	assert(game.score == original_score)
	assert(is_equal_approx(game.match_seconds, original_seconds))
	print("FOOTBALL_V5_REAL_R2_OK four_sha_verified=1 both_clubs=1 dribbles=2 cameras=2 no_physics_change=1")
	quit(0)


# CI video source. No staged sprite sheet or simulated timeline:
# render 28 actual frames from a 1.4s 60 Hz movement sequence with a
# controlled real XI opponent and the rest of the 22-player lineup visible.
# E is pressed through the same match action handler used in live gameplay.
# Rival AI is intentionally paused; the separate 48-duel lab tests combat.
func _capture_actual_e_video(game: Node2D, stage: ChessFootball3DPresenter, mode: String, output_dir: String) -> void:
	const DT := 1.0 / 60.0
	const CAPTURE_EVERY := 3
	const SIM_FRAMES := 84
	const E_FRAME := 18
	var full_dir: String = output_dir.path_join("video-frames").path_join(mode).path_join("full")
	var detail_dir: String = output_dir.path_join("video-frames").path_join(mode).path_join("detail")
	assert(DirAccess.make_dir_recursive_absolute(full_dir) == OK)
	assert(DirAccess.make_dir_recursive_absolute(detail_dir) == OK)
	for team in game.teams:
		for actor: Footballer in team:
			actor.global_position = actor.home_position
			actor.velocity = Vector2.ZERO
			actor.dribble_burst_seconds = 0.0
			actor.action_lock_seconds = 0.0
			actor.contact_stun_seconds = 0.0
			actor.tackle_recovery_seconds = 0.0
	var runner: Footballer = game.teams[0][1]
	var enemy: Footballer = game.teams[1][5]
	var center: Vector2 = game.match_pitch.get_center()
	runner.global_position = center
	runner.velocity = Vector2.RIGHT * runner.base_speed
	runner.dribble_cooldown_seconds = 0.0
	enemy.global_position = center + Vector2(140.0, -70.0)
	game._select_player(runner)
	game.ball.attach_to(runner)
	stage.player_run_views[runner.get_instance_id()] = "side"
	stage.outfield_visual_names.erase(runner.get_instance_id())
	stage.outfield_visual_phases.erase(runner.get_instance_id())
	stage._sync_camera(10.0, mode)
	var data_path: String = output_dir.path_join("moving-e-%s.csv" % mode)
	var csv: FileAccess = FileAccess.open(data_path, FileAccess.WRITE)
	assert(csv != null)
	csv.store_line("sample,time_seconds,pressed_E,animation,atlas_frame,player_x,player_y,ball_x,ball_y,speed,cut_progress")
	var sample: int = 0
	var first_lateral: float = runner.global_position.y
	var visible_cuts: int = 0
	var visible_runs_before: int = 0
	var visible_runs_after: int = 0
	var sampled_frames: Array[int] = []
	for tick in range(SIM_FRAMES):
		await physics_frame
		if tick == E_FRAME:
			game._handle_contextual_e(Vector2.RIGHT, false)
			assert(runner.dribble_mode == "cut")
			assert(runner.dribble_direction.y > 0.35)
		runner.move_human(DT, Vector2.RIGHT, false)
		game.ball.tick_ball(DT)
		stage._sync_camera(DT, mode)
		stage.sync_presentation(DT, mode)
		assert(game.ball.carrier == runner and runner.has_ball)
		assert(runner.velocity.length() <= runner.base_speed *
			runner.technique_control_multiplier * runner.SPRINT_SPEED_MULTIPLIER + 1.0)
		assert(absf(stage.ball_shadow.position.x - stage.ball_node.position.x) < 0.001)
		assert(absf(stage.ball_shadow.position.z - stage.ball_node.position.z) < 0.001)
		if tick % CAPTURE_EVERY == 0:
			var sprite: AnimatedSprite3D = stage.player_sprites[runner.get_instance_id()]
			if sprite.animation == &"hero_cut":
				visible_cuts += 1
				sampled_frames.append(sprite.frame)
			elif tick < E_FRAME:
				visible_runs_before += 1
			else:
				visible_runs_after += 1
			await process_frame
			await RenderingServer.frame_post_draw
			var shot: Image = game.get_viewport().get_texture().get_image()
			assert(shot != null and shot.get_size() == Vector2i(1280, 720))
			var camera_px: Vector2 = stage.camera.unproject_position(
				stage.player_nodes[runner.get_instance_id()].global_position + Vector3.UP * 0.75
			)
			assert(Rect2(Vector2.ZERO, Vector2(1280, 720)).has_point(camera_px))
			var detail_size := Vector2i(400, 300)
			var left: int = clampi(int(camera_px.x) - detail_size.x / 2, 0, 1280 - detail_size.x)
			var top: int = clampi(int(camera_px.y) - detail_size.y / 2, 0, 720 - detail_size.y)
			var native_crop: Image = shot.get_region(Rect2i(left, top, detail_size.x, detail_size.y))
			assert(shot.save_png(full_dir.path_join("frame_%03d.png" % sample)) == OK)
			assert(native_crop.save_png(detail_dir.path_join("frame_%03d.png" % sample)) == OK)
			csv.store_csv_line(PackedStringArray([
				str(sample), "%.4f" % (float(tick) * DT),
				"1" if tick >= E_FRAME and runner.dribble_active() else "0",
				String(sprite.animation), str(sprite.frame),
				"%.3f" % runner.global_position.x, "%.3f" % runner.global_position.y,
				"%.3f" % game.ball.global_position.x, "%.3f" % game.ball.global_position.y,
				"%.3f" % runner.velocity.length(),
				"%.3f" % (1.0 - runner.dribble_burst_seconds / maxf(runner.dribble_duration_seconds, 0.001))
			]))
			sample += 1
		runner._process(DT)
	csv.close()
	assert(sample == 28 and visible_runs_before >= 4 and visible_runs_after >= 8)
	assert(visible_cuts >= 5 and sampled_frames.size() >= 5)
	assert(sampled_frames[0] < sampled_frames[2] and sampled_frames[2] < sampled_frames[-1],
		"The real moving E video must visibly traverse distinct V5 atlas frames")
	assert(runner.global_position.y > first_lateral + 25.0,
		"Real filmed E must cross a visible lateral lane (not a cosmetic sprite swap)")
	print("FOOTBALL_V5_MOVING_E_VIDEO_OK camera=%s frames=%d cut=%d run_before=%d run_after=%d" % [
		mode, sample, visible_cuts, visible_runs_before, visible_runs_after
	])
	game.ball.release(Vector2.RIGHT, 0.0)


# The first collision slice intentionally uses existing opaque sprites.
# This captures an actual pair of knocked-down XI Footballers with the
# SAME runtime camera/QuadMesh/contact shadow as gameplay, so reviewers
# can reject a bad fallback before dedicated falling atlases are designed.
func _capture_xi_contact_fall(game: Node2D, stage: ChessFootball3DPresenter, mode: String, output_dir: String) -> void:
	for team in game.teams:
		for athlete: Footballer in team:
			athlete.global_position = Vector2(-9999.0, -9999.0)
			athlete.velocity = Vector2.ZERO
			athlete.dribble_burst_seconds = 0.0
			athlete.xi_collision_down_seconds = 0.0
			athlete.xi_collision_guard_seconds = 0.0
			athlete.tackle_active_seconds = 0.0
	var runner: Footballer = game.teams[0][1]
	var rival: Footballer = game.teams[1][5]
	var center: Vector2 = game.match_pitch.get_center()
	runner.global_position = center - Vector2(17.0, 0.0)
	rival.global_position = center + Vector2(17.0, 0.0)
	runner.velocity = Vector2.RIGHT * 255.0
	rival.velocity = Vector2.LEFT * 185.0
	runner.dribble_mode = "cut"
	runner.dribble_duration_seconds = runner.XI_DRIBBLE_CUT_SECONDS
	runner.dribble_burst_seconds = runner.XI_DRIBBLE_CUT_SECONDS * 0.52
	runner.dribble_cooldown_seconds = 0.0
	game._select_player(runner)
	game.ball.attach_to(runner)
	assert(game._update_xi_dribble_body_contacts() == "both_down")
	assert(game.ball.carrier == null)
	assert(runner.xi_collision_down_seconds > 0.0 and rival.xi_collision_down_seconds > 0.0)
	var stages := [0.05, 0.42, 0.74, 1.0]
	var montage := Image.create(1280 * 2, 720 * 2, false, Image.FORMAT_RGBA8)
	montage.fill(Color("#15392f"))
	for index in range(stages.size()):
		var progress: float = stages[index]
		runner.xi_collision_down_seconds = runner.xi_collision_down_total * (1.0 - progress)
		rival.xi_collision_down_seconds = rival.xi_collision_down_total * (1.0 - progress)
		runner.contact_stun_seconds = runner.contact_stun_total * (1.0 - progress)
		rival.contact_stun_seconds = rival.contact_stun_total * (1.0 - progress)
		stage._sync_camera(10.0, mode)
		stage.sync_presentation(0.0, mode)
		var sprite: AnimatedSprite3D = stage.player_sprites[runner.get_instance_id()]
		if index == 1:
			assert(absf(rad_to_deg(sprite.rotation.z)) >= 45.0,
				"Fallen actor must visibly lie down in the real XI renderer")
			assert(sprite.scale.y < 0.80, "Fallen silhouette must shrink vertically")
		if index == 3:
			assert(absf(sprite.rotation.z) < deg_to_rad(10.0),
				"Recovered actor must stand up rather than remain a rotating sprite")
		await process_frame
		await RenderingServer.frame_post_draw
		var shot: Image = game.get_viewport().get_texture().get_image()
		assert(shot != null and shot.get_size() == Vector2i(1280, 720))
		montage.blit_rect(shot, Rect2i(Vector2i.ZERO, Vector2i(1280, 720)),
			Vector2i((index % 2) * 1280, (index / 2) * 720))
	var dest: String = output_dir.path_join("football-xi-real-contact-fall-%s.png" % mode)
	assert(montage.save_png(dest) == OK)
	print("FOOTBALL_XI_CONTACT_FALL_VISUAL_OK camera=%s 4_phases=1 2_actors=1" % mode)
	game.ball.velocity = Vector2.ZERO
	runner.global_position = Vector2(-9999.0, -9999.0)
	rival.global_position = Vector2(-9999.0, -9999.0)
