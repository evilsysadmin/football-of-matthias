extends RefCounted

# Godot consumes a build-time snapshot generated from footballManagerRoster.js.
# Only FC Matthias and Real Enroque are selectable in the current quick match.
# All six clubs/54 identities are in the same canonical file for later use.
const ROSTER_PATH := "res://data/scouting_rosters_v1.json"
const QUICK_MATCH_CLUBS := ["fc-matthias", "real-enroque"]
const FORMATION_ROLES := ["POR", "DEF", "MED", "MED", "DEL"]
const ATTRIBUTES := ["pace", "stamina", "technique", "passing", "shooting", "tackling", "keeping"]

static var _clubs: Dictionary = {}

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
	_clubs = value
	return _clubs

static func starter(team_id: int, squad_index: int) -> Dictionary:
	if team_id < 0 or team_id >= QUICK_MATCH_CLUBS.size():
		return {}
	if squad_index < 0 or squad_index >= FORMATION_ROLES.size():
		return {}
	var squad: Variant = _load_clubs().get(QUICK_MATCH_CLUBS[team_id])
	if not (squad is Array) or squad.size() != 9:
		push_error("Missing Football match roster")
		return {}
	var player: Variant = squad[squad_index]
	if not (player is Dictionary):
		return {}
	var stats: Variant = player.get("scouting")
	if not (stats is Dictionary):
		return {}
	if String(player.get("role", "")) != FORMATION_ROLES[squad_index] or String(player.get("id", "")).is_empty():
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
