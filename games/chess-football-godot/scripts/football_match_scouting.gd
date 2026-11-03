extends RefCounted

# Godot consumes a build-time snapshot generated from footballManagerRoster.js.
# Only FC Matthias and Real Enroque are selectable in the current quick match.
# All six clubs/54 identities are in the same canonical file for later use.
const ROSTER_PATH := "res://data/scouting_rosters_v1.json"
const QUICK_MATCH_CLUBS := ["fc-matthias", "real-enroque"]
const FORMATION_ROLES := ["POR", "DEF", "MED", "MED", "DEL"]
const ELEVEN_FORMATION_ROLES := ["POR", "DEF", "DEF", "DEF", "DEF", "MED", "MED", "MED", "EXT", "EXT", "DEL"]
const ATTRIBUTES := ["pace", "stamina", "technique", "passing", "shooting", "tackling", "keeping"]

static var _clubs: Dictionary = {}
static var _eleven: Dictionary = {}

static func _load_clubs() -> Dictionary:
	if not _clubs.is_empty():
		return _clubs
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != 1:
		push_error("Invalid Football match scouting snapshot")
		return {}
	var value: Variant = parsed.get("clubs")
	if not (value is Dictionary) or value.size() != 6:
		push_error("Incomplete Football match scouting catalog")
		return {}
	var candidate_eleven: Variant = parsed.get("eleven", {})
	if not (candidate_eleven is Dictionary):
		push_error("Invalid Football 11v11 match scouting entries")
		return {}
	_eleven = candidate_eleven
	_clubs = value
	return _clubs

static func starter(team_id: int, squad_index: int, team_size: int = 5) -> Dictionary:
	if team_id < 0 or team_id >= QUICK_MATCH_CLUBS.size():
		return {}
	var expected_roles: Array
	match team_size:
		5:
			expected_roles = FORMATION_ROLES
		11:
			expected_roles = ELEVEN_FORMATION_ROLES
		_:
			return {}
	if squad_index < 0 or squad_index >= expected_roles.size():
		return {}
	var clubs: Dictionary = _load_clubs()
	if clubs.is_empty():
		return {}
	var squad: Variant = (
		clubs.get(QUICK_MATCH_CLUBS[team_id]) if team_size == 5
		else _eleven.get(QUICK_MATCH_CLUBS[team_id])
	)
	var expected_squad_size := 9 if team_size == 5 else 11
	if not (squad is Array) or squad.size() != expected_squad_size:
		push_error("Missing Football match roster for %d a side" % team_size)
		return {}
	var player: Variant = squad[squad_index]
	if not (player is Dictionary):
		return {}
	var stats: Variant = player.get("scouting")
	if not (stats is Dictionary):
		return {}
	if String(player.get("role", "")) != expected_roles[squad_index] or String(player.get("id", "")).is_empty():
		return {}
	for attribute in ATTRIBUTES:
		var value: Variant = stats.get(attribute)
		# Godot's JSON decoder represents whole numeric literals as floats.
		# Accept only finite integral 1..99 ratings, never fractional scouting.
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return {}
		var rating := float(value)
		if is_nan(rating) or is_inf(rating) or rating < 1.0 or rating > 99.0 or floorf(rating) != rating:
			return {}
	return player
