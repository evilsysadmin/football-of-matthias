extends SceneTree

# Only this Godot scene opts into the real 22-actor 4-3-3 preview.
# The public match remains 5v5 until gameplay bounds are complete.
const Formation = preload("res://scripts/football_match_formation.gd")
const Scouting = preload("res://scripts/football_match_scouting.gd")

# Real screenshot pixels: shadows, texture metadata and MeshInstance3D
# counts alone cannot pass the visual gate.
func _assert_kit_pixels(capture: Image, mode: String, minimum: int) -> void:
	var blue := 0
	var red := 0
	for y in range(190, mini(capture.get_height(), 680), 2):
		for x in range(180, mini(capture.get_width(), 1100), 2):
			var color: Color = capture.get_pixel(x, y)
			if color.b > color.r * 1.5 and color.b > color.g * 1.03 and color.g < 0.57 and color.b > 0.28:
				blue += 1
			if color.r > color.g * 1.43 and color.r > color.b * 1.15 and color.r > 0.33 and color.g < 0.57:
				red += 1
	print("FOOTBALL_XI_RENDERED_KITS mode=%s blue=%d red=%d" % [mode, blue, red])
	assert(blue >= minimum and red >= minimum,
		"XI rendered screenshot must show two real kits, not only shadows")

# Confirm physical jerseys at projected on-field actor positions.
# Stadium seats and HUD colours cannot satisfy this check.
func _assert_tactical_player_kits(capture: Image, stage: ChessFootball3DPresenter, game: Node) -> void:
	var seen := [0, 0]
	for team in game.teams:
		for player in team:
			var screen: Vector2 = stage.screen_position_for_world(player.global_position, 0.70)
			var center := Vector2i(roundi(screen.x), roundi(screen.y))
			var found := false
			for y in range(maxi(181, center.y - 12), mini(capture.get_height() - 1, center.y + 13)):
				for x in range(maxi(255, center.x - 12), mini(capture.get_width() - 255, center.x + 13)):
					var c: Color = capture.get_pixel(x, y)
					if player.team_id == 0:
						if c.b > c.r * 1.5 and c.b > c.g * 1.03 and c.b > 0.28 and c.g < 0.57:
							found = true
					else:
						if c.r > c.g * 1.43 and c.r > c.b * 1.15 and c.r > 0.33 and c.g < 0.57:
							found = true
				if found:
					break
			if found:
				break
			if found:
				seen[player.team_id] += 1
	print("FOOTBALL_XI_ACTOR_KITS tactical blue=%d red=%d" % [seen[0], seen[1]])
	assert(seen[0] >= 8 and seen[1] >= 8,
		"XI tactical image must show players at their own projected positions")


func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	game.kickoff_seconds_remaining = 15.0
	for i in range(4):
		await process_frame
	game._prepare_kickoff(0, true)
	game.kickoff_seconds_remaining = 15.0
	assert(game.debug_team_counts() == [11, 11])
	assert(game.match_pitch == Formation.ELEVEN_PITCH_RECT)
	assert(game.kickoff_active)
	assert(game.ball.carrier != null)
	assert(game.ball.carrier.squad_index == 10)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null)
	assert(is_equal_approx(stage.field_width, 56.0))
	assert(is_equal_approx(stage.field_depth, 36.4))
	assert(stage.player_sprites.size() == 22)
	assert(stage.player_nodes.size() == 22)
	assert(stage.xi_raster_meshes.size() == 22)
	assert(stage.xi_actor_models.size() == 22)
	var center: Vector2 = game.match_pitch.get_center()
	var roster_ids: Dictionary = {}
	for team_id in range(2):
		for index in range(11):
			var player: Footballer = game.teams[team_id][index]
			var key: int = player.get_instance_id()
			var profile: Dictionary = Scouting.starter(team_id, index, 11)
			assert(player.scouting_player_id == profile["id"])
			assert(not roster_ids.has(player.scouting_player_id))
			roster_ids[player.scouting_player_id] = true
			assert(player.match_pitch == game.match_pitch)
			assert(game.match_pitch.has_point(player.global_position))
			var driver: AnimatedSprite3D = stage.player_sprites[key]
			var quad: MeshInstance3D = stage.xi_raster_meshes[key]
			assert(not driver.visible)
			assert(quad != null and quad.is_visible_in_tree())
			var sculpt: Node3D = stage.xi_actor_models[key]
			assert(sculpt != null and sculpt.is_visible_in_tree())
			assert(sculpt.get_node("Jersey") is MeshInstance3D)
			assert(sculpt.get_node("Head") is MeshInstance3D)
			assert(quad.mesh is QuadMesh)
			var canvas: StandardMaterial3D = quad.material_override
			var frame: Texture2D = driver.sprite_frames.get_frame_texture(driver.animation, driver.frame)
			assert(canvas.albedo_texture == frame)
			assert((frame as ImageTexture).get_image().get_used_rect().size.y >= 80)
			assert(quad.position == driver.position)
			if player == game.ball.carrier:
				assert(absf(player.global_position.x - center.x) < 80.0)
			elif team_id == 0:
				assert(player.global_position.x < center.x)
			else:
				assert(player.global_position.x > center.x)
	assert(roster_ids.size() == 22)
	# Whole-pitch projections belong to the aerial lens; broadcast follows
	# the ball and deliberately excludes some distant players.
	game.camera_mode = "tactical"
	stage.sync_presentation(2.0, "tactical")
	var viewport := root.get_viewport()
	var bounds := viewport.get_visible_rect().size
	assert(bounds.x > 100.0 and bounds.y > 100.0)
	for team in game.teams:
		for player in team:
			var screen: Vector2 = stage.screen_position_for_world(player.global_position)
			assert(screen.x > 0.0 and screen.x < bounds.x)
			assert(screen.y > 0.0 and screen.y < bounds.y)
	if DisplayServer.get_name() != "headless":
		game.camera_mode = "tactical"
		stage.sync_presentation(2.0, "tactical")
		for step in range(12):
			stage.sync_presentation(1.0 / 60.0, "tactical")
			await process_frame
			await RenderingServer.frame_post_draw
		var tactical_image: Image = viewport.get_texture().get_image()
		var tactical_path := "user://chess-football-xi-tactical.png"
		assert(tactical_image.save_png(tactical_path) == OK)
		print("FOOTBALL_XI_PREVIEW_TACTICAL=" + ProjectSettings.globalize_path(tactical_path))
		_assert_kit_pixels(tactical_image, "tactical", 20)
		_assert_tactical_player_kits(tactical_image, stage, game)
		game.camera_mode = "broadcast"
		stage.sync_presentation(2.0, "broadcast")
		for step in range(12):
			stage.sync_presentation(1.0 / 60.0, "broadcast")
			await process_frame
			await RenderingServer.frame_post_draw
		var broadcast_image: Image = viewport.get_texture().get_image()
		var broadcast_path := "user://chess-football-xi-broadcast.png"
		assert(broadcast_image.save_png(broadcast_path) == OK)
		print("FOOTBALL_XI_PREVIEW_BROADCAST=" + ProjectSettings.globalize_path(broadcast_path))
		_assert_kit_pixels(broadcast_image, "broadcast", 45)
	# Validate actual authored animation on the visible quad, not just
	# the hidden AnimatedSprite3D frame counter.
	var winger: Footballer = game.teams[0][8]
	winger.velocity = Vector2.RIGHT * winger.base_speed
	winger.visual.play("run")
	var winger_key: int = winger.get_instance_id()
	var distinct_frames: Dictionary = {}
	for step in range(24):
		stage.sync_presentation(1.0 / 18.0, "broadcast")
		var driver: AnimatedSprite3D = stage.player_sprites[winger_key]
		var body: MeshInstance3D = stage.xi_raster_meshes[winger_key]
		var frame: Texture2D = driver.sprite_frames.get_frame_texture(driver.animation, driver.frame)
		assert((body.material_override as StandardMaterial3D).albedo_texture == frame)
		assert(body.scale == driver.scale)
		assert(body.position == driver.position)
		distinct_frames[frame.get_instance_id()] = true
	assert(distinct_frames.size() >= 2, "XI visible quad must animate")
	print("FOOTBALL_XI_ANIMATION_OK unique_run_frames=%d" % distinct_frames.size())
	print("FOOTBALL_XI_PREVIEW_OK teams=11+11 stage=full_pitch unique=22")
	quit(0)
