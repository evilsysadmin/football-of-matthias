extends SceneTree

# An independent, 22-player REAL-PHYSICS defensive threat fixture.
# Setup positions are fixed once. No teleports, scripted interceptions,
# extra speed, ball steals or forced AI targets are applied during play.
# It complements the long seeded input bot: that bot does not always visit
# the human half under sustained CPU possession.
const Formation = preload("res://scripts/football_match_formation.gd")
const XI := Formation.ELEVEN_PITCH_RECT
const STEP := 1.0 / 60.0
const TICKS := 54


func _initialize() -> void:
	seed(841127)
	var scene: PackedScene = load("res://main.tscn")
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	assert(game.debug_team_counts() == [11, 11])
	assert(game.match_pitch == XI)
	game._set_quick_difficulty("normal")
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	game.match_seconds = 0.0
	game._reset_ai_adaptation()

	var centre: Vector2 = XI.get_center()
	var carrier: Footballer = game.teams[1][10]
	var first: Footballer = game.teams[0][2]
	var cover: Footballer = game.teams[0][3]
	var screen: Footballer = game.teams[0][5]
	var human: Footballer = game.teams[0][10]
	# Move only the setup fixtures, before taking a single measured step.
	# Keep all other actors on the actual pitch, far from this local duel.
	for member: Footballer in game.teams[0]:
		if member.role != "keeper":
			member.global_position = centre + Vector2(
				-1120.0 - float(member.squad_index) * 14.0,
				600.0 + float(member.squad_index % 4) * 35.0
			)
			member.velocity = Vector2.ZERO
	for member: Footballer in game.teams[1]:
		if member.role != "keeper" and member != carrier:
			member.global_position = centre + Vector2(
				1140.0 + float(member.squad_index) * 14.0,
				-630.0 + float(member.squad_index % 4) * 35.0
			)
			member.velocity = Vector2.ZERO
	carrier.global_position = centre + Vector2(-240.0, 0.0)
	carrier.velocity = Vector2.ZERO
	first.global_position = carrier.global_position + Vector2(-470.0, -55.0)
	cover.global_position = carrier.global_position + Vector2(-570.0, 60.0)
	screen.global_position = carrier.global_position + Vector2(-700.0, -150.0)
	# A local midfielder's real 4-3-3 home lane is near this intrusion;
	# distant teammates must not acquire a third pursuit role.
	screen.home_position = carrier.global_position + Vector2(-550.0, -150.0)
	game._select_player(human)
	game.ball.attach_to(carrier)
	# The CPU must dribble using the ACTUAL AI target and body. A tactical
	# shot/pass decision is not the subject of this independent 0.9s probe.
	game.ai_next_decision[int(carrier.get_instance_id())] = 100.0
	assert(game._ai_primary_presser(0) == first)
	assert(game._ai_secondary_presser(0, first) == cover)
	var screen_target: Vector2 = game._ai_xi_human_compact_target(screen, carrier)
	var legacy_target: Vector2 = ChessFootballMath.clamp_to_pitch(
		screen.home_position.lerp(carrier.global_position, game.AI_DEFENSIVE_SHIFT_RATIO),
		XI
	)
	assert(screen_target.distance_to(carrier.global_position) <
		legacy_target.distance_to(carrier.global_position) - 40.0,
		"Local midfield cover must have a meaningfully closer defensive target")

	var initial_owner: Vector2 = carrier.global_position
	var first_start: Vector2 = first.global_position
	var cover_start: Vector2 = cover.global_position
	var screen_start: Vector2 = screen.global_position
	var initial_press_gap: float = first_start.distance_to(initial_owner)
	var largest_step: float = 0.0
	var active_ticks := 0
	var goalward_frames := 0
	var previous_carrier: Vector2 = initial_owner
	var previous_first: Vector2 = first_start
	var previous_cover: Vector2 = cover_start
	var previous_screen: Vector2 = screen_start
	for tick in range(TICKS):
		# Keep the physics server active. The match's script timer is driven
		# exactly once per 60Hz sample, matching the proved XI bot cadence.
		await physics_frame
		if game.ball.carrier != carrier:
			break
		game._physics_process(STEP)
		for team in game.teams:
			for actor: Footballer in team:
				actor._process(STEP)
		active_ticks += 1
		if carrier.global_position.x < previous_carrier.x - 0.2:
			goalward_frames += 1
		largest_step = maxf(largest_step, carrier.global_position.distance_to(previous_carrier))
		largest_step = maxf(largest_step, first.global_position.distance_to(previous_first))
		largest_step = maxf(largest_step, cover.global_position.distance_to(previous_cover))
		largest_step = maxf(largest_step, screen.global_position.distance_to(previous_screen))
		previous_carrier = carrier.global_position
		previous_first = first.global_position
		previous_cover = cover.global_position
		previous_screen = screen.global_position
		assert(XI.grow(4.0).has_point(first.global_position))
		assert(XI.grow(4.0).has_point(cover.global_position))
		assert(XI.grow(4.0).has_point(screen.global_position))
		assert(game.controlled == human,
			"The distant human controller must not be arbitrarily reassigned")

	var first_travel: float = first_start.distance_to(first.global_position)
	var cover_travel: float = cover_start.distance_to(cover.global_position)
	var screen_travel: float = screen_start.distance_to(screen.global_position)
	var carrier_travel: float = initial_owner.distance_to(carrier.global_position)
	var final_press_gap: float = first.global_position.distance_to(carrier.global_position)
	var report := {
		"kind": "60hz_real_22_player_defensive_threat_not_full_match",
		"ticks": active_ticks,
		"cpu_carrier_travel": snappedf(carrier_travel, 0.1),
		"goalward_frames": goalward_frames,
		"first_presser_travel": snappedf(first_travel, 0.1),
		"cover_travel": snappedf(cover_travel, 0.1),
		"midfielder_travel": snappedf(screen_travel, 0.1),
		"initial_press_gap": snappedf(initial_press_gap, 0.1),
		"final_press_gap": snappedf(final_press_gap, 0.1),
		"max_step": snappedf(largest_step, 0.01),
		"carrier_retained": game.ball.carrier == carrier,
	}
	print("FOOTBALL_XI_THREAT_METRICS " + JSON.stringify(report))
	assert(active_ticks >= 38, "CPU must physically carry through a sustained defensive phase")
	assert(carrier_travel >= 40.0 and goalward_frames >= 20,
		"CPU must actually advance toward the human goal, not idle in this fixture")
	assert(first_travel >= 45.0 and cover_travel >= 32.0,
		"Human first and second defenders must physically react to the advancing carrier")
	assert(screen_travel >= 30.0 and screen.global_position.x > screen_start.x + 20.0,
		"Local third midfielder must physically close the dangerous passing lane")
	assert(final_press_gap < initial_press_gap - 45.0,
		"The nearest real defender must reduce an exposed CPU-carrier gap")
	assert(screen.global_position.distance_to(carrier.global_position) >
		game.TACKLE_ATTEMPT_RANGE + 80.0,
		"Midfield cover must not become an extra instantaneous tackling presser")
	assert(largest_step < 28.0,
		"No actor may teleport or exceed a remotely plausible physical step")
	assert(game.ball.carrier == carrier,
		"No scripted steal or free possession transfer is permitted in this setup")
	print("FOOTBALL_XI_THREAT_60HZ_OK real_actors=22 cpu_goalward=1 press_physical=1 cover_physical=1 midfield_physical=1 no_teleport=1")
	root.remove_child(game)
	game.queue_free()
	quit(0)
