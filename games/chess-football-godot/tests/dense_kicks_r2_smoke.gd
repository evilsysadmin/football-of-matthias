extends SceneTree

func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	var directory := OS.get_environment("RUNNER_TEMP").path_join("football-dense-v1")
	var owner = game.ball.carrier
	for club in range(2):
		var actor: Footballer = game.teams[club][1]
		var sprite: AnimatedSprite3D = stage.player_sprites[actor.get_instance_id()]
		var keeper: AnimatedSprite3D = stage.player_sprites[game.teams[club][0].get_instance_id()]
		var keeper_before := keeper.sprite_frames.get_frame_texture(&"shoot", 0)
		var run_before := sprite.sprite_frames.get_frame_texture(&"run", 0)
		# A pass and a shot can be in flight when the second R2 sheet
		# arrives. Exercise both active action clocks independently.
		var shooter: Footballer = game.teams[club][2]
		var shot_driver: AnimatedSprite3D = stage.player_sprites[shooter.get_instance_id()]
		actor.play_action("pass", 0.58)
		shooter.play_action("shoot", 0.82)
		actor.action_lock_seconds = 0.58 * 0.40
		shooter.action_lock_seconds = 0.82 * 0.20
		stage._sync_visible_animation(actor.get_instance_id(), actor, sprite, &"pass", 0.0)
		stage._sync_visible_animation(shooter.get_instance_id(), shooter, shot_driver, &"shoot", 0.0)
		assert(sprite.frame == 4 and shot_driver.frame == 6)
		for action in ChessFootballDenseV1R2.ACTIONS:
			var meta := ChessFootballDenseV1R2.sheet_meta(club, action)
			assert(not meta.is_empty())
			var filename: String = String(meta["url"]).get_file()
			var decoded := ChessFootballR2AtlasLoader.decode_verified_webp(
				FileAccess.get_file_as_bytes(directory.path_join(filename)), meta, ChessFootballDenseV1R2.TRUSTED_ROOT)
			assert(decoded != null)
			stage._on_dense_kick_ready(decoded, club, action)
			if action == &"pass":
				assert(sprite.sprite_frames.get_frame_count(&"pass") == 8)
				assert(not stage._dense_kick_loaded.has(club))
		assert(stage._dense_kick_loaded.has(club))
		assert(sprite.animation == &"pass" and sprite.frame == 9)
		assert(shot_driver.animation == &"shoot" and shot_driver.frame == 12)
		assert(float(stage.outfield_visual_phases[actor.get_instance_id()]) == 9.0)
		assert(float(stage.outfield_visual_phases[shooter.get_instance_id()]) == 12.0)
		assert(is_equal_approx(actor.action_lock_seconds, 0.58 * 0.40))
		assert(is_equal_approx(shooter.action_lock_seconds, 0.82 * 0.20))
		actor.action_lock_seconds = 0.0
		shooter.action_lock_seconds = 0.0
		for teammate: Footballer in game.teams[club]:
			if teammate.role == "keeper":
				continue
			var driver: AnimatedSprite3D = stage.player_sprites[teammate.get_instance_id()]
			for action in ChessFootballDenseV1R2.ACTIONS:
				assert(driver.sprite_frames.get_frame_count(action) == 16)
				assert(not driver.sprite_frames.get_animation_loop(action))
		assert(keeper.sprite_frames.get_frame_texture(&"shoot", 0) == keeper_before)
		assert(sprite.sprite_frames.get_frame_texture(&"run", 0) == run_before)
		assert(game.ball.carrier == owner)
		var diagonal_meta := ChessFootballDenseV1R2.sheet_meta(club, &"run_front_diagonal")
		assert(not diagonal_meta.is_empty())
		var diagonal := ChessFootballR2AtlasLoader.decode_verified_webp(
			FileAccess.get_file_as_bytes(directory.path_join(String(diagonal_meta["url"]).get_file())),
			diagonal_meta, ChessFootballDenseV1R2.TRUSTED_ROOT)
		assert(diagonal != null)
		var diagonal_count: int = sprite.sprite_frames.get_frame_count(&"run_front_diagonal")
		stage._on_dense_diagonal_ready(diagonal, club)
		assert(not stage._dense_diagonal_loaded.has(club))
		assert(sprite.sprite_frames.get_frame_count(&"run_front_diagonal") == diagonal_count)
		# Exercise arrival precedence with a synthetic V5 bank; the dense
		# poses themselves are actual SHA-verified public R2 textures.
		var v5: Array[Texture2D] = []
		for i in range(48):
			v5.append(run_before)
		stage._apply_hero_v5_locomotion(v5, club)
		assert(stage._hero_v5_loaded.has("%d:locomotion" % club))
		var bank := sprite.sprite_frames
		var front_before := bank.get_frame_texture(&"run_front", 0)
		var back_before := bank.get_frame_texture(&"run_back_diagonal", 0)
		var old_fps := bank.get_animation_speed(&"run_front_diagonal")
		sprite.play(&"run_front_diagonal")
		sprite.pause()
		stage.outfield_visual_phases[actor.get_instance_id()] = 10.0
		stage._on_dense_diagonal_ready(diagonal, club)
		assert(stage._dense_diagonal_loaded.has(club))
		assert(sprite.frame == 15)
		assert(is_equal_approx(float(stage.outfield_visual_phases[actor.get_instance_id()]), 15.0))
		assert(is_equal_approx(bank.get_animation_speed(&"run_front_diagonal"), old_fps * 1.5))
		for teammate: Footballer in game.teams[club]:
			if teammate.role == "keeper":
				continue
			var driver: AnimatedSprite3D = stage.player_sprites[teammate.get_instance_id()]
			for name in [&"run_front_diagonal", &"sprint_front_diagonal"]:
				assert(driver.sprite_frames.get_frame_count(name) == 24)
				assert(driver.sprite_frames.get_animation_loop(name))
		var first := bank.get_frame_texture(&"run_front_diagonal", 0)
		stage._apply_hero_v5_locomotion(v5, club)
		stage._on_dense_diagonal_ready(diagonal, club)
		assert(bank.get_frame_texture(&"run_front_diagonal", 0) == first)
		assert(bank.get_frame_texture(&"run_front", 0) == front_before)
		assert(bank.get_frame_texture(&"run_back_diagonal", 0) == back_before)
		assert(bank.get_frame_texture(&"run", 0) == run_before)
		assert(game.ball.carrier == owner)
	print("FOOTBALL_DENSE_DIAGONAL_NATIVE_OK clubs=2 frames=24 phase=true precedence=true")
	print("FOOTBALL_DENSE_KICKS_NATIVE_OK teams=2 frames=16 atomic=true")
	quit(0)
