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
	# The new XI ball radius is 0.14; its centre must now sit at 0.16,
	# preserving the original 0.02 turf clearance of the 5v5 sphere.
	stage.sync_presentation(0.0, "broadcast")
	assert(is_equal_approx(stage.ball_node.position.y, 0.16),
		"Reduced XI ball must rest on the grass, not float at old height")
	var mid_near_y: float = game.match_pitch.get_center().y + game.match_pitch.size.y * 0.29
	var xi_mid_throw := Vector2(game.match_pitch.get_center().x, mid_near_y)
	# This was wrongly classified as 'near touchline' by the old 5v5
	# threshold (588 units instead of XI's 910 units).
	assert(is_equal_approx(ChessFootball3DPresenter.broadcast_restart_look_z(
		true, 0, "SAQUE DE BANDA", xi_mid_throw, game.match_pitch
	), ChessFootball3DPresenter.BROADCAST_BASE_LOOK_Z))
	assert(is_equal_approx(ChessFootball3DPresenter.broadcast_corner_camera_depth(
		true, 0, "CÓRNER", xi_mid_throw, game.match_pitch
	), ChessFootball3DPresenter.BROADCAST_DEPTH))
	assert(is_equal_approx(ChessFootball3DPresenter.broadcast_live_corner_pitch_floor(
		Vector2(game.match_pitch.get_center().x,
			game.match_pitch.get_center().y + game.match_pitch.size.y * 0.25),
		game.match_pitch
	), ChessFootball3DPresenter.BROADCAST_BASE_LOOK_Z))
	var xi_near_corner := Vector2(
		game.match_pitch.end.x - 70.0, game.match_pitch.end.y - 40.0
	)
	assert(ChessFootball3DPresenter.broadcast_restart_look_z(
		true, 0, "CÓRNER", xi_near_corner, game.match_pitch
	) > ChessFootball3DPresenter.BROADCAST_BASE_LOOK_Z)
	assert(ChessFootball3DPresenter.broadcast_corner_camera_depth(
		true, 0, "CÓRNER", xi_near_corner, game.match_pitch
	) > ChessFootball3DPresenter.BROADCAST_DEPTH)
	# The XI human near-corner framing should keep more of the end stand
	# visible, mirrored for the opposite end, and never leak into normal play.
	var corner_focus := 22.0
	var new_focus: float = ChessFootball3DPresenter.xi_corner_stadium_camera_x(
		corner_focus, true, true, 0, "CÓRNER", xi_near_corner, game.match_pitch
	)
	assert(is_equal_approx(new_focus,
		corner_focus - ChessFootball3DPresenter.XI_NEAR_CORNER_STADIUM_PAN))
	var xi_near_left := Vector2(game.match_pitch.position.x + 70.0, xi_near_corner.y)
	assert(is_equal_approx(ChessFootball3DPresenter.xi_corner_stadium_camera_x(
		-corner_focus, true, true, 0, "CÓRNER", xi_near_left, game.match_pitch
	), -new_focus), "XI corner bias must mirror at the opposite goal")
	for alternate in [
		[false, true, 0, "CÓRNER", xi_near_corner],
		[true, false, 0, "CÓRNER", xi_near_corner],
		[true, true, 1, "CÓRNER", xi_near_corner],
		[true, true, 0, "SAQUE DE BANDA", xi_near_corner],
		[true, true, 0, "CÓRNER", xi_mid_throw],
		[true, true, 0, "CÓRNER",
			Vector2(xi_near_corner.x, game.match_pitch.position.y + 40.0)],
	]:
		assert(is_equal_approx(ChessFootball3DPresenter.xi_corner_stadium_camera_x(
			corner_focus, alternate[0], alternate[1], alternate[2],
			alternate[3], alternate[4], game.match_pitch
		), corner_focus), "XI corner stadium framing leaked into another state")
	assert(is_equal_approx(stage.field_width, 56.0))
	assert(is_equal_approx(stage.field_depth, 36.4))
	assert(stage.player_sprites.size() == 22)
	assert(stage.player_nodes.size() == 22)
	assert(stage.xi_raster_meshes.size() == 22)
	# The visible XI ball is smaller, without changing the physical 2D ball.
	var ball_sphere := stage.ball_node.mesh as SphereMesh
	var ball_shadow_mesh := stage.ball_shadow.mesh as CylinderMesh
	assert(ball_sphere != null and ball_shadow_mesh != null)
	assert(is_equal_approx(ball_sphere.radius, 0.14))
	assert(is_equal_approx(ball_sphere.height, 0.28))
	assert(is_equal_approx(ball_shadow_mesh.top_radius, 0.095))
	assert(is_equal_approx(ball_shadow_mesh.bottom_radius, 0.095))
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
	# The tactical lens must include the actual four corner flags, not only
	# the narrower 4-3-3 player formation.
	for edge_x in [game.match_pitch.position.x, game.match_pitch.end.x]:
		for edge_y in [game.match_pitch.position.y, game.match_pitch.end.y]:
			var corner_screen: Vector2 = stage.screen_position_for_world(Vector2(edge_x, edge_y), 0.02)
			assert(corner_screen.x > 25.0 and corner_screen.x < bounds.x - 25.0,
				"XI tactical camera clips pitch end line")
			assert(corner_screen.y > 125.0 and corner_screen.y < bounds.y - 30.0,
				"XI tactical camera clips a touchline")
	# Wide viewports expand the playable pitch instead of showing black bars.
	# Preserve the original 16:9 lens, but use spare ultrawide width for
	# slightly larger XI sprites. Restarts/corner recovery keep the safe FOV.
	assert(is_equal_approx(
		ChessFootball3DPresenter.xi_broadcast_fov_for_aspect(Vector2(1280, 720)),
		ChessFootball3DPresenter.XI_BROADCAST_FOV
	))
	assert(ChessFootball3DPresenter.xi_broadcast_fov_for_aspect(
		Vector2(1766, 832)
	) < ChessFootball3DPresenter.XI_BROADCAST_FOV - 3.0)
	assert(is_equal_approx(
		ChessFootball3DPresenter.xi_broadcast_fov_for_aspect(Vector2(1766, 832), true),
		ChessFootball3DPresenter.XI_BROADCAST_FOV
	))
	assert(is_equal_approx(
		ChessFootball3DPresenter.xi_broadcast_fov_for_aspect(Vector2(4000, 800)),
		ChessFootball3DPresenter.XI_BROADCAST_WIDE_FOV
	))
	assert(is_equal_approx(
		ChessFootball3DPresenter.xi_broadcast_fov_for_aspect(Vector2(0, 0)),
		ChessFootball3DPresenter.XI_BROADCAST_FOV
	))
	# HUD is edge-anchored or centered as the viewport expands.
	assert(game.view_label.anchor_left == 1.0)
	assert(game.goal_label.anchor_left == 0.5)
	assert(game.shot_meter_label.anchor_left == 0.5)
	var controls_panel := game.get_node("MatchHud/MatchControlsPanel") as Panel
	assert(controls_panel.anchor_right == 1.0)
	# Live central play gets a closer lens, restoring the original safe
	# field of view near touchlines and during set pieces, at either aspect.
	var pitch_center: Vector2 = game.match_pitch.get_center()
	var near_touchline: Vector2 = pitch_center + Vector2(
		0.0, game.match_pitch.size.y * 0.45
	)
	for size in [Vector2(1280, 720), Vector2(1766, 832)]:
		var safe_fov: float = ChessFootball3DPresenter.xi_broadcast_fov_for_aspect(size)
		assert(is_equal_approx(
			ChessFootball3DPresenter.xi_broadcast_live_fov(size, pitch_center, game.match_pitch),
			safe_fov - ChessFootball3DPresenter.XI_BROADCAST_CENTER_ZOOM_DEGREES
		), "XI midfield zoom should make players larger")
		assert(is_equal_approx(
			ChessFootball3DPresenter.xi_broadcast_live_fov(size, near_touchline, game.match_pitch),
			safe_fov
		), "XI near-touchline zoom must release before cropping the ball")
		assert(is_equal_approx(
			ChessFootball3DPresenter.xi_broadcast_live_fov(size, pitch_center, game.match_pitch, true),
			ChessFootball3DPresenter.xi_broadcast_fov_for_aspect(size, true)
		), "XI set piece must preserve the wide 41-degree restart lens")
	assert(is_equal_approx(
		ChessFootball3DPresenter.xi_broadcast_live_fov(
			Vector2(1280, 720), pitch_center, Rect2()
		), ChessFootball3DPresenter.XI_BROADCAST_FOV
	), "Invalid pitch cannot force close camera")
	# A broadcast match camera should fill the screen with RECOGNIZABLE
	# sprites, not squeeze both goals and four touchlines into every shot.
	# Whole-pitch framing remains available exclusively in tactical mode.
	game.camera_mode = "broadcast"
	stage.sync_presentation(2.0, "broadcast")
	assert(absf(stage.camera.fov - ChessFootball3DPresenter.xi_broadcast_live_fov(
		bounds, game.ball.global_position, game.match_pitch
	)) < 0.08)
	assert(absf(stage.camera.position.z - (
		ChessFootball3DPresenter.BROADCAST_DEPTH *
		ChessFootball3DPresenter.XI_BROADCAST_DEPTH_SCALE
	)) < 0.08)
	var baseline_foot := stage.screen_position_for_world(center, 0.02)
	var baseline_top := stage.screen_position_for_world(center, 1.50)
	assert(baseline_foot.distance_to(baseline_top) > 30.0,
		"11v11 broadcast still makes the footballers look tiny")
	assert(not ChessFootball3DPresenter.broadcast_corner_release_active(
		"broadcast", false, stage.camera.position.z, true
	), "Normal XI broadcast must not trigger the corner-release camera")
	# The old >= base check forced the far lane to remain at midfield
	# whenever no set piece was active. Guard both signs, and keep the
	# stronger look shift reserved for an actual near/far human restart.
	var base_z := ChessFootball3DPresenter.BROADCAST_BASE_LOOK_Z
	assert(is_equal_approx(ChessFootball3DPresenter.xi_broadcast_target_look_z(
		base_z - 4.0, base_z
	), base_z - 4.0), "Far-side live play must be followed")
	assert(is_equal_approx(ChessFootball3DPresenter.xi_broadcast_target_look_z(
		base_z + 4.0, base_z
	), base_z + 4.0), "Near-side live play must be followed")
	assert(is_equal_approx(ChessFootball3DPresenter.xi_broadcast_target_look_z(
		base_z + 4.0, base_z + 7.0
	), base_z + 7.0), "Near corner needs its authored clearance")
	assert(is_equal_approx(ChessFootball3DPresenter.xi_broadcast_target_look_z(
		base_z - 4.0, base_z - 6.0
	), base_z - 6.0), "Far restart needs its authored clearance")
	# Move the authoritative ball near all four active corners, but do not
	# insist on viewing remote goals during a midfield attack.
	var initial_ball: Vector2 = game.ball.global_position
	for x_fraction in [0.10, 0.90]:
		for y_fraction in [0.12, 0.88]:
			var live_spot: Vector2 = game.match_pitch.position + Vector2(
				game.match_pitch.size.x * x_fraction,
				game.match_pitch.size.y * y_fraction
			)
			game.ball.global_position = live_spot
			stage.sync_presentation(8.0, "broadcast")
			var expected_lane: float = ChessFootball3DPresenter.xi_broadcast_lane_look_z(
				live_spot, game.match_pitch
			)
			assert(absf(stage.smoothed_restart_look_z - expected_lane) < 0.03,
				"XI broadcast does not follow the active ball in both vertical lanes")
			var in_frame := stage.screen_position_for_world(live_spot, 0.02)
			assert(in_frame.x > 70.0 and in_frame.x < bounds.x - 70.0,
				"Close-follow XI broadcast lost the ball horizontally")
			assert(in_frame.y > 145.0 and in_frame.y < bounds.y - 35.0,
				"Close-follow XI broadcast lost the ball near a touchline")
	game.ball.global_position = initial_ball
	stage.sync_presentation(8.0, "broadcast")
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
		# Preserve real pixel evidence for both halves, not just a midfield
		# kickoff picture. The simulation is frozen while staging each shot.
		game.set_process(false)
		game.set_physics_process(false)
		for lane_name in ["FAR", "NEAR"]:
			var lane_fraction: float = 0.06 if lane_name == "FAR" else 0.94
			var lane_spot: Vector2 = Vector2(
				center.x, game.match_pitch.position.y + game.match_pitch.size.y * lane_fraction
			)
			game.ball.global_position = lane_spot
			stage.sync_presentation(8.0, "broadcast")
			var expected_lane_z: float = ChessFootball3DPresenter.xi_broadcast_lane_look_z(
				lane_spot, game.match_pitch
			)
			assert(absf(stage.smoothed_restart_look_z - expected_lane_z) < 0.03)
			var ball_pixel: Vector2 = stage.screen_position_for_world(lane_spot, 0.02)
			assert(ball_pixel.x > 70.0 and ball_pixel.x < bounds.x - 70.0)
			assert(ball_pixel.y > 155.0 and ball_pixel.y < bounds.y - 35.0)
			for _settle in range(3):
				stage.sync_presentation(0.0, "broadcast")
				await process_frame
				await RenderingServer.frame_post_draw
			var lane_image: Image = viewport.get_texture().get_image()
			var lane_path: String = "user://chess-football-xi-lane-" + lane_name.to_lower() + ".png"
			assert(lane_image.save_png(lane_path) == OK)
			print("FOOTBALL_XI_LANE_CAPTURE_%s=%s" %
				[lane_name, ProjectSettings.globalize_path(lane_path)])
		game.ball.global_position = initial_ball
		stage.sync_presentation(8.0, "broadcast")
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
	# Freeze the match authority *only for this visual diagnostic*; otherwise
	# live kickoff physics resets winger velocity between frame_post_draw awaits.
	game.set_physics_process(false)
	game.set_process(false)
	winger.global_position = Vector2(
		game.match_pitch.get_center().x - 330.0,
		game.match_pitch.position.y + 360.0
	)
	winger.action_lock_seconds = 0.0
	winger.velocity = Vector2.RIGHT * winger.base_speed
	winger._sync_locomotion(false)
	for step in range(10):
		stage.sync_presentation(1.0 / 60.0, "broadcast")
		# Headless CI has no frame_post_draw signal. Keep the deterministic
		# transform assertions there; only await pixels in windowed Godot.
		if DisplayServer.get_name() != "headless":
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
	# Actual camera exercise in two human-owned XI restarts, using the full
	# 4,000 x 2,600 pitch. Keep synthetic set-piece state isolated to this
	# frozen visual test; gameplay restart and collision code are untouched.
	game.ball.release(Vector2.RIGHT, 0.0)
	game.ball.flight_height = 0.0
	game.set_piece_active = true
	game.set_piece_team_id = 0
	game.set_piece_seconds_remaining = 2.0
	for case_name in ["MID_THROW", "NEAR_CORNER"]:
		var shot_spot: Vector2 = xi_mid_throw if case_name == "MID_THROW" else xi_near_corner
		game.set_piece_kind = "SAQUE DE BANDA" if case_name == "MID_THROW" else "CÓRNER"
		game.set_piece_spot = shot_spot
		game.ball.global_position = shot_spot
		stage.sync_presentation(8.0, "broadcast")
		if case_name == "NEAR_CORNER":
			assert(stage.camera.position.x > 0.0 and stage.camera.position.x < 20.0,
				"XI near-corner camera still follows the sideline into black space")
		if case_name == "MID_THROW":
			assert(is_equal_approx(stage.smoothed_restart_look_z,
				ChessFootball3DPresenter.xi_broadcast_lane_look_z(
					shot_spot, game.match_pitch
				)),
				"Midfield XI throw-in should follow the lane without a fake corner")
		var spot_on_screen: Vector2 = stage.screen_position_for_world(shot_spot, 0.02)
		print("FOOTBALL_XI_RESTART_PROJECTION_%s=%.1f,%.1f" %
			[case_name, spot_on_screen.x, spot_on_screen.y])
		assert(spot_on_screen.x > 18.0 and spot_on_screen.x < bounds.x - 18.0,
			"XI restart camera lost the restart at the horizontal edge")
		assert(spot_on_screen.y > 142.0 and spot_on_screen.y < bounds.y - 14.0,
			"XI restart camera lost the restart at the touchline")
		if DisplayServer.get_name() != "headless":
			for _render_step in range(3):
				stage.sync_presentation(0.0, "broadcast")
				await process_frame
				await RenderingServer.frame_post_draw
			var restart_image: Image = viewport.get_texture().get_image()
			var restart_path: String = "user://chess-football-xi-restart-" + case_name.to_lower() + ".png"
			assert(restart_image.save_png(restart_path) == OK)
			print("FOOTBALL_XI_RESTART_CAPTURE_%s=%s" %
				[case_name, ProjectSettings.globalize_path(restart_path)])
	print("FOOTBALL_XI_ANIMATION_OK unique_run_frames=%d" % distinct_frames.size())
	print("FOOTBALL_XI_PREVIEW_OK teams=11+11 stage=full_pitch unique=22")
	quit(0)
