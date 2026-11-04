extends SceneTree

# Genuine 1280x720 Godot 3D captures. Published R2 bytes are independently
# HTTP/CORS/SHA-checked by CI, then decoded by the exact Godot runtime loader.
# Two clubs x (carry, dribble) x three frames, before and after, two cameras.
const CROP := Vector2i(260, 480)
const PHASES := [0, 3, 7]
const ACTIONS := [&"carry", &"dribble"]

func _initialize() -> void:
	var directory := OS.get_environment("FOOTBALL_CARRY_DRIBBLE_PREVIEW_DIR")
	assert(not directory.is_empty(), "Missing CI R2 verification directory")
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
	var scores_before: Array = game.score.duplicate()
	var actors: Array[Footballer] = [game.teams[0][1], game.teams[1][1]]
	for team in game.teams:
		for player in team:
			player.velocity = Vector2.ZERO
			player.action_lock_seconds = 0.0
			player.global_position = Vector2(-9999.0, -9999.0)
	game.ball.global_position = Vector2(-9999.0, -9999.0)

	for mode in ["broadcast", "tactical"]:
		var before := await _matrix(game, stage, actors, mode, false)
		await _save(before, "BEFORE_" + mode.to_upper(), "carry-dribble-before-" + mode + ".png")

	for team_id in range(2):
		var meta := ChessFootballCarryDribbleR2.sheet_meta(team_id)
		assert(not meta.is_empty(), "Enabled carry/dribble metadata missing")
		var filename := String(ChessFootballCarryDribbleR2.KINDS[team_id]) + "_carry_dribble_v1.webp"
		var path := directory.path_join(filename)
		assert(FileAccess.file_exists(path), "R2 WebP not downloaded: " + path)
		var raw := FileAccess.get_file_as_bytes(path)
		var decoded := ChessFootballR2AtlasLoader.decode_verified_webp(
			raw, meta, ChessFootballCarryDribbleR2.TRUSTED_ROOT
		)
		assert(decoded != null, "Godot rejects R2 SHA, WebP or dimensions: " + filename)
		stage._on_carry_dribble_ready(decoded, team_id)
		assert(stage._carry_dribble_r2_loaded.has(team_id))
		for player in game.teams[team_id]:
			if player.role == "keeper":
				continue
			var driver: AnimatedSprite3D = stage.player_sprites[player.get_instance_id()]
			for action in ACTIONS:
				assert(driver.sprite_frames.has_animation(action))
				assert(driver.sprite_frames.get_frame_count(action) == 8)

	for mode in ["broadcast", "tactical"]:
		var after := await _matrix(game, stage, actors, mode, true)
		await _save(after, "AFTER_" + mode.to_upper(), "carry-dribble-after-" + mode + ".png")
	assert(game.score == scores_before)
	print("FOOTBALL_CARRY_DRIBBLE_REAL_GODOT_REVIEW_OK teams=2 actions=2 phases=3 cameras=2")
	quit(0)


func _matrix(game: Node, stage: ChessFootball3DPresenter,
		actors: Array[Footballer], mode: String, with_new: bool) -> Image:
	var sheet := Image.create(CROP.x * 6, CROP.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#103a2d"))
	for team_id in range(2):
		var actor: Footballer = actors[team_id]
		actor.global_position = game.match_pitch.get_center()
		game.ball.attach_to(actor)
		assert(game.ball.carrier == actor and actor.has_ball)
		for action_row in range(ACTIONS.size()):
			for phase_index in range(PHASES.size()):
				var pose: int = int(PHASES[phase_index])
				var crop := await _capture(game, stage, actor, ACTIONS[action_row],
					pose, mode, with_new)
				sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, CROP),
					Vector2i((team_id * 3 + phase_index) * CROP.x, action_row * CROP.y))
		actor.global_position = Vector2(-9999.0, -9999.0)
	return sheet


func _capture(game: Node, stage: ChessFootball3DPresenter,
		actor: Footballer, action: StringName, pose: int,
		mode: String, with_new: bool) -> Image:
	var key := actor.get_instance_id()
	actor.velocity = Vector2.RIGHT * maxf(actor.base_speed, 80.0)
	actor.action_lock_seconds = 0.0
	actor.dribble_burst_seconds = 0.12 if action == &"dribble" else 0.0
	var base_action: StringName = &"sprint" if action == &"dribble" else &"run"
	actor.visual.play(base_action)
	actor.visual.frame = 0
	game.ball.global_position = actor.global_position + actor.ball_anchor()
	stage.player_run_views[key] = "side"
	stage.sync_presentation(0.0, mode)
	var expected: StringName = action if with_new else base_action
	assert(stage.player_sprites[key].animation == expected,
		"Carrier side-view action not routed to expected sprite")
	stage.outfield_visual_names[key] = expected
	stage.outfield_visual_phases[key] = float(pose)
	stage.sync_presentation(0.0, mode)
	var driver: AnimatedSprite3D = stage.player_sprites[key]
	assert(driver.frame == pose, "3D phase not applied to current action")
	var quad: MeshInstance3D = stage.xi_raster_meshes[key]
	assert(quad.is_visible_in_tree(), "XI carrier raster not visible")
	assert((quad.material_override as StandardMaterial3D).albedo_texture
		== driver.sprite_frames.get_frame_texture(expected, pose),
		"Visible quad must use exact action frame")
	assert(game.ball.carrier == actor and actor.has_ball)
	var target := stage.world_to_stage(actor.global_position)
	if mode == "tactical":
		stage.camera.position = target + Vector3(0.0, 9.0, 0.1)
	else:
		stage.camera.position = target + Vector3(0.0, 1.7, 4.8)
	stage.camera.look_at(target + Vector3(0.0, 0.85, 0.0), Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport_image := game.get_viewport().get_texture().get_image()
	assert(viewport_image != null and viewport_image.get_size() == Vector2i(1280, 720))
	var center: Vector2 = stage.camera.unproject_position(driver.global_position)
	var x := clampi(int(center.x) - CROP.x / 2, 0, viewport_image.get_width() - CROP.x)
	var y_bias := 100 if mode == "tactical" else 0
	var y := clampi(int(center.y) - CROP.y / 2 - y_bias, 0, viewport_image.get_height() - CROP.y)
	return viewport_image.get_region(Rect2i(x, y, CROP.x, CROP.y))


func _save(sheet: Image, tag: String, filename: String) -> void:
	var path := "user://" + filename
	assert(sheet.save_png(path) == OK)
	print("FOOTBALL_CARRY_DRIBBLE_CAPTURE_" + tag + "=" + ProjectSettings.globalize_path(path))
