extends SceneTree

# Offline action-pack contract: real 11v11 actors, no R2 credentials or art
# in Git. The required workflow separately authenticates all public bytes.
func _synthetic_sheet() -> Image:
	var sheet := Image.create(1024, 144, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for i in range(8):
		var top := 73 if i == 4 else 18
		var height := 61 if i == 4 else 116
		sheet.fill_rect(Rect2i(i * 128 + 16, top, 90, height),
			Color(0.15 + float(i) * 0.08, 0.65, 0.3, 1.0))
	return sheet


func _initialize() -> void:
	var contract := ChessFootballActionPosesR2.metadata()
	assert(contract.get("enabled") == true)
	assert(contract.get("quality_contract") == "football-approved-r2-action-recomposition-v2")
	assert((contract.get("entries", []) as Array).size() == 8)
	assert(contract.get("enabled_actions") == ["dribble_cut", "dribble_burst"])
	for team_id in range(2):
		var original_standing: Texture2D = bank.get_frame_texture(&"tackle", 0)
		var original_slide: Texture2D = bank.get_frame_texture(&"slide_tackle", 0)
		for action in ChessFootballActionPosesR2.ACTIVE_ANIMATIONS:
			stage._apply_verified_action_pose_frames([], team_id, action)
			assert(not bank.has_animation(action))
			stage._apply_verified_action_pose_frames(textures, team_id, action)
			assert(stage._action_poses_r2_loaded.has("%d:%s" % [team_id, String(action)]))
			assert(bank.has_animation(action) and bank.get_frame_count(action) == 8)
			assert(not bank.get_animation_loop(action))
			for i in range(8):
				assert(bank.get_frame_texture(action, i) == textures[i])
			stage._apply_verified_action_pose_frames(textures, team_id, action)
			assert(bank.get_frame_count(action) == 8)
		for held_action in [&"tackle", &"slide_tackle"]:
			stage._apply_verified_action_pose_frames(textures, team_id, held_action)
			assert(not stage._action_poses_r2_loaded.has(
				"%d:%s" % [team_id, String(held_action)]
			))
		assert(bank.get_frame_texture(&"tackle", 0) == original_standing)
		assert(bank.get_frame_texture(&"slide_tackle", 0) == original_slide)
		assert(bank.get_frame_texture(&"run", 0) == original_run)
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
		assert(sprite.animation != &"dribble_burst")
		assert(sprite.animation != &"dribble_cut")
		athlete.dribble_burst_seconds = 0.0
		athlete.visual.play(&"shoot")
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"shoot")
		game.ball.release(Vector2.RIGHT, 0.0)
		# E and Shift+E still animate via canonical fallbacks. The rejected
		# baked-shadow slide must NEVER be installed by the v2 loader.
		athlete.visual.play(&"tackle")
		athlete.action_visual_duration_seconds = 0.50
		athlete.action_lock_seconds = 0.35
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"tackle")
		assert(sprite.sprite_frames.get_frame_texture(&"tackle", 0) == original_standing)
		athlete.visual.play(&"slide_tackle")
		athlete.action_visual_duration_seconds = 0.64
		athlete.action_lock_seconds = 0.32
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"slide_tackle")
		assert(sprite.sprite_frames.get_frame_texture(&"slide_tackle", 0) == original_slide)
		assert(bank.get_frame_texture(&"run", 0) == original_run)

	assert(game.score == original_score)
	print("FOOTBALL_ACTION_POSES_R2_SMOKE_OK clubs=2 active_dribbles=2 held_tackles=2 frames=8 fallback=1 visual_only=1")
	quit(0)
