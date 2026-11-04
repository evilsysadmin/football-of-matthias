extends SceneTree

# Offline verification: no CDN required. All 22 actor SpriteFrames are updated
# only after a complete 5x8 sheet passes integrity/silhouette validation.
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

	var sheet := Image.create(1024, 720, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for row in range(5):
		for column in range(8):
			sheet.fill_rect(
				Rect2i(column * 128 + 36, row * 144 + 8, 56, 124),
				Color("#e2ae28") if row == 2 else Color("#4588d2")
			)
	var malformed := sheet.duplicate()
	malformed.fill_rect(Rect2i(0, 0, 128, 144), Color.TRANSPARENT)
	assert(ChessFootballIdleR2.frames_from_image(malformed, "keeper").is_empty())
	assert(ChessFootballIdleR2.frames_from_image(Image.create(128, 144, false, Image.FORMAT_RGBA8), "keeper").is_empty())

	var bytes := sheet.save_webp_to_buffer(false)
	var hash := HashingContext.new()
	assert(hash.start(HashingContext.HASH_SHA256) == OK)
	assert(hash.update(bytes) == OK)
	for kind in ChessFootballIdleR2.KINDS:
		var meta := ChessFootballIdleR2.sheet_meta(kind)
		assert(not meta.is_empty())
		assert(ChessFootballR2AtlasLoader.valid_metadata(meta, ChessFootballIdleR2.TRUSTED_ROOT))
		assert(ChessFootballR2AtlasLoader.decode_verified_webp(bytes, meta, ChessFootballIdleR2.TRUSTED_ROOT) == null)
		var fixture: Dictionary = meta.duplicate(true)
		fixture["sha256"] = hash.finish().hex_encode() if kind == "fc_matthias" else fixture["sha256"]
		# Rebuild the fixture hash for the independent club/keeper cases.
		if kind != "fc_matthias":
			var each_hash := HashingContext.new()
			assert(each_hash.start(HashingContext.HASH_SHA256) == OK)
			assert(each_hash.update(bytes) == OK)
			fixture["sha256"] = each_hash.finish().hex_encode()
		var decoded := ChessFootballR2AtlasLoader.decode_verified_webp(
			bytes, fixture, ChessFootballIdleR2.TRUSTED_ROOT
		)
		assert(decoded != null and decoded.get_size() == Vector2i(1024, 720))
		var textures := ChessFootballIdleR2.frames_from_image(sheet, kind)
		assert(textures.size() == 40)
		var teal_textures: Array[Texture2D] = []
		if kind == "keeper":
			teal_textures = ChessFootballIdleR2.frames_from_image(sheet, kind, true)
			assert(teal_textures.size() == 40)
		var before_run := {}
		for team in game.teams:
			for player in team:
				var actor_kind := "keeper" if player.role == "keeper" else (
					"fc_matthias" if player.team_id == 0 else "real_enroque"
				)
				if actor_kind == kind:
					var actor: AnimatedSprite3D = presenter.player_sprites[player.get_instance_id()]
					before_run[player.get_instance_id()] = actor.sprite_frames.get_frame_texture(&"run", 0)
		presenter._apply_animated_idle_frames(kind, textures, teal_textures)
		assert(bool(presenter._animated_idle_r2_loaded.get(kind, false)))
		for team in game.teams:
			for player in team:
				var actor_kind := "keeper" if player.role == "keeper" else (
					"fc_matthias" if player.team_id == 0 else "real_enroque"
				)
				if actor_kind != kind:
					continue
				var sprite: AnimatedSprite3D = presenter.player_sprites[player.get_instance_id()]
				var bank := sprite.sprite_frames
				assert(bank.get_frame_texture(&"run", 0) == before_run[player.get_instance_id()])
				for row in range(5):
					var anim := StringName(ChessFootballIdleR2.IDLE_ANIMATIONS[row])
					assert(bank.has_animation(anim))
					assert(bank.get_frame_count(anim) == 8)
					assert(bank.get_animation_speed(anim) == 7.0)
					assert(bank.get_animation_loop(anim))
					var expected := teal_textures if kind == "keeper" and player.team_id == 1 else textures
					assert(bank.get_frame_texture(anim, 0) == expected[row * 8])
				player.action_lock_seconds = 0.0
				player.velocity = Vector2.DOWN * player.base_speed
				player._sync_locomotion(false)
				presenter.sync_presentation(1.0 / 60.0, "broadcast")
				player.velocity = Vector2.ZERO
				player._sync_locomotion(false)
				var seen := {}
				for tick in range(34):
					presenter.sync_presentation(1.0 / 60.0, "broadcast")
					assert(sprite.animation == &"idle_front")
					seen[sprite.frame] = true
				assert(seen.size() >= 3)
				assert(not sprite.is_playing())
	# A legacy one-frame response arriving after the new atlas must not
	# overwrite its first frontal texture.
	var legacy_textures: Array[Texture2D] = []
	for i in range(4):
		legacy_textures.append(ChessFootballIdleR2.frames_from_image(sheet, "fc_matthias")[0])
	var first = game.teams[0][1]
	var first_sprite: AnimatedSprite3D = presenter.player_sprites[first.get_instance_id()]
	var animated_start := first_sprite.sprite_frames.get_frame_texture(&"idle_front", 0)
	presenter._apply_idle_front_textures(legacy_textures)
	assert(first_sprite.sprite_frames.get_frame_texture(&"idle_front", 0) == animated_start)
	print("football R2 5-view animated idle, 8-frame phase, 22 actors and fallback: OK")
	quit(0)
