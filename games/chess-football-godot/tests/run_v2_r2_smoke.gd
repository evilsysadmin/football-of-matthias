extends SceneTree

# Offline unit/integration contract: exact 5x8 layout, atomic 11v11 swap,
# no goalkeeper changes, raster clock continues and sculpt is not duplicated.
func _initialize() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var presenter: ChessFootball3DPresenter = game.presentation_3d
	assert(presenter != null)
	assert(game.debug_team_counts() == [11, 11])
	assert(presenter.xi_raster_meshes.size() == 22)

	var invalid := Image.create(128, 144, false, Image.FORMAT_RGBA8)
	assert(ChessFootballRunV2R2.frames_from_image(invalid).is_empty())
	var image := Image.create(1024, 720, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for row in range(5):
		for col in range(8):
			image.fill_rect(
				Rect2i(col * 128 + 34, row * 144 + 8, 58, 121), Color("#4286c6")
			)
	var missing_frame := image.duplicate()
	missing_frame.fill_rect(Rect2i(0, 0, 128, 144), Color.TRANSPARENT)
	assert(ChessFootballRunV2R2.frames_from_image(missing_frame).is_empty())
	var textures := ChessFootballRunV2R2.frames_from_image(image)
	assert(textures.size() == 40)
	var first_player: Footballer = game.teams[0][1]
	var first_sprite: AnimatedSprite3D = presenter.player_sprites[first_player.get_instance_id()]
	var previous := first_sprite.sprite_frames.get_frame_texture(&"run_front", 0)
	var keeper0: AnimatedSprite3D = presenter.player_sprites[game.teams[0][0].get_instance_id()]
	var keeper_run := keeper0.sprite_frames.get_frame_texture(&"run", 0)
	var legacy_idle := first_sprite.sprite_frames.get_frame_texture(&"idle_front", 0)
	var first_root: Node3D = presenter.player_nodes[first_player.get_instance_id()]
	assert(not first_root.get_node("XI_KitSculpt").visible)
	var local_quad: MeshInstance3D = presenter.xi_raster_meshes[first_player.get_instance_id()]
	assert(local_quad.is_visible_in_tree())
	# A failed optional R2 fetch must leave the bundled animated footballer,
	# never reintroduce the original blue cylinder/sculpt placeholder.
	presenter._apply_verified_run_v2([], 0)
	assert(first_sprite.sprite_frames.get_frame_texture(&"run_front", 0) == previous)
	assert(not first_root.get_node("XI_KitSculpt").visible)
	assert((local_quad.material_override as StandardMaterial3D).albedo_texture != null)
	assert(presenter._xi_frame_texture(first_player, first_sprite) == first_sprite.sprite_frames.get_frame_texture(&"run", first_sprite.frame % 8))

	for team_id in range(2):
		var meta := ChessFootballRunV2R2.sheet_meta(team_id)
		assert(not meta.is_empty())
		assert(ChessFootballR2AtlasLoader.valid_metadata(meta, ChessFootballRunV2R2.TRUSTED_ROOT))
		assert(not ChessFootballR2AtlasLoader.valid_metadata(meta))
		presenter._apply_verified_run_v2(textures, team_id)
		assert(presenter._run_v2_r2_loaded.has(team_id))
		for player in game.teams[team_id]:
			var key: int = player.get_instance_id()
			var shadow: MeshInstance3D = presenter.player_nodes[key].get_node("ContactShadow")
			assert(shadow.mesh is QuadMesh)
			assert(shadow.material_override is ShaderMaterial)
			assert(shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			if player.role == "keeper":
				continue
			var sprite: AnimatedSprite3D = presenter.player_sprites[key]
			for row in range(5):
				for base in ["run", "sprint"]:
					var anim := StringName(ChessFootballRunV2R2.ANIMATIONS[row].replace("run", base))
					assert(sprite.sprite_frames.get_frame_count(anim) == 8)
					assert(sprite.sprite_frames.get_frame_texture(anim, 0) == textures[row * 8])
					assert(sprite.sprite_frames.get_frame_texture(anim, 7) == textures[row * 8 + 7])
			assert(not presenter.player_nodes[key].get_node("XI_KitSculpt").visible)
			assert(presenter.xi_raster_meshes[key].visible)
	assert(first_sprite.sprite_frames.get_frame_texture(&"idle_front", 0) == legacy_idle)
	assert(keeper0.sprite_frames.get_frame_texture(&"run", 0) == keeper_run)
	var key: int = first_player.get_instance_id()
	first_player.velocity = Vector2.UP * first_player.base_speed
	first_player._sync_locomotion(false)
	presenter._sync_visible_animation(key, first_player, first_sprite, &"run_back", 0.23)
	assert(first_sprite.frame > 0)
	# A late legacy v1 response must not overwrite the v2 side-run.
	var before_side := first_sprite.sprite_frames.get_frame_texture(&"run", 0)
	presenter._apply_verified_lateral_run(textures.slice(16, 24), 0)
	assert(first_sprite.sprite_frames.get_frame_texture(&"run", 0) == before_side)
	print("football R2 v2 run: 5 views x 8 frames, XI fallback and soft shadow: OK")
	quit(0)
