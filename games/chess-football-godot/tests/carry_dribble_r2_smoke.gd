extends SceneTree

# No network, no binary art in Git. This tests the pending animation overlay
# with synthetic textures and guarantees unchanged real match authority.
func _initialize() -> void:
	var contract := ChessFootballCarryDribbleR2.metadata()
	assert(contract.get("enabled") == false)
	assert(contract.get("bucket") == "football")
	assert(contract.get("prefix") == "atlases/v1/")
	assert((contract.get("entries", []) as Array).size() == 2)
	assert(ChessFootballCarryDribbleR2.sheet_meta(0).is_empty())
	assert(ChessFootballCarryDribbleR2.sheet_meta(1).is_empty())
	assert(ChessFootballCarryDribbleR2.sheet_meta(2).is_empty())
	assert(ChessFootballCarryDribbleR2.animation_for(&"run", "side", "", true, false) == &"carry")
	assert(ChessFootballCarryDribbleR2.animation_for(&"sprint", "side", "", true, true) == &"dribble")
	for direction in ["front", "back", "front_diagonal", "back_diagonal"]:
		assert(ChessFootballCarryDribbleR2.animation_for(&"run", direction, "", true, true) == &"run")
	assert(ChessFootballCarryDribbleR2.animation_for(&"run", "side", "", false, true) == &"run")
	assert(ChessFootballCarryDribbleR2.animation_for(&"run", "side", "keeper", true, true) == &"run")
	for name in [&"pass", &"shoot", &"tackle", &"slide_tackle", &"celebrate", &"idle"]:
		assert(ChessFootballCarryDribbleR2.animation_for(name, "side", "", true, true) == name)

	var bad := Image.create(128, 144, false, Image.FORMAT_RGBA8)
	assert(ChessFootballCarryDribbleR2.frames_from_image(bad).is_empty())
	var source := Image.create(1024, 288, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	for row in range(2):
		for col in range(8):
			source.fill_rect(Rect2i(col * 128 + 28, row * 144 + 12, 70, 120), Color("#4577cc"))
	var broken := source.duplicate()
	broken.fill_rect(Rect2i(0, 0, 128, 144), Color.TRANSPARENT)
	assert(ChessFootballCarryDribbleR2.frames_from_image(broken).is_empty())
	var textures := ChessFootballCarryDribbleR2.frames_from_image(source)
	assert(textures.size() == 16)

	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null)
	var original_score: Array = game.score.duplicate()
	for team_id in range(2):
		var player: Footballer = game.teams[team_id][1]
		var keeper: Footballer = game.teams[team_id][0]
		var key := player.get_instance_id()
		var sprite: AnimatedSprite3D = stage.player_sprites[key]
		var goalie: AnimatedSprite3D = stage.player_sprites[keeper.get_instance_id()]
		var frames := sprite.sprite_frames
		var original_run := frames.get_frame_texture(&"run", 0)
		var original_idle := frames.get_frame_texture(&"idle", 0)
		var original_pass := frames.get_frame_texture(&"pass", 0)
		var original_shoot := frames.get_frame_texture(&"shoot", 0)
		var original_keeper := goalie.sprite_frames.get_frame_texture(&"run", 0)
		assert(not frames.has_animation(&"carry") and not frames.has_animation(&"dribble"))
		stage._apply_verified_carry_dribble_frames([], team_id)
		assert(not frames.has_animation(&"carry"))
		stage._apply_verified_carry_dribble_frames(textures, team_id)
		assert(stage._carry_dribble_r2_loaded.has(team_id))
		for row in range(2):
			var action: StringName = ChessFootballCarryDribbleR2.ANIMATIONS[row]
			assert(frames.get_frame_count(action) == 8)
			assert(frames.get_animation_speed(action) == (12.0 if row == 0 else 36.0))
			assert(frames.get_animation_loop(action) == (row == 0))
			for col in range(8):
				assert(frames.get_frame_texture(action, col) == textures[row * 8 + col])
		assert(frames.get_frame_texture(&"run", 0) == original_run)
		assert(frames.get_frame_texture(&"idle", 0) == original_idle)
		assert(frames.get_frame_texture(&"pass", 0) == original_pass)
		assert(frames.get_frame_texture(&"shoot", 0) == original_shoot)
		assert(goalie.sprite_frames.get_frame_texture(&"run", 0) == original_keeper)

		# Renderer checks the real ball carrier, not a parallel possession state.
		game.ball.attach_to(player)
		player.velocity = Vector2.RIGHT * maxf(player.base_speed, 80.0)
		player.action_lock_seconds = 0.0
		player.dribble_burst_seconds = 0.0
		player.visual.play(&"run")
		stage.sync_presentation(0.016, "broadcast")
		assert(sprite.animation == &"carry", "Side-facing ball carrier must show carry")
		player.dribble_burst_seconds = 0.12
		player.visual.play(&"sprint")
		stage.sync_presentation(0.016, "broadcast")
		assert(sprite.animation == &"dribble", "Active dribble burst must show dribble")
		player.dribble_burst_seconds = 0.0
		player.visual.play(&"shoot")
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"shoot", "Shot action must never be overridden")
		game.ball.release(Vector2.RIGHT, 0.0)
		player.visual.play(&"run")
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"run", "Off-ball athlete must use canonical run")
	assert(game.score == original_score)
	print("football carry/dribble R2 optional visual states, all-or-nothing and fallback: OK")
	quit(0)
