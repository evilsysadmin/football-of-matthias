extends SceneTree
const Difficulty = preload("res://scripts/football_quick_difficulty.gd")
func _initialize() -> void:
	assert(Difficulty.from_hash("#football-difficulty=easy") == "easy")
	assert(Difficulty.from_hash("#football-difficulty=hard") == "hard")
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
	print("FOOTBALL_QUICK_DIFFICULTY_OK levels=4 CPU_real_tactics player_stats_unchanged")
	quit(0)
