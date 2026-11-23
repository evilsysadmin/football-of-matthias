extends RefCounted

# The existing manager journal continues to own the original 54 profiles
# (nine per club). This Godot-only optional 4-3-3 adds three NEW players
# per club without presenting an unversioned manager roster migration.
const ROSTER_PATH := "res://data/scouting_rosters_v1.json"
# Separate Godot presentation extension: manager's canonical 54 profiles
# remain byte-for-byte identical. Transfer-aware roster writes can later
# migrate this identity-keyed property through an explicit contract.
const SHIRT_NUMBERS_PATH := "res://data/shirt_numbers_v1.json"
const QUICK_MATCH_CLUBS := ["fc-matthias", "real-enroque"]
const FIVE_ROLES := ["POR", "DEF", "MED", "MED", "DEL"]
const ELEVEN_ROLES := ["POR", "DEF", "DEF", "DEF", "DEF", "MED", "MED", "MED", "DEL", "DEL", "DEL"]
const ATTRIBUTES := ["pace", "stamina", "technique", "passing", "shooting", "tackling", "keeping"]

static var _clubs: Dictionary = {}
static var _eleven: Dictionary = {}
static var _shirt_numbers: Dictionary = {}

static func _load_shirt_numbers() -> Dictionary:
	if not _shirt_numbers.is_empty():
		return _shirt_numbers
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(SHIRT_NUMBERS_PATH)
	)
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != 1:
		push_error("Invalid Football identity shirt number catalog")
		return {}
	var numbers: Variant = parsed.get("numbersByPlayerId")
	if not (numbers is Dictionary) or numbers.size() != 72:
		push_error("Incomplete Football shirt number catalog")
		return {}
	_shirt_numbers = numbers
	return _shirt_numbers

static func _load_clubs() -> Dictionary:
	if not _clubs.is_empty():
		return _clubs
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != 1:
		push_error("Invalid Football match scouting snapshot")
		return {}
	var value: Variant = parsed.get("clubs")
	var full: Variant = parsed.get("eleven")
	if not (value is Dictionary) or value.size() != 6 or not (full is Dictionary) or full.size() != 6:
		push_error("Incomplete Football match scouting catalog")
		return {}
	_clubs = value
	_eleven = full
	return _clubs

static func starter(team_id: int, squad_index: int, team_size: int = 5) -> Dictionary:
	if team_id < 0 or team_id >= QUICK_MATCH_CLUBS.size():
		return {}
	if team_size != 5 and team_size != 11:
		return {}
	var expected_roles: Array = ELEVEN_ROLES if team_size == 11 else FIVE_ROLES
	if squad_index < 0 or squad_index >= expected_roles.size():
		return {}
	var club_data: Dictionary = _load_clubs()
	var club_id: String = QUICK_MATCH_CLUBS[team_id]
	var squad: Variant = club_data.get(club_id)
	if not (squad is Array) or squad.size() != 9:
		push_error("Missing Football match roster")
		return {}
	var player: Variant = {}
	if team_size == 5:
		player = squad[squad_index]
	else:
		var eleven_data: Variant = _eleven.get(club_id)
		if not (eleven_data is Dictionary):
			return {}
		var lineup_ids: Variant = eleven_data.get("lineupIds")
		var extra: Variant = eleven_data.get("extraPlayers")
		if not (lineup_ids is Array) or lineup_ids.size() != 11 or not (extra is Array) or extra.size() != 3:
			return {}
		var wanted_id: String = String(lineup_ids[squad_index])
		for candidate in squad:
			if candidate is Dictionary and String(candidate.get("id", "")) == wanted_id:
				player = candidate
				break
		if player.is_empty():
			for candidate in extra:
				if candidate is Dictionary and String(candidate.get("id", "")) == wanted_id:
					player = candidate
					break
	if not (player is Dictionary) or player.is_empty():
		return {}
	var stats: Variant = player.get("scouting")
	if not (stats is Dictionary):
		return {}
	if String(player.get("role", "")) != String(expected_roles[squad_index]) or String(player.get("id", "")).is_empty():
		return {}
	# A shirt belongs to a roster identity, NEVER to the active formation
	# slot. Future lineup reshuffles and transfers must carry/assign this
	# explicit profile property, not regenerate squad_index + 1.
	var number_lookup: Dictionary = _load_shirt_numbers()
	var shirt_number: Variant = number_lookup.get(String(player.get("id", "")))
	if typeof(shirt_number) != TYPE_INT or int(shirt_number) < 1 or int(shirt_number) > 99:
		return {}
	for attribute in ATTRIBUTES:
		var value: Variant = stats.get(attribute)
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return {}
		var rating := float(value)
		if is_nan(rating) or is_inf(rating) or rating < 1.0 or rating > 99.0 or floorf(rating) != rating:
			return {}
	# Caller gets a resolved match profile without mutating shared source
	# JSON, cached manager data or the snapshot's byte-integrity digest.
	var resolved: Dictionary = player.duplicate()
	resolved["shirtNumber"] = int(shirt_number)
	return resolved
