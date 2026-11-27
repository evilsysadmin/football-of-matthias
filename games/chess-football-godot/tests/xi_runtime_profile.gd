extends SceneTree

# Read-only performance probe for XI (22 real actors). CI reports timings,
# not a fragile wall-clock FPS pass/fail threshold on shared runners.
# A separate measure for presentation and HUD identifies CPU hot paths
# masked by the historical 60s endurance test, which only asserts rules.
const STEP := 1.0 / 60.0
const SAMPLES := 240


func _measure(game: Node, section: String) -> Dictionary:
	var measurements: Array[int] = []
	var total_usec := 0
	for tick in range(SAMPLES):
		var before: int = Time.get_ticks_usec()
		match section:
			"ai":
				game._update_ai(STEP)
			"presentation":
				game._update_3d_presentation(STEP)
			"hud":
				game._refresh_hud()
			"full":
				game._physics_process(STEP)
		var duration: int = maxi(Time.get_ticks_usec() - before, 0)
		measurements.append(duration)
		total_usec += duration
	measurements.sort()
	return {
		"count": SAMPLES,
		"avg_us": snappedf(float(total_usec) / float(SAMPLES), 0.1),
		"p50_us": measurements[int(SAMPLES / 2)],
		"p95_us": measurements[int(float(SAMPLES) * 0.95)],
		"worst_us": measurements[SAMPLES - 1],
	}


func _initialize() -> void:
	seed(81290)
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for team in game.teams:
		for actor: Footballer in team:
			actor.set_process(false)
			actor.set_physics_process(false)
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	game._select_player(game.teams[0][10])
	game.ball.attach_to(game.teams[0][10])
	assert(game.debug_team_counts() == [11, 11])
	assert(game.presentation_3d != null)
	# Readout stays hidden in normal play. F3 toggles it without touching
	# possession/physics and only samples monitors while explicitly visible.
	assert(game.performance_label != null and not game.performance_label.visible)
	var original_holder: Footballer = game.ball.carrier
	game._toggle_performance_overlay()
	assert(game.performance_label.visible)
	assert(game.performance_label.text.begins_with("FPS "))
	assert(game.ball.carrier == original_holder)
	# Diagnose a real selected actor's displacement separately from an
	# intentional handoff to a distant teammate. Never change possession.
	var actor: Footballer = game.controlled
	var other: Footballer = game.teams[0][1]
	var origin: Vector2 = actor.global_position
	actor.global_position += Vector2(5.0, 0.0)
	game._update_performance_overlay(STEP)
	assert(is_equal_approx(game.performance_motion_max_step, 5.0))
	assert(game.performance_motion_switches == 0)
	game._select_player(other)
	game._update_performance_overlay(STEP)
	assert(game.performance_motion_switches == 1)
	assert(is_equal_approx(game.performance_motion_last_switch_distance,
		other.global_position.distance_to(actor.global_position)))
	assert(is_equal_approx(game.performance_motion_max_step, 5.0))
	var other_origin: Vector2 = other.global_position
	game.kickoff_active = true
	other.global_position += Vector2(300.0, 0.0)
	game._update_performance_overlay(STEP)
	game.kickoff_active = false
	game._update_performance_overlay(STEP)
	assert(is_equal_approx(game.performance_motion_max_step, 5.0))
	assert(game.performance_motion_switches == 1)
	# Restore the test fixture; measuring alone never changed the ball.
	actor.global_position = origin
	other.global_position = other_origin
	game._select_player(actor)
	assert(game.ball.carrier == original_holder)
	game._toggle_performance_overlay()
	assert(not game.performance_label.visible)
	assert(game.performance_motion_switches == 0 and game.performance_motion_max_step == 0.0)
	print("FOOTBALL_XI_CONTINUITY_OVERLAY_OK same_actor=true handoff_separate=true restart_excluded=true")
	# Warm texture/memory caches before measuring steady-state work.
	for tick in range(60):
		game._physics_process(STEP)
	var results := {}
	for section in ["ai", "presentation", "hud", "full"]:
		results[section] = _measure(game, section)
	assert(results.size() == 4)
	print("FOOTBALL_XI_CPU_PROFILE " + JSON.stringify({
		"mode": "headless_wall_clock_us_not_browser_fps",
		"players": 22,
		"samples_per_section": SAMPLES,
		"sections": results,
	}))
	print("FOOTBALL_XI_CPU_PROFILE_OK")
	quit(0)
