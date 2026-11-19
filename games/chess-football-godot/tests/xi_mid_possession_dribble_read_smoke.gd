extends SceneTree

# Regression: a fresh XI E mid-possession must not give the CPU a perfect
# first-frame tackle read. Existing launched tackles stay physically legal.
const Formation = preload("res://scripts/football_match_formation.gd")

func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
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
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.global_position = game.match_pitch.position + Vector2(
				80.0 + float(actor.squad_index) * 70.0,
				90.0 + float(actor.team_id) * 220.0
			)
			actor.velocity = Vector2.ZERO
	var carrier: Footballer = game.teams[0][10]
	var presser: Footballer = game.teams[1][5]
	var centre: Vector2 = game.match_pitch.get_center()
	game._select_player(carrier)
	for level in ["normal", "hard", "expert"]:
		game._set_quick_difficulty(level)
		carrier.global_position = centre
		carrier.velocity = Vector2.RIGHT * carrier.base_speed
		carrier.dribble_burst_seconds = 0.0
		carrier.dribble_cooldown_seconds = 0.0
		carrier.action_lock_seconds = 0.0
		carrier.contact_stun_seconds = 0.0
		presser.global_position = centre + Vector2(42.0, 0.0)
		presser.velocity = Vector2.LEFT * presser.base_speed
		presser.tackle_active_seconds = 0.0
		presser.tackle_cooldown_seconds = 0.0
		presser.action_lock_seconds = 0.0
		presser.tackle_recovery_seconds = 0.0
		game.ball.attach_to(carrier)
		game.ball.possession_seconds = 3.0
		assert(game._try_dribble(Vector2.RIGHT))
		assert(carrier.dribble_mode == "cut")
		assert(bool(game._tackle_hitbox(presser, centre)["clean"]))
		var read_seconds: float = game._ai_xi_cut_read_seconds()
		assert(read_seconds > 0.0 and read_seconds < carrier.dribble_duration_seconds)
		assert(not game._ai_xi_tackle_commit_ready(presser, carrier, false),
			"An E cut after long possession must not trigger an instant CPU tackle")
		assert(not game._ai_xi_dribble_tackle_read_ready(carrier))
		var old_lane: Vector2 = game._ai_press_target(presser, carrier)
		carrier.global_position += Vector2(25.0, 32.0)
		var observed: Vector2 = game._ai_press_target(presser, carrier)
		assert(absf(observed.y - carrier.global_position.y) > 12.0,
			"CPU must first follow old running lane, not instantaneously mirror cut")
		assert(old_lane != observed)
		carrier.global_position = centre
		var legal_tackle_read: float = (
			game.AI_XI_CUT_TACKLE_READ_NORMAL if level == "normal" else read_seconds
		)
		# The planted E animation and the stamina-paid exit both advance on
		# actual physics time. Simulate both clocks to the same precise instant.
		carrier.dribble_burst_seconds = maxf(
			0.0, carrier.dribble_duration_seconds - read_seconds - 0.01
		)
		carrier.xi_cut_exit_run_seconds = (
			carrier.dribble_duration_seconds + carrier.XI_CUT_EXIT_RUN_SECONDS
			- read_seconds - 0.01
		)
		if level == "normal":
			assert(not game._ai_xi_dribble_tackle_read_ready(carrier),
				"Normal must read beyond the planted touch before attacking")
		carrier.dribble_burst_seconds = maxf(
			0.0, carrier.dribble_duration_seconds - legal_tackle_read - 0.01
		)
		carrier.xi_cut_exit_run_seconds = (
			carrier.dribble_duration_seconds + carrier.XI_CUT_EXIT_RUN_SECONDS
			- legal_tackle_read - 0.01
		)
		assert(game._ai_xi_dribble_tackle_read_ready(carrier))
		assert(game._ai_xi_tackle_commit_ready(presser, carrier, false),
			"New legal front-on tackles must be permitted after the read")
		assert(game._ai_press_target(presser, carrier).distance_to(centre) < 130.0,
			"After reading the cut CPU must resume pursuit of the real carrier")

	# F remains a risky long touch: it does not inherit the E reading beat.
	carrier.dribble_burst_seconds = 0.0
	carrier.dribble_cooldown_seconds = 0.0
	assert(carrier.start_dribble(Vector2.RIGHT, "burst"))
	assert(game._ai_xi_dribble_tackle_read_ready(carrier))
	assert(game._ai_xi_tackle_commit_ready(presser, carrier, false))
	# Easy and legacy 5v5 keep their previous decision timing.
	game._set_quick_difficulty("easy")
	carrier.dribble_burst_seconds = 0.0
	carrier.dribble_cooldown_seconds = 0.0
	assert(carrier.start_dribble(Vector2.RIGHT, "cut"))
	assert(game._ai_xi_dribble_tackle_read_ready(carrier))
	assert(game._ai_xi_tackle_commit_ready(presser, carrier, false))

	# If an opponent already committed a legal front tackle when E started,
	# physical contact still wins: no carrier immunity or fake possession.
	game._set_quick_difficulty("normal")
	carrier.dribble_burst_seconds = 0.0
	carrier.dribble_cooldown_seconds = 0.0
	assert(carrier.start_dribble(Vector2.RIGHT, "cut"))
	presser.global_position = centre + Vector2(35.0, 0.0)
	presser.velocity = Vector2.LEFT * presser.base_speed
	assert(presser.start_tackle())
	assert(not game._ai_xi_dribble_tackle_read_ready(carrier))
	assert(game._resolve_tackle_contact(presser, carrier))
	assert(game.ball.carrier == null, "Committed tackle must still dislodge carrier")
	game.match_team_size = 5
	assert(game._ai_xi_dribble_tackle_read_ready(carrier))
	# E has a real stamina-paid running follow-through. Otherwise a human
	# drops to 1.0x speed when E ends and the ordinary CPU 1.34x sprint
	# immediately catches them again, even after an earned lateral separation.
	game.match_team_size = 11
	carrier.global_position = centre
	carrier.velocity = Vector2.RIGHT * carrier.base_speed
	carrier.contact_stun_seconds = 0.0
	carrier.tackle_recovery_seconds = 0.0
	carrier.action_lock_seconds = 0.0
	carrier.dribble_cooldown_seconds = 0.0
	carrier.dribble_burst_seconds = 0.0
	carrier.stamina = carrier.STAMINA_MAX
	carrier.sprint_exhausted = false
	game.ball.attach_to(carrier)
	assert(carrier.start_dribble(Vector2.RIGHT, "cut"))
	assert(carrier.xi_cut_exit_run_seconds > carrier.dribble_duration_seconds)
	carrier.dribble_burst_seconds = 0.0
	carrier.xi_cut_exit_run_seconds = 0.26
	var stamina_before: float = carrier.stamina
	await physics_frame
	carrier.move_human(1.0 / 60.0, Vector2.RIGHT, false)
	assert(carrier.last_sprinting, "The E exit must use genuine normal sprint")
	assert(carrier.stamina < stamina_before, "E exit must spend sprint stamina")
	assert(carrier.velocity.length() > carrier.base_speed + 10.0)
	assert(carrier.velocity.length() < carrier.base_speed * carrier.SPRINT_SPEED_MULTIPLIER + 1.0)
	# Do not only check the first acceleration tick: technique must not
	# amplify the follow-through above ordinary sprint at steady speed.
	for tick in range(10):
		await physics_frame
		carrier.move_human(1.0 / 60.0, Vector2.RIGHT, false)
		assert(carrier.velocity.length() <= carrier.base_speed * carrier.SPRINT_SPEED_MULTIPLIER + 1.0)
		carrier._process(1.0 / 60.0)
	carrier.xi_cut_exit_run_seconds = 0.0
	await physics_frame
	carrier.move_human(1.0 / 60.0, Vector2.RIGHT, false)
	assert(not carrier.last_sprinting, "The E follow-through must expire")
	# Stealing or releasing the ball cancels the exit immediately.
	carrier.xi_cut_exit_run_seconds = 0.25
	game.ball.release(Vector2.RIGHT, 40.0)
	carrier.move_human(1.0 / 60.0, Vector2.RIGHT, false)
	assert(carrier.xi_cut_exit_run_seconds == 0.0)
	# Neither F nor legacy 5v5 inherit the special E follow-through.
	game.ball.attach_to(carrier)
	carrier.dribble_cooldown_seconds = 0.0
	carrier.action_lock_seconds = 0.0
	assert(carrier.start_dribble(Vector2.RIGHT, "burst"))
	assert(carrier.xi_cut_exit_run_seconds == 0.0)
	carrier.dribble_burst_seconds = 0.0
	carrier.dribble_cooldown_seconds = 0.0
	carrier.match_pitch = ChessFootballMath.PITCH_RECT
	assert(carrier.start_dribble(Vector2.RIGHT, "cut"))
	assert(carrier.xi_cut_exit_run_seconds == 0.0)
	print("FOOTBALL_XI_CUT_SPRINT_EXIT_OK stamina_paid=1 capped=1 no_immunity=1 legacy_unchanged=1")
	print("FOOTBALL_XI_MID_POSSESSION_DRIBBLE_READ_OK")
	quit(0)
