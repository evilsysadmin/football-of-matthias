extends SceneTree
const Formation = preload("res://scripts/football_match_formation.gd")
const Scouting = preload("res://scripts/football_match_scouting.gd")
const EXPECTED_ROLES := ["POR", "DEF", "DEF", "DEF", "DEF", "MED", "MED", "MED", "EXT", "EXT", "DEL"]
const MATCH_ROLES := ["keeper", "defender", "defender", "defender", "defender", "midfielder", "midfielder", "midfielder", "wing", "wing", "forward"]

func _initialize() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var match_node = scene.instantiate()
	root.add_child(match_node)
	await process_frame
	await process_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	# This slice does NOT activate 11v11 on the live pitch.
	assert(match_node.debug_team_counts() == [5, 5])
	assert(ChessFootballMath.PITCH_RECT.size == Vector2(2480.0, 1680.0))
	var full_pitch: Rect2 = Formation.ELEVEN_PITCH_RECT
	assert(full_pitch.get_center() == ChessFootballMath.PITCH_RECT.get_center())
	var all_ids := {}
	for team_id in range(2):
		var team_ids := {}
		for index in range(11):
			var profile: Dictionary = Scouting.starter(team_id, index, 11)
			assert(not profile.is_empty())
			assert(String(profile["role"]) == EXPECTED_ROLES[index])
			assert(Formation.role_for(11, index) == MATCH_ROLES[index])
			assert(String(profile["name"]).length() > 5)
			assert(String(profile["bio"]).length() > 20)
			var player_id: String = String(profile["id"])
			assert(not team_ids.has(player_id))
			assert(not all_ids.has(player_id))
			team_ids[player_id] = true
			all_ids[player_id] = true
			var stats: Dictionary = profile["scouting"]
			assert(stats.size() == 7)
			for key in Scouting.ATTRIBUTES:
				assert(int(stats[key]) >= 1 and int(stats[key]) <= 99)
			var point: Vector2 = Formation.home_position(11, team_id, index, full_pitch)
			assert(full_pitch.has_point(point))
			if index < 5:
				assert(int(stats["keeping"]) > 1)
		assert(team_ids.size() == 11)
		# The current five identities, ratings and order never change.
		for index in range(5):
			var five: Dictionary = Scouting.starter(team_id, index)
			assert(five == Scouting.starter(team_id, index, 5))
			assert(String(five["id"]) == match_node.teams[team_id][index].scouting_player_id)
			assert(five["scouting"] == Scouting.starter(team_id, index, 5)["scouting"])
	assert(all_ids.size() == 22)
	assert(Scouting.starter(0, 11, 11).is_empty())
	assert(Scouting.starter(0, 5, 5).is_empty())
	assert(Scouting.starter(0, 0, 8).is_empty())
	# One actual Footballer receives the future lineup profile end-to-end,
	# exercising configure and all seven skill fields without spawning a match.
	var wing_profile: Dictionary = Scouting.starter(0, 8, 11)
	var wing := Footballer.new()
	root.add_child(wing)
	wing.configure(0, 8, "wing", Formation.home_position(11, 0, 8, full_pitch), Color.BLUE, 11)
	assert(wing.scouting_player_id == wing_profile["id"])
	assert(wing.scouting_player_name == wing_profile["name"])
	assert(wing.scouting_technique == int(wing_profile["scouting"]["technique"]))
	assert(wing.scouting_passing == int(wing_profile["scouting"]["passing"]))
	assert(wing.scouting_shooting == int(wing_profile["scouting"]["shooting"]))
	assert(wing.scouting_tackling == int(wing_profile["scouting"]["tackling"]))
	assert(wing.scouting_keeping == int(wing_profile["scouting"]["keeping"]))
	print("FOOTBALL_ELEVEN_LINEUP_OK team_players=11 unique=22 roles=4-3-3 live=5v5")
	quit(0)
