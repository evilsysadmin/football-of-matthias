extends SceneTree

# Full 22-actor match at 60 Hz: real AI, ball, set-piece and goal transitions.
const Formation = preload("res://scripts/football_match_formation.gd")
const PITCH := Formation.ELEVEN_PITCH_RECT
const STEP := 1.0 / 60.0
const TICKS := 3600

func _kick_out(game: Node2D, who: Footballer, where: Vector2) -> void:
	assert(not game.kickoff_active and not game.goal_restart_active)
	assert(not game.set_piece_active, "Prior XI restart remained locked")
	game.ball.attach_to(who)
	game.ball.release(Vector2.RIGHT, 480.0)
	game.ball.global_position = where
	game.ball.flight_height = 0.0

func _check(game: Node2D, ids: Dictionary) -> void:
	assert(game.debug_team_counts() == [11, 11])
	assert(not is_nan(game.match_seconds))
	assert(game.ball.last_touch_team_id in [-1, 0, 1])
	for x in [game.ball.global_position.x, game.ball.global_position.y,
		game.ball.velocity.x, game.ball.velocity.y, game.ball.flight_height]:
		assert(not is_nan(x) and not is_inf(x))
	var holders := 0
	for team in game.teams:
		for p: Footballer in team:
			assert(ids.has(p.scouting_player_id) and p.match_pitch == PITCH)
			assert(PITCH.grow(70.0).has_point(p.global_position))
			assert(p.stamina >= 0.0 and p.stamina <= p.STAMINA_MAX)
			assert(not is_nan(p.global_position.x) and not is_inf(p.global_position.x))
			assert(not is_nan(p.global_position.y) and not is_inf(p.global_position.y))
			if p.has_ball:
				holders += 1
				assert(p == game.ball.carrier)
	assert(holders == (1 if game.ball.carrier != null else 0))

func _initialize() -> void:
	seed(44129)
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	assert(game.match_pitch == PITCH)
	var ids := {}
	for team in game.teams:
		for p: Footballer in team:
			assert(not ids.has(p.scouting_player_id))
			ids[p.scouting_player_id] = true
	assert(ids.size() == 22)
	var active := 0
	var human := 0
	var cpu := 0
	var loose := 0
	var moving_cpu := 0
	var injected_throw := false
	var injected_corner := false
	var injected_goal_kick := false
	var injected_goal := false
	var saw_throw := false
	var done_throw := false
	var saw_corner := false
	var done_corner := false
	var saw_goal_kick := false
	var done_goal_kick := false
	var saw_goal := false
	var saw_kickoff := false
	var resumed := false
	var initial_goals: int = int(game.score[0]) + int(game.score[1])
	for tick in range(TICKS):
		if tick == 480:
			game._select_player(game.teams[0][10])
			game.ball.attach_to(game.teams[0][10])
			game.ball.release(Vector2(1.0, 0.25), 780.0)
		if tick == 930:
			game.ball.attach_to(game.teams[1][10])
		# Natural AI play may create a real throw/corner/kickoff on an
		# injection tick. Defer each scripted out-ball until open play rather
		# than forcibly overwrite an active restart. Each stage remains
		# bounded by the next milestone within the same 60s simulation.
		var open_play: bool = not (game.kickoff_active or game.goal_restart_active
			or game.set_piece_active)
		if tick >= 1320 and tick < 2040 and not injected_throw and open_play:
			_kick_out(game, game.teams[1][8],
				Vector2(PITCH.get_center().x - 300.0, PITCH.position.y - 30.0))
			injected_throw = true
		if tick >= 2040 and tick < 2700 and not injected_corner and open_play:
			assert(saw_throw and done_throw, "XI throw-in did not complete before corner")
			_kick_out(game, game.teams[1][3],
				Vector2(PITCH.end.x + 30.0, PITCH.position.y + 110.0))
			injected_corner = true
		if tick >= 2700 and tick < 3060 and not injected_goal_kick and open_play:
			assert(saw_corner and done_corner, "XI corner did not complete before goal kick")
			_kick_out(game, game.teams[0][10],
				Vector2(PITCH.end.x + 30.0, PITCH.get_center().y + 285.0))
			injected_goal_kick = true
		if tick >= 3060 and not injected_goal and open_play:
			assert(saw_goal_kick and done_goal_kick, "XI goal kick did not complete before goal")
			game.ball.attach_to(game.teams[0][10])
			game.ball.release(Vector2.RIGHT, 0.0, 0.0, true)
			game.ball.global_position = Vector2(PITCH.end.x + 25.0, PITCH.get_center().y)
			injected_goal = true
		game._physics_process(STEP)
		if tick >= 1320 and tick < 2040:
			saw_throw = saw_throw or (game.set_piece_active and
				game.set_piece_kind == "SAQUE DE BANDA" and game.set_piece_team_id == 0)
			done_throw = done_throw or (saw_throw and not game.set_piece_active)
		if tick >= 2040 and tick < 2700:
			saw_corner = saw_corner or (game.set_piece_active and
				game.set_piece_kind == "CÓRNER" and game.set_piece_team_id == 0)
			done_corner = done_corner or (saw_corner and not game.set_piece_active)
		if tick >= 2700 and tick < 3060:
			saw_goal_kick = saw_goal_kick or (game.set_piece_active and
				game.set_piece_kind == "SAQUE DE PUERTA" and game.set_piece_team_id == 1)
			done_goal_kick = done_goal_kick or (saw_goal_kick and not game.set_piece_active)
		if tick >= 3060:
			saw_goal = saw_goal or game.goal_restart_active
			saw_kickoff = saw_kickoff or (saw_goal and game.kickoff_active)
			resumed = resumed or (saw_kickoff and not
				(game.goal_restart_active or game.kickoff_active or game.set_piece_active))
		if not (game.kickoff_active or game.goal_restart_active or game.set_piece_active):
			active += 1
		if game.ball.carrier == null:
			loose += 1
		elif game.ball.carrier.team_id == 0:
			human += 1
		else:
			cpu += 1
		if tick % 30 == 0:
			_check(game, ids)
			for p: Footballer in game.teams[1]:
				if p.role != "keeper" and p.velocity.length() > 10.0:
					moving_cpu += 1
	assert(game.match_seconds >= float(TICKS) * STEP - 0.01)
	assert(active > 1000 and loose > 0 and cpu > 0 and human > 0)
	assert(moving_cpu >= 50)
	assert(injected_throw and injected_corner and injected_goal_kick and injected_goal,
		"XI endurance did not execute all staged restart injections")
	assert(saw_throw and done_throw and saw_corner and done_corner)
	assert(saw_goal_kick and done_goal_kick and saw_goal and saw_kickoff and resumed)
	assert(game.score[0] + game.score[1] >= initial_goals + 1)
	print("FOOTBALL_XI_ENDURANCE_60S_OK ticks=%d active=%d loose=%d cpu=%d human=%d moving_cpu=%d ids=22" % [
		TICKS, active, loose, cpu, human, moving_cpu])
	quit(0)
