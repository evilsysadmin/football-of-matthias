extends SceneTree

# Genuine Godot 3D preview of BOTH 4-3-3 sides at once. Only the scene
# instance in this test opts into the XI; shipped quick matches remain 5v5.
const Formation = preload("res://scripts/football_match_formation.gd")
const Scouting = preload("res://scripts/football_match_scouting.gd")

# Validate rendered pixels, not just actor nodes/texture metadata.
# Ignore scoreboards, spectators and stands; test team kits inside the pitch.
# A successful headless smoke alone must never approve 22 invisible players.
func _assert_visible_kit_colors(capture: Image) -> void:
	var blue_pixels := 0
	var red_pixels := 0
	for y in range(190, mini(capture.get_height(), 680), 2):
		for x in range(180, mini(capture.get_width(), 1100), 2):
			var color: Color = capture.get_pixel(x, y)
			if color.b > color.r * 1.5 and color.b > color.g * 1.03 and color.g < 0.57 and color.b > 0.28:
				blue_pixels += 1
			if color.r > color.g * 1.43 and color.r > color.b * 1.15 and color.r > 0.33 and color.g < 0.57:
				red_pixels += 1
	print("FOOTBALL_XI_RENDERED_KITS blue=%d red=%d" % [blue_pixels, red_pixels])
	assert(blue_pixels >= 45 and red_pixels >= 45,
		"XI broadcast must show *both* kits on the pitch, not only shadows")


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
	# The XI-visible quad must use exactly the same approved authored frame
	# and pose as the regular AnimatedSprite3D animation driver. One visible
	# body per player, no diagnostic geometry and no duplicate draw.
	assert(stage.xi_raster_sprites.size() == 22)
	for team in game.teams:
		for athlete in team:
			var key: int = athlete.get_instance_id()
			var driver: AnimatedSprite3D = stage.player_sprites[key]
			var body: Sprite3D = stage.xi_raster_sprites[key]
			assert(not driver.visible)
			assert(body != null and body.is_visible_in_tree())
			assert(body.texture == driver.sprite_frames.get_frame_texture(driver.animation, driver.frame))
			assert(body.flip_h == driver.flip_h)
			assert(body.pixel_size == driver.pixel_size)
			assert(body.position == driver.position)
			assert(body.scale == driver.scale)
			assert((body.texture as ImageTexture).get_image().get_used_rect().size.y >= 80)
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
		var actual_image: Image = viewport.get_texture().get_image()
		_assert_visible_kit_colors(actual_image)
		assert(actual_image.save_png(broadcast_path) == OK)
		print("FOOTBALL_XI_PREVIEW_BROADCAST=" + ProjectSettings.globalize_path(broadcast_path))
	# A readable XI must also keep its original authored animation clock:
	# the visible Sprite3D samples *new* approved textures as a winger runs.
	# This is a real presenter update, not a static proxy/image count.
	var winger: Footballer = game.teams[0][8]
	winger.velocity = Vector2.RIGHT * winger.base_speed
	winger.visual.play("run")
	var winger_key: int = winger.get_instance_id()
	var distinct_raster_frames: Dictionary = {}
	for frame_step in range(24):
		stage.sync_presentation(1.0 / 18.0, "broadcast")
		var driver: AnimatedSprite3D = stage.player_sprites[winger_key]
		var visible_body: Sprite3D = stage.xi_raster_sprites[winger_key]
		var authored: Texture2D = driver.sprite_frames.get_frame_texture(driver.animation, driver.frame)
		assert(visible_body.texture == authored)
		assert(visible_body.scale == driver.scale)
		assert(visible_body.flip_h == driver.flip_h)
		assert(visible_body.position == driver.position)
		distinct_raster_frames[authored.get_instance_id()] = true
	assert(distinct_raster_frames.size() >= 2,
		"XI Sprite3D must advance through approved real run frames")
	print("FOOTBALL_XI_ANIMATION_OK unique_run_frames=%d" % distinct_raster_frames.size())
	print("FOOTBALL_XI_PREVIEW_OK teams=11+11 stage=full_pitch unique=22")
	quit(0)
