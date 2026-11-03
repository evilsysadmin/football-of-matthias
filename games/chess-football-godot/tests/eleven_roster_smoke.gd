extends SceneTree

const Scouting = preload("res://scripts/football_match_scouting.gd")
const Formation = preload("res://scripts/football_match_formation.gd")

func _initialize() -> void:
	var expected_roles := ["POR", "DEF", "DEF", "DEF", "DEF", "MED", "MED", "MED", "DEL", "DEL", "DEL"]
	var legacy_indices := [0, 1, 6, -1, -1, 2, 3, 7, 4, 8, -1]
	for team_id in range(2):
		var seen: Dictionary = {}
		for i in range(11):
			var profile: Dictionary = Scouting.starter(team_id, i, 11)
			assert(not profile.is_empty())
			assert(String(profile["role"]) == expected_roles[i])
			assert(FOOTBALL_ELEVEN_ROLE_MATCH(Formation.role_for(11, i), expected_roles[i]))
			var player_id: String = profile["id"]
			assert(not seen.has(player_id))
			seen[player_id] = true
			if legacy_indices[i] >= 0:
				var original: Dictionary = Scouting.starter(team_id, legacy_indices[i], 5) if legacy_indices[i] < 5 else {}
				if original.is_empty():
					# The legacy reserve players are exported, but never 5v5 starters.
					assert(String(profile["id"]).contains("-def-2") or String(profile["id"]).contains("-med-3") or String(profile["id"]).contains("-del-2"))
				else:
					assert(profile["id"] == original["id"])
		assert(seen.size() == 11)
		assert(Scouting.starter(team_id, 11, 11).is_empty())
		assert(Scouting.starter(team_id, 5, 5).is_empty())
		assert(Scouting.starter(team_id, 0, 7).is_empty())
	assert(Scouting.starter(-1, 0, 11).is_empty())
	print("FOOTBALL_ELEVEN_ROSTER_OK 2 clubs / 22 unique starters")
	quit(0)

func FOOTBALL_ELEVEN_ROLE_MATCH(runtime_role: String, scouting_role: String) -> bool:
	if runtime_role == "keeper":
		return scouting_role == "POR"
	if runtime_role == "defender":
		return scouting_role == "DEF"
	if runtime_role == "midfielder":
		return scouting_role == "MED"
	return (runtime_role == "wing" or runtime_role == "forward") and scouting_role == "DEL"
