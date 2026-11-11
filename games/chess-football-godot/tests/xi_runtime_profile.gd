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
	game._toggle_performance_overlay()
	assert(not game.performance_label.visible)
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
