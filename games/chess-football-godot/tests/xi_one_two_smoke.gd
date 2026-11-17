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
	for tick in range(150):
		await physics_frame
		game.match_seconds += STEP
		game.ball.tick_ball(STEP)
		game._try_claim_loose_ball()
		if game.action_feedback_text == "PARED":
			returned = true
			break
	assert(returned, "One-two must be earned by the designated physical first touch")
	assert(game.ball.carrier == null and game.controlled == passer,
		"One-two return must be an actual loose pass, not instant control")
	assert(game.ball.velocity.x < -250.0,
		"Successful one-two must physically return towards the original passer")
	assert(not game.xi_one_two_armed)
	var received_return := false
	for tick in range(150):
		await physics_frame
		game.match_seconds += STEP
		game.ball.tick_ball(STEP)
		game._try_claim_loose_ball()
		if game.ball.carrier != null:
			received_return = game.ball.carrier == passer
			break
	assert(received_return, "The physical return must be receivable by the runner")

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
	Input.action_press("change_player")
	game._handle_human(STEP)
	Input.action_release("change_player")
	assert(not game._one_two_can_request() and not game.xi_one_two_armed,
		"Manual Q must immediately cancel the planned return")

	print("FOOTBALL_XI_ONE_TWO_OK real_pass=true deliberate_input=true physical_return=true normal_pass=true interceptable=true cancel=true")
	quit(0)
