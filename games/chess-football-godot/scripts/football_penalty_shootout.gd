extends RefCounted

# Rules-only contract for an OPTIONAL penalty shootout. This class never
# touches Match goals, career journals, physics, or AI decisions. The future
# Godot match adapter must resolve a real ball event BEFORE recording a kick.
const REGULATION_KICKS := 5
const OUTCOME_GOAL := "goal"
const OUTCOME_SAVED := "saved"
const OUTCOME_MISSED := "missed"

var scores: Array[int] = [0, 0]
var kicks_taken: Array[int] = [0, 0]
var next_team_id: int = 0
var next_attempt_id: int = 0
var finished: bool = false
var winner_team_id: int = -1
var history: Array[Dictionary] = []


func _init() -> void:
	reset()


func reset(first_team_id: int = 0) -> void:
	assert(first_team_id == 0 or first_team_id == 1)
	scores = [0, 0]
	kicks_taken = [0, 0]
	next_team_id = first_team_id
	# Never reuse an ID on retry; late physics/goal callbacks from the old
	# session must not count as the first kick in a newly started shootout.
	next_attempt_id += 1
	finished = false
	winner_team_id = -1
	history.clear()


func current_attempt() -> Dictionary:
	if finished:
		return {}
	return {
		"id": next_attempt_id,
		"team_id": next_team_id,
		"kick_number": kicks_taken[next_team_id] + 1,
		"sudden_death": kicks_taken[0] >= REGULATION_KICKS and kicks_taken[1] >= REGULATION_KICKS,
	}


func record_attempt(attempt_id: int, team_id: int, outcome: String) -> bool:
	# A kick is committed only once by its live ID, team, and physical
	# outcome. A stale/double referee callback cannot score again.
	if finished or team_id != next_team_id or attempt_id != next_attempt_id:
		return false
	if outcome != OUTCOME_GOAL and outcome != OUTCOME_SAVED and outcome != OUTCOME_MISSED:
		return false
	var attempt: Dictionary = current_attempt()
	kicks_taken[team_id] += 1
	if outcome == OUTCOME_GOAL:
		scores[team_id] += 1
	attempt["outcome"] = outcome
	history.append(attempt)
	_update_winner()
	next_attempt_id += 1
	if not finished:
		next_team_id = 1 - next_team_id
	return true


func _update_winner() -> void:
	# During the first five per side a lead is decisive only when the
	# opponent cannot equalize with ALL remaining regulation kicks.
	if kicks_taken[0] <= REGULATION_KICKS and kicks_taken[1] <= REGULATION_KICKS:
		for team_id in range(2):
			var opponent: int = 1 - team_id
			var opponent_remaining: int = REGULATION_KICKS - kicks_taken[opponent]
			if scores[team_id] > scores[opponent] + opponent_remaining:
				winner_team_id = team_id
				finished = true
				return
	# Sudden death must resolve ONLY after each side has taken the same
	# number of kicks. Never award victory between paired attempts.
	if kicks_taken[0] >= REGULATION_KICKS and kicks_taken[0] == kicks_taken[1]:
		if scores[0] != scores[1]:
			winner_team_id = 0 if scores[0] > scores[1] else 1
			finished = true


func snapshot() -> Dictionary:
	return {
		"scores": scores.duplicate(),
		"kicks_taken": kicks_taken.duplicate(),
		"finished": finished,
		"winner_team_id": winner_team_id,
		"current_attempt": current_attempt(),
		"history": history.duplicate(true),
	}
