extends SceneTree

const MatchScouting = preload("res://scripts/football_match_scouting.gd")

# Identity + visual contract for authentic XI back-shirt numbers.
# Each roster ID owns one shirt number regardless of lineup slot.
# Real Godot renders approved back/diagonal rasters; no generated
# numbers in front views and no gameplay/ball/clock modifications.

func _initialize() -> void:
	var catalog: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/scouting_rosters_v1.json")
	)
	assert(catalog is Dictionary and catalog["version"] == 1)
	var validated := 0
	for club_id in catalog["clubs"]:
		var profiles: Array = catalog["clubs"][club_id].duplicate()
		profiles.append_array(catalog["eleven"][club_id]["extraPlayers"])
		assert(profiles.size() == 12)
		var ids := {}
		var numbers := {}
		for profile in profiles:
			var id: String = String(profile["id"])
			var number: int = int(profile.get("shirtNumber", 0))
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
			var decal: Label3D = stage.player_nodes[player.get_instance_id()].get_node_or_null(
				"RearShirtNumber"
			)
			assert(decal != null)
			assert(decal.text == str(player.shirt_number))
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
		stage.sync_presentation(0.0, mode)
		for player in [home, away]:
			var key: int = player.get_instance_id()
			var back_label: Label3D = stage.player_nodes[key].get_node("RearShirtNumber")
			var driver: AnimatedSprite3D = stage.player_sprites[key]
			assert(String(driver.animation).contains("_back"))
			assert(back_label.visible)
			assert(back_label.text == str(player.shirt_number))
			assert(back_label.position.y > 0.50 and back_label.position.y < 1.65,
				"Number must be over the shirt torso, not above the head")
		await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = game.get_viewport().get_texture().get_image()
		assert(frame != null and frame.get_size() == Vector2i(1280, 720))
		var path: String = "user://xi-rear-dorsals-" + mode + ".png"
		assert(frame.save_png(path) == OK)
		print("FOOTBALL_XI_DORSALS_CAPTURE_" + mode.to_upper() + "=" +
			ProjectSettings.globalize_path(path))

	# Turn around in the REAL actor/3D driver; the number must disappear
	# in front and side views, and return on an authentic back view.
	home.velocity = Vector2.DOWN * 215.0
	away.velocity = Vector2.RIGHT * 215.0
	home.visual.play(&"run")
	away.visual.play(&"run")
	stage.sync_presentation(0.0, "broadcast")
	assert(not (stage.player_nodes[home.get_instance_id()].get_node(
		"RearShirtNumber") as Label3D).visible)
	assert(not (stage.player_nodes[away.get_instance_id()].get_node(
		"RearShirtNumber") as Label3D).visible)
	home.velocity = Vector2.UP * 230.0
	home.visual.play(&"run")
	stage.sync_presentation(0.0, "broadcast")
	assert((stage.player_nodes[home.get_instance_id()].get_node(
		"RearShirtNumber") as Label3D).visible)
	assert(home.shirt_number == 11 and home.scouting_player_id == "fc-matthias-del-3")
	assert(game.score == initial_score)
	assert(is_equal_approx(game.match_seconds, initial_time))
	assert(game.ball.carrier == home)
	print("FOOTBALL_XI_DORSALS_OK catalog=72 teams=2 live=22 unique_per_club=1 identity_bound=1 back_only=1 views=2 front_side_hidden=1 authority_unchanged=1")
	quit(0)
