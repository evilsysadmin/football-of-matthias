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
			base, view, "midfielder", true, true, "feint", 0.10, true, true
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

	# The older first touch was only 0.08 versus -0.24 for the
	# countertouch: it was nearly invisible in broadcast even while both
	# planted boots were present. Both displayed touches now have genuine,
	# opposite signed displacement without moving the 2D possession ball.
	var first_touch := ChessFootball3DPresenter.xi_dribble_visual_ball_offset(
		"feint", 0.34, Vector2.DOWN
	)
	var second_touch := ChessFootball3DPresenter.xi_dribble_visual_ball_offset(
		"feint", 0.65, Vector2.DOWN
	)
	assert(first_touch.x < -0.16 and second_touch.x > 0.16)
	assert(absf(first_touch.x) / absf(second_touch.x) > 0.75)
	assert(absf(first_touch.x) / absf(second_touch.x) < 1.25)
	assert(absf(first_touch.z) < 0.001 and absf(second_touch.z) < 0.001)
	for boundary in [0.0, 0.5, 1.0]:
		assert(ChessFootball3DPresenter.xi_dribble_visual_ball_offset(
			"feint", boundary, Vector2.RIGHT
		).length() < 0.001)
	assert(ChessFootball3DPresenter.xi_dribble_visual_ball_offset(
		"feint", 0.34, Vector2.ZERO
	) == Vector3.ZERO)
	# Rotating the actual travel vector also rotates the two display
	# touches. The mechanic/ball speed is NEVER the source of the motion.
	var diagonal_touch := ChessFootball3DPresenter.xi_dribble_visual_ball_offset(
		"feint", 0.34, Vector2(1.0, 1.0)
	)
	assert(absf(diagonal_touch.length() - first_touch.length()) < 0.001)

	# Approved R2 contact geometry differs by club: a blue first
	# plant goes to the right, a red first plant goes to the left.
	# The corrected *single* display ball follows each painted support
	# foot, then crosses smoothly without teleporting at the phase split.
	var ball_baseline := Vector3(0.0, 0.16, 0.35)
	var player_foot := Vector3(0.0, 0.16, 0.0)
	for team_id in [0, 1]:
		var first := ChessFootball3DPresenter.xi_feint_display_foot_contact(
			ball_baseline, player_foot, Vector2.DOWN, team_id, false, 0.34
		)
		var second := ChessFootball3DPresenter.xi_feint_display_foot_contact(
			ball_baseline, player_foot, Vector2.DOWN, team_id, false, 0.65
		)
		var contact_sign := 1.0 if team_id == 0 else -1.0
		assert(first.x * contact_sign > 0.12)
		assert(second.x * contact_sign < -0.12)
		assert(first.distance_to(player_foot) < 0.49)
		assert(second.distance_to(player_foot) < 0.49)
		var half_before := ChessFootball3DPresenter.xi_feint_display_foot_contact(
			ball_baseline, player_foot, Vector2.DOWN, team_id, false, 0.499
		)
		var half_after := ChessFootball3DPresenter.xi_feint_display_foot_contact(
			ball_baseline, player_foot, Vector2.DOWN, team_id, false, 0.501
		)
		assert(half_before.distance_to(half_after) < 0.008,
			"No visible ball teleport at the 50% mirrored R2 plant")
		assert(ChessFootball3DPresenter.xi_feint_display_foot_contact(
			ball_baseline, player_foot, Vector2.DOWN, team_id, false, 0.0
		) == ball_baseline)
		assert(ChessFootball3DPresenter.xi_feint_display_foot_contact(
			ball_baseline, player_foot, Vector2.DOWN, team_id, false, 1.0
		).distance_to(ball_baseline) < 0.001)
	assert(ChessFootball3DPresenter.xi_feint_display_foot_contact(
		ball_baseline, player_foot, Vector2.DOWN, 0, true, 0.34
	).x < 0.0)
	assert(ChessFootball3DPresenter.xi_feint_display_foot_contact(
		ball_baseline, player_foot, Vector2.ZERO, 0, false, 0.34
	) == ball_baseline)
	assert(ChessFootball3DPresenter.xi_feint_display_foot_contact(
		ball_baseline, player_foot, Vector2.DOWN, -1, false, 0.34
	) == ball_baseline)
	# A diagonal run is precisely where the old 37px forward possession
	# anchor could leave the DISPLAYED ball beyond an R2 boot. Validate
	# both clubs and the mirror branch without inventing a second ball.
	var diagonal := Vector2(1.0, 1.0).normalized()
	for club in [0, 1]:
		for old_flip in [false, true]:
			for action_t in [0.34, 0.65]:
				var contact := ChessFootball3DPresenter.xi_feint_display_foot_contact(
					ball_baseline, player_foot, diagonal, club, old_flip, action_t
				)
				assert(contact.distance_to(player_foot) < 0.49)
				assert(contact.y == ball_baseline.y)

	# Moving E is CUT, not stationary FEINT. At 0.22s the original
	# eight R2 frames require 36 FPS; the strongest authored straight-leg
	# plant at index 4 must actually survive 15/20/30 FPS sampling.
	assert(ChessFootball3DPresenter.xi_cut_r2_contact_pose(8, 0.22) == 2.0)
	assert(ChessFootball3DPresenter.xi_cut_r2_contact_pose(8, 0.50) == 4.0)
	assert(ChessFootball3DPresenter.xi_cut_r2_contact_pose(8, 0.81) == 6.0)
	assert(ChessFootball3DPresenter.xi_cut_r2_contact_pose(8, 0.96) == 0.0)
	assert(ChessFootball3DPresenter.xi_cut_r2_contact_pose(6, 0.50) == 0.0)
	for fps in [15.0, 20.0, 30.0]:
		for sample_offset in [0.0, 0.25, 0.5, 0.95]:
			var saw_cut_contact := false
			for frame_index in range(8):
				var elapsed := (float(frame_index) + sample_offset) / fps
				if elapsed >= Footballer.DRIBBLE_BURST_SECONDS:
					break
				var progress := elapsed / Footballer.DRIBBLE_BURST_SECONDS
				var wanted := ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
					&"run_front", "front", "midfielder", true,
					true, "cut", progress, true, true
				)
				if wanted == &"dribble_cut":
					saw_cut_contact = saw_cut_contact or (
						ChessFootball3DPresenter.xi_cut_r2_contact_pose(
							8, progress
						) == 4.0
					)
			assert(saw_cut_contact,
				"Real 0.22s moving XI cut must visibly plant R2 index 4 even at 15 FPS")

	# Real 0.24s 11v11 feint at 15, 20 and 30 Hz: even with the
	# sampling phase shifted nearly one full frame, both R2 painted foot
	# plants must actually be seen. The old 8/0.24=33 FPS clock skipped
	# these on Web clients. No extra frames extend the physics window.
	assert(ChessFootball3DPresenter.xi_feint_r2_contact_pose(8, 0.30) == 2.0)
	assert(ChessFootball3DPresenter.xi_feint_r2_contact_pose(8, 0.70) == 5.0)
	assert(ChessFootball3DPresenter.xi_feint_r2_contact_pose(3, 0.70) == 0.0)
	for fps in [15.0, 20.0, 30.0]:
		for sample_offset in [0.0, 0.25, 0.5, 0.95]:
			var saw_first := false
			var saw_second := false
			for frame_index in range(8):
				var elapsed: float = (float(frame_index) + sample_offset) / fps
				if elapsed >= Footballer.XI_DRIBBLE_FEINT_SECONDS:
					break
				var progress: float = elapsed / Footballer.XI_DRIBBLE_FEINT_SECONDS
				var wanted := ChessFootball3DPresenter.xi_verified_dribble_pivot_animation(
					&"run_front", "front", "midfielder",
					true, true, "feint", progress, true, true
				)
				if wanted != &"dribble_cut":
					continue
				var selected := ChessFootball3DPresenter.xi_feint_r2_contact_pose(
					8, progress
				)
				saw_first = saw_first or selected == 2.0
				saw_second = saw_second or selected == 5.0
			assert(saw_first and saw_second,
				"Both planted feet must survive a 15/20/30-FPS Web frame budget")

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
