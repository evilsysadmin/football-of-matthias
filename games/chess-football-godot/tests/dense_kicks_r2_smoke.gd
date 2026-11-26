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
	print("FOOTBALL_DENSE_KICKS_NATIVE_OK teams=2 frames=16 atomic=true")
	quit(0)
