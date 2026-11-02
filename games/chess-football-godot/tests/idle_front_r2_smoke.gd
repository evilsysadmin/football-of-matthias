extends SceneTree

# Offline regression for the optional, SHA-pinned R2 idle-front sheet.
# No real network is required; the match must remain playable without CDN.
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
	var meta := ChessFootballSpriteBank.optional_idle_meta()
	assert(meta.get("columns") == 3 and meta.get("rows") == 1)
	assert(ChessFootballSpriteBank.idle_front_url().begins_with("https://"))
	assert(ChessFootballSpriteBank.decode_idle_front_webp(PackedByteArray([1, 2, 3])).is_empty())
	assert(ChessFootballSpriteBank.idle_front_textures_from_image(
		Image.create(128, 144, false, Image.FORMAT_RGBA8)
	).is_empty())

	var sheet := Image.create(384, 144, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for index in range(3):
		var shirt := Color(0.20, 0.45, 0.92) if index == 0 else (
			Color(0.84, 0.20, 0.27) if index == 1 else Color(0.93, 0.72, 0.12)
		)
		sheet.fill_rect(Rect2i(index * 128 + 36, 8, 56, 126), shirt)
	# The shared loader is strict on URL origin, traversal, SHA and raster
	# dimensions. All rejection paths leave the approved local art untouched.
	assert(ChessFootballR2AtlasLoader.valid_metadata(meta))
	for malformed_url in [
		"https://attacker.invalid/football/atlases/idle/football_idle_front_v1.webp",
		meta["url"] + "?cache-bust=1",
		"https://assets.chess-studio.shadowops.dpdns.org/football/atlases/../secret.webp",
		"https://assets.chess-studio.shadowops.dpdns.org/football/atlases/%2e%2e/x.webp",
	]:
		var bad_url_meta: Dictionary = meta.duplicate(true)
		bad_url_meta["url"] = malformed_url
		assert(not ChessFootballR2AtlasLoader.valid_metadata(bad_url_meta))
	var bad_hash_meta: Dictionary = meta.duplicate(true)
	bad_hash_meta["sha256"] = "not-a-real-sha"
	assert(not ChessFootballR2AtlasLoader.valid_metadata(bad_hash_meta))
	var bad_layout_meta: Dictionary = meta.duplicate(true)
	bad_layout_meta["columns"] = 100
	assert(not ChessFootballR2AtlasLoader.valid_metadata(bad_layout_meta))
	var lossless_bytes: PackedByteArray = sheet.save_webp_to_buffer(false)
	assert(not lossless_bytes.is_empty())
	var hash := HashingContext.new()
	assert(hash.start(HashingContext.HASH_SHA256) == OK)
	assert(hash.update(lossless_bytes) == OK)
	var fixture_meta: Dictionary = meta.duplicate(true)
	fixture_meta["sha256"] = hash.finish().hex_encode()
	var decoded: Image = ChessFootballR2AtlasLoader.decode_verified_webp(lossless_bytes, fixture_meta)
	assert(decoded != null and decoded.get_size() == Vector2i(384, 144))
	assert(ChessFootballR2AtlasLoader.decode_verified_webp(lossless_bytes, meta) == null)
	fixture_meta["columns"] = 2
	assert(ChessFootballR2AtlasLoader.decode_verified_webp(lossless_bytes, fixture_meta) == null)
	var textures: Array[Texture2D] = ChessFootballSpriteBank.idle_front_textures_from_image(sheet)
	assert(textures.size() == 4)
	for team_id in range(2):
		for player in game.teams[team_id]:
			var sprite: AnimatedSprite3D = presenter.player_sprites[player.get_instance_id()]
			assert(sprite.sprite_frames.has_animation(&"idle_front"))
			assert(sprite.sprite_frames.get_frame_count(&"idle_front") == 1)
			for view in ["back", "back_diagonal", "front_diagonal"]:
				var key := StringName("idle_" + view)
				assert(sprite.sprite_frames.has_animation(key))
				assert(sprite.sprite_frames.get_frame_count(key) == 1)
			var old_run := sprite.sprite_frames.get_frame_texture(&"run", 0)
			presenter._apply_idle_front_textures(textures)
			var expected_index := 2 + team_id if player.role == "keeper" else team_id
			assert(sprite.sprite_frames.get_frame_texture(&"idle_front", 0) == textures[expected_index])
			assert(sprite.sprite_frames.get_frame_texture(&"run", 0) == old_run)
			player.action_lock_seconds = 0.0
			player.velocity = Vector2.DOWN * player.base_speed
			player._sync_locomotion(false)
			presenter.sync_presentation(1.0 / 60.0, "broadcast")
			player.velocity = Vector2.ZERO
			player._sync_locomotion(false)
			presenter.sync_presentation(1.0 / 60.0, "broadcast")
			assert(sprite.animation == &"idle_front")
			assert(sprite.frame == 0)
			assert(not sprite.is_playing())
	print("football optional idle-front R2 fallback smoke: OK")
	quit(0)
