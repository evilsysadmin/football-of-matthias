extends SceneTree

const Formation = preload("res://scripts/football_match_formation.gd")

# A playable pitch must spread ten footballers in real 3D field coordinates,
# not merely render larger empty grass around the same packed central scrum.
func _initialize() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	var pitch := ChessFootballMath.PITCH_RECT
	assert(pitch.size == Vector2(2480.0, 1680.0))
	assert(pitch.get_center() == Vector2(1320.0, 790.0))
	assert(is_equal_approx(game.presentation_3d.field_depth, pitch.size.y * ChessFootball3DPresenter.WORLD_SCALE))
	assert(ChessFootballMath.in_goal_mouth(ChessFootballMath.goal_center(0)))
	for team in game.teams:
		var keeper: Footballer = team[0]
		var defender: Footballer = team[1]
		var midfielder: Footballer = team[2]
		var wing: Footballer = team[3]
		var forward: Footballer = team[4]
		assert(absf(keeper.home_position.y - pitch.get_center().y) < 0.01)
		assert(wing.home_position.y - defender.home_position.y > 950.0)
		assert(midfielder.home_position.y - forward.home_position.y > 290.0)
		for player in team:
			assert(pitch.has_point(player.global_position))
	# A midfielder in possession should have genuinely distinct passing lanes.
	var carrier: Footballer = game.teams[0][2]
	game.ball.attach_to(carrier)
	var support_def: Vector2 = game._ai_support_target(game.teams[0][1])
	var support_wing: Vector2 = game._ai_support_target(game.teams[0][3])
	var support_forward: Vector2 = game._ai_support_target(game.teams[0][4])
	assert(support_wing.y - support_def.y > 650.0)
	assert(support_def.y + 130.0 < support_forward.y)
	assert(support_forward.y + 130.0 < support_wing.y)
	for p in [support_def, support_forward, support_wing]:
		assert(pitch.has_point(p))
	# The far-side non-pressing defenders must not collapse into the dribbler.
	assert(game.AI_DEFENSIVE_SHIFT_RATIO <= 0.17)
	# Even with generous lanes, two AI teammates can briefly end up at
	# the same spot. Their future destination must be separated smoothly.
	var clustered: Footballer = game.teams[0][1]
	var other: Footballer = game.teams[0][3]
	var same_spot := pitch.get_center() + Vector2(-360.0, -240.0)
	clustered.global_position = same_spot + Vector2(-8.0, 0.0)
	other.global_position = same_spot
	var safer: Vector2 = game._ai_spaced_target(clustered, same_spot)
	assert(safer.distance_to(same_spot) >= 105.0)
	assert(safer.y < same_spot.y)
	assert(pitch.has_point(safer))
	# This is not a universal force field: a free lane is not adjusted,
	# and the ball carrier retains direct dribble control.
	other.global_position = pitch.get_center() + Vector2(900.0, 620.0)
	var free_target := pitch.position + Vector2(180.0, 160.0)
	assert(game._ai_spaced_target(clustered, free_target).distance_to(free_target) < 0.01)
	assert(game._ai_spaced_target(carrier, same_spot) == same_spot)
	# The migration contract must preserve every actual 5v5 home coordinate
	# and describe a well-spaced mirrored 4-3-3 on a larger, centred pitch.
	assert(game.debug_team_counts() == [5, 5])
	assert(Formation.FIVE_ROLES.size() == 5)
	assert(Formation.ELEVEN_ROLES.size() == 11)
	for team_id in range(2):
		for index in range(5):
			var actor: Footballer = game.teams[team_id][index]
			assert(actor.role == Formation.role_for(5, index))
			assert(actor.home_position.distance_to(
				Formation.home_position(5, team_id, index, pitch)
			) < 0.01)
	var full_pitch: Rect2 = Formation.ELEVEN_PITCH_RECT
	assert(full_pitch.size == Vector2(4000.0, 2600.0))
	assert(full_pitch.get_center() == pitch.get_center())
	assert(absf(full_pitch.size.x / full_pitch.size.y - 105.0 / 68.0) < 0.01)
	for team_id in range(2):
		var positions: Array[Vector2] = []
		for index in range(11):
			var pos: Vector2 = Formation.home_position(11, team_id, index, full_pitch)
			var opposite: Vector2 = Formation.home_position(11, 1 - team_id, index, full_pitch)
			assert(full_pitch.has_point(pos))
			assert(absf(pos.x + opposite.x - full_pitch.position.x - full_pitch.end.x) < 0.01)
			assert(absf(pos.y - opposite.y) < 0.01)
			for teammate in positions:
				assert(pos.distance_to(teammate) > 350.0)
			positions.append(pos)
		assert(Formation.role_for(11, 0) == "keeper")
		assert(positions.size() == 11)
	print("FOOTBALL_WIDTH=%.0f SUPPORT_SPREAD=%.0f" % [
		pitch.size.y, support_wing.y - support_def.y
	])
	print("chess-football pitch spacing smoke: OK")
	quit(0)
