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
	# Normal XI gives the carrier one challenger and goal-side cover.
	# Hard/Expert still allow the second defender to contest nearby.
	var xi_cover_player: Footballer = game.teams[1][5]
	var original_cover_position: Vector2 = xi_cover_player.global_position
	xi_cover_player.global_position = striker.global_position + Vector2(155.0, 0.0)
	striker.velocity = Vector2.ZERO
	game._set_quick_difficulty("easy")
	var xi_easy_cover: Vector2 = game._ai_cover_target(xi_cover_player, striker.global_position)
	game._set_quick_difficulty("normal")
	var xi_normal_cover: Vector2 = game._ai_cover_target(xi_cover_player, striker.global_position)
	assert(XI.has_point(xi_normal_cover))
	assert(xi_normal_cover.is_equal_approx(xi_easy_cover))
	assert(not game._ai_cpu_second_press_active(xi_cover_player, striker.global_position))
	# Normal XI tackle attempts use discrete read beats of the existing
	# tactical clock instead of perfect per-physics-frame timing. Movement
	# and legal tackle contact remain available at their original speeds.
	var original_age: float = game.ball.possession_seconds
	var read_interval: float = game._ai_adaptive_decision_interval()
	game.ball.possession_seconds = 0.40
	assert(not game._ai_xi_normal_tackle_read_due(striker, 1.0 / 60.0))
	game.ball.possession_seconds = read_interval * 2.0 + 0.004
	assert(game._ai_xi_normal_tackle_read_due(striker, 1.0 / 60.0))
	game.ball.possession_seconds = read_interval * 2.0 + 0.06
	assert(not game._ai_xi_normal_tackle_read_due(striker, 1.0 / 60.0))
	# Even when the new read is late, a real clean frontal challenge is
	# never made illegal or given a smaller hitbox.
	var defender_saved_pos: Vector2 = xi_cover_player.global_position
	var defender_saved_velocity: Vector2 = xi_cover_player.velocity
	xi_cover_player.global_position = striker.global_position + Vector2(31.0, -8.0)
	xi_cover_player.velocity = Vector2(-175.0, 0.0)
	assert(bool(game._tackle_hitbox(xi_cover_player, striker.global_position).get("clean", false)))
	assert(game._ai_xi_tackle_commit_ready(xi_cover_player, striker, false))
	xi_cover_player.global_position = defender_saved_pos
	xi_cover_player.velocity = defender_saved_velocity
	game._set_quick_difficulty("hard")
	assert(game._ai_xi_normal_tackle_read_due(striker, 1.0 / 60.0))
	game._set_quick_difficulty("expert")
	assert(game._ai_xi_normal_tackle_read_due(striker, 1.0 / 60.0))
	game._set_quick_difficulty("easy")
	assert(game._ai_xi_normal_tackle_read_due(striker, 1.0 / 60.0))
	game._set_quick_difficulty("normal")
	game.match_team_size = 5
	assert(game._ai_xi_normal_tackle_read_due(striker, 1.0 / 60.0))
	game.match_team_size = 11
	game.ball.possession_seconds = original_age
	game._set_quick_difficulty("hard")
	var xi_hard_cover: Vector2 = game._ai_cover_target(xi_cover_player, striker.global_position)
	assert(XI.has_point(xi_hard_cover))
	assert(xi_hard_cover.x > striker.global_position.x)
	assert(xi_normal_cover.x - xi_hard_cover.x > 70.0)
	game._set_quick_difficulty("expert")
	assert(game._ai_cpu_second_press_active(xi_cover_player, striker.global_position))
	game._set_quick_difficulty("hard")
	# The nearby XI second defender shades only toward a REAL goalward
	# diagonal, retaining its ordinary goal-side position and move_ai pace.
	striker.velocity = Vector2(210.0, 185.0)
	var read_upper: Vector2 = game._ai_cover_target(xi_cover_player, striker.global_position)
	assert(XI.has_point(read_upper))
	assert(read_upper.x > xi_hard_cover.x + 20.0)
	assert(read_upper.y > xi_hard_cover.y + 20.0)
	assert(read_upper.distance_to(xi_hard_cover) < 80.0)
	assert(read_upper.x > striker.global_position.x)
	var cover_start: Vector2 = xi_cover_player.global_position
	xi_cover_player.velocity = Vector2.ZERO
	xi_cover_player.move_ai(1.0 / 60.0, read_upper, 0.98)
	assert(xi_cover_player.global_position.distance_to(cover_start) < 15.0)
	assert(xi_cover_player.velocity.length() <= xi_cover_player.base_speed * 1.34 + 1.0)
	xi_cover_player.global_position = cover_start
	xi_cover_player.velocity = Vector2.ZERO
	striker.velocity = Vector2(210.0, -185.0)
	var read_lower: Vector2 = game._ai_cover_target(xi_cover_player, striker.global_position)
	assert(read_lower.y < xi_hard_cover.y - 20.0)
	assert(read_lower.x > striker.global_position.x)

	# Regression: before this change XI CPU predicted an E/F direction on
	# the *same physics frame* as input. Verify real Footballer actions, not
	# a synthetic direction switch: pressing and Hard second-man cover must
	# read only motion actually observed. Contact is never disabled.
	striker.velocity = Vector2(210.0, 185.0)
	assert(game._ai_press_target(xi_cover_player, striker).distance_to(
		striker.global_position
	) > 8.0, "Ordinary observed running still permits bounded pursuit lead")
	for action in ["cut", "burst", "feint"]:
		striker.dribble_burst_seconds = 0.0
		striker.dribble_cooldown_seconds = 0.0
		striker.action_lock_seconds = 0.0
		assert(striker.start_dribble(Vector2(1.0, 1.0), action))
		assert(game._ai_xi_observed_carrier_velocity(striker) == Vector2.ZERO)
		assert(game._ai_press_target(xi_cover_player, striker).is_equal_approx(
			striker.global_position
		), "Early XI %s cannot give CPU a psychic pursuit forecast" % action)
		assert(game._ai_xi_diagonal_cover_lead(
			xi_cover_player, striker.global_position
		) == Vector2.ZERO, "Cover must not anticipate the first %s step" % action)
		# Wait on the existing authoritative action clock, never wall time.
		striker.dribble_burst_seconds = striker.dribble_duration_seconds * 0.40
		if action == "feint":
			assert(game._ai_xi_observed_carrier_velocity(striker) == Vector2.ZERO)
		else:
			assert(game._ai_xi_observed_carrier_velocity(striker) == striker.velocity)
			assert(game._ai_press_target(xi_cover_player, striker).distance_to(
				striker.global_position
			) > 8.0)
			assert(game._ai_xi_diagonal_cover_lead(
				xi_cover_player, striker.global_position
			).length() > 20.0)
	# No new immunity: the usual clean physical XI hitbox can still claim
	# the ball after the defender gets within real tackle reach.
	striker.dribble_burst_seconds = striker.dribble_duration_seconds * 0.85
	striker.dribble_mode = "cut"
	var contact_position: Vector2 = xi_cover_player.global_position
	var contact_velocity: Vector2 = xi_cover_player.velocity
	xi_cover_player.global_position = striker.global_position + Vector2(31.0, -8.0)
	xi_cover_player.velocity = Vector2(-175.0, 0.0)
	assert(game._ai_xi_tackle_commit_ready(xi_cover_player, striker, false))
	xi_cover_player.global_position = contact_position
	xi_cover_player.velocity = contact_velocity
	# Easy and legacy 5v5 retain the previous instantaneous pursuit read.
	game._set_quick_difficulty("easy")
	assert(game._ai_xi_observed_carrier_velocity(striker) == striker.velocity)
	game._set_quick_difficulty("hard")
	game.match_team_size = 5
	assert(game._ai_xi_observed_carrier_velocity(striker) == striker.velocity)
	game.match_team_size = 11
	# The reading delay never follows a player after possession is lost.
	game.ball.release(Vector2.ZERO, 0.0)
	assert(game._ai_xi_observed_carrier_velocity(striker) == striker.velocity)
	game.ball.attach_to(striker)
	striker.dribble_burst_seconds = 0.0
	striker.dribble_cooldown_seconds = 0.0
	print("FOOTBALL_XI_DRIBBLE_DEFENDER_READ_OK actions=3 read_delay=1 contact=1")
	# Neither straight runs nor backwards retreats trigger a fake diagonal.
	striker.velocity = Vector2(210.0, 0.0)
	assert(game._ai_xi_diagonal_cover_lead(xi_cover_player, striker.global_position) == Vector2.ZERO)
	striker.velocity = Vector2(-210.0, 185.0)
	assert(game._ai_xi_diagonal_cover_lead(xi_cover_player, striker.global_position) == Vector2.ZERO)
	striker.velocity = Vector2(210.0, 185.0)
	xi_cover_player.global_position = striker.global_position + Vector2(290.0, 0.0)
	assert(game._ai_xi_diagonal_cover_lead(xi_cover_player, striker.global_position) == Vector2.ZERO)
	xi_cover_player.global_position = cover_start
	game._set_quick_difficulty("easy")
	assert(game._ai_xi_diagonal_cover_lead(xi_cover_player, striker.global_position) == Vector2.ZERO)
	game._set_quick_difficulty("normal")
	game.match_team_size = 5
	assert(game._ai_xi_diagonal_cover_lead(xi_cover_player, striker.global_position) == Vector2.ZERO)
	game.match_team_size = 11
	game.ball.release(Vector2.ZERO, 0.0)
	assert(game._ai_xi_diagonal_cover_lead(xi_cover_player, striker.global_position) == Vector2.ZERO)
	game.ball.attach_to(striker)
	striker.velocity = Vector2.ZERO
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
	# Real XI CPU pass errors are imperfect but bounded. A defender in
	# the passer's face makes a slightly misplaced ball more likely;
	# the same player's calm passing remains much more reliable.
	var pass_error_chances: Array[float] = []
	var pass_error_extents: Array[float] = []
	for difficulty in ["easy", "normal", "hard", "expert"]:
		game._set_quick_difficulty(difficulty)
		var chance: float = float(game.quick_difficulty_profile["pass_error"])
		var extent: float = float(game.quick_difficulty_profile["pass_error_degrees"])
		assert(chance > 0.0 and chance < 1.0)
		assert(extent > 0.0 and extent <= 13.0)
		pass_error_chances.append(chance)
		pass_error_extents.append(extent)
		var rushed_miss: float = game._ai_xi_pass_aim_error_degrees(
			passer, 90.0, 0.0, 1.0
		)
		var rushed_other_side: float = game._ai_xi_pass_aim_error_degrees(
			passer, 90.0, 0.0, -1.0
		)
		var calm_miss: float = game._ai_xi_pass_aim_error_degrees(
			passer, INF, 0.0, 1.0
		)
		assert(is_equal_approx(rushed_miss, extent))
		assert(is_equal_approx(rushed_other_side, -extent))
		assert(calm_miss > 0.0 and calm_miss < rushed_miss * 0.25)
		assert(game._ai_xi_pass_aim_error_degrees(passer, 90.0, 0.99, 1.0) == 0.0)
		# Expert has rare mistakes, never perfect tactical ball placement.
		assert(rushed_miss > 0.0 and chance > 0.0)
	for index in range(3):
		assert(pass_error_chances[index] > pass_error_chances[index + 1])
		assert(pass_error_extents[index] > pass_error_extents[index + 1])
	game._set_quick_difficulty("normal")
	assert(game._ai_xi_pass_aim_error_degrees(passer, 90.0, 0.30, 1.0) == 0.0)
	assert(game._ai_xi_pass_aim_error_degrees(passer, 90.0, 0.0, 1.0) > 8.0)
	# Same XI geometry for both goals, but only the CPU makes this
	# decision mistake. Human-side assistance and legacy 5v5 stay intact.
	var human_test_passer: Footballer = game.teams[0][10]
	assert(game._ai_xi_pass_aim_error_degrees(human_test_passer, 50.0, 0.0, 1.0) == 0.0)
	game.match_team_size = 5
	assert(game._ai_xi_pass_aim_error_degrees(passer, 50.0, 0.0, 1.0) == 0.0)
	game.match_team_size = 11
	# Distinguish directional errors from kick power: an otherwise correct
	# pass can arrive short or long. Pressure makes both more likely, and
	# difficulty changes the chance and size without ever making Expert perfect.
	var power_chances: Array[float] = []
	var power_extents: Array[float] = []
	for difficulty in ["easy", "normal", "hard", "expert"]:
		game._set_quick_difficulty(difficulty)
		var chance: float = float(game.quick_difficulty_profile["pass_power_error"])
		var extent: float = float(game.quick_difficulty_profile["pass_power_error_ratio"])
		assert(chance > 0.0 and chance < 1.0)
		assert(extent > 0.0 and extent <= 0.24)
		power_chances.append(chance)
		power_extents.append(extent)
		var rushed_short: float = game._ai_xi_pass_power_error_ratio(
			passer, 90.0, 0.0, -1.0
		)
		var rushed_long: float = game._ai_xi_pass_power_error_ratio(
			passer, 90.0, 0.0, 1.0
		)
		var calm_long: float = game._ai_xi_pass_power_error_ratio(
			passer, INF, 0.0, 1.0
		)
		assert(is_equal_approx(rushed_short, -extent))
		assert(is_equal_approx(rushed_long, extent))
		assert(calm_long > 0.0 and calm_long < rushed_long * 0.25)
		assert(game._ai_xi_pass_power_error_ratio(passer, 90.0, 0.99, 1.0) == 0.0)
	for index in range(3):
		assert(power_chances[index] > power_chances[index + 1])
		assert(power_extents[index] > power_extents[index + 1])
	game._set_quick_difficulty("normal")
	assert(game._ai_xi_pass_power_error_ratio(passer, 90.0, 0.25, 1.0) == 0.0)
	assert(game._ai_xi_pass_power_error_ratio(passer, 90.0, 0.0, -1.0) < -0.15)
	assert(game._ai_xi_pass_power_error_ratio(passer, 90.0, 0.0, 1.0) > 0.15)
	assert(game._ai_xi_pass_power_error_ratio(human_test_passer, 50.0, 0.0, 1.0) == 0.0)
	game.match_team_size = 5
	assert(game._ai_xi_pass_power_error_ratio(passer, 50.0, 0.0, 1.0) == 0.0)
	game.match_team_size = 11
	# Both kick directions preserve genuine power: a missed launch stays
	# too weak/strong. The ball itself does not correct an inaccurate pass.
	var short_power: float = 750.0 * (
		1.0 + game._ai_xi_pass_power_error_ratio(passer, 90.0, 0.0, -1.0)
	)
	var long_power: float = 750.0 * (
		1.0 + game._ai_xi_pass_power_error_ratio(passer, 90.0, 0.0, 1.0)
	)
	assert(short_power < 750.0 and long_power > 750.0)
	game.ball.attach_to(passer)
	game.ball.release(Vector2.LEFT, short_power)
	assert(is_equal_approx(game.ball.velocity.length(), short_power))
	game.ball.attach_to(passer)
	game.ball.release(Vector2.RIGHT, long_power)
	assert(is_equal_approx(game.ball.velocity.length(), long_power))
	assert(game.ball.velocity.x > 0.0)
	print("FOOTBALL_XI_PASS_HUMAN_ERROR_OK levels=4 angle_and_power=1")
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
	# Humans do not always pick the absolute highest-scored pass. Give
	# this CPU carrier TWO comparable, physically safe forward options;
	# no keeper, sent-off player, blocked corridor or long pass can qualify.
	var second_outlet: Footballer = game.teams[1][9]
	var second_outlet_home: Vector2 = second_outlet.global_position
	var second_outlet_velocity: Vector2 = second_outlet.velocity
	second_outlet.global_position = passer.global_position + Vector2(-315.0, -94.0)
	second_outlet.velocity = Vector2.ZERO
	receiver.velocity = Vector2.ZERO
	assert(game._ai_xi_pass_lane_clear(passer, second_outlet))
	assert(game._ai_xi_pass_lane_clear(passer, receiver))
	assert(game._best_ai_pass_target(passer) == receiver)
	var option_odds: Array[float] = []
	for difficulty in ["easy", "normal", "hard", "expert"]:
		game._set_quick_difficulty(difficulty)
		var option_chance: float = float(
			game.quick_difficulty_profile["pass_second_choice"]
		)
		assert(option_chance > 0.0 and option_chance < 1.0)
		option_odds.append(option_chance)
		assert(game._best_ai_pass_target(passer, 0.0) == second_outlet)
		assert(game._best_ai_pass_target(passer, 0.99) == receiver)
	for index in range(3):
		assert(option_odds[index] > option_odds[index + 1])
	game._set_quick_difficulty("normal")
	assert(game._best_ai_pass_target(passer, 0.20) == second_outlet)
	game._set_quick_difficulty("hard")
	assert(game._best_ai_pass_target(passer, 0.20) == receiver)
	# Similar-quality alternatives only. No speculative poor forward
	# choices, hopeless backwards balls or fake human/5v5 randomness.
	assert(not game._ai_xi_prefers_second_pass(passer, 180.0, 330.0, 315.0, 0.0))
	assert(not game._ai_xi_prefers_second_pass(passer, 30.0, 330.0, 80.0, 0.0))
	assert(not game._ai_xi_prefers_second_pass(passer, 30.0, 40.0, 15.0, 0.0))
	assert(not game._ai_xi_prefers_second_pass(passer, 30.0, 330.0, 315.0, -1.0))
	game.match_team_size = 5
	assert(not game._ai_xi_prefers_second_pass(passer, 30.0, 330.0, 315.0, 0.0))
	game.match_team_size = 11
	assert(not game._ai_xi_prefers_second_pass(game.teams[0][10], 30.0, 330.0, 315.0, 0.0))
	# A defender physically marking the alternative immediately removes it.
	var alternative_marker: Footballer = game.teams[0][4]
	var marker_original: Vector2 = alternative_marker.global_position
	alternative_marker.global_position = second_outlet.global_position
	assert(not game._ai_xi_pass_lane_clear(passer, second_outlet))
	assert(game._best_ai_pass_target(passer, 0.0) == receiver)
	alternative_marker.global_position = marker_original
	second_outlet.sent_off = true
	assert(game._best_ai_pass_target(passer, 0.0) == receiver)
	second_outlet.sent_off = false
	second_outlet.global_position = second_outlet_home
	second_outlet.velocity = second_outlet_velocity
	game._set_quick_difficulty("normal")
	assert(game._best_ai_pass_target(passer) == receiver)
	print("FOOTBALL_XI_PASS_SECOND_CHOICE_OK levels=4 safe_only=1")
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

	# The primary XI CPU triangle makes an open lane BEFORE a pass.
	# One marked outlet sidesteps; both alternatives covered stay unchanged.
	game.ball.attach_to(passer)
	receiver.global_position = passer.global_position + Vector2(-330.0, 90.0)
	receiver.velocity = Vector2.ZERO
	assert(game._ai_xi_support_rank(receiver) == 0)
	var triangle_base: Vector2 = game._ai_support_target(receiver)
	var lane_blocker: Footballer = game.teams[0][4]
	var upper_blocker: Footballer = game.teams[0][3]
	var lower_blocker: Footballer = game.teams[0][2]
	lane_blocker.global_position = triangle_base
	var open_lane: Vector2 = game._ai_support_target(receiver)
	assert(open_lane != triangle_base)
	assert(XI.has_point(open_lane))
	assert(open_lane.x < triangle_base.x - 50.0)
	assert(absf(open_lane.y - triangle_base.y) >= 130.0)
	assert(open_lane.distance_to(lane_blocker.global_position) >=
		game.AI_XI_SUPPORT_SAFE_RADIUS)
	assert(open_lane.distance_to(passer.global_position) <= game.AI_XI_PASS_MAX_DISTANCE)
	var support_key: int = int(receiver.get_instance_id())
	assert(game.ai_xi_support_lane_memory.has(support_key))
	var original_side: float = signf(open_lane.y - triangle_base.y)
	# A marker shifting 12 units must not flip the runner's chosen side.
	lane_blocker.global_position = triangle_base + Vector2(0.0, original_side * 12.0)
	assert(game._ai_support_target(receiver) == open_lane)
	# Truly blocking that run must make the runner switch to the safe side.
	lane_blocker.global_position = open_lane
	var alternate_lane: Vector2 = game._ai_support_target(receiver)
	assert(alternate_lane != triangle_base and alternate_lane != open_lane)
	assert(signf(alternate_lane.y - triangle_base.y) == -original_side)
	# A renewed open triangle releases memory; do not drag the side choice
	# into a new opportunity when the original pass has become safe again.
	lane_blocker.global_position = Vector2(XI.end.x - 120.0, XI.end.y - 130.0)
	assert(game._ai_support_target(receiver) == triangle_base)
	assert(not game.ai_xi_support_lane_memory.has(support_key))
	lane_blocker.global_position = triangle_base
	assert(game._ai_support_target(receiver) != triangle_base)
	upper_blocker.global_position = triangle_base + Vector2(-55.0, -135.0)
	lower_blocker.global_position = triangle_base + Vector2(-55.0, 135.0)
	assert(game._ai_support_target(receiver) == triangle_base)
	upper_blocker.global_position = Vector2(XI.end.x - 120.0, XI.end.y - 130.0)
	lower_blocker.global_position = upper_blocker.global_position
	var receiver_start: Vector2 = receiver.global_position
	var run_target: Vector2 = game._ai_support_target(receiver)
	game._update_ai(1.0 / 60.0)
	assert(receiver.ai_target.distance_to(run_target) < 1.0)
	assert(receiver.global_position.distance_to(receiver_start) < 15.0)
	assert(receiver.velocity.length() <= receiver.base_speed * 1.34 + 1.0)
	assert(game.ai_xi_support_lane_memory.has(support_key))
	# Lost CPU possession ends the old plan, even if the same player later
	# becomes the primary outlet again.
	game.ball.attach_to(game.teams[0][10])
	game._update_ai(0.0)
	assert(game.ai_xi_support_lane_memory.is_empty())
	game.ball.attach_to(passer)
	game.match_team_size = 5
	assert(game._ai_xi_open_lane_support_target(receiver, triangle_base) == triangle_base)
	game.match_team_size = 11
	# An edge-of-pitch option is rejected rather than clipped into a fake run.
	var edge_target := Vector2(XI.position.x + 30.0, centre.y)
	lane_blocker.global_position = edge_target
	assert(game._ai_xi_open_lane_support_target(receiver, edge_target) == edge_target)
	lane_blocker.global_position = Vector2(XI.end.x - 120.0, XI.end.y - 130.0)
	game.ball.attach_to(passer)

	# Nearby CPU teammates must not swap primary and recycling roles every
	# tick as their positions fluctuate by a few units. A genuinely better
	# third runner can still take over; sent-off players never hold a slot.
	var role_primary: Footballer = receiver
	var role_secondary: Footballer = game.teams[1][5]
	var role_challenger: Footballer = game.teams[1][6]
	var role_anchor: Vector2 = passer.global_position
	role_primary.global_position = role_anchor + Vector2(-210.0, 0.0)
	role_secondary.global_position = role_anchor + Vector2(-260.0, 0.0)
	role_challenger.global_position = role_anchor + Vector2(-275.0, 0.0)
	game.ai_xi_support_rank_owner = null
	game.ai_xi_support_rank_slots = [null, null]
	assert(game._ai_xi_support_rank(role_primary) == 0)
	assert(game._ai_xi_support_rank(role_secondary) == 1)
	role_challenger.global_position = role_anchor + Vector2(-240.0, 0.0)
	assert(game._ai_xi_support_rank(role_primary) == 0)
	assert(game._ai_xi_support_rank(role_secondary) == 1)
	assert(game._ai_xi_support_rank(role_challenger) == -1)
	# A 86-unit improvement over the second runner eventually earns slot 1,
	# without stealing the leading slot from its established teammate.
	role_challenger.global_position = role_anchor + Vector2(-174.0, 0.0)
	assert(game._ai_xi_support_rank(role_primary) == 0)
	assert(game._ai_xi_support_rank(role_challenger) == 1)
	# Only a clearly superior runner replaces the primary support.
	role_challenger.global_position = role_anchor + Vector2(-90.0, 0.0)
	assert(game._ai_xi_support_rank(role_challenger) == 0)
	role_challenger.sent_off = true
	assert(game._ai_xi_support_rank(role_challenger) == -1)
	assert(game._ai_xi_support_rank(role_primary) == 0)
	role_challenger.sent_off = false
	# Releasing the ball or giving it to a rival resets both assignments.
	game.ball.release(Vector2.LEFT, 300.0)
	game._update_ai(0.0)
	assert(game.ai_xi_support_rank_owner == null)
	assert(game.ai_xi_support_rank_slots == [null, null])
	game.ball.attach_to(passer)
	game.match_team_size = 5
	assert(game._ai_xi_support_rank(role_primary) == -1)
	assert(game.ai_xi_support_rank_slots == [null, null])
	game.match_team_size = 11
	role_primary.global_position = role_anchor + Vector2(-330.0, 90.0)
	role_secondary.global_position = Vector2(XI.end.x - 90.0, XI.end.y - 90.0)
	role_challenger.global_position = role_secondary.global_position
	game.ai_xi_support_rank_owner = null
	game.ai_xi_support_rank_slots = [null, null]
	game.ai_xi_support_lane_memory.clear()
	game.ball.attach_to(passer)

	# Moving CPU teammates receive a short, physically aimed through-ball.
	# The destination changes at the kick, not continuously in flight.
	game.ball.attach_to(passer)
	receiver.global_position = passer.global_position + Vector2(-330.0, 90.0)
	receiver.velocity = Vector2(-220.0, 85.0)
	var stationary_aim: Vector2 = receiver.global_position
	var running_aim: Vector2 = game._ai_xi_pass_aim_point(passer, receiver)
	assert(running_aim.x < stationary_aim.x - 30.0)
	assert(running_aim.y > stationary_aim.y + 10.0)
	assert(running_aim.distance_to(stationary_aim) <=
		game.AI_XI_PASS_RUN_LEAD_MAX_DISTANCE + 0.01)
	assert(game._best_ai_pass_target(passer) == receiver)
	game.ball.tick_ball(0.75)
	game._ai_attack(passer)
	assert(game.ball.carrier == null)
	assert(game.ai_intended_pass_receiver == receiver)
	var expected_direction: Vector2 = (
		running_aim - passer.global_position
	).normalized()
	assert(game.ball.velocity.normalized().dot(expected_direction) > 0.999)
	var launch_direction: Vector2 = game.ball.velocity.normalized()
	receiver.global_position += Vector2(0.0, 135.0)
	game.ball.tick_ball(1.0 / 60.0)
	assert(game.ball.velocity.normalized().dot(launch_direction) > 0.999)
	# Standing and barely moving runners keep the traditional direct pass.
	receiver.global_position = stationary_aim
	receiver.velocity = Vector2(-35.0, 0.0)
	assert(game._ai_xi_pass_aim_point(passer, receiver) == stationary_aim)
	receiver.velocity = Vector2.ZERO
	assert(game._ai_xi_pass_aim_point(passer, receiver) == stationary_aim)
	# Leads cannot aim outside the playable pitch.
	receiver.global_position = Vector2(XI.position.x + 80.0, XI.position.y + 4.0)
	receiver.velocity = Vector2(0.0, -310.0)
	assert(XI.has_point(game._ai_xi_pass_aim_point(passer, receiver)))
	receiver.global_position = stationary_aim
	receiver.velocity = Vector2.ZERO
	game.ball.attach_to(passer)

	# CPU XI decision: carry briefly while a clear primary runner closes
	# on his support lane, then pass by the usual physical ground-ball path.
	game.ball.attach_to(passer)
	receiver.global_position = passer.global_position + Vector2(-330.0, 90.0)
	receiver.velocity = Vector2(220.0, -160.0)
	var support_destination: Vector2 = game._ai_support_target(receiver)
	assert(receiver.global_position.distance_to(support_destination) >
		game.AI_XI_SUPPORT_RUN_WAIT_DISTANCE)
	assert(game._ai_xi_should_wait_for_support(passer, receiver, INF))
	assert(not game._ai_xi_should_wait_for_support(passer, receiver, 155.0))
	game.ball.tick_ball(0.50)
	assert(game._best_ai_pass_target(passer) == receiver)
	game._ai_attack(passer)
	assert(game.ball.carrier == passer)
	game.ball.tick_ball(0.40)
	assert(not game._ai_xi_should_wait_for_support(passer, receiver, INF))
	game._ai_attack(passer)
	assert(game.ball.carrier == null)
	assert(game.ai_intended_pass_receiver == receiver)
	# Under moderate pressure, carrying beats an unproductive backward
	# recycle. A truly close defender still triggers the safety pass.
	game.ball.attach_to(passer)
	receiver.velocity = Vector2.ZERO
	receiver.global_position = passer.global_position + Vector2(55.0, 220.0)
	var mild_marker: Footballer = game.teams[0][4]
	mild_marker.global_position = passer.global_position + Vector2(0.0, -205.0)
	game.ball.tick_ball(0.75)
	assert(game._best_ai_pass_target(passer) == receiver)
	game._ai_attack(passer)
	assert(game.ball.carrier == passer)
	mild_marker.global_position = passer.global_position + Vector2(0.0, -145.0)
	game._ai_attack(passer)
	assert(game.ball.carrier == null)
	assert(game.ai_intended_pass_receiver == receiver)
	mild_marker.global_position = Vector2(XI.end.x - 120.0, XI.end.y - 130.0)
	receiver.global_position = stationary_aim
	receiver.velocity = Vector2.ZERO
	game.ball.attach_to(passer)

	# A defender stationed on the passing lane forces a different choice;
	# when no other safe teammate exists, the CPU keeps the ball.
	game.ball.attach_to(passer)
	var blocker: Footballer = game.teams[0][4]
	blocker.global_position = passer.global_position.lerp(receiver.global_position, 0.5)
	assert(game._best_ai_pass_target(passer) == null)
	game._ai_attack(passer)
	assert(game.ball.carrier == passer)

	# When the CPU has NO safe passing outlet, a frontal blocker should
	# make the carrier run into a REAL diagonal gap, not circle backward.
	assert(game.ai_xi_no_safe_pass_owner == passer)
	blocker.global_position = passer.global_position + Vector2(-140.0, 0.0)
	var escape_target: Vector2 = game._ai_dribble_target(passer)
	assert(XI.has_point(escape_target))
	assert(escape_target.x < passer.global_position.x - 140.0)
	assert(absf(escape_target.y - passer.global_position.y) >= 160.0)
	var escape_side: float = signf(escape_target.y - passer.global_position.y)
	assert(game.ai_xi_no_pass_escape_side == escape_side)
	# A small shift of the marker is NOT a reason to change direction.
	blocker.global_position += Vector2(0.0, 9.0)
	var stable_escape: Vector2 = game._ai_dribble_target(passer)
	assert(signf(stable_escape.y - passer.global_position.y) == escape_side)
	# Movement respects normal physical acceleration, never teleporting.
	var escape_start: Vector2 = passer.global_position
	passer.move_ai(1.0 / 60.0, stable_escape, 0.83)
	assert(passer.global_position.distance_to(escape_start) < 15.0)
	assert(passer.velocity.length() <= passer.base_speed * 1.34 + 1.0)
	passer.global_position = escape_start
	passer.velocity = Vector2.ZERO
	# When the corridor clears, prefer ordinary forward play.
	blocker.global_position = Vector2(XI.end.x - 120.0, XI.end.y - 130.0)
	var restored_forward: Vector2 = game._ai_dribble_target(passer)
	assert(absf(restored_forward.y - passer.global_position.y) < 40.0)
	assert(game.ai_xi_no_pass_escape_side == 0.0)
	# A real outlet becomes available again: cease the no-pass plan.
	receiver.global_position = passer.global_position + Vector2(-330.0, 90.0)
	receiver.velocity = Vector2.ZERO
	assert(game._best_ai_pass_target(passer) == receiver)
	game._ai_attack(passer)
	assert(game.ai_xi_no_safe_pass_owner == null)
	# Lost possession clears any stale plan without affecting human or 5v5.
	game.ai_xi_no_safe_pass_owner = passer
	game.ai_xi_no_pass_escape_side = -1.0
	game.ball.attach_to(game.teams[0][10])
	game._update_ai(0.0)
	assert(game.ai_xi_no_safe_pass_owner == null)
	assert(game.ai_xi_no_pass_escape_side == 0.0)
	game.ball.attach_to(passer)
	receiver.global_position = stationary_aim

	# A moving marker can close an otherwise open ground-pass corridor.
	# The current position alone must NOT wrongly reject the outlet.
	var pass_axis: Vector2 = (receiver.global_position - passer.global_position).normalized()
	var lane_normal := Vector2(-pass_axis.y, pass_axis.x)
	blocker.global_position = passer.global_position.lerp(receiver.global_position, 0.5) + lane_normal * 110.0
	blocker.velocity = Vector2.ZERO
	assert(game._ai_xi_pass_lane_clear(passer, receiver))
	blocker.velocity = -lane_normal * 320.0
	assert(not game._ai_xi_pass_lane_clear(passer, receiver))
	assert(game._best_ai_pass_target(passer) == null)
	blocker.velocity = lane_normal * 320.0
	assert(game._ai_xi_pass_lane_clear(passer, receiver))
	# A dismissed defender's old momentum cannot block the lane.
	blocker.global_position = passer.global_position.lerp(receiver.global_position, 0.5)
	blocker.sent_off = true
	assert(game._ai_xi_pass_lane_clear(passer, receiver))
	blocker.sent_off = false
	blocker.velocity = Vector2.ZERO

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
	# An attacker near the XI byline may be inside the nominal shooting
	# radius but see only a sliver of goal. Do NOT blast from there; keep
	# possession for the existing dribble/pass decision instead.
	passer.global_position = Vector2(XI.position.x + 70.0, centre.y + 600.0)
	assert(passer.global_position.distance_to(left_goal) < game.AI_SHOOT_DISTANCE)
	assert(not game._ai_xi_has_shot_angle(passer, left_goal))
	assert(game._best_ai_pass_target(passer) == null)
	game._set_quick_difficulty("normal")
	game.ball.attach_to(passer)
	game._ai_attack(passer)
	assert(game.ball.carrier == passer)
	assert(game.ai_xi_no_safe_pass_owner == passer)
	assert(game._ai_dribble_target(passer).y < passer.global_position.y)
	# Both directions share the same measured goal mouth. A legal central
	# opportunity retains the historic shot and physical ball speed.
	striker.global_position = Vector2(XI.end.x - 70.0, centre.y - 600.0)
	assert(not game._ai_xi_has_shot_angle(striker, right_goal))
	striker.global_position = Vector2(XI.end.x - 430.0, centre.y)
	assert(game._ai_xi_has_shot_angle(striker, right_goal))
	passer.global_position = Vector2(XI.position.x + 430.0, centre.y)
	assert(game._ai_xi_has_shot_angle(passer, left_goal))
	# Shot-lane recognition uses ACTUAL defenders in front of the ball,
	# not the keeper, players behind it or impossible future predictions.
	var xi_shot_keeper: Footballer = game.teams[0][0]
	var xi_shot_target := Vector2(
		left_goal.x,
		left_goal.y + (-70.0 if xi_shot_keeper.global_position.y > left_goal.y else 70.0)
	)
	var xi_shot_blocker: Footballer = game.teams[0][5]
	var xi_shot_blocker_original := xi_shot_blocker.global_position
	assert(not game._ai_xi_shot_lane_blocked(passer, xi_shot_target))
	xi_shot_blocker.global_position = passer.global_position.lerp(xi_shot_target, 0.48)
	assert(game._ai_xi_shot_lane_blocked(passer, xi_shot_target))
	xi_shot_blocker.global_position += Vector2(0.0, 100.0)
	assert(not game._ai_xi_shot_lane_blocked(passer, xi_shot_target))
	xi_shot_blocker.global_position = passer.global_position.lerp(xi_shot_target, 0.48)
	xi_shot_blocker.sent_off = true
	assert(not game._ai_xi_shot_lane_blocked(passer, xi_shot_target))
	xi_shot_blocker.sent_off = false
	xi_shot_blocker.global_position = passer.global_position + Vector2(150.0, 0.0)
	assert(not game._ai_xi_shot_lane_blocked(passer, xi_shot_target))
	xi_shot_blocker.global_position = xi_shot_blocker_original
	# The SAME obstruction may be spotted or overlooked. Easier settings
	# misread it more often. Even Expert MUST NOT be perfect: no FCB cyborg.
	var shot_read_chances: Array[float] = []
	for difficulty in ["easy", "normal", "hard", "expert"]:
		game._set_quick_difficulty(difficulty)
		var chance: float = float(game.quick_difficulty_profile["shot_read"])
		assert(chance > 0.0 and chance < 1.0)
		shot_read_chances.append(chance)
		assert(game._ai_xi_reads_shot_blocker(0.0))
		assert(not game._ai_xi_reads_shot_blocker(0.99))
	for step in range(3):
		assert(shot_read_chances[step] < shot_read_chances[step + 1])
	game._set_quick_difficulty("easy")
	assert(not game._ai_xi_reads_shot_blocker(0.40)) # rash shot
	game._set_quick_difficulty("normal")
	assert(game._ai_xi_reads_shot_blocker(0.40)) # sees a defender
	game._set_quick_difficulty("hard")
	assert(not game._ai_xi_reads_shot_blocker(0.80)) # still human
	game._set_quick_difficulty("expert")
	assert(game._ai_xi_reads_shot_blocker(0.80))
	# Mirrored geometry is equally fallible; never privilege one goal.
	striker.global_position = Vector2(XI.end.x - 430.0, centre.y)
	var mirror_target := Vector2(
		right_goal.x, right_goal.y + (-70.0 if right_keeper.global_position.y > right_goal.y else 70.0)
	)
	var mirror_blocker: Footballer = game.teams[1][5]
	var mirror_original := mirror_blocker.global_position
	mirror_blocker.global_position = striker.global_position.lerp(mirror_target, 0.50)
	assert(game._ai_xi_shot_lane_blocked(striker, mirror_target))
	mirror_blocker.global_position = mirror_original
	game._set_quick_difficulty("normal")
	game.ball.attach_to(passer)
	game._ai_attack(passer)
	assert(game.ball.carrier == null and game.ball.velocity.x < -350.0)
	assert(game.ball.last_release_was_shot)
	print("FOOTBALL_XI_SHOT_ANGLE_OK")
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
	# XI Normal+: one carrier owns the first/second defensive pairing.
	# Small lateral feints must NOT exchange the presser and goal-side
	# cover every frame; a genuinely better runner still takes over.
	game._set_quick_difficulty("normal")
	var role_carrier: Footballer = game.teams[0][10]
	var role_first: Footballer = game.teams[1][5]
	var role_second: Footballer = game.teams[1][6]
	var role_far: Footballer = game.teams[1][7]
	var role_origin: Vector2 = centre + Vector2(220.0, 0.0)
	role_carrier.global_position = role_origin
	for defender: Footballer in game.teams[1]:
		if defender.role != "keeper":
			defender.global_position = role_origin + Vector2(-1150.0, 760.0)
	role_first.global_position = role_origin + Vector2(155.0, -90.0)
	role_second.global_position = role_origin + Vector2(170.0, 90.0)
	role_far.global_position = role_origin + Vector2(430.0, 0.0)
	game.ball.attach_to(role_carrier)
	assert(game._ai_primary_presser(1) == role_first)
	assert(game._ai_secondary_presser(1, role_first) == role_second)
	assert(game.ai_xi_defensive_role_owner == role_carrier)
	role_carrier.global_position += Vector2(0.0, 30.0)
	# The nominally closer second defender gets a modest advantage;
	# both roles remain committed to distinct, physically reachable jobs.
	assert(game._ai_primary_presser(1) == role_first)
	assert(game._ai_secondary_presser(1, role_first) == role_second)
	var first_target: Vector2 = game._ai_press_target(role_first, role_carrier)
	var second_target: Vector2 = game._ai_cover_target(role_second, role_carrier.global_position)
	assert(XI.has_point(first_target) and XI.has_point(second_target))
	assert(second_target.x > role_carrier.global_position.x + 35.0)
	assert(second_target.distance_to(first_target) > 30.0)
	# A strong change in lateral lane forces a genuine handover, without
	# sending the first and second defenders to the SAME place.
	role_carrier.global_position = role_origin + Vector2(0.0, 150.0)
	assert(game._ai_primary_presser(1) == role_second)
	assert(game._ai_secondary_presser(1, role_second) == role_first)
	role_carrier.global_position.y -= 9.0
	assert(game._ai_primary_presser(1) == role_second)
	assert(game._ai_secondary_presser(1, role_second) == role_first)
	role_second.sent_off = true
	assert(game._ai_primary_presser(1) == role_first)
	assert(game._ai_secondary_presser(1, role_first) != role_second)
	role_second.sent_off = false
	# A new owner cannot inherit an old presser pair, even during a
	# quick give-and-go. The loose-ball phase clears both role slots.
	var other_carrier: Footballer = game.teams[0][8]
	other_carrier.global_position = role_origin
	game.ball.attach_to(other_carrier)
	assert(game._ai_primary_presser(1) == role_first)
	assert(game.ai_xi_defensive_role_owner == other_carrier)
	game.ball.release(Vector2.ZERO, 0.0)
	game.ball.global_position = role_origin
	assert(game._ai_primary_presser(1) == role_first)
	assert(game.ai_xi_defensive_role_owner == null)
	# Existing loose-ball role hysteresis must survive consecutive frames,
	# not be cleared on each query by the new possession-scoped pair.
	game.ball.global_position.y += 30.0
	assert(game._ai_primary_presser(1) == role_first)
	# Easy and 5v5 keep selecting the nearest defender during possession.
	game.ball.attach_to(role_carrier)
	role_carrier.global_position = role_origin
	game._set_quick_difficulty("easy")
	assert(game._ai_primary_presser(1) == role_first)
	role_carrier.global_position.y += 30.0
	assert(game._ai_primary_presser(1) == role_second)
	game._set_quick_difficulty("normal")
	game.match_team_size = 5
	role_carrier.global_position = role_origin
	assert(game._ai_primary_presser(1) == role_first)
	role_carrier.global_position.y += 30.0
	assert(game._ai_primary_presser(1) == role_second)
	game.match_team_size = 11
	assert(game._ai_primary_presser(1) == role_second)
	assert(game._ai_secondary_presser(1, role_second) != role_second)
	game.ball.release(Vector2.ZERO, 0.0)
	game._ai_primary_presser(1)
	assert(game.ai_xi_defensive_role_owner == null)

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
	# An XI CPU defender near the carrier must contain rather than waste a
	# tackle at 80 units when its real forward hitbox reaches only ~60.
	# Position/orientation come from real Footballer bodies and velocity.
	game.ball.attach_to(lane_owner)
	lane_owner.velocity = Vector2(220.0, 150.0)
	lane_presser.velocity = Vector2(-200.0, 0.0)
	lane_presser.tackle_cooldown_seconds = 0.0
	lane_presser.tackle_recovery_seconds = 0.0
	lane_presser.tackle_active_seconds = 0.0
	lane_presser.action_lock_seconds = 0.0
	lane_presser.global_position = lane_owner.global_position + Vector2(82.0, 0.0)
	assert(game._ai_primary_presser(1) == lane_presser)
	assert(not game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, false))
	game._update_ai(0.0)
	assert(not lane_presser.tackle_active())
	assert(lane_presser.tackle_cooldown_seconds == 0.0)
	# A lateral poke inside the legal width is still viable for the first
	# presser; the second defender refuses it and preserves goal-side cover.
	lane_presser.global_position = lane_owner.global_position + Vector2(38.0, -25.0)
	lane_presser.velocity = Vector2(-175.0, 0.0)
	var glancing_tackle: Dictionary = game._tackle_hitbox(lane_presser, lane_owner.global_position)
	assert(bool(glancing_tackle["inside"]))
	assert(not bool(glancing_tackle["clean"]))
	assert(not bool(glancing_tackle["foul"]))
	# In Normal, a just-received human ball gets a finite read time.
	# The CPU can still close, and then the exact existing hitbox applies.
	assert(not game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, false))
	game.ball.tick_ball(game.AI_XI_NORMAL_FIRST_TOUCH_REACTION + 0.02)
	assert(game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, false))
	assert(not game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, true))
	# A late challenge from behind would risk a foul: keep containing.
	lane_presser.global_position = lane_owner.global_position + Vector2(-18.0, 0.0)
	assert(bool(game._tackle_hitbox(lane_presser, lane_owner.global_position)["foul"]))
	assert(not game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, false))
	# At last a front-on contact is possible. The existing authoritative
	# tackle rules execute normally; no enlarged tackle reach is involved.
	lane_presser.global_position = lane_owner.global_position + Vector2(31.0, -8.0)
	lane_presser.velocity = Vector2(-160.0, 0.0)
	assert(bool(game._tackle_hitbox(lane_presser, lane_owner.global_position)["clean"]))
	# Normal's cover contains even at a clean contact opportunity.
	assert(not game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, true))
	assert(game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, false))
	assert(game._try_tackle(lane_presser))
	assert(game.ball.carrier == null)
	# Easy and the legacy five-player fixture are explicitly untouched.
	lane_presser.tackle_cooldown_seconds = 0.0
	lane_presser.action_lock_seconds = 0.0
	lane_presser.tackle_active_seconds = 0.0
	game.ball.attach_to(lane_owner)
	lane_presser.global_position = lane_owner.global_position + Vector2(82.0, 0.0)
	game._set_quick_difficulty("easy")
	assert(game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, false))
	game._set_quick_difficulty("normal")
	game.match_team_size = 5
	assert(game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, false))
	game.match_team_size = 11
	game.ball.release(Vector2.ZERO, 0.0)
	assert(not game._ai_xi_tackle_commit_ready(lane_presser, lane_owner, false))
	print("FOOTBALL_XI_TACKLE_CONTAIN_OK no_wasted_animation=1 no_recovery=1 no_foul=1 normal_cover_contains=1 easy_five_unchanged=1")
	print("FOOTBALL_XI_CPU_LANE_GUARD_OK pressure=1 cover=1 marker=1 no_teleport=1 no_speed_boost=1 easy=off five=off")
	print("FOOTBALL_XI_AI_OK goals=2 lanes=3 dribble=1 cover=1 keeper=1 loose=1 q_switch=nearest_valid team_pass=received blocked pressure marked shot=1 old_5v5=unchanged")
	quit(0)
