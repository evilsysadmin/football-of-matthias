extends SceneTree

# Real 1280x720 Godot raster captures for the exact SHA-pinned R2 objects.
# Each composite contains cropped *real viewport pixels*: two clubs, pass
# and shoot, frames 0/4/7, before (canonical fallback) and after (R2).
# No synthetic sprites are used to pass the gate.
const CROP := Vector2i(240, 340)
const PHASES := [0, 4, 7]
const ACTIONS := [&"pass", &"shoot"]

func _initialize() -> void:
	var directory := OS.get_environment("FOOTBALL_PASS_SHOOT_PREVIEW_DIR")
	assert(not directory.is_empty(), "Missing verified Football action R2 directory")
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	for _tick in range(8):
		await process_frame
		await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	var saved_score: Array = game.score.duplicate()
	var targets: Array[Footballer] = [game.teams[0][1], game.teams[1][1]]
	for team in game.teams:
		for actor in team:
			actor.velocity = Vector2.ZERO
			actor.action_lock_seconds = 0.0
			actor.global_position = Vector2(-9999.0, -9999.0)
	game.ball.global_position = Vector2(-9999.0, -9999.0)

	for mode in ["broadcast", "tactical"]:
		var before := await _render_matrix(game, stage, targets, mode)
		await _save(before, "BEFORE_" + mode.to_upper(), "football-actions-before-" + mode + ".png")
	# Both published R2 sheets must survive the same runtime SHA and decoder.
	for team_id in range(2):
		var meta := ChessFootballPassShootR2.sheet_meta(team_id)
		assert(not meta.is_empty(), "Enabled action metadata missing")
		var filename := String(ChessFootballPassShootR2.TEAMS[team_id]) + "_pass_shoot_v1.webp"
		var path := directory.path_join(filename)
		assert(FileAccess.file_exists(path), "Missing verified WebP: " + path)
		var raw := FileAccess.get_file_as_bytes(path)
		var decoded := ChessFootballR2AtlasLoader.decode_verified_webp(
			raw, meta, ChessFootballPassShootR2.TRUSTED_ROOT
		)
		assert(decoded != null, "R2 SHA or dimensions rejected by Godot: " + filename)
		stage._on_pass_shoot_ready(decoded, team_id)
		assert(stage._pass_shoot_r2_loaded.has(team_id))
		for outfielder in game.teams[team_id]:
			if outfielder.role == "keeper":
				continue
			var driver: AnimatedSprite3D = stage.player_sprites[outfielder.get_instance_id()]
			for animation in ACTIONS:
				assert(driver.sprite_frames.get_frame_count(animation) == 8)
				assert(not driver.sprite_frames.get_animation_loop(animation))

	for mode in ["broadcast", "tactical"]:
		var after := await _render_matrix(game, stage, targets, mode)
		await _save(after, "AFTER_" + mode.to_upper(), "football-actions-after-" + mode + ".png")
	assert(game.score == saved_score)
	print("FOOTBALL_PASS_SHOOT_REAL_GODOT_REVIEW_OK teams=2 actions=2 phases=3 cameras=2")
	quit(0)


func _render_matrix(game: Node, stage: ChessFootball3DPresenter,
		targets: Array[Footballer], mode: String) -> Image:
	var matrix := Image.create(CROP.x * 6, CROP.y * 4, false, Image.FORMAT_RGBA8)
	matrix.fill(Color("#103a2d"))
	for team_id in range(2):
		var actor: Footballer = targets[team_id]
		actor.global_position = game.match_pitch.get_center()
		for action_row in range(ACTIONS.size()):
			for phase_index in range(PHASES.size()):
				var pose := PHASES[phase_index]
				var shot := await _capture(game, stage, actor, ACTIONS[action_row], pose, mode)
				var x := (team_id * 3 + phase_index) * CROP.x
				var y := action_row * CROP.y
				matrix.blit_rect(shot, Rect2i(Vector2i.ZERO, CROP), Vector2i(x, y))
		actor.global_position = Vector2(-9999.0, -9999.0)
	# Render the same sequence twice (lower rows) for enlarged visual inspection.
	matrix.blit_rect(matrix, Rect2i(0, 0, CROP.x * 6, CROP.y * 2),
		Vector2i(0, CROP.y * 2))
	return matrix


func _capture(game: Node, stage: ChessFootball3DPresenter,
		actor: Footballer, action: StringName, phase: int, mode: String) -> Image:
	var key := actor.get_instance_id()
	actor.action_lock_seconds = 0.0
	actor.velocity = Vector2.ZERO
	actor._sync_locomotion(false)
	actor.play_action(String(action), 0.78)
	stage.sync_presentation(0.0, mode)
	stage.outfield_visual_names[key] = action
	stage.outfield_visual_phases[key] = float(phase)
	stage.sync_presentation(0.0, mode)
	var driver: AnimatedSprite3D = stage.player_sprites[key]
	assert(driver.animation == action and driver.frame == phase,
		"Visible action frame mismatch")
	var quad: MeshInstance3D = stage.xi_raster_meshes[key]
	assert(quad.is_visible_in_tree())
	assert((quad.material_override as StandardMaterial3D).albedo_texture
		== driver.sprite_frames.get_frame_texture(action, phase))
	var target := stage.world_to_stage(actor.global_position)
	if mode == "tactical":
		stage.camera.position = target + Vector3(0.0, 9.0, 0.1)
	else:
		stage.camera.position = target + Vector3(0.0, 1.7, 4.8)
	stage.camera.look_at(target + Vector3(0.0, 0.85, 0.0), Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := game.get_viewport().get_texture().get_image()
	assert(screenshot != null and screenshot.get_size() == Vector2i(1280, 720),
		"Real Godot viewport must be 1280x720")
	var center: Vector2 = stage.camera.unproject_position(driver.global_position)
	var x := clampi(int(center.x) - CROP.x / 2, 0, screenshot.get_width() - CROP.x)
	var y := clampi(int(center.y) - CROP.y / 2, 0, screenshot.get_height() - CROP.y)
	return screenshot.get_region(Rect2i(x, y, CROP.x, CROP.y))


func _save(image: Image, label: String, name: String) -> void:
	var path := "user://" + name
	assert(image.save_png(path) == OK)
	print("FOOTBALL_PASS_SHOOT_CAPTURE_" + label + "=" + ProjectSettings.globalize_path(path))
