extends SceneTree

# Actual XI match lens, not the close-up inspection camera from the
# previous feint proof. Crop the native 1280x720 raster WITHOUT resizing
# it so a reviewer sees exactly how many pixels the gesture occupies.
const CELL := Vector2i(480, 320)
const PROGRESS := [0.0, 0.25, 0.75]


func _initialize() -> void:
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
	var actor: Footballer = match_node.teams[0][1]
	var actor_key: int = actor.get_instance_id()
	var center: Vector2 = match_node.match_pitch.get_center()
	for team in match_node.teams:
		for footballer: Footballer in team:
			footballer.global_position = Vector2(-9999, -9999)
			footballer.velocity = Vector2.ZERO
			footballer.action_lock_seconds = 0.0
	actor.global_position = center
	match_node.ball.attach_to(actor)
	var initial_score: Array = match_node.score.duplicate()
	var initial_time: float = match_node.match_seconds

	for mode in ["broadcast", "tactical"]:
		# This is the game's own camera planner and FOV. Do not zoom closer.
		stage._sync_camera(1.0, mode)
		var gameplay_camera: Transform3D = stage.camera.global_transform
		var gameplay_fov: float = stage.camera.fov
		var sheet := Image.create(CELL.x * PROGRESS.size(), CELL.y * 2, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("#15392f"))
		for direction_id in range(2):
			var direction: Vector2 = (
				Vector2.DOWN if direction_id == 0
				else Vector2(1.0, 1.0).normalized()
			)
			actor.global_position = center
			actor.velocity = direction * actor.base_speed
			actor.visual.play(&"run")
			actor.visual.frame = 0
			actor.dribble_mode = "feint"
			actor.dribble_direction = direction
			actor.dribble_duration_seconds = actor.XI_DRIBBLE_FEINT_SECONDS
			match_node.ball.attach_to(actor)
			stage.player_run_views[actor_key] = "front" if direction_id == 0 else "front_diagonal"
			stage.outfield_visual_names.erase(actor_key)
			stage.outfield_visual_phases.erase(actor_key)
			var images: Array[Image] = []
			for phase_index in range(PROGRESS.size()):
				var progress: float = PROGRESS[phase_index]
				actor.dribble_burst_seconds = (
					0.0 if phase_index == 0
					else actor.dribble_duration_seconds * (1.0 - progress)
				)
				stage.camera.global_transform = gameplay_camera
				stage.camera.fov = gameplay_fov
				match_node.ball.tick_ball(0.0)
				var authoritative_ball: Vector2 = match_node.ball.global_position
				stage.sync_presentation(0.0, mode)
				assert(actor.global_position == center)
				assert(match_node.ball.global_position == authoritative_ball)
				assert(match_node.ball.carrier == actor)
				await process_frame
				await RenderingServer.frame_post_draw
				var frame := match_node.get_viewport().get_texture().get_image()
				assert(frame != null and frame.get_size() == Vector2i(1280, 720))
				var body_center: Vector2 = stage.camera.unproject_position(
					stage.player_nodes[actor_key].global_position + Vector3.UP * 0.75
				)
				assert(Rect2(Vector2.ZERO, Vector2(1280, 720)).has_point(body_center))
				var left := clampi(int(body_center.x) - CELL.x / 2, 0, frame.get_width() - CELL.x)
				var top := clampi(int(body_center.y) - CELL.y / 2, 0, frame.get_height() - CELL.y)
				var crop: Image = frame.get_region(Rect2i(left, top, CELL.x, CELL.y))
				images.append(crop)
				sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, CELL),
					Vector2i(phase_index * CELL.x, direction_id * CELL.y))
				if progress == 0.75:
					var physical_ball_stage: Vector3 = stage.world_to_stage(
						match_node.ball.global_position,
						stage.XI_BALL_VISUAL_RADIUS + stage.BALL_VISUAL_GROUND_CLEARANCE
					)
					var visual_px: Vector2 = stage.camera.unproject_position(stage.ball_node.global_position)
					var physical_px: Vector2 = stage.camera.unproject_position(physical_ball_stage)
					assert(visual_px.distance_to(physical_px) >= 4.0,
						"XI countertouch must travel at least four native match-camera pixels")
					assert(absf(stage.ball_node.position.x - stage.ball_shadow.position.x) < 0.001)
					assert(absf(stage.ball_node.position.z - stage.ball_shadow.position.z) < 0.001)
			assert(images[0].get_data() != images[1].get_data())
			assert(images[1].get_data() != images[2].get_data())
			actor.dribble_burst_seconds = 0.0
		assert(sheet.save_png("user://xi-feint-match-camera-" + mode + ".png") == OK)
		print("FOOTBALL_XI_FEINT_MATCH_CAMERA_CAPTURE_" + mode.to_upper() + "=" +
			ProjectSettings.globalize_path("user://xi-feint-match-camera-" + mode + ".png"))
	assert(match_node.score == initial_score)
	assert(is_equal_approx(match_node.match_seconds, initial_time))
	print("FOOTBALL_XI_FEINT_MATCH_CAMERA_OK cameras=2 directions=2 phases=3 native_pixels=1 ball_shadow_aligned=1 authority_unchanged=1")
	quit(0)
