extends SceneTree

# The real approved R2 lateral foot-plant has to read as a body pivot
# for a human XI carrier travelling front or diagonally, at the GAME lens.
# Original WebP bytes are exact SHA-verified; no stand-in silhouette.
# Screenshots capture unresized native pixels, in both actual game cameras.
const CELL := Vector2i(300, 260)
const PROGRESS := [0.04, 0.34, 0.65, 0.96]
const ACTIONS := ["feint", "cut", "burst"]


func _initialize() -> void:
	var directory := OS.get_environment("FOOTBALL_ACTION_POSES_PREVIEW_DIR")
	var run_directory := OS.get_environment("FOOTBALL_RUN_V3_PREVIEW_DIR")
	assert(not directory.is_empty(), "Missing SHA-verified real R2 action PNG source")
	assert(not run_directory.is_empty(), "Missing SHA-verified V3 directional frames")
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var match_node = packed.instantiate()
	match_node.match_team_size = 11
	root.add_child(match_node)
	for _i in range(8):
		await process_frame
		await physics_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	match_node.kickoff_active = false
	var stage: ChessFootball3DPresenter = match_node.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	var score_before: Array = match_node.score.duplicate()
	var match_time_before: float = match_node.match_seconds
	for team in match_node.teams:
		for athlete: Footballer in team:
			athlete.global_position = Vector2(-9999, -9999)
			athlete.velocity = Vector2.ZERO
			athlete.action_lock_seconds = 0.0
	match_node.ball.global_position = Vector2(-9999, -9999)

	# Two clubs, both exact, SHA-verified dribble actions. Reuse the existing
	# loader and animation bank; do not synthesize or re-encode any asset.
	for team_id in range(2):
		for action in [&"dribble_cut", &"dribble_burst"]:
			var metadata := ChessFootballActionPosesR2.sheet_meta(team_id, action)
			assert(not metadata.is_empty())
			var filename := "%s_%s_poses_v2.webp" % [
				ChessFootballActionPosesR2.CLUBS[team_id], String(action)
			]
			var file_path := directory.path_join(filename)
			assert(FileAccess.file_exists(file_path))
			var decoded := ChessFootballR2AtlasLoader.decode_verified_webp(
				FileAccess.get_file_as_bytes(file_path),
				metadata, ChessFootballActionPosesR2.TRUSTED_ROOT
			)
			assert(decoded != null)
			stage._on_action_pose_ready(decoded, team_id, action)
			assert(stage._action_poses_r2_loaded.has("%d:%s" % [team_id, String(action)]))
		# The complete original 12x5 atlas must pass its pinned SHA before
		# replacing any run frame. Test the real loaded Web path, not a
		# source-only helper that could accept the wrong facing silhouette.
		var run_meta := ChessFootballRunV3R2.sheet_meta(team_id)
		assert(not run_meta.is_empty())
		var run_file := String(ChessFootballRunV3R2.KINDS[team_id]) + "_run_v3_clean.webp"
		var run_path := run_directory.path_join(run_file)
		assert(FileAccess.file_exists(run_path))
		var run_image := ChessFootballR2AtlasLoader.decode_verified_webp(
			FileAccess.get_file_as_bytes(run_path),
			run_meta, ChessFootballRunV3R2.TRUSTED_ROOT
		)
		assert(run_image != null)
		stage._on_run_v3_ready(run_image, team_id)
		assert(stage._run_v3_r2_loaded.has(team_id))

	for mode in ["broadcast", "tactical"]:
		for action in ACTIONS:
			var sheet := Image.create(CELL.x * PROGRESS.size(), CELL.y * 4,
				false, Image.FORMAT_RGBA8)
			sheet.fill(Color("#15392f"))
			# Unlike the four deliberate pose snapshots, these FIVE samples
			# follow the actual 0.24-second feint at 15 FPS. Reviewers can
			# see which real poses the Godot renderer exposes on a slow Web
			# client, including the final return to directional running.
			var playback_sheet: Image = null
			if action == "feint":
				playback_sheet = Image.create(CELL.x * 5, CELL.y * 4,
					false, Image.FORMAT_RGBA8)
				playback_sheet.fill(Color("#15392f"))
			for team_id in range(2):
				var athlete: Footballer = match_node.teams[team_id][1]
				for direction_id in range(2):
					var direction: Vector2 = (
						Vector2.DOWN if direction_id == 0
						else Vector2(1.0, 1.0).normalized()
					)
					athlete.global_position = match_node.match_pitch.get_center()
					athlete.velocity = direction * athlete.base_speed
					athlete.visual.play(&"run")
					athlete.visual.frame = 0
					athlete.action_lock_seconds = 0.0
					athlete.dribble_mode = action
					athlete.dribble_direction = direction
					athlete.dribble_duration_seconds = (
						athlete.XI_DRIBBLE_FEINT_SECONDS if action == "feint"
						else athlete.DRIBBLE_LONG_TOUCH_SECONDS if action == "burst"
						else athlete.DRIBBLE_BURST_SECONDS
					)
					match_node.ball.attach_to(athlete)
					var key: int = athlete.get_instance_id()
					var view := "front" if direction_id == 0 else "front_diagonal"
					stage.player_run_views[key] = view
					stage.outfield_visual_names.erase(key)
					stage.outfield_visual_phases.erase(key)
					var unchanged_position: Vector2 = athlete.global_position
					var captured_images: Array[Image] = []
					for phase_id in range(PROGRESS.size()):
						var progress: float = PROGRESS[phase_id]
						athlete.dribble_burst_seconds = (
							athlete.dribble_duration_seconds * (1.0 - progress)
						)
						match_node.ball.tick_ball(0.0)
						var authoritative_ball: Vector2 = match_node.ball.global_position
						stage.sync_presentation(0.0, mode)
						var sprite: AnimatedSprite3D = stage.player_sprites[key]
						var expected := StringName("run_" + view) if action == "feint" else (
							stage.xi_verified_dribble_pivot_animation(
								StringName("run_" + view), view, athlete.role, true,
								true, action, progress, true, true
							)
						)
						assert(sprite.animation == expected,
							"Verified V3 feint must preserve facing; cut/burst retain R2 actions")
						if action == "feint":
							assert(sprite.sprite_frames.get_frame_count(expected) == 12)
							assert(stage.xi_use_v3_directional_feint(
								11, view, athlete.role, true, true, "feint",
								expected, true, 12
							))
							var contact_pose := int(stage.xi_v3_feint_contact_pose(
								12, progress
							))
							assert(sprite.frame == contact_pose)
							assert(contact_pose == [0, 3, 9, 0][phase_id])
							assert(sprite.flip_h == athlete.visual.flip_h,
								"The diagonal athlete must not turn sideways or mirror the view")
						assert(match_node.ball.carrier == athlete)
						assert(athlete.global_position == unchanged_position)
						assert(match_node.ball.global_position == authoritative_ball)
						var quad: MeshInstance3D = stage.xi_raster_meshes[key]
						assert(quad.visible)
						var material := quad.material_override as StandardMaterial3D
						assert(material.albedo_texture ==
							sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))
						var original_flip: bool = athlete.visual.flip_h
						var expected_flip := stage.xi_feint_pivot_mirror(
							original_flip, match_node.match_team_size,
							view, athlete.role, true, true, action, sprite.animation,
							progress
						)
						assert(sprite.flip_h == expected_flip)
						assert((material.uv1_scale.x < 0.0) == expected_flip,
							"Rendered R2 QuadMesh must show the counter-planted leg")
						if action == "feint" and phase_id == 2:
							assert(sprite.frame == 9 and sprite.flip_h == original_flip,
								"V3 second planted leg must keep actual front/diagonal facing")
						if phase_id == 0 or phase_id == PROGRESS.size() - 1:
							assert(sprite.flip_h == original_flip,
								"No XI feint mirror can leak into directional running")
						await process_frame
						await RenderingServer.frame_post_draw
						var frame := match_node.get_viewport().get_texture().get_image()
						assert(frame != null and frame.get_size() == Vector2i(1280, 720))
						var center: Vector2 = stage.camera.unproject_position(
							stage.player_nodes[key].global_position + Vector3.UP * 0.75
						)
						assert(Rect2(Vector2.ZERO, Vector2(1280, 720)).has_point(center))
						var left := clampi(int(center.x) - CELL.x / 2, 0, 1280 - CELL.x)
						var top := clampi(int(center.y) - CELL.y / 2, 0, 720 - CELL.y)
						var crop: Image = frame.get_region(Rect2i(left, top, CELL.x, CELL.y))
						captured_images.append(crop)
						var row: int = team_id * 2 + direction_id
						sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, CELL),
							Vector2i(phase_id * CELL.x, row * CELL.y))
					assert(captured_images[0].get_data() != captured_images[1].get_data())
					assert(captured_images[1].get_data() != captured_images[2].get_data())
					assert(captured_images[2].get_data() != captured_images[3].get_data())
					if playback_sheet != null:
						var seen_first := false
						var seen_second := false
						for tick in range(5):
							var sampled_elapsed: float = float(tick) / 15.0
							var sampled_progress := clampf(
								sampled_elapsed / athlete.dribble_duration_seconds, 0.0, 1.0
							)
							athlete.dribble_burst_seconds = maxf(
								0.0, athlete.dribble_duration_seconds - sampled_elapsed
							)
							match_node.ball.tick_ball(0.0)
							var authoritative_ball: Vector2 = match_node.ball.global_position
							stage.sync_presentation(0.0, mode)
							var sampled_sprite: AnimatedSprite3D = stage.player_sprites[key]
							var expected_sample := StringName("run_" + view)
							assert(sampled_sprite.animation == expected_sample,
								"V3 feint never jumps to a side-only action")
							if athlete.dribble_active():
								var expected_frame := int(stage.xi_v3_feint_contact_pose(
									sampled_sprite.sprite_frames.get_frame_count(expected_sample),
									sampled_progress
								))
								assert(sampled_sprite.frame == expected_frame)
								seen_first = seen_first or expected_frame == 3
								seen_second = seen_second or expected_frame == 9
							if tick == 4:
								assert(not athlete.dribble_active())
								assert(sampled_sprite.animation == StringName("run_" + view))
							assert(athlete.global_position == unchanged_position)
							assert(match_node.ball.global_position == authoritative_ball)
							await process_frame
							await RenderingServer.frame_post_draw
							var frame := match_node.get_viewport().get_texture().get_image()
							assert(frame != null and frame.get_size() == Vector2i(1280, 720))
							var center: Vector2 = stage.camera.unproject_position(
								stage.player_nodes[key].global_position + Vector3.UP * 0.75
							)
							var left := clampi(int(center.x) - CELL.x / 2, 0, 1280 - CELL.x)
							var top := clampi(int(center.y) - CELL.y / 2, 0, 720 - CELL.y)
							var crop := frame.get_region(Rect2i(left, top, CELL.x, CELL.y))
							var row: int = team_id * 2 + direction_id
							playback_sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, CELL),
								Vector2i(tick * CELL.x, row * CELL.y))
						assert(seen_first and seen_second,
							"15 FPS XI Web capture must show BOTH verified V3 directional planted feet")
					match_node.ball.release(Vector2.RIGHT, 0.0)
					athlete.dribble_burst_seconds = 0.0
					athlete.global_position = Vector2(-9999, -9999)
			var path := "user://xi-dribble-planted-%s-%s.png" % [mode, action]
			assert(sheet.save_png(path) == OK)
			print("FOOTBALL_XI_DRIBBLE_PLANTED_CAPTURE_%s_%s=%s" % [
				mode.to_upper(), action.to_upper(),
				ProjectSettings.globalize_path(path)
			])
			if playback_sheet != null:
				var timeline_path := "user://xi-feint-playback-15fps-%s.png" % mode
				assert(playback_sheet.save_png(timeline_path) == OK)
				print("FOOTBALL_XI_FEINT_PLAYBACK_15FPS_%s=%s" % [
					mode.to_upper(), ProjectSettings.globalize_path(timeline_path)
				])
	assert(match_node.score == score_before)
	assert(is_equal_approx(match_node.match_seconds, match_time_before))
	print("FOOTBALL_XI_DRIBBLE_PLANTED_OK clubs=2 views=2 actions=3 phases=4 cameras=2 r2_verified=1 authority_intact=1")
	quit(0)
