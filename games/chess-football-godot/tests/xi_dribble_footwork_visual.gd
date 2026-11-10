extends SceneTree

# The approved XI raster must SHOW a feint from front and diagonal,
# not merely change a GDScript variable. Genuine Godot 3D pixels in the
# actual broadcast/tactical cameras; three consecutive poses per player.
# No external atlas or cloud credentials are required for this fallback.
const CELL := Vector2i(240, 300)
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
	var starting_score: Array = match_node.score.duplicate()
	var starting_time: float = match_node.match_seconds
	for team in match_node.teams:
		for footballer: Footballer in team:
			footballer.global_position = Vector2(-9999, -9999)
			footballer.velocity = Vector2.ZERO
			footballer.action_lock_seconds = 0.0
	match_node.ball.global_position = Vector2(-9999, -9999)

	for mode in ["broadcast", "tactical"]:
		var sheet := Image.create(CELL.x * 3, CELL.y * 4, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("#15392f"))
		for team_id in range(2):
			var actor: Footballer = match_node.teams[team_id][1]
			for direction_id in range(2):
				var axis: Vector2 = (
					Vector2.DOWN if direction_id == 0
					else Vector2(1.0, 1.0).normalized()
				)
				var row: int = team_id * 2 + direction_id
				actor.global_position = match_node.match_pitch.get_center()
				actor.velocity = axis * actor.base_speed
				actor.visual.play(&"run")
				actor.visual.frame = 0
				actor.dribble_mode = "feint"
				actor.dribble_direction = axis
				actor.dribble_duration_seconds = actor.DRIBBLE_FEINT_SECONDS
				match_node.ball.attach_to(actor)
				var physical_position: Vector2 = actor.global_position
				var key: int = actor.get_instance_id()
				stage.player_run_views[key] = "front" if direction_id == 0 else "front_diagonal"
				stage.outfield_visual_names.erase(key)
				stage.outfield_visual_phases.erase(key)
				var images: Array[Image] = []
				for phase_index in range(PROGRESS.size()):
					var progress: float = PROGRESS[phase_index]
					actor.dribble_burst_seconds = (
						0.0 if phase_index == 0
						else actor.dribble_duration_seconds * (1.0 - progress)
					)
					match_node.ball.tick_ball(0.0)
					stage.sync_presentation(0.0, mode)
					var visible: AnimatedSprite3D = stage.player_sprites[key]
					assert(visible != null)
					assert(String(visible.animation) in [
						"run", "run_front", "run_front_diagonal"
					], "Dribble fallback must not steal side-facing R2 art")
					assert(match_node.ball.carrier == actor)
					assert(actor.global_position == physical_position)
					var target: Vector3 = stage.world_to_stage(actor.global_position)
					if mode == "tactical":
						stage.camera.position = target + Vector3(0.0, 9.0, 0.1)
					else:
						stage.camera.position = target + Vector3(0.0, 1.7, 4.8)
					stage.camera.look_at(target + Vector3(0.0, 0.85, 0.0), Vector3.UP)
					await process_frame
					await RenderingServer.frame_post_draw
					var frame := match_node.get_viewport().get_texture().get_image()
					assert(frame != null and frame.get_size() == Vector2i(1280, 720))
					var center: Vector2 = stage.camera.unproject_position(visible.global_position)
					var left := clampi(int(center.x) - CELL.x / 2, 0, frame.get_width() - CELL.x)
					var top := clampi(int(center.y) - CELL.y / 2, 0, frame.get_height() - CELL.y)
					var cell: Image = frame.get_region(Rect2i(left, top, CELL.x, CELL.y))
					images.append(cell)
					sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL),
						Vector2i(phase_index * CELL.x, row * CELL.y))
				assert(images[0].get_data() != images[1].get_data(),
					"Actual initial XI feint pose must change rendered pixels")
				assert(images[1].get_data() != images[2].get_data(),
					"Counter-step must visibly change pose in real 3D raster")
				actor.dribble_burst_seconds = 0.0
				match_node.ball.release(Vector2.RIGHT, 0.0)
				actor.global_position = Vector2(-9999, -9999)
		var filename := "xi-feint-footwork-" + mode + ".png"
		var output: String = "user://" + filename
		assert(sheet.save_png(output) == OK)
		print("FOOTBALL_XI_FEINT_FOOTWORK_CAPTURE_" + mode.to_upper() +
			"=" + ProjectSettings.globalize_path(output))
	assert(match_node.score == starting_score)
	assert(is_equal_approx(match_node.match_seconds, starting_time))
	print("FOOTBALL_XI_FEINT_FOOTWORK_OK teams=2 directions=2 phases=3 cameras=2 pixels_change=1 authority_unchanged=1")
	quit(0)
