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
	# A clear 330-unit outlet must NOT cause an instantaneous 0.00s pass.
	# This used to happen as soon as the carrier touched the ball.
	assert(game.ball.possession_seconds == 0.0)
	assert(game._ai_xi_pass_setup_seconds(passer, INF, 330.0) >= 0.4)
	game._ai_attack(passer)
	assert(game.ball.carrier == passer)
	game.ball.tick_ball(0.30)
	game._ai_attack(passer)
	assert(game.ball.carrier == passer)
	game.ball.tick_ball(0.20)
	game._ai_attack(passer)
	assert(game.ball.carrier == null)
	assert(game.ball.possession_seconds == 0.0)
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
	# A pressured sideways recycle has a shorter but still real first-touch
	# phase. Do not force a one-touch pinball volley on every reception.
	game._ai_attack(passer)
	assert(game.ball.carrier == passer)
	game.ball.tick_ball(0.29)
	game._ai_attack(passer)
	assert(game.ball.carrier == null)
	assert(game.ball.velocity.x > 0.0 and game.ball.velocity.y > 0.0)
	# A closely marked receiver is no longer a valid outlet.
	game.ball.attach_to(passer)
	blocker.global_position = receiver.global_position + Vector2(32.0, 0.0)
	assert(game._best_ai_pass_target(passer) == null)

	# Reclaiming resets control time, including reattaching the same player.
	game.ball.attach_to(passer)
	assert(game.ball.possession_seconds == 0.0)
	game.ball.tick_ball(0.38)
	assert(is_equal_approx(game.ball.possession_seconds, 0.38))
	game.ball.attach_to(passer)
	assert(game.ball.possession_seconds == 0.0)
	game.ball.release(Vector2.LEFT, 320.0)
	assert(game.ball.possession_seconds == 0.0)
	# Under immediate pressure an emergency outlet may be quicker, but a
	# central defender in open space should settle before recycling.
	assert(game._ai_xi_pass_setup_seconds(passer, 60.0, 200.0) < 0.2)
	assert(game._ai_xi_pass_setup_seconds(passer, 135.0, 200.0) > 0.2)
	assert(game._ai_xi_pass_setup_seconds(game.teams[1][2], INF, 90.0) >
		game._ai_xi_pass_setup_seconds(passer, INF, 90.0))
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
	# Q is a browser-safe alternative to Tab. Both physical keys map to
	# the same nearest-to-ball action, with no extra player-selection state.
	var q_event := InputEventKey.new()
	q_event.physical_keycode = KEY_Q
	var tab_event := InputEventKey.new()
	tab_event.physical_keycode = KEY_TAB
	assert(InputMap.event_is_action(q_event, "change_player"))
	assert(InputMap.event_is_action(tab_event, "change_player"))
	# The keeper standing closest to a loose ball and a dismissed
	# outfielder must not steal the manual switch from the eligible runner.
	game.ball.release(Vector2.LEFT, 90.0)
	game.ball.global_position = centre
	game.ball.velocity = Vector2.ZERO
	game.ball.flight_height = 0.0
	game.teams[0][0].global_position = centre
	for human in game.teams[0]:
		if human.role != "keeper":
			human.global_position = centre + Vector2(-800.0, 430.0)
	var nearest_human: Footballer = game.teams[0][7]
	nearest_human.global_position = centre + Vector2(70.0, 0.0)
	var dismissed_human: Footballer = game.teams[0][8]
	dismissed_human.global_position = centre + Vector2(15.0, 0.0)
	dismissed_human.sent_off = true
	assert(game._best_switch_candidate() == nearest_human)
	game._select_player(game.teams[0][6])
	game.pending_human_pass_receiver = game.teams[0][9]
	Input.action_press("change_player")
	game._handle_human(1.0 / 60.0)
	Input.action_release("change_player")
	assert(game.controlled == nearest_human)
	assert(game.pending_human_pass_receiver == null)
	# With actual human possession the switch favors the real ball carrier.
	game.ball.attach_to(game.teams[0][6])
	assert(game._best_switch_candidate() == game.teams[0][6])
	# Legacy default math still points at the original nets.
	assert(ChessFootballMath.goal_center(0).x == FIVE.end.x)
	assert(ChessFootballMath.goal_center(1).x == FIVE.position.x)
	# CPU XI Normal+: the first man presses, second protects goal side,
	# and exactly one REACHABLE third man guards an actual forward pass.
	# The selector must ignore sent-off players and never teleport the
	# back line or accelerate a marker beyond ordinary CPU movement.
	game._set_quick_difficulty("normal")
	var lane_owner: Footballer = game.teams[0][10]
	var lane_receiver: Footballer = game.teams[0][9]
	lane_owner.global_position = centre + Vector2(600.0, 0.0)
	for attacker: Footballer in game.teams[0]:
		if attacker != lane_owner:
			attacker.global_position = lane_owner.global_position + Vector2(-720.0, 640.0)
	lane_receiver.global_position = lane_owner.global_position + Vector2(350.0, -165.0)
	var lane_presser: Footballer = game.teams[1][10]
	var lane_cover: Footballer = game.teams[1][8]
	var expected_marker: Footballer = game.teams[1][6]
	for rival: Footballer in game.teams[1]:
		if rival.role != "keeper":
			rival.global_position = centre + Vector2(1300.0, 800.0)
	lane_presser.global_position = lane_owner.global_position + Vector2(70.0, 0.0)
	lane_cover.global_position = lane_owner.global_position + Vector2(100.0, 220.0)
	expected_marker.global_position = lane_owner.global_position + Vector2(245.0, -260.0)
	expected_marker.velocity = Vector2.ZERO
	expected_marker.stamina = 100.0
	game.ball.attach_to(lane_owner)
	var lane_plan: Dictionary = game._ai_xi_lane_assignment(lane_presser, lane_cover)
	assert(lane_plan.get("marker") == expected_marker)
	assert(lane_plan.get("receiver") == lane_receiver)
	var lane_target: Vector2 = lane_plan["target"]
	var lane_segment: Vector2 = lane_receiver.global_position - lane_owner.global_position
	assert(XI.has_point(lane_target))
	assert(lane_target.x > lane_owner.global_position.x + 150.0)
	assert(lane_target.x < lane_receiver.global_position.x)
	assert(absf(
		(lane_target - lane_owner.global_position).cross(lane_segment)
	) / lane_segment.length() < 25.0)
	assert(lane_target.distance_to(lane_presser.global_position) > 125.0)
	assert(lane_target.distance_to(lane_cover.global_position) > 125.0)
	# Normal decision scheduling owns the AI target. There is no position
	# assignment/teleport and no boosted runner speed.
	var marker_start: Vector2 = expected_marker.global_position
	await physics_frame
	game._update_ai(1.0 / 60.0)
	assert(expected_marker.ai_target.distance_to(lane_target) < 15.0)
	assert(expected_marker.global_position.distance_to(marker_start) < 15.0)
	assert(expected_marker.velocity.length() <= expected_marker.base_speed * 1.34 + 1.0)
	# No artificial defensive crowd: the other idle backs retain their
	# usual weak shift rather than following the same passing corridor.
	assert(game.teams[1][4].ai_target.distance_to(lane_target) > 300.0)
	# Easy, 5v5 and possession/loose-ball states keep the old behaviour.
	game._set_quick_difficulty("easy")
	assert(game._ai_xi_lane_assignment(lane_presser, lane_cover).is_empty())
	game._set_quick_difficulty("normal")
	game.match_team_size = 5
	assert(game._ai_xi_lane_assignment(lane_presser, lane_cover).is_empty())
	game.match_team_size = 11
	lane_receiver.sent_off = true
	assert(game._ai_xi_lane_assignment(lane_presser, lane_cover).is_empty())
	lane_receiver.sent_off = false
	expected_marker.global_position = centre + Vector2(1300.0, 800.0)
	assert(game._ai_xi_lane_assignment(lane_presser, lane_cover).is_empty())
	game.ball.release(Vector2.ZERO, 0.0)
	assert(game._ai_xi_lane_assignment(lane_presser, lane_cover).is_empty())
	print("FOOTBALL_XI_CPU_LANE_GUARD_OK pressure=1 cover=1 marker=1 no_teleport=1 no_speed_boost=1 easy=off five=off")
	print("FOOTBALL_XI_AI_OK goals=2 lanes=3 dribble=1 cover=1 keeper=1 loose=1 q_switch=nearest_valid team_pass=received blocked pressure marked shot=1 old_5v5=unchanged")
	quit(0)
