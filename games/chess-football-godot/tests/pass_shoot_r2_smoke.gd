extends SceneTree

# No network, no binaries in Git: the pending action sheets cannot affect
# any player until a whole SHA-verified club atlas becomes available.
func _initialize() -> void:
	var contract := ChessFootballPassShootR2.metadata()
	assert(contract.get("enabled") == true)
	assert(contract.get("bucket") == "football")
	assert(contract.get("prefix") == "atlases/v1/")
	assert((contract.get("entries", []) as Array).size() == 2)
	assert(not ChessFootballPassShootR2.sheet_meta(0).is_empty())
	assert(not ChessFootballPassShootR2.sheet_meta(1).is_empty())
	assert(ChessFootballPassShootR2.sheet_meta(0)["sha256"] == contract["entries"][0]["sha256"])
	assert(ChessFootballPassShootR2.sheet_meta(1)["sha256"] == contract["entries"][1]["sha256"])
	assert(ChessFootballPassShootR2.sheet_meta(3).is_empty())
	assert(ChessFootballPassShootR2.frames_from_image(
		Image.create(128, 144, false, Image.FORMAT_RGBA8)
	).is_empty())

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

	var image := Image.create(1024, 288, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for row in range(2):
		for col in range(8):
			image.fill_rect(Rect2i(col * 128 + 28, row * 144 + 12, 72, 120), Color("#4f80ce"))
	var invalid := image.duplicate()
	invalid.fill_rect(Rect2i(0, 0, 128, 144), Color.TRANSPARENT)
	assert(ChessFootballPassShootR2.frames_from_image(invalid).is_empty())
	var textures := ChessFootballPassShootR2.frames_from_image(image)
	assert(textures.size() == 16)
	for team_id in range(2):
		var outfielder: Footballer = game.teams[team_id][1]
		var keeper: Footballer = game.teams[team_id][0]
		var out_sprite: AnimatedSprite3D = presenter.player_sprites[outfielder.get_instance_id()]
		var keep_sprite: AnimatedSprite3D = presenter.player_sprites[keeper.get_instance_id()]
		var bank := out_sprite.sprite_frames
		var run_before := bank.get_frame_texture(&"run", 0)
		var idle_before := bank.get_frame_texture(&"idle", 0)
		var tackle_before := bank.get_frame_texture(&"tackle", 0)
		var keeper_before := keep_sprite.sprite_frames.get_frame_texture(&"shoot", 0)
		var pass_before := bank.get_frame_texture(&"pass", 0)
		presenter._apply_verified_pass_shoot_frames([], team_id)
		assert(bank.get_frame_texture(&"pass", 0) == pass_before)
		presenter._apply_verified_pass_shoot_frames(textures, team_id)
		assert(bool(presenter._pass_shoot_r2_loaded.get(team_id, false)))
		for anim_row in range(2):
			var name: StringName = ChessFootballPassShootR2.ANIMATIONS[anim_row]
			assert(bank.get_frame_count(name) == 8)
			assert(bank.get_animation_speed(name) == 10.0)
			assert(not bank.get_animation_loop(name))
			for i in range(8):
				assert(bank.get_frame_texture(name, i) == textures[anim_row * 8 + i])
		assert(bank.get_frame_texture(&"run", 0) == run_before)
		assert(bank.get_frame_texture(&"idle", 0) == idle_before)
		assert(bank.get_frame_texture(&"tackle", 0) == tackle_before)
		assert(keep_sprite.sprite_frames.get_frame_texture(&"shoot", 0) == keeper_before)

		# The legacy lateral sheet may arrive AFTER the new action sheet:
		# it cannot silently undo either approved kick sequence.
		var legacy: Array[Texture2D] = []
		for i in range(8):
			legacy.append(bank.get_frame_texture(&"run", i))
		presenter._apply_verified_lateral_run(legacy, team_id)
		assert(bank.get_frame_texture(&"pass", 0) == textures[0])
		assert(bank.get_frame_texture(&"shoot", 7) == textures[15])
	print("football optional R2 pass/shoot sheets, atomic frames and fallback: OK")
	quit(0)
