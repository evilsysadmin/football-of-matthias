extends SceneTree

# Use REAL XI Footballer instances, the match's E handler and the physical
# tackle path. No mock players, invented success rolls or altered career data.
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
	player.tackle_contact_resolved = false
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

	var carrier: Footballer = game.teams[0][10]
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	carrier.velocity = Vector2.ZERO
	var initial_score := game.score.duplicate()
	var initial_home: Vector2 = carrier.global_position

	# A stationary E is a short feint, direction+E is a cut, sprint+E
	# commits to a longer touch. All keep the authoritative ball attached.
	assert(game._try_dribble(Vector2.ZERO))
	assert(carrier.dribble_mode == "feint")
	assert(is_equal_approx(carrier.dribble_duration_seconds, carrier.DRIBBLE_FEINT_SECONDS))
	assert(is_equal_approx(carrier.dribble_touch_distance, carrier.DRIBBLE_FEINT_TOUCH))
	assert(game.ball.carrier == carrier)
	_reset_dribble(carrier)
	assert(game._try_dribble(Vector2.UP))
	assert(carrier.dribble_mode == "cut")
	assert(carrier.dribble_direction.is_equal_approx(Vector2.UP))
	assert(is_equal_approx(carrier.dribble_touch_distance, carrier.DRIBBLE_TOUCH_DISTANCE))
	_reset_dribble(carrier)
	assert(game._try_dribble(Vector2.RIGHT, true))
	assert(carrier.dribble_mode == "burst")
	assert(carrier.dribble_duration_seconds > carrier.DRIBBLE_BURST_SECONDS)
	assert(carrier.dribble_touch_distance > carrier.DRIBBLE_TOUCH_DISTANCE)
	assert(game.ball.carrier == carrier)
	assert(game.score == initial_score)
	assert(carrier.global_position == initial_home)
	_reset_dribble(carrier)

	# No roulette: better technique gives shorter recovery; all modes
	# remain bounded and the neutral rating retains the old cut cooldown.
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
	game.match_seconds = 10.0
	game._press_contextual_tackle(false)
	assert(defender.visual.animation == &"tackle")
	assert(not defender.tackle_aggressive)
	assert(not defender.tackle_contact_resolved)
	assert(defender.tackle_cooldown_seconds > 0.0)
	# Second E upgrades the unfinished standing tackle without a 300ms
	# delay on the first press. The already-live ball path still decides hit.
	game.match_seconds = 10.15
	game._press_contextual_tackle(false)
	assert(defender.visual.animation == &"slide_tackle")
	assert(defender.tackle_aggressive_active())
	assert(defender.tackle_recovery_seconds >= 0.68)
	assert(game.score == initial_score)

	# No repeated E means no surprise slide. Shift+E remains immediate
	# and does not require a previous standing attempt.
	_reset_tackle(defender)
	game.last_e_tackle_player = null
	game.match_seconds = 12.0
	game._press_contextual_tackle(false)
	assert(defender.visual.animation == &"tackle")
	_reset_tackle(defender)
	game.match_seconds = 13.0
	game._press_contextual_tackle(true)
	assert(defender.visual.animation == &"slide_tackle")

	# A real resolved contact is final: no retroactive reclassification as
	# a slide, even when a double tap comes during the same action.
	_reset_tackle(defender)
	game.last_e_tackle_player = null
	defender.global_position = center
	victim.global_position = center + Vector2(26, 0)
	game.ball.attach_to(victim)
	game.match_seconds = 16.0
	game._press_contextual_tackle(false)
	assert(defender.tackle_contact_resolved)
	assert(not defender.upgrade_standing_tackle_to_slide())
	assert(not defender.tackle_aggressive)
	assert(game.score == initial_score)

	# Switching controlled players discards any unfinished double tap.
	_reset_tackle(defender)
	game.ball.attach_to(victim)
	game.last_e_tackle_player = null
	victim.global_position = center + Vector2(83, 0)
	game.match_seconds = 20.0
	game._press_contextual_tackle(false)
	var substitute: Footballer = game.teams[0][2]
	game._select_player(substitute)
	game._select_player(defender)
	_reset_tackle(defender)
	game.match_seconds = 20.12
	game._press_contextual_tackle(false)
	assert(defender.visual.animation == &"tackle")
	assert(not defender.tackle_aggressive)
	print("FOOTBALL_CONTEXTUAL_E_OK feint_cut_burst=1 technique=1 double_tap=1 shift_slide=1 resolved_contact=1 switch_reset=1 score_isolated=1")
	quit(0)
