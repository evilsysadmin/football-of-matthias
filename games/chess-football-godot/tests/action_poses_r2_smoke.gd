extends SceneTree

# P0: only exact SHA-verified original-runtime R2 action sheets can install
# in XI. The slide's oversized painted ground shadow is removed from middle
# poses after decode while the opaque boot contact and all physics survive.
func _synthetic_sheet() -> Image:
	var sheet := Image.create(1024, 144, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for i in range(8):
		# Shadow first, then a grounded opaque athlete. It deliberately
		# overlaps the boots, so the filter must keep the opaque body.
		if i in [3, 4, 5]:
			sheet.fill_rect(Rect2i(i * 128 + 7, 126, 114, 11),
				Color(0.03, 0.04, 0.06, 0.24))
		sheet.fill_rect(Rect2i(i * 128 + 16, 18, 90, 116),
			Color(0.15 + float(i) * 0.08, 0.65, 0.3, 1.0))
	return sheet


func _initialize() -> void:
	# The scrape is bounded, reversible and tied only to the action clock.
	assert(ChessFootball3DPresenter.xi_slide_scrape_weight(0.64, 0.64) == 0.0)
	assert(is_equal_approx(ChessFootball3DPresenter.xi_slide_scrape_weight(0.64, 0.32), 1.0))
	assert(ChessFootball3DPresenter.xi_slide_scrape_weight(0.64, 0.0) == 0.0)
	assert(ChessFootball3DPresenter.xi_slide_scrape_weight(0.0, 0.32) == 0.0)
	assert(ChessFootball3DPresenter.xi_slide_scrape_weight(0.64, 0.12) < 0.60)
	var contract := ChessFootballActionPosesR2.metadata()
	assert(contract.get("version") == 2 and contract.get("enabled") == true)
	assert(contract.get("quality_contract") == "football-approved-r2-action-recomposition-v2")
	assert(contract.get("enabled_actions") == [
		"dribble_cut", "dribble_burst", "tackle", "slide_tackle"
	])
	assert((contract.get("entries", []) as Array).size() == 8)
	for team_id in range(2):
		for action in ChessFootballActionPosesR2.ACTIVE_ANIMATIONS:
			var meta := ChessFootballActionPosesR2.sheet_meta(team_id, action)
			assert(not meta.is_empty() and meta["url"].begins_with(
				ChessFootballActionPosesR2.TRUSTED_ROOT))
			assert(ChessFootballR2AtlasLoader.decode_verified_webp(
				PackedByteArray([1, 2, 3]), meta,
				ChessFootballActionPosesR2.TRUSTED_ROOT
			) == null)
	# A verified, authored lateral plant can sell a brief body turn for
	# front/diagonal XI dribbles. Enter and exit in the original runner;
	# never use a non-verified atlas or overlay a keeper/off-ball action.
	for view in ["front", "back", "front_diagonal", "back_diagonal"]:
		var base := StringName("run_" + view)
		assert(ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
			base, view, "midfielder", true, true, "feint", 0.15, true, true
		) == base)
		assert(ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
			base, view, "midfielder", true, true, "feint", 0.48, true, true
		) == &"dribble_cut")
		assert(ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
			base, view, "midfielder", true, true, "feint", 0.92, true, true
		) == base)
		assert(ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
			base, view, "midfielder", true, true, "cut", 0.50, true, true
		) == &"dribble_cut")
		assert(ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
			base, view, "midfielder", true, true, "burst", 0.50, true, true
		) == &"dribble_burst")
		for blocked in [
			["keeper", true, true, true],
			["midfielder", false, true, true],
			["midfielder", true, false, true],
			["midfielder", true, true, false],
		]:
			assert(ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
				base, view, blocked[0], blocked[1], blocked[2],
				"feint", 0.50, blocked[3], true
			) == base)
		assert(ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
			base, view, "midfielder", true, true, "burst", 0.50, true, false
		) == base)
	assert(ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
		&"run", "side", "midfielder", true, true, "cut", 0.50, true, true
	) == &"run")
	assert(ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
		&"shoot", "front", "midfielder", true, true, "cut", 0.50, true, true
	) == &"shoot")

	# Against front/diagonal XI movement, an authentic R2 plant sells
	# one side and recovers through an *opposite* boot/shoulder plant.
	# No flip survives the action or leaks into a real directional runner.
	for view in ["front", "back", "front_diagonal", "back_diagonal"]:
		for original_flip in [false, true]:
			assert(ChessFootball3DPresenter.xi_feint_pivot_mirror(
				original_flip, 11, view, "midfielder",
				true, true, "feint", &"dribble_cut", 0.34
			) == original_flip)
			assert(ChessFootball3DPresenter.xi_feint_pivot_mirror(
				original_flip, 11, view, "midfielder",
				true, true, "feint", &"dribble_cut", 0.65
			) != original_flip)
			for excluded in [
				[5, view, "midfielder", true, true, "feint", &"dribble_cut"],
				[11, view, "keeper", true, true, "feint", &"dribble_cut"],
				[11, view, "midfielder", false, true, "feint", &"dribble_cut"],
				[11, view, "midfielder", true, false, "feint", &"dribble_cut"],
				[11, view, "midfielder", true, true, "burst", &"dribble_burst"],
				[11, view, "midfielder", true, true, "cut", &"dribble_cut"],
				[11, view, "midfielder", true, true, "feint", &"run_front"],
			]:
				assert(ChessFootball3DPresenter.xi_feint_pivot_mirror(
					original_flip, excluded[0], excluded[1], excluded[2],
					excluded[3], excluded[4], excluded[5], excluded[6], 0.65
				) == original_flip)
	assert(ChessFootball3DPresenter.xi_feint_pivot_mirror(
		false, 11, "side", "midfielder", true, true, "feint",
		&"dribble_cut", 0.65
	) == false)

	assert(ChessFootballActionPosesR2.sheet_meta(2, &"slide_tackle").is_empty())
	assert(ChessFootballActionPosesR2.sheet_meta(0, &"dance").is_empty())
	assert(ChessFootballActionPosesR2.animation_for(
		&"sprint", "side", "", true, true, "cut") == &"dribble_cut")
	assert(ChessFootballActionPosesR2.animation_for(
		&"run", "side", "", true, true, "burst") == &"dribble_burst")
	for view in ["front", "back", "front_diagonal", "back_diagonal"]:
		assert(ChessFootballActionPosesR2.animation_for(
			&"run", view, "", true, true, "cut") == &"run")
	for blocked in [&"shoot", &"pass", &"tackle", &"slide_tackle"]:
		assert(ChessFootballActionPosesR2.animation_for(
			blocked, "side", "", true, true, "burst") == blocked)
	assert(ChessFootballActionPosesR2.animation_for(
		&"run", "side", "keeper", true, true, "cut") == &"run")

	var sheet := _synthetic_sheet()
	assert(sheet.get_pixel(3 * 128 + 7, 130).a > 0.20)
	var clean := ChessFootballActionPosesR2.frames_from_image(
		sheet, &"slide_tackle")
	assert(clean.size() == 8)
	var original := ChessFootballActionPosesR2.frames_from_image(
		sheet, &"tackle")
	assert(original.size() == 8)
	for i in range(8):
		var restored: Image = clean[i].get_image()
		assert(restored.get_size() == Vector2i(128, 144))
		assert(restored.get_pixel(40, 130).a > 0.98)  # boot/body opaque
		if i in [3, 4, 5]:
			assert(restored.get_pixel(7, 130).a < 0.01)
			assert(original[i].get_image().get_pixel(7, 130).a > 0.20)
		else:
			assert(restored.get_data() == original[i].get_image().get_data())
	var erased := sheet.duplicate()
	erased.fill_rect(Rect2i(4 * 128, 0, 128, 144), Color.TRANSPARENT)
	assert(ChessFootballActionPosesR2.frames_from_image(
		erased, &"slide_tackle").is_empty())
	var opaque := sheet.duplicate()
	opaque.set_pixel(0, 0, Color.WHITE)
	assert(ChessFootballActionPosesR2.frames_from_image(
		opaque, &"slide_tackle").is_empty())
	assert(ChessFootballActionPosesR2.frames_from_image(
		Image.create(1024, 288, false, Image.FORMAT_RGBA8),
		&"slide_tackle").is_empty())

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
	var initial_score: Array = game.score.duplicate()
	for team_id in range(2):
		var athlete: Footballer = game.teams[team_id][1]
		var keeper: Footballer = game.teams[team_id][0]
		var key := athlete.get_instance_id()
		var sprite: AnimatedSprite3D = stage.player_sprites[key]
		var goalie: AnimatedSprite3D = stage.player_sprites[keeper.get_instance_id()]
		var bank := sprite.sprite_frames
		var original_run: Texture2D = bank.get_frame_texture(&"run", 0)
		var original_pass: Texture2D = bank.get_frame_texture(&"pass", 0)
		var original_keeper: Texture2D = goalie.sprite_frames.get_frame_texture(
			&"slide_tackle", 0
		)
		for action in ChessFootballActionPosesR2.ACTIVE_ANIMATIONS:
			var replacements: Array[Texture2D] = (
				clean if action == &"slide_tackle" else original
			)
			stage._apply_verified_action_pose_frames([], team_id, action)
			if action in [&"dribble_cut", &"dribble_burst"]:
				assert(not bank.has_animation(action))
			stage._apply_verified_action_pose_frames(replacements, team_id, action)
			assert(stage._action_poses_r2_loaded.has(
				"%d:%s" % [team_id, String(action)]))
			assert(bank.has_animation(action) and bank.get_frame_count(action) == 8)
			for i in range(8):
				assert(bank.get_frame_texture(action, i) == replacements[i])
			stage._apply_verified_action_pose_frames(replacements, team_id, action)
			assert(bank.get_frame_count(action) == 8)
		assert(bank.get_frame_texture(&"run", 0) == original_run)
		assert(bank.get_frame_texture(&"pass", 0) == original_pass)
		assert(goalie.sprite_frames.get_frame_texture(&"slide_tackle", 0)
			== original_keeper)

		game.ball.attach_to(athlete)
		athlete.action_lock_seconds = 0.0
		athlete.velocity = Vector2.RIGHT * maxf(athlete.base_speed, 80.0)
		athlete.visual.play(&"sprint")
		athlete.dribble_duration_seconds = 0.22
		athlete.dribble_burst_seconds = 0.12
		athlete.dribble_mode = "cut"
		stage.player_run_views[key] = "side"
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"dribble_cut")
		athlete.dribble_mode = "burst"
		athlete.dribble_duration_seconds = 0.27
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"dribble_burst")
		athlete.dribble_burst_seconds = 0.0
		athlete.visual.play(&"shoot")
		stage.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"shoot")
		game.ball.release(Vector2.RIGHT, 0.0)
		for action in [&"tackle", &"slide_tackle"]:
			athlete.visual.play(action)
			athlete.action_visual_duration_seconds = (
				0.50 if action == &"tackle" else 0.64
			)
			athlete.action_lock_seconds = athlete.action_visual_duration_seconds * 0.50
			stage.sync_presentation(0.0, "broadcast")
			assert(sprite.animation == action and sprite.frame == 4)
			if action == &"slide_tackle":
				# R2 slide now has a small grounded scrape, never a gameplay
				# displacement, and its body position returns towards zero.
				assert(absf(sprite.position.x) > 0.055)
				assert(absf(sprite.rotation.z) < deg_to_rad(3.0))
			else:
				assert(absf(sprite.position.x) < 0.001)
			athlete.action_lock_seconds = 0.04
			stage.sync_presentation(0.0, "broadcast")
			assert(sprite.frame == 7)
			if action == &"slide_tackle":
				assert(absf(sprite.position.x) < 0.025)
		assert(bank.get_frame_texture(&"run", 0) == original_run)

	assert(game.score == initial_score)
	print("FOOTBALL_ACTION_POSES_R2_SMOKE_OK clubs=2 actions=4 slide_shadow_clean=1 grounded_boot=1 frames=8 fallback=1 visual_only=1")
	quit(0)
