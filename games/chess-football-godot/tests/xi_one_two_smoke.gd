extends SceneTree

# Real XI pass release, Input.action_press, 60 Hz ball travel and possession.
# The receiver must physically win the first pass before returning a second,
# independently interceptable ball. No fake goals, pickups or engine mocks.
const STEP := 1.0 / 60.0

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
	game.pending_tackle_player = null
	for team in game.teams:
		for player: Footballer in team:
			player.set_process(false)
			player.set_physics_process(false)
			player.velocity = Vector2.ZERO
			player.global_position = (
				game.match_pitch.position + Vector2(
					80.0 + float(player.team_id) * 3600.0,
					80.0 + float(player.squad_index) * 180.0
				)
			)
	var passer: Footballer = game.teams[0][10]
	var receiver: Footballer = game.teams[0][6]
	var interceptor: Footballer = game.teams[1][4]
	var start: Vector2 = game.match_pitch.get_center() + Vector2(-350.0, 0.0)
	passer.global_position = start
	receiver.global_position = start + Vector2(300.0, 0.0)
	game._select_player(passer)
	game.ball.attach_to(passer)
	assert(game._begin_directional_pass_charge(Vector2.RIGHT))
	assert(game.pass_target == receiver, "XI Space needs the actual targeted teammate")
	game.pass_charge_seconds = 0.11
	assert(game._release_charged_pass())
	assert(game.ball.carrier == null and game.controlled == passer)
	assert(game._one_two_can_request())
	assert(game.contextual_help_text(false).contains("pedir pared"))
	# Second Space during the FIRST pass flight, while the user keeps
	# controlling the original passer, explicitly requests the return.
	Input.action_press("pass_ball")
	game._handle_human(STEP)
	assert(game.xi_one_two_armed)
	assert(game.action_feedback_text == "PARED PEDIDA")
	Input.action_release("pass_ball")
	game._handle_human(STEP)
	var returned := false
	var run_start: Vector2 = passer.global_position
	assert(game.xi_one_two_run_until > game.match_seconds)
	for tick in range(150):
		await physics_frame
		game.match_seconds += STEP
		game._handle_human(STEP)
		game.ball.tick_ball(STEP)
		game._try_claim_loose_ball()
		game._maybe_select_pass_receiver()
		assert(game.controlled == passer, "Requested wall retains passer until actual return")
		if game.action_feedback_text == "PARED":
			returned = true
			break
	assert(returned, "One-two must be earned by the designated physical first touch")
	assert(passer.global_position.x > run_start.x + 15.0)
	assert(absf(passer.global_position.y - run_start.y) > 10.0)
	print("FOOTBALL_XI_ONE_TWO_RUN_OK travel=", passer.global_position.distance_to(run_start), " forward=", passer.global_position.x - run_start.x)
	assert(game.ball.carrier == null and game.controlled == passer,
		"One-two return must be an actual loose pass, not instant control")
	assert(game.ball.velocity.x < -250.0,
		"Successful one-two must physically return towards the original passer")
	assert(not game.xi_one_two_armed)
	var received_return := false
	for tick in range(150):
		await physics_frame
		game.match_seconds += STEP
		game._handle_human(STEP)
		game.ball.tick_ball(STEP)
		game._try_claim_loose_ball()
		game._maybe_select_pass_receiver()
		if game.ball.carrier != null:
			received_return = game.ball.carrier == passer
			break
	assert(received_return, "The physical return must be receivable by the runner")

	# Reset the initial fixture for independent normal-pass and interception tests.
	passer.global_position = start
	receiver.global_position = start + Vector2(300.0, 0.0)
	# Without a second Space, the ordinary first touch retains the ball
	# and transfers human control to its real receiver. No automatic walls.
	game._select_player(passer)
	game.ball.attach_to(passer)
	passer.velocity = Vector2.ZERO
	receiver.velocity = Vector2.ZERO
	assert(game._begin_directional_pass_charge(Vector2.RIGHT))
	assert(game.pass_target == receiver)
	game.pass_charge_seconds = 0.11
	assert(game._release_charged_pass())
	assert(not game.xi_one_two_armed)
	var ordinary_receive := false
	for tick in range(150):
		await physics_frame
		game.match_seconds += STEP
		game.ball.tick_ball(STEP)
		game._try_claim_loose_ball()
		if game.ball.carrier != null:
			ordinary_receive = game.ball.carrier == receiver
			break
	assert(ordinary_receive and game.controlled == receiver,
		"Normal XI passing must not trigger an unsolicited one-touch return")

	# A genuine CPU interception cancels the requested combination. Set
	# only the initial defensive fixture; from there 60 Hz ball and contact
	# mechanics decide who reaches the ball first.
	game._select_player(passer)
	game.ball.attach_to(passer)
	receiver.velocity = Vector2.ZERO
	interceptor.global_position = passer.global_position + Vector2(160.0, 0.0)
	assert(game._begin_directional_pass_charge(Vector2.RIGHT))
	game.pass_charge_seconds = 0.11
	assert(game._release_charged_pass())
	Input.action_press("pass_ball")
	game._handle_human(STEP)
	assert(game.xi_one_two_armed)
	assert(game._xi_one_two_run_direction(Vector2.UP) == Vector2.UP)
	assert(game.xi_one_two_run_until == 0.0 and game.xi_one_two_armed,
		"Manual movement cancels only assistance, not the deliberate wall")
	Input.action_release("pass_ball")
	game._handle_human(STEP)
	var intercepted := false
	for tick in range(100):
		await physics_frame
		game.match_seconds += STEP
		game.ball.tick_ball(STEP)
		game._try_claim_loose_ball()
		if game.ball.carrier != null:
			intercepted = game.ball.carrier == interceptor
			break
	assert(intercepted, "A real opponent must be able to intercept a requested one-two")
	assert(not game.xi_one_two_armed and game.action_feedback_text != "PARED",
		"An interception must cancel the combination without fake returns")
	# Manual Q has priority even if the pass is still airborne.
	interceptor.global_position = game.match_pitch.position + Vector2(3700.0, 450.0)
	game._select_player(passer)
	game.ball.attach_to(passer)
	assert(game._begin_directional_pass_charge(Vector2.RIGHT))
	assert(game._release_charged_pass())
	assert(game._one_two_can_request())
	# As in eleven_ai_pitch_smoke: a fresh process frame separates this
	# key edge from the preceding pass. Otherwise Godot's just_pressed
	# cache can reuse the same tick and a real Q is never presented.
	await process_frame
	Input.action_press("change_player")
	assert(Input.is_action_just_pressed("change_player"),
		"Test fixture must present a genuine Q edge")
	game._handle_human(STEP)
	Input.action_release("change_player")
	assert(not game._one_two_can_request() and not game.xi_one_two_armed,
		"Manual Q must immediately cancel the planned return")

	# A neutral-input XI receiver must not stop just because the early
	# handoff transferred control before the physical first touch.
	await process_frame
	game._select_player(passer)
	game.ball.attach_to(passer)
	passer.velocity = Vector2.ZERO
	receiver.global_position = passer.global_position + Vector2(300.0, 0.0)
	receiver.velocity = Vector2.ZERO
	assert(game._begin_directional_pass_charge(Vector2.RIGHT))
	game.pass_charge_seconds = 0.11
	assert(game._release_charged_pass())
	var handed_off := false
	var first_touch := false
	var neutral_travel := 0.0
	for tick in range(150):
		await physics_frame
		game.match_seconds += STEP
		if game.controlled == receiver:
			var before: Vector2 = receiver.global_position
			game._handle_human(STEP)
			neutral_travel += receiver.global_position.distance_to(before)
		else:
			receiver.move_ai(STEP, game.ball.global_position + game.ball.velocity * 0.12, 1.0)
		game.ball.tick_ball(STEP)
		game._try_claim_loose_ball()
		game._maybe_select_pass_receiver()
		if game.ball.carrier != null:
			first_touch = game.ball.carrier == receiver
			break
		if game.controlled == receiver:
			handed_off = true
	assert(handed_off and first_touch, "Early handoff must finish with a real first touch")
	assert(neutral_travel > 10.0, "Neutral input must not brake the selected receiving runner")
	assert(game.xi_pass_handoff_actor == null, "Possession ends the chase")
	# New deliberate directional input wins, even during a live handoff.
	game.ball.release(Vector2.RIGHT, 500.0)
	game.xi_pass_handoff_actor = receiver
	game.xi_pass_handoff_until = game.match_seconds + 0.45
	assert(game._xi_pass_handoff_direction(Vector2.UP) == Vector2.UP)
	assert(game.xi_pass_handoff_actor == null)
	print("FOOTBALL_XI_PASS_HANDOFF_OK neutral_travel=", neutral_travel)

	# A fall between the request and real reception must not force a
	# return to an incapacitated passer. Ordinary possession still works.
	await process_frame
	game._select_player(passer)
	passer.global_position = start
	receiver.global_position = start + Vector2(300.0, 0.0)
	passer.velocity = Vector2.ZERO
	receiver.velocity = Vector2.ZERO
	game.ball.attach_to(passer)
	assert(game._begin_directional_pass_charge(Vector2.RIGHT))
	assert(game.pass_target == receiver)
	game.pass_charge_seconds = 0.11
	assert(game._release_charged_pass())
	assert(game._try_arm_one_two())
	passer.xi_collision_down_seconds = 1.0
	var fall_receive := false
	for tick in range(150):
		await physics_frame
		game.match_seconds += STEP
		game.ball.tick_ball(STEP)
		game._try_claim_loose_ball()
		game._maybe_select_pass_receiver()
		if game.ball.carrier != null:
			fall_receive = game.ball.carrier == receiver
			break
	assert(fall_receive and game.controlled == receiver)
	assert(not game.xi_one_two_armed and game.xi_one_two_run_until == 0.0)
	passer.xi_collision_down_seconds = 0.0
	print("FOOTBALL_XI_ONE_TWO_FALL_OK receiver_keeps_ball=true")

	_first_touch_continuity(game, passer, receiver, interceptor)
	print("FOOTBALL_XI_ONE_TWO_OK real_pass=true deliberate_input=true physical_return=true normal_pass=true interceptable=true cancel=true")
	# A fresh match exercises the production tick ordering with all 22
	# players available. Only the initial positions and first charged pass
	# are arranged; no player, ball or possession is moved by the test
	# after the pass begins.
	game.queue_free()
	await process_frame
	await _live_wall(scene)
	quit(0)


func _live_wall(scene: PackedScene) -> void:
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
	game.pending_tackle_player = null
	for team in game.teams:
		for player: Footballer in team:
			player.set_process(false)
			player.set_physics_process(false)
			player.velocity = Vector2.ZERO
			player.global_position = game.match_pitch.position + Vector2(
				150.0 if player.team_id == 0 else game.match_pitch.size.x - 150.0,
				100.0 + float(player.squad_index) * (game.match_pitch.size.y - 200.0) / 10.0
			)
	var passer: Footballer = game.teams[0][10]
	var receiver: Footballer = game.teams[0][6]
	var rival: Footballer = game.teams[1][4]
	var start: Vector2 = game.match_pitch.get_center() + Vector2(-350.0, 0.0)
	passer.global_position = start
	receiver.global_position = start + Vector2(300.0, 0.0)
	var rival_start: Vector2 = rival.global_position
	game._select_player(passer)
	game.ball.attach_to(passer)
	assert(game._begin_directional_pass_charge(Vector2.RIGHT))
	assert(game.pass_target == receiver)
	game.pass_charge_seconds = 0.11
	assert(game._release_charged_pass())
	await process_frame
	Input.action_press("pass_ball")
	game._physics_process(STEP)
	assert(game.xi_one_two_armed)
	Input.action_release("pass_ball")
	var returned := false
	var received := false
	for tick in range(150):
		await physics_frame
		game._physics_process(STEP)
		if game.action_feedback_text == "PARED":
			returned = true
		if game.ball.carrier != null:
			received = returned and game.ball.carrier == passer
			break
	assert(returned and received and game.controlled == passer,
		"Live XI tick must complete the requested wall with ordinary AI and possession")
	assert(passer.global_position.distance_to(start) > 15.0)
	assert(rival.global_position.distance_to(rival_start) > 1.0,
		"The full rival AI must actually move during the combination")
	print("FOOTBALL_XI_ONE_TWO_LIVE_OK passer_travel=", passer.global_position.distance_to(start),
		" rival_travel=", rival.global_position.distance_to(rival_start), " real_return=true")
	game.queue_free()


# A legal incoming ball must retain its exact world position when claimed.
# Exercise the production claim path, not a direct test-only pickup.
func _first_touch_continuity(game, passer: Footballer, receiver: Footballer, rival: Footballer) -> void:
	game._clear_one_two()
	var centre: Vector2 = game.match_pitch.get_center()
	for team in game.teams:
		for player: Footballer in team:
			player.velocity = Vector2.ZERO
			player.global_position = centre + Vector2(
				500.0 if player.team_id == 0 else -500.0,
				100.0 + float(player.squad_index) * 50.0
			)
	receiver.global_position = centre
	for motion: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]:
		game.ball.attach_to(passer)
		game.ball.release(Vector2.RIGHT, 400.0)
		receiver.velocity = motion * receiver.base_speed
		var contact: Vector2 = centre + Vector2(-24.0, 0.0)
		game.ball.global_position = contact
		game._try_claim_loose_ball()
		assert(game.ball.carrier == receiver and game.controlled == receiver)
		assert(game.ball.global_position.is_equal_approx(contact), "XI claim must not snap to boot")
		assert(game.ball.velocity == Vector2.ZERO and game.ball.possession_seconds == 0.0)
		# An immediate kick originates at the actual contact point.
		if motion != Vector2.ZERO:
			game.ball.release(Vector2.RIGHT, 400.0)
			assert(game.ball.global_position.is_equal_approx(contact))
		else:
			var target: Vector2 = centre + receiver.ball_anchor()
			var initial_error := contact.distance_to(target)
			game.ball.tick_ball(STEP)
			assert(game.ball.global_position.distance_to(target) < initial_error)
			assert(not game.ball.global_position.is_equal_approx(target))
			for tick in range(12):
				game.ball.tick_ball(STEP)
			assert(game.ball.global_position.distance_to(target) < 1.0)
			assert(game.ball.carrier == receiver)
	# Equal opposing contact remains loose; preserving position cannot grant
	# priority to the intended receiver or to a particular team.
	game.ball.attach_to(passer)
	game.ball.release(Vector2.RIGHT, 400.0)
	receiver.velocity = Vector2.ZERO
	rival.velocity = Vector2.ZERO
	rival.global_position = centre + Vector2(0.0, 40.0)
	game.ball.global_position = centre + Vector2(0.0, 20.0)
	game._try_claim_loose_ball()
	assert(game.ball.carrier == null)
	rival.global_position = centre + Vector2(500.0, 0.0)
	game._try_claim_loose_ball()
	assert(game.ball.carrier == receiver)
	# Explicit placement/restart, keeper catch and legacy 5v5 still snap.
	game.ball.attach_to(receiver)
	assert(game.ball.global_position.is_equal_approx(centre + receiver.ball_anchor()))
	var keeper: Footballer = game.teams[0][0]
	game.ball.attach_to(keeper, true)
	assert(game.ball.global_position.is_equal_approx(keeper.global_position + keeper.ball_anchor()))
	var pitch: Rect2 = receiver.match_pitch
	receiver.match_pitch = ChessFootballMath.PITCH_RECT
	game.ball.attach_to(receiver, true)
	assert(game.ball.global_position.is_equal_approx(centre + receiver.ball_anchor()))
	receiver.match_pitch = pitch
	print("FOOTBALL_XI_FIRST_TOUCH_CONTINUITY_OK four_headings=true tie=true immediate_release=true legacy=true")
