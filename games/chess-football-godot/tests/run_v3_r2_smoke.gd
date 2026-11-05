extends SceneTree

# Offline 12x5 integrity, atomic club swap, subframe stride continuity,
# 11v11-only presentation and strict v2 fallback without changing gameplay.
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
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	assert(ChessFootballRunV3R2.frames_from_image(Image.create(128, 144, false, Image.FORMAT_RGBA8)).is_empty())
	var atlas := Image.create(1536, 720, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for row in range(5):
		for col in range(12):
			atlas.fill_rect(Rect2i(col * 128 + 30, row * 144 + 7, 68, 128), Color("#326db9"))
	var sparse := atlas.duplicate()
	sparse.fill_rect(Rect2i(0, 0, 128, 144), Color.TRANSPARENT)
	assert(ChessFootballRunV3R2.frames_from_image(sparse).is_empty())
	var textures: Array[Texture2D] = ChessFootballRunV3R2.frames_from_image(atlas)
	assert(textures.size() == 60)
	for team_id in range(2):
		var meta := ChessFootballRunV3R2.sheet_meta(team_id)
		assert(not meta.is_empty())
		assert(ChessFootballR2AtlasLoader.valid_metadata(meta, ChessFootballRunV3R2.TRUSTED_ROOT))
		assert(not ChessFootballR2AtlasLoader.valid_metadata(meta))
		var runner: Footballer = game.teams[team_id][1]
		var key: int = runner.get_instance_id()
		var driver: AnimatedSprite3D = stage.player_sprites[key]
		var keeper: Footballer = game.teams[team_id][0]
		var keeper_sprite: AnimatedSprite3D = stage.player_sprites[keeper.get_instance_id()]
		var keeper_frame: Texture2D = keeper_sprite.sprite_frames.get_frame_texture(&"run", 0)
		var idle_frame: Texture2D = driver.sprite_frames.get_frame_texture(&"idle_front", 0)
		var old_fps: float = driver.sprite_frames.get_animation_speed(&"run_front")
		runner.velocity = Vector2.RIGHT * runner.base_speed
		runner._sync_locomotion(false)
		stage._sync_visible_animation(key, runner, driver, &"run_front", 0.0)
		stage.outfield_visual_phases[key] = 3.25
		driver.frame = 3
		var original: Texture2D = driver.sprite_frames.get_frame_texture(&"run_front", 0)
		stage._apply_verified_run_v3([], team_id)
		assert(driver.sprite_frames.get_frame_count(&"run_front") == 8)
		assert(driver.sprite_frames.get_frame_texture(&"run_front", 0) == original)
		stage._apply_verified_run_v3(textures, team_id)
		assert(stage._run_v3_r2_loaded.has(team_id))
		assert(is_equal_approx(float(stage.outfield_visual_phases[key]), 3.25 * 1.5))
		assert(driver.frame == 4)
		for player in game.teams[team_id]:
			if player.role == "keeper":
				continue
			var sprite: AnimatedSprite3D = stage.player_sprites[player.get_instance_id()]
			for row in range(5):
				for base in ["run", "sprint"]:
					var name := StringName(ChessFootballRunV3R2.ANIMATIONS[row].replace("run", base))
					assert(sprite.sprite_frames.get_frame_count(name) == 12)
					assert(sprite.sprite_frames.get_frame_texture(name, 0) == textures[row * 12])
					assert(sprite.sprite_frames.get_frame_texture(name, 11) == textures[row * 12 + 11])
			assert(not stage.player_nodes[player.get_instance_id()].get_node("XI_KitSculpt").visible)
			assert(stage.xi_raster_meshes[player.get_instance_id()].visible)
		assert(is_equal_approx(driver.sprite_frames.get_animation_speed(&"run_front"), old_fps * 1.5))
		assert(driver.sprite_frames.get_frame_texture(&"idle_front", 0) == idle_frame)
		assert(keeper_sprite.sprite_frames.get_frame_texture(&"run", 0) == keeper_frame)
		# A v2 request may finish after v3: it must not downgrade the 12 poses.
		stage._apply_verified_run_v2([], team_id)
		assert(driver.sprite_frames.get_frame_count(&"run_front") == 12)
		stage._apply_verified_run_v3(textures, team_id)
		assert(driver.sprite_frames.get_frame_count(&"run_front") == 12)
		stage._sync_visible_animation(key, runner, driver, &"run_front", 0.09)
		assert(driver.frame >= 4)
		assert(stage._xi_frame_texture(runner, driver) == driver.sprite_frames.get_frame_texture(&"run_front", driver.frame))
	print("FOOTBALL_RUN_V3_R2_SMOKE_OK clubs=2 views=5 frames=12 fallback=v2 keeper=unchanged phase=preserved")
	quit(0)
