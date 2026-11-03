extends SceneTree

# These are game-engine collisions and catches, not isolated formula tests.
func _set_tackle_geometry(tackler: Footballer, victim: Footballer) -> void:
	tackler.global_position = Vector2(1040.0, 760.0)
	tackler.velocity = Vector2(160.0, 0.0)
	victim.global_position = tackler.global_position + Vector2(30.0, 21.8)
	victim.velocity = Vector2.ZERO

func _place_low_shot(match_node: Node2D, keeper: Footballer, distance: float) -> void:
	var own_goal: Vector2 = ChessFootballMath.goal_center(1 - keeper.team_id)
	keeper.global_position = own_goal + Vector2(match_node.KEEPER_LINE_OFFSET, 0.0)
	match_node.ball.release(Vector2.LEFT, 790.0, 0.0, true)
	match_node.ball.global_position = keeper.global_position + Vector2(distance, 0.0)
	match_node.ball.flight_height = 0.0
	match_node.ball.vertical_velocity = 0.0

func _initialize() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var match_node = scene.instantiate()
	root.add_child(match_node)
	await process_frame
	await process_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	var central: Footballer = match_node.teams[0][1] # Iván Prieto: Defensa 84
	var striker: Footballer = match_node.teams[0][4] # Lucas Aguirre: Defensa 32
	var victim: Footballer = match_node.teams[1][4]
	var keeper: Footballer = match_node.teams[0][0] # Óscar Campos: Portería 85
	var other_keeper: Footballer = match_node.teams[1][0] # Iker Vidal: Portería 88
	assert(central.scouting_tackling == 84)
	assert(striker.scouting_tackling == 32)
	assert(keeper.scouting_keeping == 85 and other_keeper.scouting_keeping == 88)
	assert(central.clean_tackle_multiplier() > striker.clean_tackle_multiplier())
	assert(other_keeper.keeper_reflex_multiplier() > keeper.keeper_reflex_multiplier())
	assert(central.clean_tackle_multiplier() <= 1.08)
	assert(striker.clean_tackle_multiplier() >= 0.88)
	# Same front-on trajectory is physically inside the contact area for
	# both, but a strong defender converts the edge into a clean touch.
	_set_tackle_geometry(central, victim)
	var good_hit: Dictionary = match_node._tackle_hitbox(central, victim.global_position)
	_set_tackle_geometry(striker, victim)
	var bad_hit: Dictionary = match_node._tackle_hitbox(striker, victim.global_position)
	assert(bool(good_hit["inside"]) and bool(bad_hit["inside"]))
	assert(bool(good_hit["contact"]) and bool(bad_hit["contact"]))
	assert(bool(good_hit["clean"]) and not bool(bad_hit["clean"]))
	assert(not bool(good_hit["foul"]) and not bool(bad_hit["foul"]))
	# Real tackle: a legitimate clean poke gets a delayed claim, whereas
	# a glancing hit must leave a contestable loose ball.
	_set_tackle_geometry(central, victim)
	match_node.ball.attach_to(victim)
	assert(match_node._try_tackle(central))
	assert(match_node.ball.carrier == null)
	assert(match_node.pending_tackle_player == central)
	match_node.pending_tackle_player = null
	match_node.pending_tackle_seconds = 0.0
	_set_tackle_geometry(striker, victim)
	match_node.ball.attach_to(victim)
	assert(match_node._try_tackle(striker))
	assert(match_node.ball.carrier == null)
	assert(match_node.pending_tackle_player == null)
	assert(match_node.ball.contact_reclaim_block_player == striker)
	# Nothing above changes physical reach: even the central cannot
	# touch a ball outside the original tackle attempt area.
	var old_victim_position: Vector2 = victim.global_position
	victim.global_position = central.global_position + Vector2(135.0, 0.0)
	assert(not match_node._try_tackle(central))
	victim.global_position = old_victim_position
	# Goalkeeper anticipation: the real goalward ball is readable at
	# the edge of a good keeper's range, not at the poor keeper's range.
	var original_keeping: int = keeper.scouting_keeping
	var own_goal: Vector2 = ChessFootballMath.goal_center(1 - keeper.team_id)
	var line_x: float = own_goal.x + match_node.KEEPER_LINE_OFFSET
	match_node.ball.release(Vector2.LEFT, 790.0, 0.0, true)
	match_node.ball.global_position = Vector2(own_goal.x + 925.0, own_goal.y)
	assert(match_node._keeper_reading_shot(keeper, line_x))
	keeper.scouting_keeping = 30
	assert(not match_node._keeper_reading_shot(keeper, line_x))
	keeper.scouting_keeping = original_keeping
	# The physical save is also bounded: ball must travel toward own
	# goal, below the crossbar and within hand reach, even at rating 99.
	_place_low_shot(match_node, keeper, 59.0)
	keeper.scouting_keeping = 30
	assert(not match_node._keeper_try_save(keeper))
	assert(match_node.ball.carrier == null)
	keeper.scouting_keeping = original_keeping
	assert(match_node._keeper_try_save(keeper))
	assert(match_node.ball.carrier == keeper)
	_place_low_shot(match_node, keeper, 75.0)
	assert(not match_node._keeper_try_save(keeper))
	_place_low_shot(match_node, keeper, 30.0)
	match_node.ball.velocity = Vector2.RIGHT * 790.0
	assert(not match_node._keeper_try_save(keeper))
	_place_low_shot(match_node, keeper, 30.0)
	match_node.ball.flight_height = match_node.KEEPER_SAVE_MAX_HEIGHT + 1.0
	assert(not match_node._keeper_try_save(keeper))
	assert(match_node.ball.carrier == null)
	assert(keeper.scouting_keeping == original_keeping)
	print("FOOTBALL_DEFENSE_KEEPER_SCOUTING_OK clean_vs_glancing=1 early_read=1 save_range=1 foul_and_reach_preserved=1")
	quit(0)
