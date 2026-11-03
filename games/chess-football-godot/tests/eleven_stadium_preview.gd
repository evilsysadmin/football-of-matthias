extends SceneTree

# Genuine Godot 3D preview of BOTH 4-3-3 sides at once. Only the scene
# instance in this test opts into the XI; shipped quick matches remain 5v5.
const Formation = preload("res://scripts/football_match_formation.gd")
const Scouting = preload("res://scripts/football_match_scouting.gd")

func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	for i in range(4):
		await process_frame
	# Preserve the SAME real physics/presenter update path as a normal match.
	# Keep the kickoff freeze long enough to capture both camera modes without
	# letting the incomplete 11v11 match rules advance.
	game.kickoff_seconds_remaining = 15.0
	assert(game.debug_team_counts() == [11, 11])
	assert(game.match_pitch == Formation.ELEVEN_PITCH_RECT)
	assert(game.kickoff_active)
	assert(game.ball.carrier != null)
	assert(game.ball.carrier.squad_index == 10)
	assert(game.ball.carrier.team_id == game.kickoff_team_id)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null)
	assert(is_equal_approx(stage.field_width, 56.0))
	assert(is_equal_approx(stage.field_depth, 36.4))
	assert(stage.player_sprites.size() == 22)
	assert(stage.player_nodes.size() == 22)
	var center: Vector2 = game.match_pitch.get_center()
	var roster_ids: Dictionary = {}
	for team_id in range(2):
		for index in range(11):
			var player: Footballer = game.teams[team_id][index]
			var profile: Dictionary = Scouting.starter(team_id, index, 11)
			assert(player.scouting_player_id == profile["id"])
			assert(not roster_ids.has(player.scouting_player_id))
			roster_ids[player.scouting_player_id] = true
			assert(player.match_pitch == game.match_pitch)
			assert(game.match_pitch.has_point(player.global_position))
			assert(stage.player_sprites.has(player.get_instance_id()))
			assert(stage.player_nodes.has(player.get_instance_id()))
			if player == game.ball.carrier:
				assert(absf(player.global_position.x - center.x) < 80.0)
			elif team_id == 0:
				assert(player.global_position.x < center.x)
			else:
				assert(player.global_position.x > center.x)
	assert(roster_ids.size() == 22)
	game.camera_mode = "tactical"
	stage.sync_presentation(2.0, "tactical")
	# Sprite3D textures and camera transforms must survive multiple real
	# rendered frames before taking visual evidence of the 22 athletes.
	if DisplayServer.get_name() != "headless":
		for render_frame in range(12):
			stage.sync_presentation(1.0 / 60.0, "tactical")
			await process_frame
			await RenderingServer.frame_post_draw
	# Diagnostic guard: a valid 3D proxy is not sufficient if its authored
	# raster body is empty/invisible. Keep the instrumented sample small.
	for sample_id in [0, 10]:
		var athlete: Footballer = game.teams[0][sample_id]
		var body: AnimatedSprite3D = stage.player_sprites[athlete.get_instance_id()]
		var source: Texture2D = body.sprite_frames.get_frame_texture(body.animation, body.frame)
		assert(source != null)
		var silhouette: Rect2i = (source as ImageTexture).get_image().get_used_rect()
		print("FOOTBALL_XI_BODY_SAMPLE index=%d visible=%s tree=%s frame=%s bounds=%s world=%s scale=%s camera=%s color=%s opacity=%.2f pixel=%.4f" % [
			sample_id, body.visible, body.is_visible_in_tree(), body.animation,
			silhouette, body.global_position, body.scale, stage.camera.global_position,
			body.modulate, body.transparency, body.pixel_size,
		])
		assert(silhouette.size.y >= 80)
	# Diagnostic comparison: a plain Sprite3D using the SAME approved raster
	# frame, beside the actual animated players. If it renders, distinguish
	# an AnimatedSprite3D path failure from camera/material/lens visibility.
	var source_actor: Footballer = game.teams[0][10]
	var animated: AnimatedSprite3D = stage.player_sprites[source_actor.get_instance_id()]
	var diagnostic := Sprite3D.new()
	diagnostic.texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	diagnostic.pixel_size = animated.pixel_size
	diagnostic.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	diagnostic.shaded = false
	diagnostic.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	diagnostic.alpha_scissor_threshold = 0.12
	diagnostic.position = Vector3(-2.0, 1.0, 0.0)
	diagnostic.name = "XI_StandaloneRasterDiagnostic"
	stage.add_child(diagnostic)
	var marker := MeshInstance3D.new()
	marker.mesh = BoxMesh.new()
	marker.position = Vector3(2.0, 1.0, 0.0)
	marker.name = "XI_MeshDiagnostic"
	stage.add_child(marker)
	var viewport := root.get_viewport()
	var size := viewport.get_visible_rect().size
	assert(size.x > 100.0 and size.y > 100.0)
	for team in game.teams:
		for player in team:
			var screen: Vector2 = stage.screen_position_for_world(player.global_position)
			assert(screen.x > 0.0 and screen.x < size.x)
			assert(screen.y > 0.0 and screen.y < size.y)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var tactical_path := "user://chess-football-xi-tactical.png"
		assert(viewport.get_texture().get_image().save_png(tactical_path) == OK)
		print("FOOTBALL_XI_PREVIEW_TACTICAL=" + ProjectSettings.globalize_path(tactical_path))
		game.camera_mode = "broadcast"
		stage.sync_presentation(2.0, "broadcast")
		for render_frame in range(12):
			stage.sync_presentation(1.0 / 60.0, "broadcast")
			await process_frame
			await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var broadcast_path := "user://chess-football-xi-broadcast.png"
		assert(viewport.get_texture().get_image().save_png(broadcast_path) == OK)
		print("FOOTBALL_XI_PREVIEW_BROADCAST=" + ProjectSettings.globalize_path(broadcast_path))
	print("FOOTBALL_XI_PREVIEW_OK teams=11+11 stage=full_pitch unique=22")
	quit(0)
