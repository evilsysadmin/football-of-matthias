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
			# Valid breathing frames vary their alpha height but share one
			# planted boot line. Their RENDER scale must not oscillate.
			var top := 8 + (column % 4) * 3
			sheet.fill_rect(
				Rect2i(column * 128 + 36, row * 144 + top, 56, 132 - top),
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

	# XI used to normalize every animated idle frame independently. A single
	# breathing cycle then inflated/deflated a stationary footballer despite
	# the sprites sharing the same planted footline.
	var xi = packed.instantiate()
	xi.match_team_size = 11
	root.add_child(xi)
	await process_frame
	await process_frame
	xi.set_process(false)
	xi.set_physics_process(false)
	var xi_presenter: ChessFootball3DPresenter = xi.presentation_3d
	assert(xi_presenter != null)
	var xi_actor: Footballer = xi.teams[0][1]
	var xi_sprite: AnimatedSprite3D = xi_presenter.player_sprites[xi_actor.get_instance_id()]
	var xi_textures := ChessFootballIdleR2.frames_from_image(sheet, "fc_matthias")
	assert(xi_textures.size() == 40)
	xi_presenter._apply_animated_idle_frames("fc_matthias", xi_textures, [])
	xi_sprite.play(&"idle_front")
	xi_sprite.pause()
	var stable_scale := -1.0
	var measured_heights: Array[float] = []
	for frame_id in range(8):
		xi_sprite.frame = frame_id
		measured_heights.append(ChessFootballSpriteBank.frame_height(
			xi_sprite.sprite_frames.get_frame_texture(&"idle_front", frame_id)
		))
		var frame_scale := xi_presenter._canonical_body_scale(
			xi_sprite, xi_actor.role, xi_actor.team_id
		)
		if frame_id == 0:
			stable_scale = frame_scale
		else:
			assert(is_equal_approx(frame_scale, stable_scale),
				"XI idle breathing cannot rescale the footballer every frame")
	assert(measured_heights.max() - measured_heights.min() >= 8.0)
	var idle_key := "idle:%s:%d:%s" % [xi_actor.role, xi_actor.team_id, "idle_front"]
	assert(xi_presenter.body_scale_cache.has(idle_key))
	var original_position: Vector2 = xi_actor.global_position
	var original_velocity: Vector2 = xi_actor.velocity
	# A later verified atlas replacement changes the source height. Only
	# the derived size cache is invalidated, not positions or match authority.
	var revised := Image.create(1024, 720, false, Image.FORMAT_RGBA8)
	revised.fill(Color.TRANSPARENT)
	for row in range(5):
		for column in range(8):
			var revised_top := 18 + column % 2
			revised.fill_rect(
				Rect2i(column * 128 + 36, row * 144 + revised_top, 56, 132 - revised_top),
				Color("#4588d2")
			)
	var revised_textures := ChessFootballIdleR2.frames_from_image(revised, "fc_matthias")
	assert(revised_textures.size() == 40)
	xi_presenter._apply_animated_idle_frames("fc_matthias", revised_textures, [])
	assert(not xi_presenter.body_scale_cache.has(idle_key))
	xi_sprite.frame = 0
	var revised_scale := xi_presenter._canonical_body_scale(
		xi_sprite, xi_actor.role, xi_actor.team_id
	)
	assert(revised_scale > stable_scale + 0.02)
	assert(xi_actor.global_position == original_position)
	assert(xi_actor.velocity == original_velocity)
	assert(xi.match_team_size == 11)
	print("FOOTBALL_XI_ANIMATED_IDLE_STABLE_SCALE_OK frames=8 teams=2 atlas_refresh=1")
	print("football R2 5-view animated idle, 8-frame phase, 22 actors and fallback: OK")
	quit(0)
