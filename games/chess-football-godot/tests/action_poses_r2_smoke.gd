extends SceneTree

# P0: the real 11v11 game may install only the two visually approved dribble
# gestures. The baked-shadow tackle/slide WebPs remain isolated in R2 and
# E / Shift+E continue to show their canonical local animations.
func _synthetic_sheet() -> Image:
	var sheet := Image.create(1024, 144, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for i in range(8):
		sheet.fill_rect(Rect2i(i * 128 + 16, 18, 90, 116),
			Color(0.15 + float(i) * 0.08, 0.65, 0.3, 1.0))
	return sheet


func _initialize() -> void:
	var contract := ChessFootballActionPosesR2.metadata()
	assert(contract.get("version") == 2 and contract.get("enabled") == true)
	assert(contract.get("quality_contract") == "football-approved-r2-action-recomposition-v2")
	assert(contract.get("enabled_actions") == ["dribble_cut", "dribble_burst"])
	assert((contract.get("entries", []) as Array).size() == 8)
	for team_id in range(2):
		for action in ChessFootballActionPosesR2.ANIMATIONS:
			var meta := ChessFootballActionPosesR2.sheet_meta(team_id, action)
			if action not in ChessFootballActionPosesR2.ACTIVE_ANIMATIONS:
				assert(meta.is_empty())
				continue
			assert(not meta.is_empty())
			assert(meta["url"].begins_with(ChessFootballActionPosesR2.TRUSTED_ROOT))
			assert(ChessFootballR2AtlasLoader.decode_verified_webp(
				PackedByteArray([1, 2, 3]), meta,
				ChessFootballActionPosesR2.TRUSTED_ROOT
			) == null)
	assert(ChessFootballActionPosesR2.sheet_meta(0, &"tackle").is_empty())
	assert(ChessFootballActionPosesR2.sheet_meta(1, &"slide_tackle").is_empty())
	assert(ChessFootballActionPosesR2.sheet_meta(2, &"dribble_cut").is_empty())
	assert(ChessFootballActionPosesR2.animation_for(
		&"sprint", "side", "", true, true, "cut") == &"dribble_cut")
	assert(ChessFootballActionPosesR2.animation_for(
		&"run", "side", "", true, true, "burst") == &"dribble_burst")
	for view in ["front", "back", "front_diagonal", "back_diagonal"]:
		assert(ChessFootballActionPosesR2.animation_for(
			&"run", view, "", true, true, "cut") == &"run")
	for blocked in [&"shoot", &"pass", &"tackle", &"slide_tackle"]:
		assert(ChessFootballActionPosesR2.animation_for(
			blocked, "side", "", true, true, "burst") == blocked)
	assert(ChessFootballActionPosesR2.animation_for(
		&"run", "side", "keeper", true, true, "cut") == &"run")
	assert(ChessFootballActionPosesR2.animation_for(
		&"run", "side", "", false, true, "cut") == &"run")

	var sheet := _synthetic_sheet()
	var erased := sheet.duplicate()
	erased.fill_rect(Rect2i(4 * 128, 0, 128, 144), Color.TRANSPARENT)
	assert(ChessFootballActionPosesR2.frames_from_image(erased).is_empty())
	var opaque := sheet.duplicate()
	opaque.set_pixel(0, 0, Color.WHITE)
	assert(ChessFootballActionPosesR2.frames_from_image(opaque).is_empty())
	assert(ChessFootballActionPosesR2.frames_from_image(
		Image.create(1024, 288, false, Image.FORMAT_RGBA8)).is_empty())
	var textures := ChessFootballActionPosesR2.frames_from_image(sheet)
	assert(textures.size() == 8)

	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	var original_score: Array = game.score.duplicate()
	for team_id in range(2):
		var athlete: Footballer = game.teams[team_id][1]
		var keeper: Footballer = game.teams[team_id][0]
		var key := athlete.get_instance_id()
		var sprite: AnimatedSprite3D = stage.player_sprites[key]
		var goalie: AnimatedSprite3D = stage.player_sprites[keeper.get_instance_id()]
		var bank := sprite.sprite_frames
		var original_run := bank.get_frame_texture(&"run", 0)
		var original_pass := bank.get_frame_texture(&"pass", 0)
		var original_standing := bank.get_frame_texture(&"tackle", 0)
		var original_slide := bank.get_frame_texture(&"slide_tackle", 0)
		var original_keeper := goalie.sprite_frames.get_frame_texture(&"tackle", 0)
		for action in ChessFootballActionPosesR2.ACTIVE_ANIMATIONS:
			assert(not bank.has_animation(action))
			stage._apply_verified_action_pose_frames([], team_id, action)
			assert(not bank.has_animation(action))
			stage._apply_verified_action_pose_frames(textures, team_id, action)
			assert(stage._action_poses_r2_loaded.has("%d:%s" % [team_id, String(action)]))
			assert(bank.has_animation(action) and bank.get_frame_count(action) == 8)
			for i in range(8):
				assert(bank.get_frame_texture(action, i) == textures[i])
			stage._apply_verified_action_pose_frames(textures, team_id, action)
			assert(bank.get_frame_count(action) == 8)
		for held in [&"tackle", &"slide_tackle"]:
			stage._apply_verified_action_pose_frames(textures, team_id, held)
			assert(not stage._action_poses_r2_loaded.has("%d:%s" % [team_id, String(held)]))
		assert(bank.get_frame_texture(&"tackle", 0) == original_standing)
		assert(bank.get_frame_texture(&"slide_tackle", 0) == original_slide)
		assert(bank.get_frame_texture(&"pass", 0) == original_pass)
		assert(goalie.sprite_frames.get_frame_texture(&"tackle", 0) == original_keeper)

		game.ball.attach_to(athlete)
		athlete.action_lock_seconds = 0.0
		athlete.velocity = Vector2.RIGHT * maxf(athlete.base_speed, 80.0)
		athlete.visual.play(&"sprint")
		athlete.dribble_duration_seconds = 0.22
		athlete.dribble_burst_seconds = 0.12
		athlete.dribble_mode = "cut"
		stage.player_run_views[key] = "side"
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"dribble_cut")
		athlete.dribble_mode = "burst"
		athlete.dribble_duration_seconds = 0.27
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"dribble_burst")
		athlete.dribble_mode = "feint"
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation not in [&"dribble_cut", &"dribble_burst"])
		athlete.dribble_burst_seconds = 0.0
		athlete.visual.play(&"shoot")
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"shoot")
		game.ball.release(Vector2.RIGHT, 0.0)
		athlete.visual.play(&"tackle")
		athlete.action_lock_seconds = 0.35
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"tackle")
		assert(bank.get_frame_texture(&"tackle", 0) == original_standing)
		athlete.visual.play(&"slide_tackle")
		athlete.action_lock_seconds = 0.32
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"slide_tackle")
		assert(bank.get_frame_texture(&"slide_tackle", 0) == original_slide)
		assert(bank.get_frame_texture(&"run", 0) == original_run)

	assert(game.score == original_score)
	print("FOOTBALL_ACTION_POSES_R2_SMOKE_OK clubs=2 active_dribbles=2 held_tackles=2 frames=8 fallback=1 visual_only=1")
	quit(0)
