extends SceneTree

# Staging activation uses an explicitly pinned dedicated R2 development origin.
# This smoke never accesses the network; the CI preflight verifies the exact
# published WebP bytes and CORS, and the visual job captures actual Godot poses.
func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var match_node = packed.instantiate()
	root.add_child(match_node)
	await process_frame
	await process_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	var presenter: ChessFootball3DPresenter = match_node.presentation_3d
	var metadata := ChessFootballKeeperCatchR2.metadata()
	assert(metadata.get("version") == 1)
	assert(metadata.get("quality_contract") == "football-keeper-catch-v1")
	assert(metadata.get("bucket") == "football")
	assert(metadata.get("prefix") == "atlases/v1/")
	assert(metadata.get("enabled") == true)
	assert(String(metadata.get("cdn_base", "")) ==
		"https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v1")
	assert((metadata.get("entries", []) as Array).size() == 2)
	assert(ChessFootballKeeperCatchR2.source_entry(-1).is_empty())
	# The published origin is selected solely by the bundled manifest.
	# Verify that existing shared-CDN consumers cannot use it accidentally.
	var proposed: Dictionary = metadata.duplicate(true)
	proposed["enabled"] = true
	proposed["cdn_base"] = "https://football-assets.example.org/atlases/v1"
	var approved_root := ChessFootballKeeperCatchR2.trusted_public_root(proposed)
	assert(approved_root == "https://football-assets.example.org/atlases/v1/")
	assert(ChessFootballKeeperCatchR2.public_root() ==
		"https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v1/")
	var invalid_bases := [
		"http://football-assets.example.org/atlases/v1",
		"https://football-assets.example.org/other/v1",
		"https://football-assets.example.org/atlases/v1?token=bad",
		"https://football-assets.example.org/atlases/v1/",
		"https://football-assets.example.org:8443/atlases/v1",
		"https://127.0.0.1/atlases/v1",
		"https://football-assets.example.org.evil.invalid/atlases/v1/../v1",
		"https://assets.chess-studio.shadowops.dpdns.org/football/atlases/v1",
	]
	for candidate_base in invalid_bases:
		proposed["cdn_base"] = candidate_base
		assert(ChessFootballKeeperCatchR2.trusted_public_root(proposed).is_empty())
	proposed["cdn_base"] = "https://football-assets.example.org/atlases/v1"
	proposed["bucket"] = "chess-studio-assets"
	assert(ChessFootballKeeperCatchR2.trusted_public_root(proposed).is_empty())
	proposed["bucket"] = "football"
	proposed["prefix"] = "football/atlases/v1/"
	assert(ChessFootballKeeperCatchR2.trusted_public_root(proposed).is_empty())
	var original_score: Array = match_node.score.duplicate()
	var original_time: float = match_node.match_seconds
	for team_id in range(2):
		var source := ChessFootballKeeperCatchR2.source_entry(team_id)
		assert(String(source.get("file", "")).ends_with("_keeper_catch_v1.webp"))
		assert(String(source.get("sha256", "")).length() == 64)
		var actual: Dictionary = ChessFootballKeeperCatchR2.active_entry(team_id)
		assert(ChessFootballR2AtlasLoader.valid_metadata(
			actual, ChessFootballKeeperCatchR2.public_root()
		))
		assert(String(actual["url"]) == ChessFootballKeeperCatchR2.public_root() + String(source["file"]))
		assert(actual["sha256"] == source["sha256"])
		var keeper: Footballer = match_node.teams[team_id][0]
		var sprite: AnimatedSprite3D = presenter.player_sprites[keeper.get_instance_id()]
		var original_run: Texture2D = sprite.sprite_frames.get_frame_texture(&"run", 0)
		var original_tackle: Texture2D = sprite.sprite_frames.get_frame_texture(&"tackle", 0)
		assert(not sprite.sprite_frames.has_animation(&"keeper_catch"))
		# Reject bad sizes and empty, full-canvas or clipped frames.
		var bad := Image.create(1024, 144, false, Image.FORMAT_RGBA8)
		bad.fill(Color.TRANSPARENT)
		assert(ChessFootballKeeperCatchR2.frames_from_image(bad, source).is_empty())
		bad.fill(Color.WHITE)
		assert(ChessFootballKeeperCatchR2.frames_from_image(bad, source).is_empty())
		assert(ChessFootballKeeperCatchR2.frames_from_image(
			Image.create(512, 144, false, Image.FORMAT_RGBA8), source
		).is_empty())
		var candidate := Image.create(1024, 144, false, Image.FORMAT_RGBA8)
		candidate.fill(Color.TRANSPARENT)
		for i in range(8):
			candidate.fill_rect(
				Rect2i(128 * i + 32 + i, 9, 64 - i * 2, 123),
				Color(0.2 + float(i) * 0.08, 0.6, 0.25, 1.0)
			)
		# The shared loader still rejects the keeper's other origin by
		# default; accepting one exact approved prefix cannot allow siblings,
		# traversal, query strings, a bad hash or untrusted binary.
		var test_meta: Dictionary = source.duplicate(true)
		test_meta["url"] = approved_root + String(source["file"])
		test_meta["cell"] = metadata["cell"]
		test_meta["columns"] = 8
		test_meta["rows"] = 1
		assert(not ChessFootballR2AtlasLoader.valid_metadata(test_meta))
		assert(ChessFootballR2AtlasLoader.valid_metadata(test_meta, approved_root))
		var encoded: PackedByteArray = candidate.save_webp_to_buffer(false)
		assert(not encoded.is_empty())
		var hasher := HashingContext.new()
		assert(hasher.start(HashingContext.HASH_SHA256) == OK)
		assert(hasher.update(encoded) == OK)
		test_meta["sha256"] = hasher.finish().hex_encode()
		assert(ChessFootballR2AtlasLoader.decode_verified_webp(encoded, test_meta) == null)
		var decoded: Image = ChessFootballR2AtlasLoader.decode_verified_webp(
			encoded, test_meta, approved_root
		)
		assert(decoded != null and decoded.get_size() == Vector2i(1024, 144))
		var corrupted: PackedByteArray = encoded.duplicate()
		corrupted[corrupted.size() - 1] ^= 1
		assert(ChessFootballR2AtlasLoader.decode_verified_webp(
			corrupted, test_meta, approved_root
		) == null)
		for malicious in [
			"https://football-assets.example.org.evil.invalid/atlases/v1/" + String(source["file"]),
			"https://football-assets.example.org/atlases/v1/../bad.webp",
			"https://football-assets.example.org/atlases/v1/%2e%2e/bad.webp",
			"https://football-assets.example.org/atlases/v1/" + String(source["file"]) + "?v=2",
			"https://assets.chess-studio.shadowops.dpdns.org/football/atlases/v1/" + String(source["file"]),
		]:
			var altered: Dictionary = test_meta.duplicate(true)
			altered["url"] = malicious
			assert(not ChessFootballR2AtlasLoader.valid_metadata(altered, approved_root))
		var textures := ChessFootballKeeperCatchR2.frames_from_image(candidate, source)
		assert(textures.size() == 8)
		for i in range(8):
			assert(textures[i].get_size() == Vector2(128, 144))
		assert(not presenter._keeper_catch_r2_loaded.has(team_id))
		presenter._apply_verified_keeper_catch_frames([], team_id)
		assert(not sprite.sprite_frames.has_animation(&"keeper_catch"))
		presenter._apply_verified_keeper_catch_frames(textures, team_id)
		assert(sprite.sprite_frames.has_animation(&"keeper_catch"))
		assert(sprite.sprite_frames.get_frame_count(&"keeper_catch") == 8)
		assert(sprite.sprite_frames.get_frame_texture(&"keeper_catch", 7) == textures[7])
		assert(sprite.sprite_frames.get_frame_texture(&"run", 0) == original_run)
		assert(sprite.sprite_frames.get_frame_texture(&"tackle", 0) == original_tackle)
		assert(presenter._keeper_catch_r2_loaded.has(team_id))
		# Presentation swaps on actual keeper possession only; the 3D glove
		# fallback is hidden while the authored palms are in the sprite.
		match_node.ball.attach_to(keeper)
		presenter.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"keeper_catch")
		assert(sprite.frame == 0)
		assert(not presenter.debug_keeper_catch_hands_visible(keeper))
		presenter.sync_presentation(0.25, "broadcast")
		presenter.sync_presentation(0.0, "broadcast")
		assert(sprite.frame == 7)
		# The real 3D ball must meet the centre of the two painted palms.
		assert(absf(presenter.ball_node.position.x - presenter.world_to_stage(keeper.global_position).x) < 0.04)
		assert(not presenter.ball_shadow.visible)
		assert(match_node.ball.carrier == keeper)
		match_node.ball.release(Vector2.RIGHT, 200.0)
		presenter.sync_presentation(0.0, "broadcast")
		assert(sprite.animation != &"keeper_catch")
		assert(not presenter.debug_keeper_catch_hands_visible(keeper))
		assert(presenter.ball_shadow.visible)
	assert(match_node.score == original_score)
	assert(is_equal_approx(match_node.match_seconds, original_time))
	print("football keeper catch R2 two-sheet staging, 8 poses and fallback: OK")
	quit(0)
