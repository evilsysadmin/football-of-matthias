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
	# A fixed-Y quad viewed from directly above becomes a flat horizontal
	# streak even though the old connected-component counter still passes.
	# This is below the pre-regression main/#68 red-shirt pixel baseline
	# (500 samples) while rejecting the flattened #69 image (356).
	if mode == "tactical":
		assert(red >= 400, "XI tactical bodies look foreshortened/flat from overhead camera")

# Check the 11v11 tactical raster itself: 10 distinct shirt groups per
# team are inside the useful central pitch ROI (both extreme goalkeepers
# sit just beyond it). Each connected component is an independent player,
# so stands/UI colours cannot produce a false-green test.
func _assert_tactical_kit_clusters(capture: Image) -> void:
	var counts := [0, 0]
	for team_id in range(2):
		var colored: Dictionary = {}
		for y in range(182, mini(capture.get_height(), 630), 2):
			for x in range(260, mini(capture.get_width() - 260, 1020), 2):
				var c: Color = capture.get_pixel(x, y)
				var kit := (
					(c.b > c.r * 1.5 and c.b > c.g * 1.03 and c.b > 0.28 and c.g < 0.57)
					if team_id == 0 else
					(c.r > c.g * 1.43 and c.r > c.b * 1.15 and c.r > 0.33 and c.g < 0.57)
				)
				if kit:
					colored[Vector2i(x / 2, y / 2)] = true
		var visited: Dictionary = {}
		for origin in colored:
			if visited.has(origin):
				continue
			var stack: Array[Vector2i] = [origin]
			visited[origin] = true
			var members := 0
			while not stack.is_empty():
				var sample: Vector2i = stack.pop_back()
				members += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var neighbor := sample + Vector2i(dx, dy)
						if colored.has(neighbor) and not visited.has(neighbor):
							visited[neighbor] = true
							stack.push_back(neighbor)
			if members >= 4:
				counts[team_id] += 1
	print("FOOTBALL_XI_KIT_CLUSTERS tactical blue=%d red=%d" % [counts[0], counts[1]])
	assert(counts[0] >= 9 and counts[1] >= 9,
		"XI tactical image must contain distinct players from BOTH teams")


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
	# Both local and R2 XI frames render the same exclusive, texel-filtered QuadMesh.
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
			var fallback_model := stage.player_nodes[key].get_node_or_null("XI_KitSculpt") as Node3D
			assert(fallback_model != null and not fallback_model.visible)
			assert((quad.material_override as StandardMaterial3D).texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
			assert(quad.mesh is QuadMesh)
			var canvas: StandardMaterial3D = quad.material_override
			var frame: Texture2D = stage._xi_frame_texture(player, driver)
			assert(canvas.albedo_texture == frame)
			# Offline XI must honour the real authored idle/directional frame.
			# Rendered-pixel clusters below guard against invisible bodies.
			assert(frame == driver.sprite_frames.get_frame_texture(driver.animation, driver.frame))
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
	for quad in stage.xi_raster_meshes.values():
		assert((quad.material_override as StandardMaterial3D).billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED)
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
		_assert_tactical_kit_clusters(tactical_image)
		game.camera_mode = "broadcast"
		stage.sync_presentation(2.0, "broadcast")
		for quad in stage.xi_raster_meshes.values():
			assert((quad.material_override as StandardMaterial3D).billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y)
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
		var frame: Texture2D = stage._xi_frame_texture(winger, driver)
		assert((body.material_override as StandardMaterial3D).albedo_texture == frame)
		assert(body.scale == driver.scale)
		var expected_run_offset := stage.xi_rotated_foot_anchor_offset(
			stage.camera, frame, driver.pixel_size, driver.scale.y,
			driver.rotation.z, false
		)
		assert(body.position.is_equal_approx(driver.position + expected_run_offset))
		distinct_frames[frame.get_instance_id()] = true
	assert(distinct_frames.size() >= 2, "XI visible quad must animate")
	# Capture an ACTUALLY running far-touchline footballer. The ordinary XI
	# kickoff preview contains idle poses and cannot reveal tilted boot gaps.
	winger.global_position = Vector2(
		game.match_pitch.get_center().x - 330.0,
		game.match_pitch.position.y + 360.0
	)
	winger.action_lock_seconds = 0.0
	winger.velocity = Vector2.RIGHT * winger.base_speed
	winger._sync_locomotion(false)
	for step in range(10):
		stage.sync_presentation(1.0 / 60.0, "broadcast")
		await process_frame
		await RenderingServer.frame_post_draw
	var running_driver: AnimatedSprite3D = stage.player_sprites[winger_key]
	assert(absf(running_driver.rotation.z) > deg_to_rad(2.0))
	if DisplayServer.get_name() != "headless":
		var run_image: Image = viewport.get_texture().get_image()
		var run_path := "user://chess-football-xi-running-ground-broadcast.png"
		assert(run_image.save_png(run_path) == OK)
		print("FOOTBALL_XI_RUN_GROUND_BROADCAST=" + ProjectSettings.globalize_path(run_path))
		_assert_kit_pixels(run_image, "broadcast", 45)
	print("FOOTBALL_XI_ANIMATION_OK unique_run_frames=%d" % distinct_frames.size())
	print("FOOTBALL_XI_PREVIEW_OK teams=11+11 stage=full_pitch unique=22")
	quit(0)
