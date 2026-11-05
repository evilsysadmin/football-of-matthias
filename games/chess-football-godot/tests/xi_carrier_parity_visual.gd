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
		var sheet := Image.create(CELL.x * VIEWS.size(), CELL.y * 2, false, Image.FORMAT_RGBA8)
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
		var path: String = "user://xi-carrier-ball-parity-" + mode + ".png"
		assert(sheet.save_png(path) == OK)
		print("FOOTBALL_XI_CARRIER_PARITY_CAPTURE_" + mode.to_upper() + "="
			+ ProjectSettings.globalize_path(path))
	assert(game.score == scores)
	print("FOOTBALL_XI_CARRIER_PARITY_VISUAL_OK teams=2 views=3 cameras=2 actual_r2=1")
	quit(0)
