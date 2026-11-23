extends SceneTree

const MatchScouting = preload("res://scripts/football_match_scouting.gd")

# Identity + visual contract for authentic XI back-shirt numbers.
# Each roster ID owns one shirt number regardless of lineup slot.
# Real Godot renders approved back/diagonal rasters plus composited ink
# on an Image COPY; original pixels/5v5 and match authority stay untouched.

func _initialize() -> void:
	var catalog: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/scouting_rosters_v1.json")
	)
	assert(catalog is Dictionary and catalog["version"] == 1)
	var shirt_catalog: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/shirt_numbers_v1.json")
	)
	assert(shirt_catalog is Dictionary and shirt_catalog["version"] == 1)
	var shirt_by_id: Dictionary = shirt_catalog["numbersByPlayerId"]
	assert(shirt_by_id.size() == 72)
	var validated := 0
	for club_id in catalog["clubs"]:
		var profiles: Array = catalog["clubs"][club_id].duplicate()
		profiles.append_array(catalog["eleven"][club_id]["extraPlayers"])
		assert(profiles.size() == 12)
		var ids := {}
		var numbers := {}
		for profile in profiles:
			var id: String = String(profile["id"])
			var number: int = int(shirt_by_id.get(id, 0))
			assert(not ids.has(id) and number >= 1 and number <= 99)
			assert(not numbers.has(number),
				"Shirt numbers must be unique PER club including substitutes")
			ids[id] = true
			numbers[number] = true
			validated += 1
		assert(numbers.size() == 12)
	assert(validated == 72)

	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game: Node2D = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	for _i in range(8):
		await process_frame
		await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	game.last_goal_text = ""
	var initial_score: Array = game.score.duplicate()
	var initial_time: float = game.match_seconds
	var home: Footballer = game.teams[0][10]
	var away: Footballer = game.teams[1][1]
	for team in game.teams:
		for player: Footballer in team:
			player.set_process(false)
			player.set_physics_process(false)
			player.velocity = Vector2.ZERO
			player.global_position = Vector2(-9999.0, -9999.0)
			var profile := MatchScouting.starter(
				player.team_id, player.squad_index, 11
			)
			assert(player.scouting_player_id == String(profile["id"]))
			assert(player.shirt_number == int(profile["shirtNumber"]))
			assert(player.shirt_number >= 1 and player.shirt_number <= 99)
			assert(stage.player_nodes[player.get_instance_id()].get_node_or_null(
				"RearShirtNumber") == null, "No floating text mesh over shirt")
	assert(home.shirt_number == 11 and away.shirt_number == 2)
	var center: Vector2 = game.match_pitch.get_center()
	home.global_position = center + Vector2(-170.0, 55.0)
	away.global_position = center + Vector2(110.0, -25.0)
	home.velocity = Vector2.UP * 230.0
	away.velocity = Vector2.UP * 215.0
	home.visual.play(&"run")
	away.visual.play(&"run")
	game.ball.attach_to(home)
	game._select_player(home)

	for mode in ["broadcast", "tactical"]:
		game.camera_mode = mode
		game._refresh_hud()
		stage._sync_camera(1.0, mode)
		stage.sync_presentation(0.0, mode)
		for player in [home, away]:
			var key: int = player.get_instance_id()
			var driver: AnimatedSprite3D = stage.player_sprites[key]
			assert(String(driver.animation).contains("_back"))
			var raw: Texture2D = stage._xi_frame_texture(player, driver)
			var render: Texture2D = (
				stage.xi_raster_meshes[key].material_override as StandardMaterial3D
			).albedo_texture
			assert(raw != null and render != null and raw != render,
				"Back jersey must be visibly textured, not a floating text node")
			assert(render.get_size() == raw.get_size())
			var raw_image: Image = raw.get_image()
			var rendered: Image = render.get_image()
			assert(rendered.get_data() != raw_image.get_data(),
				"Dorsal must actually change rendered shirt pixels")
			assert(rendered.get_used_rect() == raw_image.get_used_rect(),
				"Shirt ink must not change the athlete silhouette")
		await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = game.get_viewport().get_texture().get_image()
		assert(frame != null and frame.get_size() == Vector2i(1280, 720))
		var path: String = "user://xi-rear-dorsals-" + mode + ".png"
		assert(frame.save_png(path) == OK)
		print("FOOTBALL_XI_DORSALS_CAPTURE_" + mode.to_upper() + "=" +
			ProjectSettings.globalize_path(path))
		var body_px: Vector2 = stage.screen_position_for_player(home)
		var left := clampi(int(body_px.x) - 160, 0, 1280 - 480)
		var top := clampi(int(body_px.y) - 150, 0, 720 - 320)
		var detail: Image = frame.get_region(Rect2i(left, top, 480, 320))
		var detail_path: String = "user://xi-rear-dorsals-detail-" + mode + ".png"
		assert(detail.save_png(detail_path) == OK)
		print("FOOTBALL_XI_DORSALS_DETAIL_" + mode.to_upper() + "=" +
			ProjectSettings.globalize_path(detail_path))

	# Turning around must restore the very SAME approved source texture,
	# not show shirt ink on the chest, the side or on passing actions.
	home.velocity = Vector2.DOWN * 215.0
	away.velocity = Vector2.RIGHT * 215.0
	home.visual.play(&"run")
	away.visual.play(&"run")
	stage.sync_presentation(0.0, "broadcast")
	for player in [home, away]:
		var key: int = player.get_instance_id()
		var driver: AnimatedSprite3D = stage.player_sprites[key]
		var raw: Texture2D = stage._xi_frame_texture(player, driver)
		var render: Texture2D = (
			stage.xi_raster_meshes[key].material_override as StandardMaterial3D
		).albedo_texture
		assert(raw == render, "No digit pixels allowed on front/side raster frames")
	home.velocity = Vector2.UP * 230.0
	home.visual.play(&"run")
	stage.sync_presentation(0.0, "broadcast")
	var last_driver: AnimatedSprite3D = stage.player_sprites[home.get_instance_id()]
	assert((stage.xi_raster_meshes[home.get_instance_id()].material_override
		as StandardMaterial3D).albedo_texture != stage._xi_frame_texture(home, last_driver))
	assert(home.shirt_number == 11 and home.scouting_player_id == "fc-matthias-del-3")
	assert(game.score == initial_score)
	assert(is_equal_approx(game.match_seconds, initial_time))
	assert(game.ball.carrier == home)
	print("FOOTBALL_XI_DORSALS_OK catalog=72 teams=2 live=22 unique_per_club=1 identity_bound=1 back_only=1 views=2 front_side_unpainted=1 atlas_immutable=1 authority_unchanged=1")
	quit(0)
