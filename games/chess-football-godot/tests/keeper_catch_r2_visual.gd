extends SceneTree

# The normal visual gate captures the canonical, unchanged fallback. This
# *additional* real Godot 3D renderer review uses the two exact R2 WebPs that
# the preceding CI step downloaded, checked for SHA256 and CORS.
func _initialize() -> void:
	var asset_dir := OS.get_environment("FOOTBALL_KEEPER_CATCH_PREVIEW_DIR")
	assert(not asset_dir.is_empty(), "Missing verified external keeper WebP directory")
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var match_node = packed.instantiate()
	root.add_child(match_node)
	for _frame in range(8):
		await process_frame
		await physics_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	var presenter: ChessFootball3DPresenter = match_node.presentation_3d
	assert(match_node.camera_mode == "broadcast")
	var original_score: Array = match_node.score.duplicate()
	for team_id in range(2):
		var meta := ChessFootballKeeperCatchR2.active_entry(team_id)
		assert(not meta.is_empty())
		var file_path := asset_dir.path_join(String(ChessFootballKeeperCatchR2.source_entry(team_id)["file"]))
		assert(FileAccess.file_exists(file_path), "Real keeper sheet was not downloaded")
		var bytes := FileAccess.get_file_as_bytes(file_path)
		# Runtime verifies the same exact independent origin as the live
		# keeper-only HTTP loader; the shared CDN default must stay rejected.
		var authorized_root := ChessFootballKeeperCatchR2.public_root()
		assert(not authorized_root.is_empty())
		assert(not ChessFootballR2AtlasLoader.valid_metadata(meta))
		assert(ChessFootballR2AtlasLoader.valid_metadata(meta, authorized_root))
		var sheet := ChessFootballR2AtlasLoader.decode_verified_webp(bytes, meta, authorized_root)
		assert(sheet != null, "R2 keeper bytes must pass the runtime's own SHA-256 verifier")
		var poses := ChessFootballKeeperCatchR2.frames_from_image(
			sheet, ChessFootballKeeperCatchR2.source_entry(team_id)
		)
		assert(poses.size() == 8, "R2 keeper sheet must have eight usable poses")
		presenter._apply_verified_keeper_catch_frames(poses, team_id)
		assert(presenter._keeper_catch_r2_loaded.has(team_id))
		var keeper: Footballer = match_node.teams[team_id][0]
		var sprite: AnimatedSprite3D = presenter.player_sprites[keeper.get_instance_id()]
		var original_keeper_position: Vector2 = keeper.global_position
		# Centre-field inspection avoids the edge-clamped broadcast camera
		# cropping a goalkeeper during the first capture of either team.
		# This is a visual test scene only; the match never gets this move.
		keeper.global_position = ChessFootballMath.PITCH_RECT.get_center()
		match_node.ball.attach_to(keeper)
		# Preposition the actual broadcast camera at each end of the
		# pitch BEFORE resetting the grip clock. A single focus tick can
		# leave the first frame cropped as the camera crosses the stadium.
		for _camera_step in range(4):
			match_node.debug_focus_presentation()
		for _render_step in range(2):
			await process_frame
		presenter.keeper_catch_carrier_id = 0
		presenter.keeper_catch_elapsed = 0.0
		presenter.sync_presentation(0.018, "broadcast")
		assert(sprite.animation == &"keeper_catch" and sprite.frame == 0)
		assert(not presenter.debug_keeper_catch_hands_visible(keeper))
		await _save_keeper(match_node, team_id, "open")
		presenter.sync_presentation(0.075, "broadcast")
		# The grip clock advances at the end of sync_presentation; refresh
		# the visible sprite frame from that updated clock before asserting.
		presenter.sync_presentation(0.0, "broadcast")
		assert(sprite.frame >= 2 and sprite.frame <= 5)
		await _save_keeper(match_node, team_id, "closing")
		presenter.sync_presentation(0.20, "broadcast")
		presenter.sync_presentation(0.0, "broadcast")
		assert(sprite.frame == 7)
		assert(not presenter.ball_shadow.visible)
		assert(not presenter.debug_keeper_catch_hands_visible(keeper))
		assert(absf(presenter.ball_node.position.x
			- presenter.world_to_stage(keeper.global_position).x) < 0.04)
		await _save_keeper(match_node, team_id, "held")
		await _save_full(match_node, team_id)
		match_node.ball.release(Vector2.RIGHT, 0.0)
		presenter.sync_presentation(0.0, "broadcast")
		assert(sprite.animation != &"keeper_catch")
		assert(presenter.ball_shadow.visible)
		keeper.global_position = original_keeper_position
	assert(match_node.score == original_score)
	print("FOOTBALL_KEEPER_R2_REAL_GODOT_REVIEW_OK teams=2 poses=8")
	quit(0)


func _team_key(team_id: int) -> String:
	return "fc" if team_id == 0 else "enroque"


func _save_keeper(match_node: Node, team_id: int, phase: String) -> void:
	await process_frame
	var viewport := match_node.get_viewport()
	var image := viewport.get_texture().get_image()
	assert(image != null and not image.is_empty())
	var camera := viewport.get_camera_3d()
	assert(camera != null)
	var keeper: Footballer = match_node.teams[team_id][0]
	var sprite: AnimatedSprite3D = match_node.presentation_3d.player_sprites[keeper.get_instance_id()]
	var center := camera.unproject_position(sprite.global_position)
	var width := 116
	var height := 144
	assert(center.x >= float(width) * 0.5 + 8.0)
	assert(center.x <= float(image.get_width()) - float(width) * 0.5 - 8.0)
	assert(center.y >= float(height) * 0.5 + 8.0)
	assert(center.y <= float(image.get_height()) - float(height) * 0.5 - 8.0)
	var x := clampi(int(center.x) - width / 2, 0, image.get_width() - width)
	var y := clampi(int(center.y) - height / 2, 0, image.get_height() - height)
	var crop := image.get_region(Rect2i(x, y, width, height))
	crop.resize(width * 4, height * 4, Image.INTERPOLATE_NEAREST)
	var id := "keeper-r2-%s-%s" % [_team_key(team_id), phase]
	var path := "user://football-%s.png" % id
	assert(crop.save_png(path) == OK)
	print("FOOTBALL_KEEPER_R2_CAPTURE_%s_%s=%s" % [
		_team_key(team_id).to_upper(), phase.to_upper(), ProjectSettings.globalize_path(path)
	])


func _save_full(match_node: Node, team_id: int) -> void:
	await process_frame
	var image := match_node.get_viewport().get_texture().get_image()
	assert(image != null and not image.is_empty())
	var path := "user://football-keeper-r2-%s-broadcast.png" % _team_key(team_id)
	assert(image.save_png(path) == OK)
	print("FOOTBALL_KEEPER_R2_CAPTURE_%s_BROADCAST=%s" % [
		_team_key(team_id).to_upper(), ProjectSettings.globalize_path(path)
	])
