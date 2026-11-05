extends SceneTree

# Real Godot XI PNG comparison using both EXACT, SHA/CORS-verified R2 sources:
# 8-pose v2 baseline and 12-pose v3 candidate, two cameras, 22 actual actors.
func _initialize() -> void:
	var v2_dir := OS.get_environment("FOOTBALL_RUN_V2_PREVIEW_DIR")
	var v3_dir := OS.get_environment("FOOTBALL_RUN_V3_PREVIEW_DIR")
	assert(not v2_dir.is_empty() and not v3_dir.is_empty())
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
	var presenter: ChessFootball3DPresenter = game.presentation_3d
	assert(presenter != null and presenter.xi_raster_meshes.size() == 22)
	for team in game.teams:
		for player in team:
			if player.role == "keeper":
				continue
			player.velocity = Vector2.RIGHT * maxf(player.base_speed, 60.0)
			player._sync_locomotion(false)
	for team_id in range(2):
		var meta := ChessFootballRunV2R2.sheet_meta(team_id)
		var kind := String(ChessFootballRunV2R2.KINDS[team_id])
		var bytes := FileAccess.get_file_as_bytes(v2_dir.path_join(kind + "_run_v2_clean.webp"))
		var image := ChessFootballR2AtlasLoader.decode_verified_webp(bytes, meta, ChessFootballRunV2R2.TRUSTED_ROOT)
		assert(image != null, "v2 baseline bytes missing or unverified")
		presenter._on_run_v2_ready(image, team_id)
		assert(presenter._run_v2_r2_loaded.has(team_id))
	for mode in ["broadcast", "tactical"]:
		# Snap to the FINAL calibrated camera before capturing either version;
		# lerped broadcast/tactical camera poses make body size comparisons false.
		presenter._sync_camera(10.0, mode)
		presenter.sync_presentation(0.0, mode)
		await _capture(game, "BEFORE", mode)
	for team_id in range(2):
		var meta := ChessFootballRunV3R2.sheet_meta(team_id)
		var kind := String(ChessFootballRunV3R2.KINDS[team_id])
		var bytes := FileAccess.get_file_as_bytes(v3_dir.path_join(kind + "_run_v3_clean.webp"))
		var image := ChessFootballR2AtlasLoader.decode_verified_webp(bytes, meta, ChessFootballRunV3R2.TRUSTED_ROOT)
		assert(image != null, "v3 SHA, dimensions or WebP decode failed for " + kind)
		presenter._on_run_v3_ready(image, team_id)
		assert(presenter._run_v3_r2_loaded.has(team_id))
	for mode in ["broadcast", "tactical"]:
		presenter._sync_camera(10.0, mode)
		presenter.sync_presentation(0.0, mode)
		for team in game.teams:
			for player in team:
				var key: int = player.get_instance_id()
				assert(not presenter.player_nodes[key].get_node("XI_KitSculpt").visible)
				assert(presenter.xi_raster_meshes[key].is_visible_in_tree())
		await _capture(game, "AFTER", mode)
	print("FOOTBALL_RUN_V3_REAL_GODOT_REVIEW_OK teams=2 outfield=20 shadows=22 frames=12 cameras=2")
	quit(0)


func _capture(game: Node, phase: String, mode: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := game.get_viewport().get_texture().get_image()
	assert(img != null and img.get_size() == Vector2i(1280, 720))
	var path := "user://football-v3-" + phase.to_lower() + "-" + mode + ".png"
	assert(img.save_png(path) == OK)
	print("FOOTBALL_RUN_V3_CAPTURE_" + phase + "_" + mode.to_upper() + "=" + ProjectSettings.globalize_path(path))
