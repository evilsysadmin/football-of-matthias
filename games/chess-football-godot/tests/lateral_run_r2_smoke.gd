extends SceneTree

# The two approved side atlases are not yet publicly accredited. Exercise
# their exact hot-swap entirely offline, including corruption and rollback.
func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var presenter: ChessFootball3DPresenter = game.presentation_3d
	assert(presenter != null)
	var config: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://optional_lateral_run_v1.json")
	)
	assert(config is Dictionary)
	assert(config.get("enabled") == false)
	for team_id in range(2):
		assert(ChessFootballSpriteBank.lateral_run_meta(team_id).is_empty())
		var master := ChessFootballSpriteBank._canonical_run_texture(team_id)
		var image := master.get_image()
		if image.has_mipmaps():
			image.clear_mipmaps()
		var textures := ChessFootballSpriteBank.validated_lateral_run_frames(image, team_id)
		assert(textures.size() == 8)
		var corrupt := image.duplicate()
		corrupt.set_pixel(0, 0, Color(1.0, 0.0, 0.0))
		assert(ChessFootballSpriteBank.validated_lateral_run_frames(corrupt, team_id).is_empty())
		var field_players: Array[AnimatedSprite3D] = []
		var keeper_sprite: AnimatedSprite3D = null
		for player in game.teams[team_id]:
			var sprite: AnimatedSprite3D = presenter.player_sprites[player.get_instance_id()]
			if player.role == "keeper":
				keeper_sprite = sprite
			else:
				field_players.append(sprite)
		assert(field_players.size() > 0 and keeper_sprite != null)
		var first := field_players[0]
		var original_side := first.sprite_frames.get_frame_texture(&"run", 0)
		var original_front := first.sprite_frames.get_frame_texture(&"run_front", 0)
		var original_keeper := keeper_sprite.sprite_frames.get_frame_texture(&"run", 0)
		var original_fps := first.sprite_frames.get_animation_speed(&"run")
		var saved_phase := float(presenter.outfield_visual_phases.get(
			game.teams[team_id][1].get_instance_id(), 0.0
		))
		presenter._apply_verified_lateral_run([], team_id)
		assert(first.sprite_frames.get_frame_texture(&"run", 0) == original_side)
		presenter._apply_verified_lateral_run(textures, team_id)
		for sprite in field_players:
			var bank := sprite.sprite_frames
			assert(bank.get_frame_texture(&"run", 0) == textures[0])
			assert(bank.get_frame_texture(&"sprint", 7) == textures[7])
			assert(bank.get_frame_texture(&"shoot", 0) == textures[1])
			assert(bank.get_frame_texture(&"tackle", 0) == textures[5])
			assert(bank.get_frame_texture(&"idle", 0) == textures[0])
			assert(bank.get_animation_speed(&"run") == original_fps)
		assert(keeper_sprite.sprite_frames.get_frame_texture(&"run", 0) == original_keeper)
		assert(first.sprite_frames.get_frame_texture(&"run_front", 0) == original_front)
		assert(is_equal_approx(float(presenter.outfield_visual_phases.get(
			game.teams[team_id][1].get_instance_id(), 0.0
		)), saved_phase))
		for idx in range(8):
			assert(textures[idx].get_image().get_data() == image.get_region(
				Rect2i(idx * 128, 0, 128, 144)
			).get_data())
	print("football lateral R2 staged parity/fallback smoke: OK")
	quit(0)
