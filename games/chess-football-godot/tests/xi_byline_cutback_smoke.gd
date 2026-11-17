extends SceneTree

# XI: human wing reaches the actual byline -> striker attacks the spot,
# midfielder arrives for the safer cutback. CPU may mark the REAL lane.
# No teleports, automatic goals, free catches or changed 5v5/CPU attack.
const DT := 1.0 / 60.0

func _initialize() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	var pitch: Rect2 = game.match_pitch
	var mid: Vector2 = pitch.get_center()
	var goal_x: float = pitch.end.x
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.velocity = Vector2.ZERO
			actor.global_position = Vector2(
				pitch.position.x + 80.0 if actor.team_id == 0 else pitch.end.x - 80.0,
				pitch.position.y + 65.0 + float(actor.squad_index) * 170.0
			)
	var carrier: Footballer = game.teams[0][8]
	var striker: Footballer = game.teams[0][10]
	var edge: Footballer = game.teams[0][6]
	var tempting_winger: Footballer = game.teams[0][9]
	carrier.global_position = Vector2(goal_x - 520.0, mid.y - 720.0)
	striker.global_position = Vector2(goal_x - 965.0, mid.y - 185.0)
	edge.global_position = Vector2(goal_x - 930.0, mid.y + 45.0)
	tempting_winger.global_position = carrier.global_position + Vector2(-85.0, -160.0)
	game._select_player(carrier)
	game.ball.attach_to(carrier)

	assert(game._xi_human_byline_attack())
	assert(game._ai_xi_human_support_rank(striker) == 0,
		"The central striker should attack the spot, not the nearest offside winger")
	assert(game._ai_xi_human_support_rank(edge) == 1,
		"The midfielder provides a second, trailing cutback, not a third player")
	assert(game._ai_xi_human_support_rank(tempting_winger) == -1)
	var spot: Vector2 = game._ai_support_target(striker)
	var edge_target: Vector2 = game._ai_support_target(edge)
	assert(is_equal_approx(spot.x, goal_x - game.XI_BYLINE_SPOT_DEPTH))
	assert(absf(spot.y - (mid.y - game.XI_BYLINE_SPOT_CENTRE_OFFSET)) < 0.1)
	assert(is_equal_approx(edge_target.x, goal_x - game.XI_BYLINE_EDGE_DEPTH))
	assert(absf(edge_target.y - (mid.y + game.XI_BYLINE_EDGE_CENTRE_OFFSET)) < 0.1)
	assert(pitch.has_point(spot) and pitch.has_point(edge_target))
	assert(spot.distance_to(edge_target) > 250.0)
	assert(game.ai_xi_human_support_slots == [striker, edge])
	assert(game.ball.carrier == carrier and game.controlled == carrier)

	# Both supporters SPRINT physically into different receiving lanes.
	var first: Vector2 = striker.global_position
	var second: Vector2 = edge.global_position
	var first_stamina: float = striker.stamina
	var second_stamina: float = edge.stamina
	for frame in range(24):
		await physics_frame
		game.match_seconds += DT
		game._update_ai(DT)
		striker._process(DT)
		edge._process(DT)
		assert(striker.global_position.distance_to(first) < 145.0)
		assert(edge.global_position.distance_to(second) < 145.0)
		assert(striker.velocity.length() <= striker.base_speed *
			striker.SPRINT_SPEED_MULTIPLIER + 2.0)
		assert(edge.velocity.length() <= edge.base_speed *
			edge.SPRINT_SPEED_MULTIPLIER + 2.0)
	assert(striker.last_sprinting and edge.last_sprinting)
	assert(striker.stamina < first_stamina and edge.stamina < second_stamina)
	assert(striker.global_position.distance_to(spot) < first.distance_to(spot) - 25.0)
	assert(edge.global_position.distance_to(edge_target) <
		second.distance_to(edge_target) - 25.0)
	assert(game.ball.carrier == carrier)

	# A defensive central is free to close a physically reachable lane,
	# using the same NORMAL+ assignment and ordinary movement. No AI
	# foresight of future button presses.
	var presser: Footballer = game.teams[1][5]
	var cover: Footballer = game.teams[1][6]
	var central: Footballer = game.teams[1][2]
	presser.global_position = carrier.global_position + Vector2(-65.0, -25.0)
	cover.global_position = carrier.global_position + Vector2(-90.0, 80.0)
	central.global_position = Vector2(goal_x - 790.0, mid.y - 300.0)
	# This actor has spent 24 real AI frames sprinting from the isolated
	# background. Reset that previous scenario's momentum when placing the
	# central into a NEW physical lane, rather than expecting an instant
	# velocity reversal on the very next 1/60 s tick.
	central.velocity = Vector2.ZERO
	var predicted: Dictionary = game._ai_xi_lane_assignment(presser, cover)
	assert(not predicted.is_empty(), "Normal XI must consider a real backwards cutback lane")
	assert(predicted["marker"] == central)
	var marker_target: Vector2 = predicted["target"]
	assert(pitch.has_point(marker_target))
	assert(marker_target.distance_to(carrier.global_position) > 120.0)
	var old_centre: Vector2 = central.global_position
	await physics_frame
	# Isolate the lane defense from a tackle at the carrier's feet:
	# the real pass-selection test below retains opponent interception.
	central.move_ai(DT, marker_target, 0.75)
	assert(central.global_position.distance_to(old_centre) < 14.0)
	assert(central.global_position.distance_to(marker_target) <
		old_centre.distance_to(marker_target))

	# Real pass with short manual directional Space targeting the striker.
	# Return to an open corridor, leaving the defensive central in play.
	presser.global_position = Vector2(goal_x + 450.0, mid.y + 1000.0)
	cover.global_position = Vector2(goal_x + 400.0, mid.y + 900.0)
	central.global_position = Vector2(goal_x + 400.0, mid.y + 900.0)
	var aim: Vector2 = striker.global_position - carrier.global_position
	assert(aim.length_squared() > 1.0)
	assert(game._begin_directional_pass_charge(aim.normalized()))
	assert(game.pass_target == striker)
	game.pass_charge_seconds = game.PASS_CHARGE_SECONDS * 0.36
	assert(game._release_charged_pass())
	assert(game.action_feedback_text == "PASE ATRÁS")
	assert(game.ball.carrier == null)
	assert(game.ball.velocity.length() > 400.0)
	assert(game.pending_human_pass_receiver == striker)
	assert(game.ball.carrier != striker)

	# A byline run is contextual, not a global behavior or a stored reward.
	game.ball.attach_to(carrier)
	carrier.global_position = Vector2(goal_x - 900.0, mid.y - 720.0)
	assert(not game._xi_human_byline_attack())
	var midfield_target: Vector2 = game._ai_support_target(striker)
	assert(midfield_target != spot)
	carrier.global_position = Vector2(goal_x - 520.0, mid.y)
	assert(not game._xi_human_byline_attack())
	game.ball.attach_to(game.teams[1][10])
	assert(not game._xi_human_byline_attack())
	assert(game._ai_xi_human_support_rank(striker) == -1)
	game.ball.attach_to(carrier)
	carrier.global_position = Vector2(goal_x - 520.0, mid.y - 720.0)
	game.match_team_size = 5
	assert(not game._xi_human_byline_attack())
	assert(game._ai_xi_human_support_rank(striker) == -1)
	game.match_team_size = 11
	game.ball.release(Vector2.RIGHT, 400.0)
	assert(not game._xi_human_byline_attack())
	print("FOOTBALL_XI_BYLINE_CUTBACK_OK two_runners=true stamina_sprint=true real_defensive_lane=true manual_ground_pass=true no_instant_catch=true non_byline=false cpu=false legacy_5v5=false")
	quit(0)
