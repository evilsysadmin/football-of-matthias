extends SceneTree

# Real SHA-pinned v3 run and carry/dribble-v1 11v11 visual matrix:
# one footballer at the SAME pitch position, side/front/back diagonals.
# Actual 3D quad + authoritative possession ball + shadow, two cameras.
const CELL := Vector2i(280, 300)
const VIEWS := ["side", "front_diagonal", "back_diagonal"]
# The unit diagonal vectors are normalized at runtime, not const-folded.

func _initialize() -> void:
	var run_dir := OS.get_environment("FOOTBALL_RUN_V3_PREVIEW_DIR")
	var carry_dir := OS.get_environment("FOOTBALL_CARRY_DRIBBLE_PREVIEW_DIR")
	assert(not run_dir.is_empty() and not carry_dir.is_empty())
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	for _i in range(8):
		await process_frame
		await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	var scores: Array = game.score.duplicate()
	var axes: Array[Vector2] = [
		Vector2.RIGHT, Vector2(1.0, 1.0).normalized(),
		Vector2(1.0, -1.0).normalized()
	]
	for team in game.teams:
		for actor in team:
			actor.global_position = Vector2(-9999.0, -9999.0)
			actor.velocity = Vector2.ZERO
			actor.action_lock_seconds = 0.0
	for team_id in range(2):
		var run_meta := ChessFootballRunV3R2.sheet_meta(team_id)
		var carry_meta := ChessFootballCarryDribbleR2.sheet_meta(team_id)
		var name := String(ChessFootballRunV3R2.KINDS[team_id])
		var run_bytes := FileAccess.get_file_as_bytes(run_dir.path_join(name + "_run_v3_clean.webp"))
		var carry_bytes := FileAccess.get_file_as_bytes(carry_dir.path_join(name + "_carry_dribble_v1.webp"))
		var run_image := ChessFootballR2AtlasLoader.decode_verified_webp(
			run_bytes, run_meta, ChessFootballRunV3R2.TRUSTED_ROOT)
		var carry_image := ChessFootballR2AtlasLoader.decode_verified_webp(
			carry_bytes, carry_meta, ChessFootballCarryDribbleR2.TRUSTED_ROOT)
		assert(run_image != null and carry_image != null)
		stage._on_run_v3_ready(run_image, team_id)
		stage._on_carry_dribble_ready(carry_image, team_id)
		assert(stage._run_v3_r2_loaded.has(team_id))
		assert(stage._carry_dribble_r2_loaded.has(team_id))
	for mode in ["broadcast", "tactical"]:
		var sheet := Image.create(CELL.x * VIEWS.size(), CELL.y * 3, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("#23572f"))
		for team_id in range(2):
			var actor: Footballer = game.teams[team_id][1]
			actor.global_position = game.match_pitch.get_center()
			var side_normalized_width := -1.0
			for index in range(VIEWS.size()):
				var axis: Vector2 = axes[index]
				actor.velocity = axis * actor.base_speed
				actor.dribble_burst_seconds = 0.0
				actor.visual.play(&"run")
				actor.visual.frame = 0
				game.ball.attach_to(actor)
				game.ball.tick_ball(0.0)
				var lead: Vector2 = game.ball.global_position - actor.global_position
				assert(lead.dot(axis) > 36.0)
				var key: int = actor.get_instance_id()
				stage.player_run_views[key] = VIEWS[index]
				stage.outfield_visual_names.erase(key)
				stage.outfield_visual_phases.erase(key)
				stage.sync_presentation(0.0, mode)
				var sprite: AnimatedSprite3D = stage.player_sprites[key]
				var expected: StringName = (
					&"carry" if index == 0 else StringName("run_" + VIEWS[index])
				)
				assert(sprite.animation == expected, "The carrier must use correct source view")
				var pose: Texture2D = sprite.sprite_frames.get_frame_texture(expected, sprite.frame)
				var height: float = ChessFootballSpriteBank.frame_height(pose)
				var scaled: float = height * stage._canonical_body_scale(sprite, actor.role, team_id)
				assert(absf(scaled - stage.CANONICAL_BODY_HEIGHT_PIXELS) < 13.0,
					"Carrier jumps in size on orientation switch")
				# The prior test only compared HEIGHT. At exactly the same pitch
				# location and camera, the width must receive the V3 diagonal
				# compensation in the actual QuadMesh transform as well.
				var quad: MeshInstance3D = stage.xi_raster_meshes[key]
				assert(quad.scale == sprite.scale)
				var normalized_width: float = sprite.scale.x / (
					stage._canonical_body_scale(sprite, actor.role, team_id) *
					stage.view_compensation(sprite.animation).x
				)
				if index == 0:
					side_normalized_width = normalized_width
				else:
					var expected_trim: float = stage.xi_v3_diagonal_width_trim(
						sprite.animation, game.match_team_size, false,
						stage._run_v3_r2_loaded.has(team_id)
					)
					assert(is_equal_approx(expected_trim, stage.XI_V3_DIAGONAL_WIDTH_TRIM))
					assert(absf(normalized_width / side_normalized_width - expected_trim) < 0.055,
						"Oblique footballer is still drawn with oversized torso width")
					print("FOOTBALL_XI_V3_DIAGONAL_WIDTH_PARITY team=%d camera=%s view=%s ratio=%.3f"
						% [team_id, mode, VIEWS[index], normalized_width / side_normalized_width])
				await process_frame
				await RenderingServer.frame_post_draw
				var screenshot := game.get_viewport().get_texture().get_image()
				assert(screenshot != null and screenshot.get_size() == Vector2i(1280, 720))
				var center := stage.camera.unproject_position(
					stage.world_to_stage(actor.global_position, stage.PLAYER_BASE_Y)
				)
				var px := clampi(int(center.x) - CELL.x / 2, 0, 1280 - CELL.x)
				var py := clampi(int(center.y) - CELL.y / 2, 0, 720 - CELL.y)
				sheet.blit_rect(screenshot, Rect2i(px, py, CELL.x, CELL.y),
					Vector2i(index * CELL.x, team_id * CELL.y))
			game.ball.release(Vector2.RIGHT, 0.0)
			actor.global_position = Vector2(-9999.0, -9999.0)
		# Third row: three actual rendered stride phases, not three crops
		# of an identical boot-anchored ball. The body stays at one pitch
		# position so the change is the real rolling touch in 3D.
		var touch_runner: Footballer = game.teams[0][1]
		touch_runner.global_position = game.match_pitch.get_center()
		touch_runner.velocity = Vector2.RIGHT * touch_runner.base_speed
		touch_runner.dribble_burst_seconds = 0.0
		touch_runner.visual.play(&"run")
		touch_runner.visual.frame = 0
		var touch_key: int = touch_runner.get_instance_id()
		stage.player_run_views[touch_key] = "side"
		stage.outfield_visual_names.erase(touch_key)
		stage.outfield_visual_phases.erase(touch_key)
		var touch_leads: Array[float] = []
		var samples := [1, 11, 22]
		for sample_id in range(samples.size()):
			game.ball.attach_to(touch_runner)
			stage.ball_node.rotation = Vector3.ZERO
			for _tick in range(samples[sample_id]):
				game.ball.tick_ball(1.0 / 60.0)
				stage._sync_ball_visual_roll(1.0 / 60.0)
			touch_leads.append(
				(game.ball.global_position - touch_runner.global_position).dot(Vector2.RIGHT)
			)
			stage.sync_presentation(0.0, mode)
			for _frame in range(3):
				await process_frame
				await RenderingServer.frame_post_draw
			var touch_screen := game.get_viewport().get_texture().get_image()
			assert(touch_screen != null and touch_screen.get_size() == Vector2i(1280, 720))
			var touch_center := stage.camera.unproject_position(
				stage.world_to_stage(touch_runner.global_position, stage.PLAYER_BASE_Y)
			)
			var touch_px := clampi(int(touch_center.x) - CELL.x / 2, 0, 1280 - CELL.x)
			var touch_py := clampi(int(touch_center.y) - CELL.y / 2, 0, 720 - CELL.y)
			sheet.blit_rect(
				touch_screen, Rect2i(touch_px, touch_py, CELL.x, CELL.y),
				Vector2i(sample_id * CELL.x, 2 * CELL.y)
			)
		assert(touch_leads.max() - touch_leads.min() > 8.0,
			"Actual XI possession ball did not advance between boot touches")
		print("FOOTBALL_XI_CARRY_TOUCH_VISUAL camera=%s gap_min=%.2f gap_max=%.2f"
			% [mode, touch_leads.min(), touch_leads.max()])
		game.ball.release(Vector2.RIGHT, 0.0)
		touch_runner.global_position = Vector2(-9999.0, -9999.0)
		var path: String = "user://xi-carrier-ball-parity-" + mode + ".png"
		assert(sheet.save_png(path) == OK)
		print("FOOTBALL_XI_CARRIER_PARITY_CAPTURE_" + mode.to_upper() + "="
			+ ProjectSettings.globalize_path(path))
	# Pixel-level proof: capture the SAME diagonal and camera twice with
	# identical authored V3 WebPs, once with the width trim disabled and
	# once enabled. A previous CI compared only transforms and uploaded
	# screenshots that were byte-for-byte unchanged; this catches that.
	for mode in ["broadcast", "tactical"]:
		var runner: Footballer = game.teams[0][1]
		var runner_key: int = runner.get_instance_id()
		runner.global_position = game.match_pitch.get_center()
		runner.velocity = axes[1] * runner.base_speed
		runner.dribble_burst_seconds = 0.0
		runner.visual.play(&"run")
		runner.visual.frame = 0
		game.ball.attach_to(runner)
		game.ball.tick_ball(0.0)
		stage.player_run_views[runner_key] = "front_diagonal"
		stage.outfield_visual_names.erase(runner_key)
		stage.outfield_visual_phases.erase(runner_key)
		stage._sync_camera(10.0, mode)
		stage._run_v3_r2_loaded.erase(0)
		stage.sync_presentation(0.0, mode)
		var before_scale_x: float = stage.player_sprites[runner_key].scale.x
		# Give the software renderer several draw submissions after each
		# state switch; a single frame_post_draw can return its prior buffer.
		for _pass in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var without_trim: Image = game.get_viewport().get_texture().get_image()
		stage._run_v3_r2_loaded[0] = true
		stage.sync_presentation(0.0, mode)
		var after_scale_x: float = stage.player_sprites[runner_key].scale.x
		assert(after_scale_x < before_scale_x * 0.90,
			"XI diagonal width trim did not change the real 3D sprite scale")
		for _pass in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var with_trim: Image = game.get_viewport().get_texture().get_image()
		assert(without_trim != null and with_trim != null)
		var screen_center: Vector2 = stage.camera.unproject_position(
			stage.world_to_stage(runner.global_position, stage.PLAYER_BASE_Y)
		)
		var start_x := clampi(int(screen_center.x) - CELL.x / 2, 0, 1280 - CELL.x)
		var start_y := clampi(int(screen_center.y) - CELL.y / 2, 0, 720 - CELL.y)
		var region := Rect2i(start_x, start_y, CELL.x, CELL.y)
		var before_crop := without_trim.get_region(region)
		var after_crop := with_trim.get_region(region)
		var changed_pixels := 0
		for cy in range(CELL.y):
			for cx in range(CELL.x):
				var old_color: Color = before_crop.get_pixel(cx, cy)
				var new_color: Color = after_crop.get_pixel(cx, cy)
				var difference: float = (
					absf(old_color.r - new_color.r)
					+ absf(old_color.g - new_color.g)
					+ absf(old_color.b - new_color.b)
				)
				if difference > 0.24:
					changed_pixels += 1
		var comparison := Image.create(CELL.x * 2, CELL.y, false, Image.FORMAT_RGBA8)
		comparison.blit_rect(before_crop, Rect2i(Vector2i.ZERO, CELL), Vector2i.ZERO)
		comparison.blit_rect(after_crop, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x, 0))
		var compare_path: String = "user://xi-v3-width-on-off-" + mode + ".png"
		assert(comparison.save_png(compare_path) == OK)
		print("FOOTBALL_XI_V3_WIDTH_RENDER_DELTA camera=%s changed_pixels=%d before_scale=%.4f after_scale=%.4f"
			% [mode, changed_pixels, before_scale_x, after_scale_x])
		print("FOOTBALL_XI_V3_WIDTH_CAPTURE_" + mode.to_upper() + "="
			+ ProjectSettings.globalize_path(compare_path))
		if changed_pixels <= 12:
			printerr("V3 width compensation changed transforms but not actual rendered pixels")
			quit(1)
			return
		game.ball.release(Vector2.RIGHT, 0.0)
		runner.global_position = Vector2(-9999.0, -9999.0)
	assert(game.score == scores)
	print("FOOTBALL_XI_CARRIER_PARITY_VISUAL_OK teams=2 views=3 cameras=2 actual_r2=1")
	quit(0)
