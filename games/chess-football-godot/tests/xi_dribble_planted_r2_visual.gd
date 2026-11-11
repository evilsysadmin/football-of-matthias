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
	assert(not directory.is_empty(), "Missing SHA-verified real R2 action PNG source")
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

	for mode in ["broadcast", "tactical"]:
		for action in ACTIONS:
			var sheet := Image.create(CELL.x * PROGRESS.size(), CELL.y * 4,
				false, Image.FORMAT_RGBA8)
			sheet.fill(Color("#15392f"))
			# Beyond deliberate snapshots, these FIVE genuine 15-FPS frames
			# follow FEINT (0.24s), CUT (0.22s), or F LONG TOUCH (0.27s).
			# Keep preparation and real kicking toe legible even on slow Web.
			var playback_sheet: Image = null
			if action in ["feint", "cut", "burst"]:
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
						var expected := stage.xi_verified_dribble_pivot_animation(
							StringName("run_" + view), view, athlete.role, true,
							true, action, progress, true, true
						)
						assert(sprite.animation == expected,
							"Actual XI front/diagonal view must pivot only in the planted interval")
						if action in ["feint", "cut"] and expected == &"dribble_cut":
							# Assert the actual R2 painted index, not just the
							# animation name. Moving cuts retain the extended
							# foot at frame 4; stationary feints alternate 2/5.
							var actual_count := sprite.sprite_frames.get_frame_count(expected)
							var expected_contact := int(
								stage.xi_feint_r2_contact_pose(actual_count, progress)
								if action == "feint"
								else stage.xi_cut_r2_contact_pose(actual_count, progress)
							)
							assert(sprite.frame == expected_contact,
								"XI contact phase mismatch action=%s mode=%s team=%d view=%s progress=%.4f expected=%d actual=%d" % [
									action, mode, team_id, view, progress,
									expected_contact, sprite.frame
								])
							if action == "feint":
								if phase_id == 1:
									assert(sprite.frame == 2)
								elif phase_id == 2:
									assert(sprite.frame == 5)
							elif phase_id == 1:
								assert(sprite.frame == 2,
									"Moving XI cut should retain its planted lead-in")
							elif phase_id == 2:
								assert(sprite.frame == 4,
									"Moving XI E must show the authored extended boot")
						if action == "burst" and expected == &"dribble_burst":
							var burst_count := sprite.sprite_frames.get_frame_count(expected)
							var expected_burst_pose := int(stage.xi_burst_r2_contact_pose(
								burst_count, progress
							))
							assert(sprite.frame == expected_burst_pose,
								"Real R2 F long-touch must follow the authored kick clock")
							if phase_id == 1:
								assert(sprite.frame == 3,
									"F should expose the original long-touch preparation")
							elif phase_id == 2:
								assert(sprite.frame == 5,
									"F should expose the original extended kicking toe")
						assert(match_node.ball.carrier == athlete)
						assert(athlete.global_position == unchanged_position)
						assert(match_node.ball.global_position == authoritative_ball)
						if action == "feint" and phase_id in [1, 2]:
							# In real Godot, not just a math helper, require
							# BOTH signed contacts visible in broadcast AND
							# tactical. No ghost-ball: the existing single
							# ball and its ground shadow follow one offset.
							var base_ball := stage.world_to_stage(
								authoritative_ball,
								stage.XI_BALL_VISUAL_RADIUS + stage.BALL_VISUAL_GROUND_CLEARANCE
							)
							var moved_ball: Vector3 = stage.ball_node.position
							var touch := moved_ball - base_ball
							var expected_touch := stage.xi_dribble_visual_ball_offset(
								"feint", progress, direction
							)
							assert(Vector2(touch.x, touch.z).length() > 0.15)
							var foot_anchor := stage.world_to_stage(
								athlete.global_position,
								stage.XI_BALL_VISUAL_RADIUS + stage.BALL_VISUAL_GROUND_CLEARANCE
							)
							var expected_render := stage.xi_feint_display_foot_contact(
								base_ball + expected_touch, foot_anchor, direction,
								team_id, athlete.visual.flip_h, progress
							)
							assert(moved_ball.distance_to(expected_render) < 0.001,
								"XI R2 foot contact mismatch camera=%s team=%d view=%s diff=%.4f" % [
									mode, team_id, view, moved_ball.distance_to(expected_render)
								])
							assert(Vector2(moved_ball.x - foot_anchor.x,
								moved_ball.z - foot_anchor.z).length() < 0.55,
								"Rendered feint must keep the ball within foot reach")
							var actual_pixels: float = stage.camera.unproject_position(
								moved_ball
							).distance_to(stage.camera.unproject_position(base_ball))
							assert(actual_pixels > 2.0,
								"Both XI feint ball touches must register at actual match zoom")
							assert(stage.ball_shadow != null and stage.ball_shadow.visible)
							assert(absf(stage.ball_shadow.position.x - moved_ball.x) < 0.001)
							assert(absf(stage.ball_shadow.position.z - moved_ball.z) < 0.001)
						if action == "cut" and phase_id in [1, 2]:
							# The real single 3D ball must actually follow
							# the extended R2 cut toe (both clubs, two views,
							# broadcast + tactical), with its existing ground
							# shadow. No gameplay ball, 2D anchor or collider
							# is permitted to move during this visual pass.
							var base_cut_ball := stage.world_to_stage(
								authoritative_ball,
								stage.XI_BALL_VISUAL_RADIUS + stage.BALL_VISUAL_GROUND_CLEARANCE
							)
							var natural_cut := stage.xi_dribble_visual_ball_offset(
								"cut", progress, direction
							)
							var cut_foot := stage.world_to_stage(
								athlete.global_position,
								stage.XI_BALL_VISUAL_RADIUS + stage.BALL_VISUAL_GROUND_CLEARANCE
							)
							var expected_cut := stage.xi_cut_display_ball_contact(
								base_cut_ball + natural_cut, cut_foot,
								sprite.flip_h, progress
							)
							var actual_cut := stage.ball_node.position
							assert(actual_cut.distance_to(expected_cut) < 0.001,
								"XI moving-cut ball must track the actual R2 boot, not the old forward axis")
							assert(absf(actual_cut.x - cut_foot.x) > 0.16,
								"Extended R2 cut must take the ball to the planted side")
							assert(stage.ball_shadow != null and stage.ball_shadow.visible)
							assert(absf(stage.ball_shadow.position.x - actual_cut.x) < 0.001)
							assert(absf(stage.ball_shadow.position.z - actual_cut.z) < 0.001)
						if action == "burst" and phase_id in [1, 2]:
							var base_burst_ball := stage.world_to_stage(
								authoritative_ball,
								stage.XI_BALL_VISUAL_RADIUS + stage.BALL_VISUAL_GROUND_CLEARANCE
							)
							var natural_burst := stage.xi_dribble_visual_ball_offset(
								"burst", progress, direction
							)
							var burst_foot := stage.world_to_stage(
								athlete.global_position,
								stage.XI_BALL_VISUAL_RADIUS + stage.BALL_VISUAL_GROUND_CLEARANCE
							)
							var expected_render_burst := stage.xi_cut_display_ball_contact(
								base_burst_ball + natural_burst, burst_foot,
								sprite.flip_h, progress, 0.68
							)
							var actual_burst_ball := stage.ball_node.position
							assert(actual_burst_ball.distance_to(expected_render_burst) < 0.001,
								"Long touch F must visually contact its real R2 toe")
							assert(actual_burst_ball.distance_to(burst_foot) < 0.72,
								"The long-touch ball must remain by the extended R2 toe")
							assert(stage.ball_shadow != null and stage.ball_shadow.visible)
							assert(absf(stage.ball_shadow.position.x - actual_burst_ball.x) < 0.001)
							assert(absf(stage.ball_shadow.position.z - actual_burst_ball.z) < 0.001)
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
							assert(sprite.flip_h != original_flip,
								"Second step of XI feint must reverse the actual R2 pose")
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
							var expected_sample := stage.xi_verified_dribble_pivot_animation(
								StringName("run_" + view), view, athlete.role,
								true, athlete.dribble_active(), action, sampled_progress,
								true, true
							)
							assert(sampled_sprite.animation == expected_sample)
							if expected_sample in [&"dribble_cut", &"dribble_burst"]:
								var sampled_count := sampled_sprite.sprite_frames.get_frame_count(expected_sample)
								var expected_frame := int(
									stage.xi_feint_r2_contact_pose(sampled_count, sampled_progress)
									if action == "feint" else
									stage.xi_cut_r2_contact_pose(sampled_count, sampled_progress)
									if action == "cut" else
									stage.xi_burst_r2_contact_pose(sampled_count, sampled_progress)
								)
								assert(sampled_sprite.frame == expected_frame,
									"15 FPS XI R2 contact frame must match the action clock")
								seen_first = seen_first or expected_frame == (
									3 if action == "burst" else 2
								)
								seen_second = seen_second or expected_frame == (
									5 if action in ["feint", "burst"] else 4
								)
							if tick == 4:
								# F has a slightly longer window than CUT/FEINT,
								# but the R2 pivot already exited to its real
								# directional runner at >87% progress.
								if action != "burst":
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
							"15 FPS must show both feint plants, cut toe, or F long-touch preparation/contact")
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
				var timeline_path := "user://xi-%s-playback-15fps-%s.png" % [action, mode]
				assert(playback_sheet.save_png(timeline_path) == OK)
				print("FOOTBALL_XI_%s_PLAYBACK_15FPS_%s=%s" % [
					action.to_upper(), mode.to_upper(),
					ProjectSettings.globalize_path(timeline_path)
				])
	assert(match_node.score == score_before)
	assert(is_equal_approx(match_node.match_seconds, match_time_before))
	print("FOOTBALL_XI_DRIBBLE_PLANTED_OK clubs=2 views=2 actions=3 phases=4 cameras=2 r2_verified=1 authority_intact=1")
	quit(0)
