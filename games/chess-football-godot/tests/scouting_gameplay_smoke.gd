extends SceneTree
const DELTA := 1.0 / 60.0
const CHARGE_RATIO := 0.55

func _pass_speed(match_node: Node2D, actor: Footballer, receiver: Footballer) -> float:
	match_node._select_player(actor)
	match_node.ball.attach_to(actor)
	assert(match_node._begin_pass_charge(receiver))
	match_node.pass_charge_seconds = match_node.PASS_CHARGE_SECONDS * CHARGE_RATIO
	assert(match_node._release_charged_pass())
	assert(not match_node.ball.last_release_was_shot)
	return match_node.ball.velocity.length()

func _shot_speed(match_node: Node2D, actor: Footballer) -> float:
	match_node._select_player(actor)
	match_node.ball.attach_to(actor)
	match_node._begin_shot_charge(0.0)
	match_node.shot_charge_seconds = match_node.SHOT_CHARGE_SECONDS * CHARGE_RATIO
	match_node._release_charged_shot()
	assert(match_node.ball.last_release_was_shot)
	return match_node.ball.velocity.length()

func _human_speed(actor: Footballer) -> float:
	actor.global_position = Vector2(390.0, 180.0)
	actor.velocity = Vector2.ZERO
	for _frame in range(60):
		actor.move_human(DELTA, Vector2.RIGHT, false)
	return actor.velocity.length()

func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var match_node = packed.instantiate()
	root.add_child(match_node)
	await process_frame
	await process_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	var defender: Footballer = match_node.teams[0][1]
	var midfielder: Footballer = match_node.teams[0][2]
	var striker: Footballer = match_node.teams[0][4]
	assert(defender.scouting_passing == 70 and defender.scouting_shooting == 34 and defender.scouting_technique == 58)
	assert(midfielder.scouting_passing == 90 and midfielder.scouting_technique == 88)
	assert(striker.scouting_passing == 64 and striker.scouting_shooting == 92)
	assert(midfielder.pass_power_multiplier() > striker.pass_power_multiplier())
	assert(striker.shot_power_multiplier() > defender.shot_power_multiplier())
	assert(midfielder.technique_control_multiplier > defender.technique_control_multiplier)
	assert(midfielder.pass_power_multiplier() <= 1.10)
	assert(defender.shot_power_multiplier() >= 0.86)
	assert(midfielder.technique_control_multiplier <= 1.06)
	# Real passes: identical charges and receiving position, different athletes.
	midfielder.global_position = Vector2(920.0, 510.0)
	striker.global_position = midfielder.global_position
	defender.global_position = Vector2(1170.0, 510.0)
	var strong_pass: float = _pass_speed(match_node, midfielder, defender)
	var weak_pass: float = _pass_speed(match_node, striker, defender)
	assert(strong_pass > weak_pass + 35.0)
	assert(strong_pass <= match_node.ball.max_speed)
	# Real shots: same charge and origin, no random spread or auto-goals.
	defender.global_position = Vector2(1770.0, 770.0)
	striker.global_position = defender.global_position
	var strong_shot: float = _shot_speed(match_node, striker)
	var weak_shot: float = _shot_speed(match_node, defender)
	assert(strong_shot > weak_shot + 70.0)
	assert(strong_shot <= match_node.ball.max_speed)
	# Same midfielder: on-ball close control affects real movement.
	match_node.ball.attach_to(midfielder)
	var carrying: float = _human_speed(midfielder)
	match_node.ball.attach_to(match_node.teams[1][4])
	var free: float = _human_speed(midfielder)
	assert(carrying > free + 3.0)
	# CPU uses identical stats, not a second invented skill model.
	var cpu: Footballer = match_node.teams[1][2]
	cpu.global_position = Vector2(1200.0, 390.0)
	cpu.velocity = Vector2.ZERO
	match_node.ball.attach_to(cpu)
	for _frame in range(60):
		cpu.move_ai(DELTA, Vector2(700.0, 390.0), 0.85)
	var cpu_carry: float = cpu.velocity.length()
	match_node.ball.attach_to(striker)
	cpu.global_position = Vector2(1200.0, 390.0)
	cpu.velocity = Vector2.ZERO
	for _frame in range(60):
		cpu.move_ai(DELTA, Vector2(700.0, 390.0), 0.85)
	var cpu_free: float = cpu.velocity.length()
	if cpu.technique_control_multiplier > 1.0:
		assert(cpu_carry > cpu_free)
	elif cpu.technique_control_multiplier < 1.0:
		assert(cpu_carry < cpu_free)
	else:
		assert(is_equal_approx(cpu_carry, cpu_free))
	assert(match_node.quick_difficulty == "normal")
	assert(match_node.teams[0][0].movement_multiplier == 1.0)
	print("FOOTBALL_SCOUTING_GAMEPLAY_OK pass=%.1f/%.1f shot=%.1f/%.1f technique=%.1f/%.1f" % [
		strong_pass, weak_pass, strong_shot, weak_shot, carrying, free
	])
	quit(0)
