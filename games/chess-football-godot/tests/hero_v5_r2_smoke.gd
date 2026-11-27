extends SceneTree

# Published SHA/CORS-verified V5 art must expose trusted metadata.
# Synthetic sheets separately test atomic swaps and no changes to the
# 2D match authority, keepers or unsupported run directions.
func _sample_atlas(rows: int) -> Image:
	var atlas := Image.create(2048, rows * 144, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for row in range(rows):
		for col in range(16):
			atlas.fill_rect(Rect2i(col * 128 + 29, row * 144 + 12, 70, 120), Color("#4079bb"))
	return atlas


func _initialize() -> void:
	var game_scene := load("res://main.tscn") as PackedScene
	assert(game_scene != null)
	var game = game_scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	# A normal match must never opt into the incomplete V5/dense generation.
	# Direct private installer calls below are explicit art preview tests.
	assert(not stage.complete_xi_art_release_ready())
	assert(not stage._allow_xi_art_preview())
	assert(stage._hero_v5_loaded.is_empty() and stage._dense_kick_loaded.is_empty() and stage._dense_diagonal_loaded.is_empty())
	for club in range(2):
		for athlete: Footballer in game.teams[club]:
			var driver: AnimatedSprite3D = stage.player_sprites[athlete.get_instance_id()]
			assert(not driver.sprite_frames.has_animation(&"hero_feint"))
			assert(not driver.sprite_frames.has_animation(&"hero_cut"))
	print("FOOTBALL_XI_PUBLIC_ART_HOLD_OK both_clubs=true")
	for club in range(2):
		for family in ChessFootballHeroV5R2.FAMILIES:
			var verified_meta: Dictionary = ChessFootballHeroV5R2.sheet_meta(club, family)
			assert(not verified_meta.is_empty(), "Uploaded V5 sheet must be enabled")
			assert(ChessFootballR2AtlasLoader.valid_metadata(
				verified_meta, ChessFootballHeroV5R2.TRUSTED_ROOT
			))
			assert(verified_meta.url == ChessFootballHeroV5R2.TRUSTED_ROOT
				+ ChessFootballHeroV5R2.CLUBS[club] + "_" + family + "_v5.webp")
	assert(ChessFootballHeroV5R2.sheet_meta(-1, "locomotion").is_empty())
	assert(ChessFootballHeroV5R2.sheet_meta(0, "invalid").is_empty())
	assert(ChessFootballHeroV5R2.frames_from_image(
		_sample_atlas(2), "locomotion"
	).is_empty())
	assert(ChessFootballHeroV5R2.frames_from_image(
		_sample_atlas(3), "dribbles"
	).is_empty())
	var missing := _sample_atlas(3)
	missing.fill_rect(Rect2i(0, 0, 128, 144), Color.TRANSPARENT)
	assert(ChessFootballHeroV5R2.frames_from_image(missing, "locomotion").is_empty())
	var runs := ChessFootballHeroV5R2.frames_from_image(_sample_atlas(3), "locomotion")
	var actions := ChessFootballHeroV5R2.frames_from_image(_sample_atlas(2), "dribbles")
	assert(runs.size() == 48 and actions.size() == 32)
	# Real R2 source has 16 action time slots, but odd source poses carry
	# translucent ghost silhouettes. Runtime must NEVER show those odd
	# textures for E, either club, while retaining all 8 clean poses.
	for row in range(2):
		for col in range(1, 16, 2):
			var index: int = row * 16 + col
			assert(actions[index] == actions[index - 1],
				"V5 action slot must reuse its clean even pose")
		for col in range(2, 16, 2):
			var index: int = row * 16 + col
			assert(actions[index] != actions[index - 2],
				"All eight clear poses must remain distinct")
	# Non-dribble locomotion atlas retains its full 16 frames.
	assert(runs[0] != runs[1])
	assert(ChessFootballHeroV5R2.action_animation("feint", true, true) == &"hero_feint")
	assert(ChessFootballHeroV5R2.action_animation("cut", true, true) == &"hero_cut")
	assert(ChessFootballHeroV5R2.action_animation("burst", true, true) == &"hero_cut")
	assert(ChessFootballHeroV5R2.action_animation("feint", false, true) == &"")
	assert(ChessFootballHeroV5R2.action_animation("cut", true, false) == &"")
	var owner: Footballer = game.teams[0][10]
	game.ball.attach_to(owner)
	var initial_owner: Footballer = game.ball.carrier
	for club in range(2):
		var runner: Footballer = game.teams[club][1]
		var sprite: AnimatedSprite3D = stage.player_sprites[runner.get_instance_id()]
		var keeper_sprite: AnimatedSprite3D = stage.player_sprites[game.teams[club][0].get_instance_id()]
		var original_keeper := keeper_sprite.sprite_frames.get_frame_texture(&"idle_front", 0)
		var original_back := sprite.sprite_frames.get_frame_texture(&"run_back", 0)
		var original_side := sprite.sprite_frames.get_frame_texture(&"run", 0)
		var old_fps: float = sprite.sprite_frames.get_animation_speed(&"run_front")
		stage._apply_hero_v5_locomotion([], club)
		assert(not stage._hero_v5_loaded.has("%d:locomotion" % club))
		# Simulate a partially upgraded directional bank: the old idle may
		# have one pose, or a separately installed animated idle. Capture
		# the real count, not a club-wide V3/V4 arrival flag.
		var idle_actor: Footballer = game.teams[club][2]
		var idle_driver: AnimatedSprite3D = stage.player_sprites[idle_actor.get_instance_id()]
		idle_driver.play(&"idle_front")
		idle_driver.pause()
		idle_driver.frame = 0
		stage.outfield_visual_phases[idle_actor.get_instance_id()] = 0.0
		# A run bank with no cached phase must preserve the visible frame
		# before SpriteFrames.clear resets it.
		sprite.play(&"run_front_diagonal")
		sprite.pause()
		var old_diag_count: int = sprite.sprite_frames.get_frame_count(&"run_front_diagonal")
		sprite.frame = 5
		stage.outfield_visual_phases.erase(runner.get_instance_id())
		# Another actor uses a genuine fractional phase with a distinct count.
		var mixed_actor: Footballer = game.teams[club][3]
		var mixed_driver: AnimatedSprite3D = stage.player_sprites[mixed_actor.get_instance_id()]
		var mixed_bank: SpriteFrames = mixed_driver.sprite_frames
		mixed_bank.clear(&"run_front_diagonal")
		for pose in range(12):
			mixed_bank.add_frame(&"run_front_diagonal", runs[32 + pose])
		mixed_driver.play(&"run_front_diagonal")
		mixed_driver.pause()
		stage.outfield_visual_phases[mixed_actor.get_instance_id()] = 8.25
		stage._apply_hero_v5_locomotion(runs, club)
		assert(stage._hero_v5_loaded.has("%d:locomotion" % club))
		assert(is_equal_approx(float(stage.outfield_visual_phases[runner.get_instance_id()]), 5.0 * 16.0 / float(old_diag_count)))
		assert(is_equal_approx(float(stage.outfield_visual_phases[mixed_actor.get_instance_id()]), 11.0))
		assert(mixed_driver.frame == 11 and idle_driver.frame == 0)
		print("FOOTBALL_XI_ASYNC_ATLAS_PHASE_OK club=%d actual_count=true fallback_frame=true" % club)
		assert(sprite.sprite_frames.get_frame_count(&"idle_front") == 16)
		assert(sprite.sprite_frames.get_frame_texture(&"idle_front", 0) == runs[0])
		for anim in [&"run_front", &"sprint_front"]:
			assert(sprite.sprite_frames.get_frame_count(anim) == 16)
			assert(sprite.sprite_frames.get_frame_texture(anim, 0) == runs[16])
		for anim in [&"run_front_diagonal", &"sprint_front_diagonal"]:
			assert(sprite.sprite_frames.get_frame_count(anim) == 16)
			assert(sprite.sprite_frames.get_frame_texture(anim, 0) == runs[32])
		assert(is_equal_approx(sprite.sprite_frames.get_animation_speed(&"run_front"), old_fps * 2.0))
		assert(sprite.sprite_frames.get_frame_texture(&"run", 0) == original_side)
		assert(sprite.sprite_frames.get_frame_texture(&"run_back", 0) == original_back)
		assert(keeper_sprite.sprite_frames.get_frame_texture(&"idle_front", 0) == original_keeper)
		stage._apply_verified_run_v3([], club)
		assert(sprite.sprite_frames.get_frame_texture(&"run_front", 0) == runs[16])
		stage._apply_hero_v5_dribbles([], club)
		assert(not stage._hero_v5_loaded.has("%d:dribbles" % club))
		stage._apply_hero_v5_dribbles(actions, club)
		assert(stage._hero_v5_loaded.has("%d:dribbles" % club))
		assert(sprite.sprite_frames.get_frame_texture(&"hero_feint", 0) == actions[0])
		assert(sprite.sprite_frames.get_frame_texture(&"hero_cut", 0) == actions[16])
		assert(sprite.sprite_frames.get_frame_count(&"hero_feint") == 16)
		assert(sprite.sprite_frames.get_frame_count(&"hero_cut") == 16)
		assert(not keeper_sprite.sprite_frames.has_animation(&"hero_feint"))
		# Test actual visible clock switches between verified 16-pose
		# front diagonal and existing eight-pose side/rear gait.
		var actor_id: int = runner.get_instance_id()
		runner.velocity = Vector2.RIGHT * runner.base_speed
		runner.action_lock_seconds = 0.0
		for transition in [
			[&"run", &"run_front_diagonal"],
			[&"run_front_diagonal", &"sprint_back_diagonal"],
			[&"sprint_back_diagonal", &"sprint_front"],
			[&"sprint_front", &"run"],
			[&"idle", &"idle_front"],
			[&"idle_front", &"idle_back"],
		]:
			var from: StringName = transition[0]
			var to: StringName = transition[1]
			var old_count: int = sprite.sprite_frames.get_frame_count(from)
			var new_count: int = sprite.sprite_frames.get_frame_count(to)
			var fraction: float = 0.6875 if old_count > 1 else 0.0
			stage._sync_visible_animation(actor_id, runner, sprite, from, 0.0)
			stage.outfield_visual_phases[actor_id] = fraction * float(old_count)
			stage._sync_visible_animation(actor_id, runner, sprite, to, 0.0)
			assert(is_equal_approx(float(stage.outfield_visual_phases[actor_id]),
				fraction * float(new_count)), "Turn must retain fractional cycle phase")
			assert(sprite.frame == floori(fraction * float(new_count)))
			assert(sprite.animation == to)
		print("FOOTBALL_XI_DIAGONAL_PHASE_OK club=%d mixed_counts=true gait_and_idle=true" % club)
	# Offline five-direction preview must fail closed on any missing view
	# and must not mutate the match's current bank while preparing a copy.
	var preview = preload("res://scripts/review_xi_directional_candidates.gd")
	var driver: AnimatedSprite3D = stage.player_sprites[owner.get_instance_id()]
	var original_bank: SpriteFrames = driver.sprite_frames
	var rows := {}
	for i in range(preview.VIEWS.size()):
		var poses: Array[Texture2D] = []
		for j in range(preview.EXPECTED[i]):
			poses.append(runs[0])
		rows[preview.VIEWS[i]] = poses
	var missing_view := rows.duplicate()
	missing_view.erase("back")
	assert(preview.build_preview_bank(original_bank, missing_view) == null)
	var mixed := rows.duplicate()
	mixed["front"] = rows["front"].slice(0, 16)
	assert(preview.build_preview_bank(original_bank, mixed) == null)
	var comparison: SpriteFrames = preview.build_preview_bank(original_bank, mixed, true)
	assert(comparison != null and comparison.get_frame_count(&"run_front") == 16)
	var copy_bank: SpriteFrames = preview.build_preview_bank(original_bank, rows)
	assert(copy_bank != null and copy_bank != original_bank)
	assert(driver.sprite_frames == original_bank)
	for i in range(preview.VIEWS.size()):
		for base in [&"run", &"sprint"]:
			var name := ChessFootballRunDirection.animation_for(base, preview.VIEWS[i])
			assert(copy_bank.get_frame_count(name) == preview.EXPECTED[i])
	assert(copy_bank.get_frame_texture(&"pass", 0) == original_bank.get_frame_texture(&"pass", 0))
	# Exercise the same whole-match transaction used by real Godot review.
	var installer = preload("res://scripts/football_dense_run_bank.gd")
	var old_banks := {}
	for club in range(2):
		for athlete: Footballer in game.teams[club]:
			var id: int = athlete.get_instance_id()
			old_banks[id] = stage.player_sprites[id].sprite_frames
	var owner_id: int = owner.get_instance_id()
	stage._sync_visible_animation(owner_id, owner, driver, &"run", 0.0)
	var old_run_count := driver.sprite_frames.get_frame_count(&"run")
	stage.outfield_visual_phases[owner_id] = 0.625 * float(old_run_count)
	assert(not installer.install_all(game.teams, stage.player_sprites,
		stage.outfield_visual_phases, stage.outfield_visual_names, {0: rows}))
	assert(not installer.install_all(game.teams, stage.player_sprites,
		stage.outfield_visual_phases, stage.outfield_visual_names, {0: rows, 1: missing_view}))
	for id in old_banks:
		assert(stage.player_sprites[id].sprite_frames == old_banks[id])
	assert(is_equal_approx(float(stage.outfield_visual_phases[owner_id]), 0.625 * float(old_run_count)))
	assert(installer.install_all(game.teams, stage.player_sprites,
		stage.outfield_visual_phases, stage.outfield_visual_names, {0: rows, 1: rows}))
	assert(driver.animation == &"run" and driver.frame == 15)
	assert(is_equal_approx(float(stage.outfield_visual_phases[owner_id]), 15.0))
	for club in range(2):
		for athlete: Footballer in game.teams[club]:
			var id: int = athlete.get_instance_id()
			var installed: SpriteFrames = stage.player_sprites[id].sprite_frames
			if athlete.role == "keeper":
				assert(installed == old_banks[id])
				continue
			assert(installed != old_banks[id])
			assert(installed.get_frame_texture(&"pass", 0) == old_banks[id].get_frame_texture(&"pass", 0))
			for view in installer.VIEWS:
				for base in [&"run", &"sprint"]:
					assert(installed.get_frame_count(ChessFootballRunDirection.animation_for(base, view)) == 24)
	# Fresh canonical bank only: live Dense must not retain an old
	# outfield texture in idle, kicks or temporary action animations.
	var fresh := ChessFootballSpriteBank.build_frames(0, owner.role, owner.squad_index, true)
	var kick_rows := {}
	for action in [&"pass", &"shoot"]:
		var poses: Array[Texture2D] = []
		for i in range(16):
			poses.append(runs[1])
		kick_rows[action] = poses
	var live: SpriteFrames = installer.build_bank(fresh, rows, false, kick_rows)
	assert(live != null)
	for view in installer.VIEWS:
		assert(live.get_frame_texture(ChessFootballRunDirection.animation_for(&"idle", view), 0) == runs[0])
	for action in [&"pass", &"shoot"]:
		assert(live.get_frame_count(action) == 16 and live.get_frame_texture(action, 0) == runs[1])
	for action in [&"tackle", &"slide_tackle", &"celebrate"]:
		assert(live.get_frame_count(action) == fresh.get_frame_count(action))
		assert(live.get_frame_texture(action, 0) == runs[0])
	assert(installer.build_bank(fresh, rows, false, {&"pass": kick_rows[&"pass"]}) == null)
	print("FOOTBALL_DENSE_LIVE_BANK_OK same_generation_fallbacks=true kicks=true")
	print("FOOTBALL_DENSE_RUN_TRANSACTION_OK both_clubs=true rollback=true phase=true keeper_untouched=true")
	print("FOOTBALL_XI_CANDIDATE_PREVIEW_BANK_OK five_views=true missing_rejected=true")
	assert(game.ball.carrier == initial_owner)
	print("FOOTBALL_HERO_V5_SMOKE_OK clubs=2 families=2 frames=80 no_painted_ball=contract fallback=1")
	quit(0)
