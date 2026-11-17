extends SceneTree

# Real 60 Hz XI human E cut against a physical defender -> one earned
# forward overlap. It must never trigger on empty grass, standing feints,
# a lost ball, unsafe lanes or legacy 5v5. Normal sprint and pass physics.
const Formation = preload("res://scripts/football_match_formation.gd")
const DT := 1.0 / 60.0

func _reset_cut(player: Footballer) -> void:
	player.dribble_cooldown_seconds = 0.0
	player.dribble_burst_seconds = 0.0
	player.action_lock_seconds = 0.0
	player.contact_stun_seconds = 0.0
	player.tackle_recovery_seconds = 0.0


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
	var centre: Vector2 = game.match_pitch.get_center()
	for team in game.teams:
		for athlete: Footballer in team:
			athlete.set_process(false)
			athlete.set_physics_process(false)
			athlete.global_position = Vector2(
				-500.0 if athlete.team_id == 0 else 3200.0,
				-380.0 + float(athlete.squad_index) * 180.0
			)
			athlete.velocity = Vector2.ZERO
	var carrier: Footballer = game.teams[0][10]
	var lead: Footballer = game.teams[0][5]
	var recycle: Footballer = game.teams[0][6]
	var marker: Footballer = game.teams[1][5]
	carrier.global_position = centre
	carrier.velocity = Vector2.RIGHT * carrier.base_speed
	lead.global_position = centre + Vector2(-165.0, 90.0)
	recycle.global_position = centre + Vector2(-270.0, -105.0)
	marker.global_position = centre + Vector2(85.0, 0.0)
	marker.tackle_cooldown_seconds = 99.0
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	assert(game._ai_xi_human_support_rank(lead) == 0)
	assert(game._ai_xi_human_support_rank(recycle) == 1)

	# Only a real cut with a defender ahead can arm a challenge.
	assert(game._try_dribble(Vector2.RIGHT))
	assert(carrier.dribble_mode == "cut")
	assert(game.xi_cut_duel_owner == carrier)
	assert(game.xi_cut_duel_defender == marker)
	assert(game.xi_breakaway_runner == null)
	# Physical movement through the game's real 2D CharacterBody2D, NOT
	# moving the actor to a fictitious win coordinate.
	var start: Vector2 = carrier.global_position
	var won := false
	for frame in range(72):
		await physics_frame
		var previous: Vector2 = carrier.global_position
		game.match_seconds += DT
		carrier.move_human(DT, Vector2.RIGHT, false)
		game.ball.tick_ball(DT)
		game._update_xi_cut_duel_followthrough()
		assert(carrier.global_position.distance_to(previous) < 13.0)
		assert(carrier.velocity.length() <= carrier.base_speed * 1.35 + 3.0)
		assert(game.match_pitch.has_point(carrier.global_position))
		assert(game.ball.carrier == carrier)
		carrier._process(DT)
		if game.xi_breakaway_runner != null:
			won = true
			break
	assert(won, "Real lateral cut must move past the actual defender before followthrough")
	assert(carrier.global_position.x > marker.global_position.x + 20.0)
	assert(absf(carrier.global_position.y - marker.global_position.y) > 58.0)
	assert(carrier.global_position.x - start.x > 85.0)
	assert(game.xi_breakaway_runner == lead)
	assert(game.xi_breakaway_owner == carrier)
	assert(game.ai_xi_human_support_slots[0] == lead)
	assert(game.ai_xi_human_support_slots[1] == recycle)
	assert(game.action_feedback_text == "¡REGATE GANADO! · DESMARQUE")
	var run_target: Vector2 = game.xi_breakaway_target
	assert(game.match_pitch.has_point(run_target))
	assert(run_target.x > carrier.global_position.x + 300.0)
	assert(game._ai_xi_human_lane_clearance(run_target) >= game.XI_CUT_BREAKAWAY_CLEARANCE)
	assert(run_target.distance_to(carrier.global_position) < game.AI_XI_PASS_MAX_DISTANCE)
	assert(game._ai_support_target(lead) == run_target)

	# THE SAME real runner now sprints, paying stamina and traversing
	# physical space. The recycle runner and far defenders keep their lanes.
	var lead_start: Vector2 = lead.global_position
	var stamina_start: float = lead.stamina
	await physics_frame
	game._update_ai(DT)
	assert(lead.last_sprinting)
	assert(lead.global_position.distance_to(lead_start) < 14.0)
	assert(lead.velocity.length() <= lead.base_speed * lead.SPRINT_SPEED_MULTIPLIER + 3.0)
	for step in range(24):
		await physics_frame
		game._update_ai(DT)
		lead._process(DT)
		recycle._process(DT)
	assert(lead.global_position.distance_to(run_target) <
		lead_start.distance_to(run_target) - 20.0)
	assert(lead.stamina < stamina_start, "Breakaway uses ordinary draining sprint")
	assert(game.ai_xi_human_support_slots[0] == lead)
	assert(game.ai_xi_human_support_slots[1] == recycle)
	assert(game.ball.carrier == carrier and game.controlled == carrier)

	# Intentionally aim the EXISTING real charged pass toward the forward
	# runner. No fabricated pass completion, homing, teleport or auto-goal.
	var toward_runner: Vector2 = lead.global_position - carrier.global_position
	assert(toward_runner.length() > 1.0)
	game._begin_directional_pass_charge(toward_runner.normalized())
	assert(game.pass_target == lead)
	game.pass_charge_seconds = game.PASS_CHARGE_SECONDS * 0.78
	assert(game._release_charged_pass())
	assert(game.ball.carrier == null)
	assert(game.ball.velocity.length() > 500.0)
	assert(game.pending_human_pass_receiver == lead)
	assert(lead.global_position.distance_to(run_target) > 1.0)
	assert(game.ball.carrier != lead, "Receiver must physically win the pass later")
	game._update_xi_cut_duel_followthrough()
	assert(game.xi_breakaway_runner == null)

	# Fresh E while no marker ahead cannot secretly grant a runner.
	_reset_cut(carrier)
	carrier.global_position = centre
	carrier.velocity = Vector2.RIGHT * carrier.base_speed
	marker.global_position = centre + Vector2(-260.0, 0.0)
	game.ball.attach_to(carrier)
	assert(game._try_dribble(Vector2.RIGHT))
	assert(game.xi_cut_duel_owner == null)
	assert(game.xi_breakaway_runner == null)
	# Stationary feints never count as beating a defender.
	_reset_cut(carrier)
	carrier.velocity = Vector2.ZERO
	marker.global_position = centre + Vector2(80.0, 0.0)
	assert(game._try_dribble(Vector2.ZERO))
	assert(carrier.dribble_mode == "feint")
	assert(game.xi_cut_duel_owner == null)

	# An armed cut whose carrier loses the ball must immediately expire.
	_reset_cut(carrier)
	carrier.velocity = Vector2.RIGHT * carrier.base_speed
	assert(game._try_dribble(Vector2.RIGHT))
	assert(game.xi_cut_duel_owner == carrier)
	game.ball.release(Vector2.RIGHT, 320.0)
	game._update_xi_cut_duel_followthrough()
	assert(game.xi_cut_duel_owner == null)
	assert(game.xi_breakaway_runner == null)
	# A complete physical break past a defender, but BOTH forward passing
	# corridors are marked, must not manufacture an overlap.
	game.ball.attach_to(carrier)
	_reset_cut(carrier)
	carrier.global_position = centre
	carrier.velocity = Vector2.RIGHT * carrier.base_speed
	marker.global_position = centre + Vector2(80.0, 0.0)
	assert(game._try_dribble(Vector2.RIGHT))
	assert(game.xi_cut_duel_owner == carrier)
	var other: Footballer = game.teams[1][6]
	# This time validate the explicit decision without teleporting the
	# carrier through a rival: move the defender behind the runner after
	# physically traversing the same 60 Hz human cut.
	for frame in range(70):
		await physics_frame
		game.match_seconds += DT
		carrier.move_human(DT, Vector2.RIGHT, false)
		carrier._process(DT)
		game.ball.tick_ball(DT)
		# A moving defensive line can close both 325x190 through-pass
		# options without ever interfering with the dribbler's body.
		other.global_position = carrier.global_position + Vector2(325.0, 190.0)
		game.teams[1][7].global_position = carrier.global_position + Vector2(325.0, -190.0)
		game._update_xi_cut_duel_followthrough()
		if game.xi_cut_duel_owner == null:
			break
	assert(game.xi_breakaway_runner == null)
	assert(game.xi_cut_duel_owner == null)

	# CPU never gets a human-specific prize and the 5v5 remains exact.
	game.ball.attach_to(game.teams[1][10])
	_reset_cut(carrier)
	game._arm_xi_cut_duel(carrier)
	assert(game.xi_cut_duel_owner == null)
	game.ball.attach_to(carrier)
	game.match_team_size = 5
	_reset_cut(carrier)
	assert(game._try_dribble(Vector2.RIGHT))
	assert(game.xi_cut_duel_owner == null and game.xi_breakaway_runner == null)

	print("FOOTBALL_XI_EARNED_BREAKAWAY_OK real_cut=true physical_outplay=true two_roles=true normal_sprint=true real_pass=true empty_grass=false feint=false lost_ball=false blocked_lane=false legacy_5v5=true")
	quit(0)
