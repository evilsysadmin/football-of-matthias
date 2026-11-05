extends SceneTree

# Full-XI tactics must work OUTSIDE the original 5v5 rect. Verify actual
# match targets with 22 real players; no browser feature flag is enabled.
const Formation = preload("res://scripts/football_match_formation.gd")
const FIVE := ChessFootballMath.PITCH_RECT
const XI := Formation.ELEVEN_PITCH_RECT

func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.kickoff_active = false
	assert(game.match_pitch == XI)
	assert(game.debug_team_counts() == [11, 11])
	var centre := XI.get_center()
	var right_goal := ChessFootballMath.goal_center(0, XI)
	var left_goal := ChessFootballMath.goal_center(1, XI)
	assert(right_goal.x == XI.end.x and left_goal.x == XI.position.x)
	assert(game._assisted_shot_target(game.teams[0][10], 0.0).x == right_goal.x)
	assert(game._assisted_shot_target(game.teams[1][10], 0.0).x == left_goal.x)
	# The attacking winger does NOT dribble backwards when already past
	# the old 5v5 goal line. No rival nearby should force an evasion.
	for rival in game.teams[1]:
		rival.global_position = Vector2(centre.x - 500.0, XI.end.y - 140.0)
	var winger: Footballer = game.teams[0][8]
	winger.global_position = Vector2(FIVE.end.x + 180.0, XI.position.y + 210.0)
	var advance: Vector2 = game._ai_dribble_target(winger)
	assert(advance.x > winger.global_position.x + 50.0)
	assert(XI.has_point(advance))
	assert(advance.x > FIVE.end.x)
	# A true 4-3-3 retains distant wide lanes when midfield advances.
	var striker: Footballer = game.teams[0][10]
	striker.global_position = Vector2(XI.end.x - 410.0, centre.y)
	game.ball.attach_to(striker)
	var upper: Vector2 = game._ai_support_target(game.teams[0][8])
	var lower: Vector2 = game._ai_support_target(game.teams[0][9])
	var middle: Vector2 = game._ai_support_target(game.teams[0][6])
	assert(XI.has_point(upper) and XI.has_point(lower) and XI.has_point(middle))
	assert(lower.y - upper.y > 950.0)
	assert(middle.y > upper.y + 350.0 and middle.y < lower.y - 350.0)
	assert(upper.x > FIVE.end.x - 800.0)
	# Cover and interception can protect the ACTUAL far-end goal.
	var cover: Vector2 = game._ai_cover_target(game.teams[1][5], Vector2(XI.end.x - 420.0, centre.y))
	assert(XI.has_point(cover) and cover.x > FIVE.end.x + 100.0)
	# The 11v11 CPU second defender joins a real contest only when nearby.
	# Preserve goal-side positioning without expanding physical tackle reach.
	var xi_cover_player: Footballer = game.teams[1][5]
	var original_cover_position: Vector2 = xi_cover_player.global_position
	xi_cover_player.global_position = striker.global_position + Vector2(155.0, 0.0)
	game._set_quick_difficulty("easy")
	var xi_easy_cover: Vector2 = game._ai_cover_target(xi_cover_player, striker.global_position)
	game._set_quick_difficulty("normal")
	var xi_normal_cover: Vector2 = game._ai_cover_target(xi_cover_player, striker.global_position)
	assert(XI.has_point(xi_normal_cover))
	assert(xi_normal_cover.x > striker.global_position.x)
	assert(xi_easy_cover.x - xi_normal_cover.x > 70.0)
	xi_cover_player.global_position = original_cover_position
	var right_keeper: Footballer = game.teams[1][0]
	var left_keeper: Footballer = game.teams[0][0]
	var guard_right: Vector2 = game._keeper_defensive_target(right_keeper)
	var guard_left: Vector2 = game._keeper_defensive_target(left_keeper)
	assert(guard_right.x > FIVE.end.x + 400.0 and guard_right.x < XI.end.x)
	assert(guard_left.x < FIVE.position.x - 400.0 and guard_left.x > XI.position.x)
	# A rolling loose ball in the new extra turf must be chased there,
	# not clamped back to the smaller 5-a-side field.
	game.ball.release(Vector2.LEFT, 310.0)
	game.ball.global_position = Vector2(XI.position.x + 150.0, XI.position.y + 215.0)
	game.ball.flight_height = 0.0
	game.ball.vertical_velocity = 0.0
	var pursuit: Vector2 = game._ai_loose_ball_pursuit_point()
	assert(XI.has_point(pursuit))
	assert(pursuit.x < FIVE.position.x and pursuit.y < FIVE.position.y)
	# Real 11v11 link-up: a reachable unmarked teammate, not the most
	# distant attacker, receives a ball using normal friction and first touch.
	var passer: Footballer = game.teams[1][10]
	var receiver: Footballer = game.teams[1][8]
	passer.global_position = Vector2(XI.end.x - 850.0, centre.y)
	receiver.global_position = passer.global_position + Vector2(-330.0, 90.0)
	for teammate in game.teams[1]:
		if teammate != passer and teammate != receiver and teammate.role != "keeper":
			teammate.global_position = Vector2(XI.end.x - 90.0, XI.end.y - 90.0)
	for rival in game.teams[0]:
		rival.global_position = Vector2(XI.end.x - 120.0, XI.end.y - 130.0)
	game.ball.attach_to(passer)
	assert(game._ai_xi_support_rank(receiver) == 0)
	assert(game._ai_support_target(receiver).distance_to(passer.global_position) < 300.0)
	assert(game._ai_xi_support_rank(game.teams[1][5]) == -1)
	assert(game._best_ai_pass_target(passer) == receiver)
	game._ai_attack(passer)
	assert(game.ball.carrier == null)
	assert(game.ball.velocity.length() > 540.0)
	assert(game.ai_intended_pass_receiver == receiver)
	game._update_ai(1.0 / 60.0)
	assert(receiver.last_sprinting)
	var completed_link_up := false
	for frame in range(150):
		game.ball.tick_ball(1.0 / 60.0)
		game._try_claim_loose_ball()
		if game.ball.carrier == receiver:
			completed_link_up = true
			break
	assert(completed_link_up)

	# A defender stationed on the passing lane forces a different choice;
	# when no other safe teammate exists, the CPU keeps the ball.
	game.ball.attach_to(passer)
	var blocker: Footballer = game.teams[0][4]
	blocker.global_position = passer.global_position.lerp(receiver.global_position, 0.5)
	assert(game._best_ai_pass_target(passer) == null)
	game._ai_attack(passer)
	assert(game.ball.carrier == passer)

	# Under pressure, a safe sideways/backward outlet is worth using.
	# Without pressure, don't initiate pointless lateral ping-pong.
	receiver.global_position = passer.global_position + Vector2(55.0, 220.0)
	blocker.global_position = Vector2(XI.end.x - 120.0, XI.end.y - 130.0)
	assert(game._best_ai_pass_target(passer) == receiver)
	game._ai_attack(passer)
	assert(game.ball.carrier == passer)
	blocker.global_position = passer.global_position + Vector2(90.0, -120.0)
	game._ai_attack(passer)
	assert(game.ball.carrier == null)
	assert(game.ball.velocity.x > 0.0 and game.ball.velocity.y > 0.0)
	# A closely marked receiver is no longer a valid outlet.
	game.ball.attach_to(passer)
	blocker.global_position = receiver.global_position + Vector2(32.0, 0.0)
	assert(game._best_ai_pass_target(passer) == null)

	# A CPU striker must shoot LEFT toward the XI goal, never right toward
	# the old arcade goal now located behind the attacker.
	passer.global_position = Vector2(XI.position.x + 430.0, centre.y)
	game.ball.attach_to(passer)
	game._ai_attack(passer)
	assert(game.ball.carrier == null and game.ball.velocity.x < -350.0)
	# Real goalkeeping near the distant right goal. Previously saves were
	# rejected outright because the ball lay outside the old 5v5 rect.
	right_keeper.global_position = Vector2(XI.end.x - game.KEEPER_LINE_OFFSET, centre.y)
	game.ball.attach_to(striker)
	game.ball.release(Vector2.RIGHT, 970.0, 0.0, true)
	game.ball.global_position = right_keeper.global_position + Vector2(-38.0, 18.0)
	game.ball.flight_height = 0.0
	assert(game._keeper_try_save(right_keeper))
	assert(game.ball.carrier == right_keeper)
	# Legacy default math still points at the original nets.
	assert(ChessFootballMath.goal_center(0).x == FIVE.end.x)
	assert(ChessFootballMath.goal_center(1).x == FIVE.position.x)
	print("FOOTBALL_XI_AI_OK goals=2 lanes=3 dribble=1 cover=1 keeper=1 loose=1 team_pass=received blocked pressure marked shot=1 old_5v5=unchanged")
	quit(0)
