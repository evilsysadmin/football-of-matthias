extends SceneTree

# Genuine rendered 11v11 Godot screenshot before and after loading the two
# exact R2 sheets downloaded, pinned and CORS-verified by the preceding CI.
func _initialize() -> void:
	var directory := OS.get_environment("FOOTBALL_RUN_V2_PREVIEW_DIR")
	assert(not directory.is_empty(), "Verified R2 preview directory not set")
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	for _frame in range(8):
		await process_frame
		await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var presenter: ChessFootball3DPresenter = game.presentation_3d
	assert(presenter != null)
	assert(presenter.xi_raster_meshes.size() == 22)
	# The BEFORE screenshot must have 22 visible players and only one
	# body per actor while optional R2 is unavailable.
	for team in game.teams:
		for player in team:
			var key: int = player.get_instance_id()
			assert(presenter.player_nodes[key].get_node("XI_KitSculpt").visible)
			assert(not presenter.xi_raster_meshes[key].visible)
	for team in game.teams:
		for player in team:
			if player.role != "keeper":
				player.velocity = Vector2.RIGHT * maxf(player.base_speed, 60.0)
				player._sync_locomotion(false)
	presenter.sync_presentation(0.11, "broadcast")
	await _capture(game, "BEFORE", "football-run-v2-before.png")
	for team_id in range(2):
		var meta := ChessFootballRunV2R2.sheet_meta(team_id)
		assert(not meta.is_empty())
		var kind: String = String(ChessFootballRunV2R2.KINDS[team_id])
		var filename: String = kind + "_run_v2_clean.webp"
		var path := directory.path_join(filename)
		assert(FileAccess.file_exists(path), "Missing SHA-verified R2 WebP: " + path)
		var bytes := FileAccess.get_file_as_bytes(path)
		var image := ChessFootballR2AtlasLoader.decode_verified_webp(
			bytes, meta, ChessFootballRunV2R2.TRUSTED_ROOT
		)
		assert(image != null, "R2 integrity failed at Godot decoder: " + filename)
		presenter._on_run_v2_ready(image, team_id)
		assert(presenter._run_v2_r2_loaded.has(team_id))
		for player in game.teams[team_id]:
			if player.role == "keeper":
				continue
			assert(not presenter.player_nodes[player.get_instance_id()].get_node("XI_KitSculpt").visible)
			assert(presenter.xi_raster_meshes[player.get_instance_id()].visible)
	presenter.sync_presentation(0.11, "broadcast")
	await _capture(game, "AFTER", "football-run-v2-after.png")
	print("FOOTBALL_RUN_V2_REAL_GODOT_REVIEW_OK teams=2 outfield=20 shadows=22")
	quit(0)


func _capture(game: Node, label: String, filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := game.get_viewport().get_texture().get_image()
	assert(image != null and image.get_size() == Vector2i(1280, 720))
	var path := "user://" + filename
	assert(image.save_png(path) == OK)
	print("FOOTBALL_RUN_V2_CAPTURE_" + label + "=" + ProjectSettings.globalize_path(path))
