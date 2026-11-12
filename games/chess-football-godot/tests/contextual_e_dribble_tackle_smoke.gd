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
	# The actual on-screen hint must explain what E does at the moment
	# it is pressed. XI stationary E feints, moving E cuts; the previous
	# generic "amago/recorte" hid this important difference.
	var desktop_hint: String = game.contextual_help_text(false)
	assert(desktop_hint.contains("E quieto: amago"))
	assert(desktop_hint.contains("E en marcha: recorte"))
	assert(desktop_hint.contains("F toque largo"))
	var touch_hint: String = game.contextual_help_text(true)
	assert(touch_hint.contains("césped libre: regate"))
	assert(not touch_hint.contains("E quieto"))
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
	assert(carrier.dribble_direction.dot(Vector2.UP) > 0.79,
		"Moving axial E must retain forward agency")
	assert(absf(carrier.dribble_direction.x) > 0.35,
		"Moving axial E must actually cut sideways, not run straight")
	assert(is_equal_approx(carrier.dribble_duration_seconds, carrier.XI_DRIBBLE_CUT_SECONDS))
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

	# One physical clock: disable the actors' automatic processing before
	# manually stepping the next 21 60 Hz frames.
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
			actor.set_physics_process(false)

	# Exercise MOVING E with real 60 Hz CharacterBody2D movement. A rival
	# just below the running lane forces a deterministic safe-side cut.
	# First plant remains forward, middle beat crosses the lane, final beat
	# exits with a pace BELOW the ordinary sprint. No ghost-ball or free steal.
	carrier.global_position = game.match_pitch.get_center()
	for rival in game.teams[1]:
		rival.global_position = game.match_pitch.position + Vector2(60.0, 60.0)
	var approaching_rival: Footballer = game.teams[1][5]
	approaching_rival.global_position = carrier.global_position + Vector2(140.0, 70.0)
	game.ball.attach_to(carrier)
	_reset_dribble(carrier)
	carrier.velocity = Vector2.RIGHT * carrier.base_speed
	game._handle_contextual_e(Vector2.RIGHT, false)
	assert(carrier.dribble_mode == "cut")
	assert(carrier.dribble_direction.y < -0.63,
		"Axial E must commit to a readable diagonal AWAY from the defender")
	assert(carrier.dribble_entry_direction.dot(Vector2.RIGHT) > 0.99)
	assert(is_equal_approx(carrier.dribble_duration_seconds, carrier.XI_DRIBBLE_CUT_SECONDS))
	assert(carrier._xi_cut_speed_multiplier() < 0.9)
	var cut_origin: Vector2 = carrier.global_position
	var early_speed := 0.0
	var middle_speed := 0.0
	var exit_speed := 0.0
	var early_lateral := 0.0
	var middle_lateral := 0.0
	for frame in range(21):
		await physics_frame
		carrier.move_human(1.0 / 60.0, Vector2.RIGHT, false)
		game.ball.tick_ball(1.0 / 60.0)
		if frame == 2:
			early_speed = carrier.velocity.length()
			early_lateral = absf(carrier.velocity.y)
		elif frame == 10:
			middle_speed = carrier.velocity.length()
			middle_lateral = absf(carrier.velocity.y)
		elif frame == 18:
			exit_speed = carrier.velocity.length()
		assert(carrier.velocity.length() <= carrier.base_speed *
			carrier.technique_control_multiplier * 1.25 + 1.0,
			"E cut cannot become the old 1.52x sprint")
		assert(game.ball.carrier == carrier)
		carrier._process(1.0 / 60.0)
	assert(middle_lateral > early_lateral + 20.0,
		"The real mid-cut must change lateral velocity after the foot plant")
	assert(middle_speed > early_speed and exit_speed > middle_speed,
		"Planted step, lateral touch and exit need three distinct physical beats")
	assert(carrier.global_position.y < cut_origin.y - 25.0,
		"E must cross at least a boot-width of real lateral lane, not only accelerate")
	assert(carrier.dribble_burst_seconds <= 0.0)
	assert(game.score == initial_score)
	print("FOOTBALL_XI_MOVING_E_THREE_BEATS_OK sideways=1 no_sprint=1 actual_60hz=1")
	carrier.global_position = initial_home
	game.ball.attach_to(carrier)
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
		assert(middle.z >= 0.93 and middle.z <= 1.0)
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

	# The visual ball travels ACROSS the other foot during a feint. The
	# ball's actual 2D position, possession and physical touch stay unchanged.
	var real_ball_position: Vector2 = game.ball.global_position
	var fake_ball_first := stage.xi_dribble_visual_ball_offset("feint", 0.25, Vector2.UP)
	var fake_ball_second := stage.xi_dribble_visual_ball_offset("feint", 0.75, Vector2.UP)
	assert(fake_ball_first.x > 0.04 and fake_ball_second.x < -0.15)
	assert(absf(fake_ball_first.x - fake_ball_second.x) > 0.20)
	assert(stage.xi_dribble_visual_ball_offset("feint", 0.0, Vector2.UP) == Vector3.ZERO)
	assert(stage.xi_dribble_visual_ball_offset("feint", 1.0, Vector2.UP).length() < 0.0001)
	assert(stage.xi_dribble_visual_ball_offset("cut", 0.5, Vector2.UP).length() < 0.35)
	assert(stage.xi_dribble_visual_ball_offset("burst", 0.5, Vector2.UP).length() < 0.35)
	assert(stage.xi_dribble_visual_ball_offset("feint", 0.75, Vector2.ZERO) == Vector3.ZERO)
	assert(game.ball.global_position == real_ball_position and game.ball.carrier == carrier)
	# Different original leg silhouettes should sell each of the two false
	# steps in 8-frame fallbacks and 12-frame verified V3 run sheets.
	for count in [8, 12]:
		var first_pose: float = stage.xi_front_feint_foot_pose(count, 0.25)
		var counter_pose: float = stage.xi_front_feint_foot_pose(count, 0.75)
		assert(first_pose >= 2.0 and counter_pose - first_pose >= 4.0)
		assert(counter_pose < count)

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
	assert(historical.contextual_help_text(false).contains("E regate/entrada"))
	assert(not historical.contextual_help_text(false).contains("E quieto"))

	print("FOOTBALL_CONTEXTUAL_E_OK feint_cut_burst=1 technique=1 E_standing=1 repeated_E_no_slide=1 F_slide=1 shift_E_normal=1 physical_contact=1 score_isolated=1")
	quit(0)
