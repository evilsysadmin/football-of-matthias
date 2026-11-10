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
	assert(is_equal_approx(carrier.dribble_duration_seconds, carrier.XI_DRIBBLE_FEINT_SECONDS))
	# The longer visual beat must not grant extra forward distance: this
	# speed×window proxy differs by less than two percent from 5v5.
	var legacy_footprint: float = carrier.DRIBBLE_FEINT_SECONDS * carrier.DRIBBLE_FEINT_SPEED
	var xi_footprint: float = carrier.XI_DRIBBLE_FEINT_SECONDS * carrier.XI_DRIBBLE_FEINT_SPEED
	assert(absf(xi_footprint - legacy_footprint) < 0.004)
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

	# Exercise the actual XI keyboard action through the same human input
	# path used by Chromium (not just the direct decision helper).
	game.ball.attach_to(carrier)
	_reset_dribble(carrier)
	Input.action_press("special_move")
	game._handle_human(1.0 / 60.0)
	Input.action_release("special_move")
	assert(carrier.dribble_mode == "burst", "F did not reach the real XI player")
	assert(game.action_feedback_text == "TOQUE LARGO")
	_reset_dribble(carrier)

	# Front/diagonal run atlases cannot use a sideways dribble pose.
	# The presenter must still show a grounded, visible body pivot during
	# an ACTUAL legal dribble, without moving the gameplay actor or its ball.
	var stage: ChessFootball3DPresenter = game.presentation_3d
	var key: int = carrier.get_instance_id()
	var actor_sprite: AnimatedSprite3D = stage.player_sprites[key]
	var actor_proxy: Node3D = stage.player_nodes[key]
	assert(actor_sprite.sprite_frames.has_animation(&"run_front"))
	actor_sprite.play(&"run_front")
	actor_sprite.pause()
	carrier.velocity = Vector2.UP * carrier.base_speed
	stage._sync_player_secondary_motion(carrier, actor_sprite, actor_proxy)
	var resting_tilt: float = actor_sprite.rotation.z
	var physical_point: Vector2 = carrier.global_position
	assert(carrier.start_dribble(Vector2.UP, "cut"))
	carrier.dribble_burst_seconds = carrier.dribble_duration_seconds * 0.5
	stage._sync_player_secondary_motion(carrier, actor_sprite, actor_proxy)
	assert(absf(actor_sprite.rotation.z - resting_tilt) > deg_to_rad(3.0))
	assert(carrier.global_position == physical_point)
	assert(game.ball.carrier == carrier)
	_reset_dribble(carrier)

	# A fake must genuinely sell one side, then counter-lean to the other.
	# The output blends to neutral at both ends and is driven by the
	# AUTHORITATIVE (unmodified) dribble countdown, not a new fake clock.
	var first_step := stage.xi_dribble_fallback_footwork("feint", 0.25)
	var second_step := stage.xi_dribble_fallback_footwork("feint", 0.75)
	assert(first_step.x > 0.06 and first_step.y > 10.0)
	assert(second_step.x < -0.06 and second_step.y < -10.0)
	assert(absf(first_step.x + second_step.x) < 0.001)
	for kind in ["feint", "cut", "burst"]:
		assert(stage.xi_dribble_fallback_footwork(kind, 0.0).is_equal_approx(Vector3(0, 0, 1)))
		assert(stage.xi_dribble_fallback_footwork(kind, 1.0).is_equal_approx(Vector3(0, 0, 1)))
		var middle: Vector3 = stage.xi_dribble_fallback_footwork(kind, 0.5)
		assert(middle.z >= 0.94 and middle.z <= 1.0)
		if kind != "feint":
			assert(middle.x > 0.08 and middle.y >= 14.0)
	assert(carrier.start_dribble(Vector2.UP, "feint"))
	carrier.dribble_burst_seconds = carrier.dribble_duration_seconds * 0.75
	stage._sync_player_secondary_motion(carrier, actor_sprite, actor_proxy)
	var fake_first_tilt := actor_sprite.rotation.z
	carrier.dribble_burst_seconds = carrier.dribble_duration_seconds * 0.25
	stage._sync_player_secondary_motion(carrier, actor_sprite, actor_proxy)
	var fake_second_tilt := actor_sprite.rotation.z
	# A UP-facing dribble reverses the sign of the lean: assert the two
	# opposed beats, not an arbitrary world-space direction.
	assert(absf(fake_first_tilt - fake_second_tilt) > deg_to_rad(20.0),
		"Front-view feint must visibly reverse shoulder direction")
	assert(carrier.global_position == physical_point and game.ball.carrier == carrier)
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

	# The longer two-beat action is XI-only; the legacy five-a-side feint
	# retains its exact old window and speed profile.
	var historical = packed.instantiate()
	historical.match_team_size = 5
	root.add_child(historical)
	await process_frame
	await process_frame
	historical.set_process(false)
	historical.set_physics_process(false)
	historical.kickoff_active = false
	var legacy_actor: Footballer = historical.teams[0][2]
	historical._select_player(legacy_actor)
	historical.ball.attach_to(legacy_actor)
	legacy_actor.velocity = Vector2.ZERO
	historical._handle_contextual_e(Vector2.ZERO, false)
	assert(legacy_actor.dribble_mode == "feint")
	assert(is_equal_approx(legacy_actor.dribble_duration_seconds, 0.16))
	assert(is_equal_approx(legacy_actor.DRIBBLE_FEINT_SPEED, 0.65))
	assert(historical.ball.carrier == legacy_actor)

	print("FOOTBALL_CONTEXTUAL_E_OK feint_cut_burst=1 technique=1 E_standing=1 repeated_E_no_slide=1 F_slide=1 shift_E_normal=1 physical_contact=1 score_isolated=1")
	quit(0)
