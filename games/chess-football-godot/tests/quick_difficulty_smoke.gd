extends SceneTree
const Difficulty = preload("res://scripts/football_quick_difficulty.gd")
func _initialize() -> void:
	assert(Difficulty.from_hash("#football-difficulty=easy") == "easy")
	assert(Difficulty.from_hash("#football-difficulty=hard") == "hard")
	assert(Difficulty.from_hash("#football-difficulty=hard&football-team-size=11") == "hard")
	assert(Difficulty.from_hash("#football-difficulty=expert") == "expert")
	for invalid in ["", "#football-difficulty=foo", "#football-difficulty=expert%0A", "#other=hard"]:
		assert(Difficulty.from_hash(invalid) == "normal")
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var match_node = scene.instantiate()
	root.add_child(match_node)
	await process_frame
	await process_frame
	var cpu_speed: float = match_node.teams[1][4].base_speed
	var home_speed: float = match_node.teams[0][4].base_speed
	var normal_interval: float = match_node._ai_adaptive_decision_interval()
	var normal_pressure: float = match_node._ai_adaptive_pressure_radius()
	assert(match_node.quick_difficulty == "normal")
	assert(is_equal_approx(normal_interval, match_node.AI_DECISION_INTERVAL))
	assert(is_equal_approx(normal_pressure, match_node.AI_PRESSURE_RADIUS))
	assert(is_equal_approx(match_node._ai_cpu_intensity(0.75), 0.75))
	var intervals := []
	var radii := []
	var efforts := []
	var shots := []
	for level in ["easy","normal","hard","expert"]:
		match_node._set_quick_difficulty(level)
		intervals.append(match_node._ai_adaptive_decision_interval())
		radii.append(match_node._ai_adaptive_pressure_radius())
		efforts.append(match_node._ai_cpu_intensity(0.75))
		shots.append(float(match_node.quick_difficulty_profile["shoot"]))
		assert(is_equal_approx(match_node._ai_adaptive_pressure_radius(0), normal_pressure))
		assert(is_equal_approx(match_node.teams[1][4].base_speed,cpu_speed))
		assert(is_equal_approx(match_node.teams[0][4].base_speed,home_speed))
	for i in range(3):
		assert(intervals[i] > intervals[i+1])
		assert(radii[i] < radii[i+1])
		assert(efforts[i] < efforts[i+1])
		assert(shots[i] < shots[i+1])
	match_node._set_quick_difficulty("expert")
	match_node.match_seconds = 2.0
	var striker: Footballer = match_node.teams[1][4]
	assert(match_node._ai_decision_ready(striker))
	var deadline: float = float(match_node.ai_next_decision[int(striker.get_instance_id())])
	assert(is_equal_approx(deadline - match_node.match_seconds, intervals[3]))
	assert(not match_node._ai_decision_ready(striker))
	match_node._set_quick_difficulty("bogus")
	assert(match_node.quick_difficulty == "normal")
	assert(is_equal_approx(match_node._ai_adaptive_decision_interval(),normal_interval))
	# A nearby CPU cover must actually close goal-side when a human carries
	# the ball. Easy keeps the positional cushion; neither mode buffs stats.
	match_node.set_process(false)
	match_node.set_physics_process(false)
	var human_carrier: Footballer = match_node.teams[0][4]
	var cpu_cover: Footballer = match_node.teams[1][2]
	human_carrier.global_position = match_node.match_pitch.get_center()
	cpu_cover.global_position = human_carrier.global_position + Vector2(160.0, 0.0)
	match_node.ball.attach_to(human_carrier)
	match_node._set_quick_difficulty("easy")
	var easy_cover: Vector2 = match_node._ai_cover_target(cpu_cover, human_carrier.global_position)
	match_node._set_quick_difficulty("normal")
	var normal_cover: Vector2 = match_node._ai_cover_target(cpu_cover, human_carrier.global_position)
	assert(normal_cover.is_equal_approx(easy_cover))
	match_node._set_quick_difficulty("hard")
	var hard_cover: Vector2 = match_node._ai_cover_target(cpu_cover, human_carrier.global_position)
	assert(normal_cover.x > human_carrier.global_position.x)
	assert(normal_cover.x - hard_cover.x > 70.0)
	# No cross-pitch chase, and never change the human-side cover plan.
	cpu_cover.global_position = human_carrier.global_position + Vector2(350.0, 0.0)
	assert(match_node._ai_cover_target(cpu_cover, human_carrier.global_position).is_equal_approx(easy_cover))
	var human_cover: Footballer = match_node.teams[0][1]
	var human_goal_side: Vector2 = match_node._ai_cover_target(human_cover, human_carrier.global_position)
	match_node._set_quick_difficulty("easy")
	assert(match_node._ai_cover_target(human_cover, human_carrier.global_position).is_equal_approx(human_goal_side))
	# Normal no longer sends TWO sprinting tacklers at the same new human
	# touch. Hard still activates the real close-range second challenge.
	var lead_cpu: Footballer = match_node.teams[1][1]
	lead_cpu.global_position = human_carrier.global_position + Vector2(117.0, 0.0)
	cpu_cover.global_position = human_carrier.global_position + Vector2(155.0, 40.0)
	cpu_cover.home_position.y = human_carrier.global_position.y + 260.0
	for other_cpu in match_node.teams[1]:
		if other_cpu != lead_cpu and other_cpu != cpu_cover and other_cpu.role != "keeper":
			other_cpu.global_position = human_carrier.global_position + Vector2(400.0, 250.0)
	assert(match_node._ai_primary_presser(1) == lead_cpu)
	assert(match_node._ai_secondary_presser(1, lead_cpu) == cpu_cover)
	var easy_local_cover: Vector2 = match_node._ai_cover_target(cpu_cover, human_carrier.global_position)
	match_node._update_ai(1.0 / 60.0)
	assert(match_node.ball.carrier == human_carrier)
	assert(not cpu_cover.last_sprinting)
	match_node._set_quick_difficulty("normal")
	assert(not match_node._ai_cpu_second_press_active(cpu_cover, human_carrier.global_position))
	var normal_local_cover: Vector2 = match_node._ai_cover_target(cpu_cover, human_carrier.global_position)
	assert(normal_local_cover.is_equal_approx(easy_local_cover))
	match_node._update_ai(1.0 / 60.0)
	assert(match_node.ball.carrier == human_carrier)
	assert(not cpu_cover.last_sprinting)
	match_node._set_quick_difficulty("hard")
	assert(match_node._ai_cpu_second_press_active(cpu_cover, human_carrier.global_position))
	var hard_local_cover: Vector2 = match_node._ai_cover_target(cpu_cover, human_carrier.global_position)
	assert(absf(hard_local_cover.y - human_carrier.global_position.y) < absf(normal_local_cover.y - human_carrier.global_position.y))
	match_node._update_ai(1.0 / 60.0)
	assert(match_node.ball.carrier == human_carrier)
	assert(cpu_cover.last_sprinting)
	assert(cpu_cover.ai_target.is_equal_approx(match_node._ai_cover_target(cpu_cover, human_carrier.global_position)))
	# Hard still limits the second chase to a genuine nearby contest.
	cpu_cover.global_position = human_carrier.global_position + Vector2(350.0, 0.0)
	assert(not match_node._ai_cpu_second_press_active(cpu_cover, human_carrier.global_position))
	# Normal allows a tiny, REAL first-touch read before a new tackle;
	# physical tackle and hitbox mechanics are unchanged afterward.
	lead_cpu.global_position = human_carrier.global_position + Vector2(31.0, -8.0)
	lead_cpu.velocity = Vector2(-175.0, 0.0)
	lead_cpu.tackle_cooldown_seconds = 0.0
	lead_cpu.tackle_recovery_seconds = 0.0
	lead_cpu.tackle_active_seconds = 0.0
	lead_cpu.action_lock_seconds = 0.0
	match_node.ball.attach_to(human_carrier)
	match_node._set_quick_difficulty("normal")
	assert(not match_node._ai_xi_tackle_commit_ready(lead_cpu, human_carrier, false))
	assert(not match_node._ai_xi_tackle_commit_ready(lead_cpu, human_carrier, true))
	match_node.ball.tick_ball(match_node.AI_XI_NORMAL_FIRST_TOUCH_REACTION + 0.02)
	assert(match_node._ai_xi_tackle_commit_ready(lead_cpu, human_carrier, false))
	assert(not match_node._ai_xi_tackle_commit_ready(lead_cpu, human_carrier, true))
	match_node._set_quick_difficulty("hard")
	match_node.ball.attach_to(human_carrier)
	assert(match_node._ai_xi_tackle_commit_ready(lead_cpu, human_carrier, false))
	print("FOOTBALL_QUICK_DIFFICULTY_OK levels=4 CPU_real_tactics player_stats_unchanged normal_one_presser=1 hard_second_press=1 first_touch_read=1 easy_and_human_unchanged=1")

	quit(0)
