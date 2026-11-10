extends SceneTree

# Real XI actors and authoritative physical tackle path, not input mocks.
# XI: E feints/cuts, F makes a long touch with possession or slides in defense.
# Shift remains sprint ONLY. No double tap or animation/physics shortcuts.
func _reset_dribble(player: Footballer) -> void:
	player.dribble_burst_seconds = 0.0
	player.dribble_cooldown_seconds = 0.0
	player.action_lock_seconds = 0.0
	player.velocity = Vector2.ZERO


func _reset_tackle(player: Footballer) -> void:
	player.tackle_active_seconds = 0.0
	player.tackle_cooldown_seconds = 0.0
	player.tackle_recovery_seconds = 0.0
	player.tackle_aggressive = false
	player.action_lock_seconds = 0.0
	player.velocity = Vector2.RIGHT * player.base_speed


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

	assert(InputMap.has_action("special_move"))
	var mapped := InputMap.action_get_events("special_move")
	assert(mapped.size() == 1 and mapped[0] is InputEventKey)
	assert(mapped[0].physical_keycode == KEY_F)

	var carrier: Footballer = game.teams[0][10]
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	carrier.velocity = Vector2.ZERO
	var initial_score: Array = game.score.duplicate()
	var initial_home: Vector2 = carrier.global_position

	# Stationary E: feint; moving E: cut, even if Shift is held.
	# F: long touch independently of sprint; all retain real ball possession.
	game._handle_contextual_e(Vector2.ZERO, false)
	assert(game.action_feedback_text == "AMAGO")
	assert(carrier.dribble_mode == "feint")
	assert(is_equal_approx(carrier.dribble_duration_seconds, carrier.DRIBBLE_FEINT_SECONDS))
	assert(is_equal_approx(carrier.dribble_touch_distance, carrier.DRIBBLE_FEINT_TOUCH))
	assert(game.ball.carrier == carrier)
	_reset_dribble(carrier)
	game._handle_contextual_e(Vector2.UP, false)
	assert(game.action_feedback_text == "RECORTE")
	assert(carrier.dribble_mode == "cut")
	assert(carrier.dribble_direction.is_equal_approx(Vector2.UP))
	assert(is_equal_approx(carrier.dribble_touch_distance, carrier.DRIBBLE_TOUCH_DISTANCE))
	_reset_dribble(carrier)
	game._handle_contextual_e(Vector2.RIGHT, true)
	assert(carrier.dribble_mode == "cut", "Shift cannot turn E into a long touch")
	_reset_dribble(carrier)
	game._handle_contextual_special(Vector2.RIGHT)
	assert(carrier.dribble_mode == "burst")
	assert(carrier.dribble_duration_seconds > carrier.DRIBBLE_BURST_SECONDS)
	assert(carrier.dribble_touch_distance > carrier.DRIBBLE_TOUCH_DISTANCE)
	assert(game.action_feedback_text == "TOQUE LARGO")
	assert(game.ball.carrier == carrier)
	assert(game.score == initial_score and carrier.global_position == initial_home)
	_reset_dribble(carrier)

	# Technique improves recovery, but never grants a guaranteed tackle
	# evasion, a ghost ball, or a random skill-success result.
	carrier.scouting_technique = 75
	assert(carrier.start_dribble(Vector2.RIGHT))
	var neutral_cooldown := carrier.dribble_cooldown_seconds
	assert(is_equal_approx(neutral_cooldown, carrier.DRIBBLE_COOLDOWN_SECONDS))
	_reset_dribble(carrier)
	carrier.scouting_technique = 99
	assert(carrier.start_dribble(Vector2.RIGHT))
	var expert_cooldown := carrier.dribble_cooldown_seconds
	_reset_dribble(carrier)
	carrier.scouting_technique = 30
	assert(carrier.start_dribble(Vector2.RIGHT))
	var novice_cooldown := carrier.dribble_cooldown_seconds
	assert(expert_cooldown < neutral_cooldown and neutral_cooldown < novice_cooldown)
	assert(novice_cooldown <= neutral_cooldown * 1.18 + 0.0001)
	_reset_dribble(carrier)

	var defender: Footballer = game.teams[0][3]
	var victim: Footballer = game.teams[1][4]
	var center: Vector2 = game.match_pitch.get_center()
	defender.global_position = center
	victim.global_position = center + Vector2(83, 0)
	game.ball.attach_to(victim)
	game._select_player(defender)
	_reset_tackle(defender)

	# E alone never slides, even on a rapid second E. The first tackle
	# animates immediately; cooldown stops repeat hits while locked.
	game._handle_contextual_e(Vector2.ZERO, false)
	assert(defender.visual.animation == &"tackle")
	assert(not defender.tackle_aggressive_active())
	assert(defender.tackle_cooldown_seconds > 0.0)
	game._handle_contextual_e(Vector2.ZERO, false)
	assert(defender.visual.animation == &"tackle")
	assert(not defender.tackle_aggressive)
	assert(game.score == initial_score)

	# Shift+E must stay an ordinary tackle; dedicated F slides.
	_reset_tackle(defender)
	victim.global_position = center + Vector2(83, 0)
	game.ball.attach_to(victim)
	game._handle_contextual_e(Vector2.ZERO, true)
	assert(defender.visual.animation == &"tackle")
	assert(not defender.tackle_aggressive_active())
	_reset_tackle(defender)
	victim.global_position = center + Vector2(108, 0)
	game.ball.attach_to(victim)
	game._handle_contextual_special(Vector2.ZERO)
	assert(defender.visual.animation == &"slide_tackle")
	assert(defender.tackle_aggressive_active())
	assert(game.action_feedback_text == "SEGADA")
	assert(defender.tackle_recovery_seconds >= 0.68)
	assert(game.score == initial_score)

	# Contact only follows the actual physical standing hitbox; no
	# automatic ball theft from holding E or pressing it twice.
	_reset_tackle(defender)
	defender.global_position = center
	victim.global_position = center + Vector2(26, 0)
	game.ball.attach_to(victim)
	game._handle_contextual_e(Vector2.ZERO, false)
	assert(defender.visual.animation == &"tackle")
	assert(not defender.tackle_aggressive)
	assert(game.ball.carrier == null)
	assert(game.score == initial_score)

	# Switching players cannot leave a pending gesture behind.
	_reset_tackle(defender)
	game.pending_tackle_player = null
	game.pending_tackle_seconds = 0.0
	victim.global_position = center + Vector2(83, 0)
	game.ball.attach_to(victim)
	var substitute: Footballer = game.teams[0][2]
	game._select_player(substitute)
	game._select_player(defender)
	game._handle_contextual_e(Vector2.ZERO, false)
	assert(defender.visual.animation == &"tackle")
	assert(not defender.tackle_aggressive)
	assert(game.score == initial_score)

	print("FOOTBALL_CONTEXTUAL_E_OK feint_cut_burst=1 technique=1 E_standing=1 repeated_E_no_slide=1 F_slide=1 shift_E_normal=1 physical_contact=1 score_isolated=1")
	quit(0)
