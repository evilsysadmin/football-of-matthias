class_name FootballMatchFormation
extends RefCounted

# Future regulation-style 11-a-side field: approx. 105:68 aspect ratio.
# It shares the existing centre with the live 5v5 pitch, so ball/camera
# origins will not jump when the full-pitch migration is enabled.
# DO NOT switch the live pitch or actor count until AI, restarts, camera,
# 11 unique starters and the real Web visual gate have been integrated.
const ELEVEN_PITCH_RECT := Rect2(-680.0, -510.0, 4000.0, 2600.0)

# Formation order is deliberately stable. The keeper is always index zero.
# Current arcade lineup remains byte-for-byte equivalent to match.gd's
# previous normalized home coordinates.
const FIVE_ROLES := ["keeper", "defender", "midfielder", "wing", "forward"]
const FIVE_HOME := [
	Vector2(0.09, 0.50),
	Vector2(0.26, 0.20),
	Vector2(0.40, 0.53),
	Vector2(0.46, 0.80),
	Vector2(0.58, 0.34),
]

# Initial 4-3-3 candidate: defensive line, three midfielders, two wide
# forwards and a central striker. Reuses existing match AI role categories
# rather than introducing role strings the current runtime cannot handle.
const ELEVEN_ROLES := [
	"keeper",
	"defender", "defender", "defender", "defender",
	"midfielder", "midfielder", "midfielder",
	"wing", "wing", "forward",
]
const ELEVEN_HOME := [
	Vector2(0.055, 0.50),
	Vector2(0.21, 0.12),
	Vector2(0.20, 0.36),
	Vector2(0.20, 0.64),
	Vector2(0.21, 0.88),
	Vector2(0.37, 0.21),
	Vector2(0.35, 0.50),
	Vector2(0.37, 0.79),
	Vector2(0.52, 0.13),
	Vector2(0.52, 0.87),
	Vector2(0.57, 0.50),
]

static func roles_for_team_size(team_size: int) -> Array:
	match team_size:
		5:
			return FIVE_ROLES
		11:
			return ELEVEN_ROLES
	push_error("Unsupported football formation team size: %d" % team_size)
	return []

static func _home_slots(team_size: int) -> Array:
	match team_size:
		5:
			return FIVE_HOME
		11:
			return ELEVEN_HOME
	push_error("Unsupported football formation team size: %d" % team_size)
	return []

static func role_for(team_size: int, squad_index: int) -> String:
	var roles: Array = roles_for_team_size(team_size)
	assert(squad_index >= 0 and squad_index < roles.size())
	return String(roles[squad_index])

static func home_position(team_size: int, team_id: int, squad_index: int, pitch: Rect2) -> Vector2:
	assert(team_id == 0 or team_id == 1)
	var slots: Array = _home_slots(team_size)
	assert(squad_index >= 0 and squad_index < slots.size())
	var normalized: Vector2 = slots[squad_index]
	var ratio_x: float = normalized.x if team_id == 0 else 1.0 - normalized.x
	return Vector2(
		pitch.position.x + pitch.size.x * ratio_x,
		pitch.position.y + pitch.size.y * normalized.y,
	)

# Preview-only kickoff contract for 4-3-3. All outfielders must start in
# their own half; the kicking side places exactly one striker at midfield.
# The real 5v5 kickoff remains unchanged until the match migration is ready.
static func eleven_kickoff_position(team_id: int, squad_index: int, pitch: Rect2, kicking_team: int) -> Vector2:
	assert(team_id in [0, 1] and kicking_team in [0, 1])
	assert(squad_index >= 0 and squad_index < 11)
	var home: Vector2 = home_position(11, team_id, squad_index, pitch)
	if squad_index == 0:
		return home
	var center: Vector2 = pitch.get_center()
	var side := -1.0 if team_id == 0 else 1.0
	if team_id == kicking_team and squad_index == 10:
		return Vector2(center.x + side * 32.0, center.y)
	var offset := maxf(absf(home.x - center.x), 160.0 if team_id == kicking_team else 230.0)
	return Vector2(center.x + side * offset, home.y)
