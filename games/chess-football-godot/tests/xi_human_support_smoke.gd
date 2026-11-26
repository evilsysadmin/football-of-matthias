extends SceneTree

# XI human teammates move to two playable triangle outlets instead of
# waiting at their static 4-3-3 homes. No auto-catch, speed bonus or teleports.
const Formation = preload("res://scripts/football_match_formation.gd")
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
	for team_id in range(2):
		for player: Footballer in game.teams[team_id]:
			player.set_process(false)
			player.set_physics_process(false)
			player.velocity = Vector2.ZERO
			player.global_position = Vector2(
				-540.0 if team_id == 0 else 3000.0,
				-365.0 + float(player.squad_index) * 186.0
			)
	var carrier: Footballer = game.teams[0][10]
	var lead: Footballer = game.teams[0][5]
	var recycle: Footballer = game.teams[0][6]
	var challenger: Footballer = game.teams[0][7]
	var rival_marker: Footballer = game.teams[1][3]
	var centre: Vector2 = game.match_pitch.get_center()
	carrier.global_position = centre
	lead.global_position = centre + Vector2(-205.0, 75.0)
	recycle.global_position = centre + Vector2(-260.0, -105.0)
	challenger.global_position = centre + Vector2(-630.0, 250.0)
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	game._ai_xi_refresh_human_support_assignment()
	assert(game._ai_xi_human_support_rank(lead, true) == 0)
	assert(game._ai_xi_human_support_rank(recycle) == 1)
	assert(game._ai_xi_human_support_rank(challenger) == -1)
	assert(game.ai_xi_human_support_slots[0] == lead)
	assert(game.ai_xi_human_support_slots[1] == recycle)
	# Compare repeated rank lookups with one shared assignment per batch.
	# Positions are fixed, both paths must return identical ranks. Timing
	# is informative only: shared runners and CI hosts vary in speed.
	var queries: Array = []
	for teammate: Footballer in game.teams[0]:
		if teammate != carrier and teammate.role != "keeper":
			queries.append(teammate)
	var expected_ranks: Array[int] = []
	for teammate: Footballer in queries:
		expected_ranks.append(game._ai_xi_human_support_rank(teammate))
	var batches := 200
	var direct_start := Time.get_ticks_usec()
	for batch in range(batches):
		for index in range(queries.size()):
			assert(game._ai_xi_human_support_rank(queries[index]) == expected_ranks[index])
	var direct_usec := Time.get_ticks_usec() - direct_start
	var shared_start := Time.get_ticks_usec()
	for batch in range(batches):
		game._ai_xi_refresh_human_support_assignment()
		for index in range(queries.size()):
			assert(game._ai_xi_human_support_rank(queries[index], true) == expected_ranks[index])
	var shared_usec := Time.get_ticks_usec() - shared_start
	print("FOOTBALL_XI_SUPPORT_ASSIGNMENT_PROFILE batches=", batches,
		" queries_per_batch=", queries.size(), " direct_usec=", direct_usec,
		" shared_usec=", shared_usec)
	var lead_base: Vector2 = game._ai_support_target(lead)
	var recycle_target: Vector2 = game._ai_support_target(recycle)
	assert(game.match_pitch.has_point(lead_base))
	assert(game.match_pitch.has_point(recycle_target))
	assert(lead_base.x > carrier.global_position.x + 160.0)
	assert(recycle_target.x < carrier.global_position.x - 120.0)
	assert(absf(lead_base.y - recycle_target.y) > 350.0,
		"XI human attack must present forward and opposite-side recycle runs")
	assert(lead_base.distance_to(carrier.global_position) < 350.0)
	assert(recycle_target.distance_to(carrier.global_position) < 350.0)
	assert(game.ball.carrier == carrier and game.controlled == carrier)

	# A small positional improvement cannot replace a support assignment
	# every frame. A sufficiently stronger runner can take over the second
	# outlet, while the first and the human carrier remain untouched.
	challenger.global_position = centre + Vector2(-260.0, 0.0)
	assert(game._ai_xi_human_support_rank(recycle) == 1)
	assert(game._ai_xi_human_support_rank(challenger) == -1)
	challenger.global_position = centre + Vector2(-190.0, 0.0)
	# During a single AI pass, queries share the pre-movement snapshot.
	# A later independent query must still see the improved challenger.
	assert(game._ai_xi_human_support_rank(recycle, true) == 1)
	assert(game._ai_xi_human_support_rank(challenger, true) == -1)
	assert(game._ai_xi_human_support_rank(lead) == 0)
	assert(game._ai_xi_human_support_rank(challenger) == 1)
	challenger.sent_off = true
	# Even within a snapshot an unavailable selected outlet is invalid.
	assert(game._ai_xi_human_support_rank(challenger, true) == -1)
	assert(game._ai_xi_human_support_rank(recycle, true) == 1)
	print("FOOTBALL_XI_SUPPORT_SNAPSHOT_OK shared=true refresh=true invalidation=true")
	challenger.sent_off = false
	challenger.global_position = centre + Vector2(-630.0, 250.0)

	# Generic teammate spacing can push an otherwise clear outlet into a
	# rival. Preserve as much safe separation as possible, not a teleport.
	var spacing_normal: Vector2 = (lead_base - centre).normalized().orthogonal()
	var challenger_start: Vector2 = challenger.global_position
	challenger.global_position = lead_base - spacing_normal * 25.0
	rival_marker.global_position = lead_base + spacing_normal * 160.0
	var raw_spaced: Vector2 = game._ai_spaced_target(lead, lead_base)
	var safe_spaced: Vector2 = game._ai_spaced_target(lead, lead_base, true)
	assert(game._ai_xi_human_lane_clearance(lead_base, true) >= game.AI_XI_HUMAN_LANE_SAFE)
	assert(game._ai_xi_human_lane_clearance(raw_spaced, true) < game.AI_XI_HUMAN_LANE_HOLD)
	assert(game._ai_xi_human_lane_clearance(safe_spaced, true) >= game.AI_XI_HUMAN_LANE_HOLD)
	assert(safe_spaced.distance_to(challenger.global_position) > lead_base.distance_to(challenger.global_position))
	assert(safe_spaced.distance_to(lead_base) < raw_spaced.distance_to(lead_base))
	assert(game.ball.carrier == carrier and game.controlled == carrier)
	print("FOOTBALL_XI_SPACING_LANE_OK raw=", game._ai_xi_human_lane_clearance(raw_spaced, true),
		" guarded=", game._ai_xi_human_lane_clearance(safe_spaced, true))
	# A remembered 105u lane remains viable even below the 110u
	# acquisition threshold. Spacing must not invalidate its hysteresis.
	rival_marker.global_position = lead_base + spacing_normal * 105.0
	var retained_gap: float = game._ai_xi_human_lane_clearance(lead_base, true)
	assert(retained_gap >= game.AI_XI_HUMAN_LANE_HOLD)
	assert(retained_gap < game.AI_XI_HUMAN_LANE_SAFE)
	assert(game._ai_xi_human_lane_clearance(game._ai_spaced_target(lead, lead_base, true), true) >= game.AI_XI_HUMAN_LANE_HOLD)
	# A genuinely contested lead lane keeps the ordinary spacing path.
	rival_marker.global_position = lead_base + spacing_normal * 70.0
	assert(game._ai_xi_human_lane_clearance(lead_base, true) < game.AI_XI_HUMAN_LANE_HOLD)
	assert(game._ai_spaced_target(lead, lead_base, true).is_equal_approx(raw_spaced))
	# No obstacle: apply the full separation instead of suppressing it.
	rival_marker.global_position = centre + Vector2(1450.0, 800.0)
	assert(game._ai_spaced_target(lead, lead_base, true).is_equal_approx(raw_spaced))
	challenger.global_position = challenger_start
	print("FOOTBALL_XI_SPACING_HYSTERESIS_OK retained=true contested_fallback=true clear_full=true")

	# A nearby teammate must not push the safety outlet into the centre
	# or too close to the carrier. Isolate spacing from role selection.
	var saved_positions: Dictionary = {}
	for teammate: Footballer in game.teams[0]:
		if teammate != carrier and teammate != recycle:
			saved_positions[teammate] = teammate.global_position
			teammate.global_position = centre + Vector2(900.0, 900.0)
	var safety_flank: float = signf(recycle_target.y - centre.y)
	var narrow_outlet: Vector2 = centre + Vector2(-150.0, safety_flank * 45.0)
	challenger.global_position = narrow_outlet + Vector2(-20.0, safety_flank * 20.0)
	var raw_recycle: Vector2 = game._ai_spaced_target(recycle, narrow_outlet)
	var guarded_recycle: Vector2 = game._ai_spaced_target(recycle, narrow_outlet, true)
	assert((raw_recycle.y - centre.y) * safety_flank < game.AI_XI_HUMAN_RECYCLE_MIN_WIDTH)
	assert((guarded_recycle.y - centre.y) * safety_flank >= game.AI_XI_HUMAN_RECYCLE_MIN_WIDTH)
	assert(centre.x - guarded_recycle.x >= game.AI_XI_HUMAN_RECYCLE_MIN_DEPTH)
	# An independent push directly toward the carrier tests depth alone.
	challenger.global_position = recycle_target - Vector2(20.0, 0.0)
	raw_recycle = game._ai_spaced_target(recycle, recycle_target)
	guarded_recycle = game._ai_spaced_target(recycle, recycle_target, true)
	assert(centre.x - raw_recycle.x < game.AI_XI_HUMAN_RECYCLE_MIN_DEPTH)
	assert(centre.x - guarded_recycle.x >= game.AI_XI_HUMAN_RECYCLE_MIN_DEPTH)
	assert(guarded_recycle.distance_to(challenger.global_position) > recycle_target.distance_to(challenger.global_position))
	for teammate: Footballer in saved_positions:
		teammate.global_position = saved_positions[teammate]
	print("FOOTBALL_XI_SPACING_RECYCLE_OK flank=true depth=true")

	# A rival blocking the LEAD's actual intended pass makes that runner
	# look for another reachable, defensible corridor. No invisible catch:
	# the defender remains on the pitch and can intercept any real pass.
	rival_marker.global_position = lead_base
	assert(game._ai_xi_human_lane_clearance(lead_base) < 1.0)
	var open_lane: Vector2 = game._ai_support_target(lead)
	assert(game.match_pitch.has_point(open_lane))
	assert(open_lane != lead_base and open_lane.x > lead_base.x + 50.0)
	assert(absf(open_lane.y - lead_base.y) >= 130.0)
	assert(game._ai_xi_human_lane_clearance(open_lane) >= game.AI_XI_HUMAN_LANE_SAFE)
	var remembered_id: int = int(lead.get_instance_id())
	assert(game.ai_xi_human_lane_memory.has(remembered_id))
	var side: float = signf(open_lane.y - lead_base.y)
	rival_marker.global_position = lead_base + Vector2(0.0, side * 9.0)
	assert(game._ai_support_target(lead) == open_lane,
		"A marker wobble must not flip the receiving runner every physics frame")
	rival_marker.global_position = open_lane
	assert(game._ai_support_target(lead) != open_lane,
		"An actually blocked remembered lane cannot remain protected")
	rival_marker.global_position = centre + Vector2(1450.0, 800.0)
	assert(game._ai_support_target(lead) == lead_base)
	assert(game.ai_xi_human_lane_memory.is_empty())

	# The lead outlet can read a defender already crossing a clear lane.
	# Same initial position, opposite observed velocities; no future input.
	var normal: Vector2 = (lead_base - centre).normalized().orthogonal()
	rival_marker.global_position = centre.lerp(lead_base, 0.6) + normal * 160.0
	rival_marker.velocity = -normal * 300.0
	var static_gap: float = game._ai_xi_human_lane_clearance(lead_base)
	var incoming_gap: float = game._ai_xi_human_lane_clearance(lead_base, true)
	assert(static_gap >= game.AI_XI_HUMAN_LANE_MARKED)
	assert(incoming_gap < game.AI_XI_HUMAN_LANE_SAFE)
	assert(static_gap - incoming_gap <= game.AI_XI_HUMAN_LANE_READ_MAX_DISTANCE + 0.01)
	var anticipatory_target: Vector2 = game._ai_support_target(lead)
	assert(anticipatory_target != lead_base)
	assert(game._ai_xi_human_lane_clearance(anticipatory_target, true) >= game.AI_XI_HUMAN_LANE_SAFE)
	# Exercise the actual runner and the crossing defender using their
	# CharacterBody2D movement, not position writes inside the loop.
	# This isolates the two-player positioning interaction from other AI.
	var lead_start: Vector2 = lead.global_position
	var lead_start_velocity: Vector2 = lead.velocity
	var marker_start: Vector2 = rival_marker.global_position
	var marker_destination: Vector2 = centre.lerp(lead_base, 0.6)
	var max_prediction_step := 0.0
	for tick in range(12):
		await physics_frame
		var before_step: Vector2 = lead.global_position
		var predicted_outlet: Vector2 = game._ai_support_target(lead)
		lead.move_ai(STEP, predicted_outlet, 0.83, true)
		rival_marker.move_ai(STEP, marker_destination, 1.0)
		max_prediction_step = maxf(max_prediction_step, lead.global_position.distance_to(before_step))
	assert(lead.global_position.distance_to(anticipatory_target) <
		lead_start.distance_to(anticipatory_target) - 15.0)
	assert(rival_marker.global_position.distance_to(marker_start) > 20.0)
	assert(max_prediction_step < 10.0)
	assert(game.ball.carrier == carrier and game.controlled == carrier)
	print("FOOTBALL_XI_LANE_READ_MOTION lead=", lead.global_position.distance_to(lead_start),
		" defender=", rival_marker.global_position.distance_to(marker_start), " max_step=", max_prediction_step)
	# Restore the separate directional/threshold fixture.
	lead.global_position = lead_start
	lead.velocity = lead_start_velocity
	rival_marker.global_position = marker_start
	rival_marker.velocity = normal * 300.0
	assert(is_equal_approx(game._ai_xi_human_lane_clearance(lead_base, true), static_gap))
	assert(game._ai_support_target(lead) == lead_base)
	# Slow movement or a fallen defender cannot be extrapolated into a
	# threat. A currently blocked lane must remain blocked even if the
	# defender appears to be moving away: the forecast never clears it.
	rival_marker.velocity = -normal * 79.0
	assert(is_equal_approx(game._ai_xi_human_lane_clearance(lead_base, true), static_gap))
	rival_marker.velocity = -normal * 300.0
	rival_marker.xi_collision_down_seconds = 0.5
	assert(is_equal_approx(game._ai_xi_human_lane_clearance(lead_base, true), static_gap))
	rival_marker.xi_collision_down_seconds = 0.0
	rival_marker.global_position = centre.lerp(lead_base, 0.6)
	rival_marker.velocity = normal * 300.0
	assert(game._ai_xi_human_lane_clearance(lead_base, true) < 0.01)
	# Both forecast endpoints are away from the corridor, yet the
	# defender's bounded path crosses it. Endpoint-only reads miss this.
	rival_marker.global_position = centre.lerp(lead_base, 0.6) + normal * 40.0
	rival_marker.velocity = -normal * 300.0
	assert(game._ai_xi_human_lane_clearance(lead_base) > 39.0)
	assert(game._ai_xi_human_lane_clearance(lead_base, true) < 0.01)
	# An equivalent crossing within the excluded carrier-pressure zone
	# must not be mistaken for a blocked receiving corridor.
	rival_marker.global_position = centre.lerp(lead_base, 0.08) + normal * 40.0
	assert(game._ai_xi_human_lane_clearance(lead_base, true) > 39.0)
	rival_marker.velocity = Vector2.ZERO
	rival_marker.global_position = centre + Vector2(1450.0, 800.0)
	assert(game.ai_xi_human_lane_memory.is_empty())
	print("FOOTBALL_XI_LANE_SWEEP_OK crossing=true carrier_pressure_excluded=true")
	print("FOOTBALL_XI_LANE_READ_OK static=", static_gap, " crossing=", incoming_gap)

	# Safety outlet uses the same bounded read without becoming another
	# forward runner. Test the identical defender position with opposite
	# velocities and then restore the independent static recycle fixture.
	var recycle_normal: Vector2 = (recycle_target - centre).normalized().orthogonal()
	if recycle_normal.y * (recycle_target.y - centre.y) < 0.0:
		recycle_normal = -recycle_normal
	rival_marker.global_position = centre.lerp(recycle_target, 0.6) + recycle_normal * 160.0
	rival_marker.velocity = -recycle_normal * 300.0
	assert(game._ai_xi_human_lane_clearance(recycle_target) >= game.AI_XI_HUMAN_LANE_MARKED)
	assert(game._ai_xi_human_lane_clearance(recycle_target, true) < game.AI_XI_HUMAN_LANE_SAFE)
	var anticipated_recycle: Vector2 = game._ai_support_target(recycle)
	assert(anticipated_recycle != recycle_target)
	assert(is_equal_approx(anticipated_recycle.x, recycle_target.x))
	assert(signf(anticipated_recycle.y - centre.y) == signf(recycle_target.y - centre.y))
	assert(game._ai_xi_human_lane_clearance(anticipated_recycle, true) >= game.AI_XI_HUMAN_LANE_SAFE)
	rival_marker.velocity = recycle_normal * 300.0
	assert(game._ai_support_target(recycle) == recycle_target)
	assert(game.ai_xi_human_recycle_memory.is_empty())
	rival_marker.velocity = Vector2.ZERO
	rival_marker.global_position = centre + Vector2(1450.0, 800.0)
	print("FOOTBALL_XI_RECYCLE_READ_OK forecast=true same_flank=true same_depth=true")

	# The second outlet remains behind the ball and on its original flank,
	# but it must not wait inside a marked passing corridor.
	rival_marker.global_position = recycle_target
	assert(game._ai_xi_human_lane_clearance(recycle_target) < 1.0)
	var open_recycle: Vector2 = game._ai_support_target(recycle)
	assert(game.match_pitch.has_point(open_recycle))
	assert(is_equal_approx(open_recycle.x, recycle_target.x))
	assert(signf(open_recycle.y - centre.y) == signf(recycle_target.y - centre.y))
	assert(absf(open_recycle.y - recycle_target.y) >= 130.0)
	assert(game._ai_xi_human_lane_clearance(open_recycle) >= game.AI_XI_HUMAN_LANE_SAFE)
	assert(game._ai_support_target(lead) == lead_base)
	# An established 105u corridor is below the 110u acquisition gate
	# but above the 98u retention gate. Do not reverse the runner here.
	var inward: Vector2 = (open_recycle - recycle_target).normalized()
	rival_marker.global_position = recycle_target + inward * 35.0
	assert(game._ai_xi_human_lane_clearance(open_recycle) < game.AI_XI_HUMAN_LANE_SAFE)
	assert(game._ai_support_target(recycle) == open_recycle)
	rival_marker.global_position = open_recycle
	assert(game._ai_support_target(recycle) != open_recycle)
	rival_marker.global_position = recycle_target
	assert(game._ai_support_target(recycle) == open_recycle)
	var recycle_start: Vector2 = recycle.global_position
	for tick in range(16):
		await physics_frame
		recycle.move_ai(STEP, open_recycle, 0.83, true)
	assert(recycle.global_position.distance_to(open_recycle) <
		recycle_start.distance_to(open_recycle) - 20.0)
	assert(game.ball.carrier == carrier and game.controlled == carrier)
	# Reset the independent movement fixture before the existing lead test.
	recycle.global_position = recycle_start
	recycle.velocity = Vector2.ZERO
	rival_marker.global_position = centre + Vector2(1450.0, 800.0)
	assert(game._ai_support_target(recycle) == recycle_target)
	assert(game.ai_xi_human_recycle_memory.is_empty())
	print("FOOTBALL_XI_RECYCLE_OUTLET_OK lateral=true behind_ball=true physical=true")

	# Real CharacterBody2D AI runs toward the triangle: no teleport,
	# no stamina bypass, no ball handoff, no forced input for the carrier.
	var initial: Vector2 = lead.global_position
	await physics_frame
	game._update_ai(STEP)
	assert(lead.ai_target.distance_to(lead_base) < 112.0)
	assert(lead.global_position.distance_to(initial) < 16.0)
	assert(lead.velocity.length() <= lead.base_speed * 1.36 + 2.0)
	assert(game.ball.carrier == carrier and game.controlled == carrier)
	for tick in range(16):
		await physics_frame
		game._update_ai(STEP)
	assert(lead.global_position.distance_to(lead_base) <
		initial.distance_to(lead_base) - 20.0,
		"The support has to run into space at normal physical speed")
	assert(game.ball.carrier == carrier and game.controlled == carrier)

	# Once the carrier loses possession, NO human attack role persists.
	game.ball.release(Vector2.RIGHT, 420.0)
	game._update_ai(0.0)
	assert(game.ai_xi_human_support_owner == null)
	assert(game.ai_xi_human_recycle_memory.is_empty())
	assert(game.ai_xi_human_support_slots == [null, null])
	assert(game.ai_xi_human_lane_memory.is_empty())
	assert(game._ai_xi_human_support_rank(lead) == -1)
	assert(game._ai_xi_human_support_rank(lead, true) == -1)
	# Legacy 5v5 keeps its established off-ball support path.
	game.ball.attach_to(carrier)
	game.match_team_size = 5
	assert(game._ai_xi_human_support_rank(lead) == -1)
	assert(game._ai_xi_human_support_rank(lead, true) == -1)
	assert(game._ai_support_target(lead) != lead_base)
	game.match_team_size = 11
	# CPU has independent, unchanged role/lane memory and direction.
	game.ball.attach_to(game.teams[1][10])
	assert(game._ai_xi_human_support_rank(lead) == -1)
	assert(game._ai_xi_human_support_rank(lead, true) == -1)
	assert(game._ai_xi_support_rank(game.teams[1][5]) >= -1)
	assert(game.ai_xi_support_rank_slots.size() == 2)
	assert(game.ai_xi_human_support_slots == [null, null])

	# A sprinting support runner must arrive under its own inertia, not
	# run through a stationary outlet and turn back. No position writes
	# after this fixture: real CharacterBody2D movement at 60 Hz.
	var arrival_target: Vector2 = centre + Vector2(470.0, 300.0)
	lead.global_position = arrival_target - Vector2(240.0, 0.0)
	lead.velocity = Vector2.ZERO
	lead.debug_set_stamina(100.0)
	var overshoot := 0.0
	var peak_speed := 0.0
	for tick in range(100):
		await physics_frame
		lead.move_ai(STEP, arrival_target, 1.0, true)
		overshoot = maxf(overshoot, lead.global_position.x - arrival_target.x)
		peak_speed = maxf(peak_speed, lead.velocity.length())
	assert(peak_speed > lead.base_speed, "Arrival must preserve the distant sprint")
	assert(overshoot <= 8.0, "XI support must brake before running through its outlet")
	assert(lead.global_position.distance_to(arrival_target) <= 9.0)
	assert(lead.velocity.length() < 1.0)
	print("FOOTBALL_XI_SUPPORT_ARRIVAL overshoot=", overshoot, " peak_speed=", peak_speed)

	# A requested snapshot reuse cannot carry assignments or lane memory
	# across a real human possession handoff, even before the next update.
	game._select_player(carrier)
	game.ball.attach_to(carrier)
	game._ai_xi_human_support_rank(carrier)
	assert(game.ai_xi_human_support_owner == carrier)
	game.ai_xi_human_lane_memory[int(lead.get_instance_id())] = {"owner": int(carrier.get_instance_id()), "side": 1.0}
	game.ai_xi_human_recycle_memory = {"actor": int(recycle.get_instance_id()), "direction": 1.0}
	game._select_player(recycle)
	game.ball.attach_to(recycle)
	assert(game._ai_xi_human_support_rank(recycle, true) == -1)
	assert(game.ai_xi_human_support_owner == recycle)
	assert(not (recycle in game.ai_xi_human_support_slots))
	assert(game.ai_xi_human_lane_memory.is_empty())
	assert(game.ai_xi_human_recycle_memory.is_empty())
	print("FOOTBALL_XI_SUPPORT_SNAPSHOT_HANDOFF_OK possession=true memory_reset=true")

	print("FOOTBALL_XI_HUMAN_SUPPORT_OK two_outlets=true open_lane=true stable_roles=true real_movement=true loss_reset=true legacy_5v5=true cpu_unchanged=true")
	game.queue_free()
	await process_frame
	await _loose_transition_shape(scene)
	await process_frame
	await _mirrored_cutback_shape(scene)
	quit(0)


func _mirrored_cutback_shape(scene: PackedScene) -> void:
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
	var centre: Vector2 = game.match_pitch.get_center()
	var owner: Footballer = game.teams[1][10]
	var home_owner: Footballer = game.teams[0][10]
	var lead: Footballer = game.teams[1][5]
	var recycle: Footballer = game.teams[1][6]
	for flank: float in [-1.0, 1.0]:
		owner.global_position = Vector2(game.match_pitch.position.x + 250.0, centre.y + flank * 650.0)
		home_owner.global_position = Vector2(game.match_pitch.end.x - 250.0, owner.global_position.y)
		for teammate: Footballer in game.teams[1]:
			if teammate != owner:
				teammate.global_position = centre + Vector2(1100.0, 700.0)
				teammate.velocity = Vector2.ZERO
		lead.global_position = owner.global_position + Vector2(170.0, -flank * 80.0)
		recycle.global_position = owner.global_position + Vector2(310.0, -flank * 110.0)
		game.ball.attach_to(owner)
		assert(game._ai_xi_support_rank(lead) == 0)
		assert(game._ai_xi_support_rank(recycle) == 1)
		for rank in range(2):
			var runner: Footballer = lead if rank == 0 else recycle
			var target: Vector2 = game._ai_support_target(runner)
			var reflected: Vector2 = game._ai_xi_cutback_target(home_owner, rank)
			assert(target.is_equal_approx(game._ai_xi_cutback_target(owner, rank)))
			assert(is_equal_approx(target.x + reflected.x, centre.x * 2.0))
			assert(is_equal_approx(target.y, reflected.y))
			assert(game.match_pitch.has_point(target))
			assert(target.x > owner.global_position.x)
	owner.global_position = centre
	assert(not game._ai_xi_away_cutback_available(lead))
	game.match_team_size = 5
	assert(not game._ai_xi_away_cutback_available(lead))
	print("FOOTBALL_XI_SHARED_CUTBACK_OK mirrored=true both_flanks=true two_outlets=true midfield_off=true legacy_off=true")
	game.queue_free()


func _loose_transition_shape(scene: PackedScene) -> void:
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
	for team in game.teams:
		for player: Footballer in team:
			player.global_position = player.home_position
			player.velocity = Vector2.ZERO
	var centre: Vector2 = game.match_pitch.get_center()
	var home: Footballer = game.teams[0][1]
	var away: Footballer = game.teams[1][1]
	var manual: Footballer = game.teams[0][10]
	game._select_player(manual)
	game.ball.release(Vector2.RIGHT, 0.0)
	game.ball.global_position = centre
	var home_target: Vector2 = game._ai_xi_loose_support_target(home, centre)
	var away_target: Vector2 = game._ai_xi_loose_support_target(away, centre)
	assert(home_target.distance_to(centre) < home.home_position.distance_to(centre) - 100.0)
	assert(away_target.distance_to(centre) < away.home_position.distance_to(centre) - 100.0)
	assert(is_equal_approx(home_target.x + away_target.x, centre.x * 2.0))
	assert(is_equal_approx(home_target.y, away_target.y))
	assert(home_target.distance_to(home.home_position) <= 180.01)
	assert(away_target.distance_to(away.home_position) <= 180.01)
	assert(game._ai_xi_loose_support_target(home, centre) == home_target)
	for defender: Footballer in [home, away]:
		var first: Footballer = game._ai_primary_presser(defender.team_id)
		var second: Footballer = game._ai_secondary_presser(defender.team_id, first)
		assert(defender != first and defender != second)
	var home_expected: Vector2 = game._ai_spaced_target(home, home_target)
	var away_expected: Vector2 = game._ai_spaced_target(away, away_target)
	var manual_start: Vector2 = manual.global_position
	game._update_ai(0.0)
	assert(home.ai_target.distance_to(home_expected) < 0.1)
	assert(away.ai_target.distance_to(away_expected) < 0.1)
	assert(manual.global_position.is_equal_approx(manual_start))
	var home_start: Vector2 = home.global_position
	var away_start: Vector2 = away.global_position
	for tick in range(12):
		await physics_frame
		game._update_ai(STEP)
	assert(home.global_position.distance_to(home_target) < home_start.distance_to(home_target) - 5.0)
	assert(away.global_position.distance_to(away_target) < away_start.distance_to(away_target) - 5.0)
	assert(game.ball.carrier == null and game.controlled == manual)
	game.ball.attach_to(manual)
	assert(game._ai_xi_loose_support_target(home, centre) == home.home_position)
	game.ball.release(Vector2.RIGHT, 0.0)
	game.match_team_size = 5
	assert(game._ai_xi_loose_support_target(home, centre) == home.home_position)
	print("FOOTBALL_XI_LOOSE_TRANSITION_SHAPE_OK mirrored=true real_movement=true bounded=true manual_unchanged=true legacy=true")
	game.queue_free()
