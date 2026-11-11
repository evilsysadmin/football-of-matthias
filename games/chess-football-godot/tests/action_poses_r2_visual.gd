extends SceneTree

# Real 1280x720 Godot 3D captures, before/after verified CDN bytes.
# 2 clubs x 4 actions x 2 contact/recovery poses x 2 cameras.
const CROP := Vector2i(240, 320)
const PHASES := [3, 6]
const ACTIONS := [&"dribble_cut", &"dribble_burst", &"tackle", &"slide_tackle"]


func _initialize() -> void:
	var directory := OS.get_environment("FOOTBALL_ACTION_POSES_PREVIEW_DIR")
	assert(not directory.is_empty(), "Missing exact R2 action pose verification directory")
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	for _i in range(8):
		await process_frame
		await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	var scores_before: Array = game.score.duplicate()
	var actors: Array[Footballer] = [game.teams[0][1], game.teams[1][1]]
	for team in game.teams:
		for player in team:
			player.velocity = Vector2.ZERO
			player.action_lock_seconds = 0.0
			player.global_position = Vector2(-9999.0, -9999.0)
	game.ball.global_position = Vector2(-9999.0, -9999.0)

	for mode in ["broadcast", "tactical"]:
		var before := await _matrix(game, stage, actors, mode, false)
		_save(before, "BEFORE_" + mode.to_upper(), "action-poses-before-" + mode + ".png")

	for team_id in range(2):
		for action in ACTIONS:
			var meta := ChessFootballActionPosesR2.sheet_meta(team_id, action)
			assert(not meta.is_empty())
			var filename := String(ChessFootballActionPosesR2.CLUBS[team_id]) + "_" + String(action) + "_poses_v2.webp"
			var full_path := directory.path_join(filename)
			assert(FileAccess.file_exists(full_path), "Verified R2 WebP unavailable: " + full_path)
			var raw := FileAccess.get_file_as_bytes(full_path)
			var decoded := ChessFootballR2AtlasLoader.decode_verified_webp(
				raw, meta, ChessFootballActionPosesR2.TRUSTED_ROOT
			)
			assert(decoded != null, "R2 WebP SHA/geometry rejected by real Godot: " + filename)
			if action == &"slide_tackle":
				var clean := ChessFootballActionPosesR2.frames_from_image(
					decoded, action
				)
				assert(clean.size() == 8)
				# The old v2 has a horizontal alpha-painted band on the
				# middle three slide frames. Remove only that band, not
				# the grounded opaque boots or any of the other poses.
				for i in range(8):
					var source := decoded.get_region(Rect2i(i * 128, 0, 128, 144))
					if source.get_format() != Image.FORMAT_RGBA8:
						source.convert(Image.FORMAT_RGBA8)
					var result := clean[i].get_image()
					if i not in [3, 4, 5]:
						assert(result.get_data() == source.get_data())
						continue
					var erased := 0
					var ground_opaque_before := 0
					var ground_opaque_after := 0
					for y in range(126, 144):
						for x in range(128):
							var px := source.get_pixel(x, y)
							var after := result.get_pixel(x, y)
							if px.a > 0.0 and after.a <= 0.01:
								erased += 1
							if px.a >= 0.95:
								ground_opaque_before += 1
								if after.a >= 0.95:
									ground_opaque_after += 1
					assert(erased >= 650 and erased <= 1200)
					assert(ground_opaque_before > 25)
					assert(ground_opaque_before == ground_opaque_after)
				print("FOOTBALL_ACTION_SLIDE_SHADOW_CLEAN_OK team=", team_id)
			stage._on_action_pose_ready(decoded, team_id, action)
			assert(stage._action_poses_r2_loaded.has("%d:%s" % [team_id, String(action)]))
			for actor in game.teams[team_id]:
				if actor.role == "keeper":
					continue
				var driver: AnimatedSprite3D = stage.player_sprites[actor.get_instance_id()]
				assert(driver.sprite_frames.has_animation(action))
				assert(driver.sprite_frames.get_frame_count(action) == 8)

	for mode in ["broadcast", "tactical"]:
		var after := await _matrix(game, stage, actors, mode, true)
		_save(after, "AFTER_" + mode.to_upper(), "action-poses-after-" + mode + ".png")
	assert(game.score == scores_before)
	print("FOOTBALL_ACTION_POSES_R2_GODOT_REVIEW_OK teams=2 actions=4 slide_shadow_clean=1 phases=2 cameras=2 exact_r2=1")
	quit(0)


func _matrix(game: Node, stage: ChessFootball3DPresenter,
		actors: Array[Footballer], mode: String, with_new: bool) -> Image:
	var sheet := Image.create(CROP.x * 4, CROP.y * ACTIONS.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#13392c"))
	for team_id in range(2):
		var actor: Footballer = actors[team_id]
		actor.global_position = game.match_pitch.get_center()
		for row in range(ACTIONS.size()):
			for phase_idx in range(PHASES.size()):
				var pose: int = int(PHASES[phase_idx])
				var crop := await _capture(game, stage, actor, ACTIONS[row],
					pose, mode, with_new)
				sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, CROP),
					Vector2i((team_id * 2 + phase_idx) * CROP.x, row * CROP.y))
		actor.global_position = Vector2(-9999.0, -9999.0)
	return sheet


func _capture(game: Node, stage: ChessFootball3DPresenter,
		actor: Footballer, action: StringName, pose: int,
		mode: String, with_new: bool) -> Image:
	var key := actor.get_instance_id()
	actor.velocity = Vector2.RIGHT * maxf(actor.base_speed, 80.0)
	var is_dribble := action in [&"dribble_cut", &"dribble_burst"]
	if is_dribble:
		game.ball.attach_to(actor)
		actor.action_lock_seconds = 0.0
		actor.dribble_mode = "cut" if action == &"dribble_cut" else "burst"
		actor.dribble_duration_seconds = 0.22 if action == &"dribble_cut" else 0.27
		# The 3D player derives pose directly from the real dribble countdown.
		actor.dribble_burst_seconds = actor.dribble_duration_seconds * (1.0 - (float(pose) + 0.2) / 8.0)
		actor.visual.play(&"sprint")
	else:
		if game.ball.carrier != null:
			game.ball.release(Vector2.RIGHT, 0.0)
		game.ball.global_position = Vector2(-9999.0, -9999.0)
		actor.dribble_burst_seconds = 0.0
		actor.action_visual_duration_seconds = 0.50 if action == &"tackle" else 0.64
		# For the verified new action pack the 3D phase is tied to the real
		# authoritative action countdown, not a manually seeded preview clock.
		actor.action_lock_seconds = actor.action_visual_duration_seconds * (
			1.0 - (float(pose) + 0.20) / 8.0
		)
		actor.visual.play(action)
	stage.player_run_views[key] = "side"
	stage.sync_presentation(0.0, mode)
	var expected: StringName = action if with_new else (
		&"sprint" if is_dribble else action
	)
	var driver: AnimatedSprite3D = stage.player_sprites[key]
	assert(driver.animation == expected, "Incorrect native action routing")
	stage.outfield_visual_names[key] = expected
	stage.outfield_visual_phases[key] = float(pose)
	stage.sync_presentation(0.0, mode)
	# The real 0.22-second moving CUT now holds the *approved* R2
	# extended boot (frame 4) while the authoring matrix requests
	# phase 3, then displays the original recovery (frame 6).
	# This test still inspects actual public WebP pixels through
	# the QuadMesh, not a synthetic or manually forced snapshot.
	var expected_frame := pose
	if with_new and action == &"dribble_cut":
		var action_progress := (float(pose) + 0.20) / 8.0
		expected_frame = int(stage.xi_cut_r2_contact_pose(
			driver.sprite_frames.get_frame_count(expected),
			action_progress
		))
		assert(expected_frame == (4 if pose == 3 else 6))
	assert(driver.frame == expected_frame,
		"Native R2 action contact frame must follow real XI cut clock")
	var quad: MeshInstance3D = stage.xi_raster_meshes[key]
	assert(quad.is_visible_in_tree())
	assert((quad.material_override as StandardMaterial3D).albedo_texture
		== driver.sprite_frames.get_frame_texture(expected, expected_frame))
	var target := stage.world_to_stage(actor.global_position)
	if mode == "tactical":
		stage.camera.position = target + Vector3(0.0, 9.0, 0.1)
	else:
		stage.camera.position = target + Vector3(0.0, 1.7, 4.8)
	stage.camera.look_at(target + Vector3(0.0, 0.85, 0.0), Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := game.get_viewport().get_texture().get_image()
	assert(image != null and image.get_size() == Vector2i(1280, 720))
	var center: Vector2 = stage.camera.unproject_position(driver.global_position)
	var x := clampi(int(center.x) - CROP.x / 2, 0, image.get_width() - CROP.x)
	var y_bias := 80 if mode == "tactical" else 0
	var y := clampi(int(center.y) - CROP.y / 2 - y_bias, 0, image.get_height() - CROP.y)
	return image.get_region(Rect2i(x, y, CROP.x, CROP.y))


func _save(sheet: Image, tag: String, filename: String) -> void:
	var path := "user://" + filename
	assert(sheet.save_png(path) == OK)
	print("FOOTBALL_ACTION_POSES_CAPTURE_" + tag + "=" + ProjectSettings.globalize_path(path))
