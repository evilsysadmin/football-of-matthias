extends SceneTree

# XI physical duel contract. Tackle orientation is committed at launch; a
# short early human E/F input is honored ONLY upon real contact range.
# No lock-on, immunity, instant possession, changed 5v5 rules or animation mocks.
const Formation = preload("res://scripts/football_match_formation.gd")
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
	assert(game.match_pitch == Formation.ELEVEN_PITCH_RECT)
	var point: Vector2 = game.match_pitch.get_center()
	for team in game.teams:
		for athlete: Footballer in team:
			athlete.set_process(false)
			athlete.set_physics_process(false)
			athlete.global_position = game.match_pitch.position + Vector2(
				60.0 + float(athlete.squad_index) * 68.0,
				60.0 + float(athlete.team_id) * 430.0
			)
			athlete.velocity = Vector2.ZERO

	var human_carrier: Footballer = game.teams[0][10]
	var cpu_tackler: Footballer = game.teams[1][5]
	game._select_player(human_carrier)
	game.ball.attach_to(human_carrier)
	human_carrier.global_position = point
	cpu_tackler.global_position = point + Vector2(70.0, 0.0)
	cpu_tackler.velocity = Vector2.LEFT * cpu_tackler.base_speed
	assert(cpu_tackler.start_tackle())
	assert(cpu_tackler.xi_tackle_launch_heading.dot(Vector2.LEFT) > 0.99)
	var initial_forward: Vector2 = game._tackle_forward(cpu_tackler)
	assert(initial_forward.dot(Vector2.LEFT) > 0.99)
	# Even if pursuit turns north, the committed boot cannot swing its
	# active real hitbox by 90 degrees to steal from a lateral dodge.
	cpu_tackler.velocity = Vector2.UP * cpu_tackler.base_speed
	assert(game._tackle_forward(cpu_tackler).is_equal_approx(initial_forward))
	human_carrier.global_position = cpu_tackler.global_position + Vector2(0.0, -35.0)
	var dodge_hit: Dictionary = game._tackle_hitbox(cpu_tackler, human_carrier.global_position)
	assert(not bool(dodge_hit["contact"]))
	assert(not game._resolve_tackle_contact(cpu_tackler, human_carrier))
	assert(game.ball.carrier == human_carrier,
		"An opponent changing momentum cannot rotate an already-launched tackle cone")
	cpu_tackler._process(cpu_tackler.TACKLE_ACTIVE_SECONDS + 0.01)
	assert(not cpu_tackler.tackle_active())
	assert(cpu_tackler.xi_tackle_launch_heading == Vector2.ZERO)
	assert(game._tackle_forward(cpu_tackler).dot(Vector2.UP) > 0.99)

	# A properly timed frontal challenge still works, with the ordinary
	# clean-contact poke rather than a rigged immunity for E cut runners.
	human_carrier.global_position = point
	cpu_tackler.global_position = point + Vector2(36.0, 0.0)
	cpu_tackler.velocity = Vector2.LEFT * cpu_tackler.base_speed
	cpu_tackler.tackle_cooldown_seconds = 0.0
	cpu_tackler.action_lock_seconds = 0.0
	cpu_tackler.tackle_recovery_seconds = 0.0
	assert(game._try_tackle(cpu_tackler))
	assert(game.ball.carrier == null,
		"Legal front-on CPU tackles must still dislodge the human carrier")
	assert(game.pending_tackle_player == cpu_tackler)

	# Only Hard automatic challenges against a moving cut receive the
	# preparation beat. Use real E state and the actual physical ball.
	game._set_quick_difficulty("hard")
	for dodge in [false, true]:
		game.pending_tackle_player = null
		game.pending_tackle_seconds = 0.0
		human_carrier.contact_stun_seconds = 0.0
		human_carrier.global_position = point
		human_carrier.velocity = Vector2.DOWN * human_carrier.base_speed if dodge else Vector2.ZERO
		human_carrier.action_lock_seconds = 0.0
		human_carrier.tackle_recovery_seconds = 0.0
		human_carrier.dribble_burst_seconds = 0.0
		human_carrier.dribble_cooldown_seconds = 0.0
		human_carrier.stamina = human_carrier.STAMINA_MAX
		human_carrier.sprint_exhausted = false
		cpu_tackler.tackle_active_seconds = 0.0
		cpu_tackler.tackle_cooldown_seconds = 0.0
		cpu_tackler.action_lock_seconds = 0.0
		cpu_tackler.tackle_recovery_seconds = 0.0
		game.ball.attach_to(human_carrier)
		assert(human_carrier.start_dribble(Vector2.DOWN if dodge else Vector2.RIGHT, "cut"))
		game.ball.tick_ball(0.0)
		var initial_position: Vector2 = human_carrier.global_position
		var initial_ball: Vector2 = game.ball.global_position
		# Face a ball already within the legal lateral edge. For the
		# moving case the carrier and ball move farther down that flank.
		cpu_tackler.global_position = initial_ball + Vector2(36.0, -26.0 if dodge else 0.0)
		cpu_tackler.velocity = Vector2.LEFT * cpu_tackler.base_speed
		var initial_hitbox: Dictionary = game._tackle_hitbox(cpu_tackler, initial_ball)
		assert(initial_hitbox["inside"] and initial_hitbox["contact"])
		assert(not game._try_tackle(cpu_tackler, false, true))
		assert(cpu_tackler.tackle_active() and game.ball.carrier == human_carrier)
		for tick in range(3):
			await physics_frame
			if dodge:
				human_carrier.move_human(DT, Vector2.DOWN, true)
				game.ball.tick_ball(DT)
			cpu_tackler._process(DT)
			game._update_active_tackle_contacts()
			if tick < 2:
				assert(game.ball.carrier == human_carrier)
		assert((game.ball.carrier == human_carrier) == dodge)
		if dodge:
			var travel: float = human_carrier.global_position.distance_to(initial_position)
			assert(travel > 8.0 and travel < 40.0)
			assert(not game._tackle_hitbox(cpu_tackler, game.ball.global_position)["contact"])
			print("FOOTBALL_XI_HARD_TACKLE_PHYSICAL_ESCAPE_OK travel=", travel)
	game._set_quick_difficulty("normal")
	print("FOOTBALL_XI_HARD_TACKLE_WINDUP_OK ticks=3 legal_contact=true lateral_escape=true")
	# The human E press just outside the old range waits briefly for the
	# player to RUN into a real legal hitbox, with no instant tackle/steal.
	var cpu_owner: Footballer = game.teams[1][10]
	var human_tackler: Footballer = game.teams[0][3]
	game.pending_tackle_player = null
	game.pending_tackle_seconds = 0.0
	cpu_owner.global_position = point
	cpu_owner.velocity = Vector2.ZERO
	human_tackler.global_position = point + Vector2(-104.0, 0.0)
	human_tackler.velocity = Vector2.RIGHT * 300.0
	human_tackler.tackle_cooldown_seconds = 0.0
	human_tackler.tackle_recovery_seconds = 0.0
	human_tackler.action_lock_seconds = 0.0
	human_tackler.tackle_active_seconds = 0.0
	game._select_player(human_tackler)
	game.ball.attach_to(cpu_owner)
	game._handle_contextual_e(Vector2.RIGHT, false)
	assert(game.xi_buffered_tackle_actor == human_tackler)
	assert(game.xi_buffered_tackle_victim == cpu_owner)
	assert(human_tackler.tackle_active_seconds == 0.0)
	assert(human_tackler.tackle_cooldown_seconds == 0.0)
	assert(game.ball.carrier == cpu_owner)
	var started := false
	for tick in range(12):
		await physics_frame
		game.match_seconds += DT
		human_tackler.move_human(DT, Vector2.RIGHT, true)
		game._update_xi_human_tackle_buffer()
		if human_tackler.tackle_active():
			started = true
			break
		human_tackler._process(DT)
	assert(started, "Early E must become a REAL contact-range tackle while chasing")
	assert(game.xi_buffered_tackle_actor == null)
	assert(human_tackler.tackle_cooldown_seconds > 0.0)
	assert(game.ball.carrier == null,
		"Only an actual physical hitbox may poke the ball loose")
	# Both a clean poke and a glancing loose-ball duel count as a real
	# executed contact; neither grants instant ownership to the tackler.
	assert(game.ball.carrier == null and human_tackler.tackle_active())
	# The REAL previous tackle pushes its victim 24 units. A fresh scenario
	# must restore the starting position, not silently ask the input buffer
	# to chase a rival now 139 units away (outside its 136-unit gate).
	assert(cpu_owner.global_position.distance_to(point) >= 20.0)
	cpu_owner.global_position = point

	# A retreating press must NOT buffer an automatic self-aiming tackle.
	game.pending_tackle_player = null
	game.pending_tackle_seconds = 0.0
	human_tackler.tackle_active_seconds = 0.0
	human_tackler.tackle_cooldown_seconds = 0.0
	human_tackler.action_lock_seconds = 0.0
	human_tackler.tackle_recovery_seconds = 0.0
	human_tackler.velocity = Vector2.RIGHT * 300.0
	human_tackler.global_position = point + Vector2(-115.0, 0.0)
	game.ball.attach_to(cpu_owner)
	game._handle_contextual_e(Vector2.LEFT, false)
	assert(game.xi_buffered_tackle_actor == null)
	assert(human_tackler.tackle_active_seconds == 0.0)

	# If the attacker remains beyond reach, the early request expires
	# without an action cooldown or a phantom stolen ball.
	game._handle_contextual_e(Vector2.RIGHT, false)
	assert(game.xi_buffered_tackle_actor == human_tackler)
	game.match_seconds += game.XI_HUMAN_TACKLE_BUFFER_SECONDS + 0.02
	game._update_xi_human_tackle_buffer()
	assert(game.xi_buffered_tackle_actor == null)
	assert(human_tackler.tackle_cooldown_seconds == 0.0)
	assert(game.ball.carrier == cpu_owner)

	# Switching controlled players immediately discards the intent;
	# possession changing must do the same.
	game._handle_contextual_e(Vector2.RIGHT, false)
	assert(game.xi_buffered_tackle_actor == human_tackler)
	await process_frame
	Input.action_press("change_player")
	game._handle_human(0.0)
	Input.action_release("change_player")
	assert(game.xi_buffered_tackle_actor == null)
	game._select_player(human_tackler)
	game._handle_contextual_e(Vector2.RIGHT, false)
	assert(game.xi_buffered_tackle_actor == human_tackler)
	game.ball.attach_to(game.teams[1][8])
	game._update_xi_human_tackle_buffer()
	assert(game.xi_buffered_tackle_actor == null)

	# Explicit F is riskier but uses the SAME short buffered-input gate,
	# and still requires a real contact when it launches.
	human_tackler.velocity = Vector2.RIGHT * 300.0
	human_tackler.global_position = point + Vector2(-137.0, 0.0)
	game.ball.attach_to(cpu_owner)
	game._handle_contextual_special(Vector2.RIGHT)
	assert(game.xi_buffered_tackle_actor == human_tackler)
	assert(game.xi_buffered_tackle_aggressive)
	assert(human_tackler.tackle_active_seconds == 0.0)
	game._clear_xi_human_tackle_buffer()

	# Existing five-a-side has no buffered E and a live heading after a
	# tackle is launched: do not silently change legacy physics.
	game.match_team_size = 5
	human_tackler.match_pitch = ChessFootballMath.PITCH_RECT
	human_tackler.tackle_cooldown_seconds = 0.0
	human_tackler.tackle_active_seconds = 0.0
	human_tackler.action_lock_seconds = 0.0
	human_tackler.tackle_recovery_seconds = 0.0
	human_tackler.velocity = Vector2.RIGHT * 300.0
	human_tackler.global_position = point + Vector2(-110.0, 0.0)
	game.ball.attach_to(cpu_owner)
	game._handle_contextual_e(Vector2.RIGHT, false)
	assert(game.xi_buffered_tackle_actor == null)
	assert(human_tackler.start_tackle())
	human_tackler.velocity = Vector2.UP * 250.0
	assert(game._tackle_forward(human_tackler).dot(Vector2.UP) > 0.99)
	assert(human_tackler.xi_tackle_launch_heading == Vector2.ZERO)

	print("FOOTBALL_XI_COMMITTED_TACKLE_OK locked_heading=true real_buffered_e=true legal_front_contact=true expires=true cancel_q=true cancel_possession=true buffered_f=true legacy_5v5=true")
	quit(0)
