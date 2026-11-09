extends SceneTree

const Shootout = preload("res://scripts/football_penalty_shootout.gd")


func _kick(shootout: RefCounted, team_id: int, outcome: String) -> void:
	var attempt: Dictionary = shootout.current_attempt()
	assert(attempt.get("team_id", -1) == team_id)
	assert(shootout.record_attempt(int(attempt["id"]), team_id, outcome))


func _initialize() -> void:
	var shootout = Shootout.new()
	var first: Dictionary = shootout.current_attempt()
	assert(first["team_id"] == 0 and first["kick_number"] == 1)
	assert(not first["sudden_death"])
	var first_id: int = int(first["id"])
	assert(not shootout.record_attempt(first_id + 1, 0, "goal"))
	assert(not shootout.record_attempt(first_id, 1, "goal"))
	assert(not shootout.record_attempt(first_id, 0, "unknown"))
	assert(shootout.snapshot()["scores"] == [0, 0])
	assert(shootout.snapshot()["kicks_taken"] == [0, 0])
	_kick(shootout, 0, "goal")
	assert(not shootout.record_attempt(first_id, 0, "goal"))
	assert(shootout.snapshot()["scores"] == [1, 0])
	assert(shootout.current_attempt()["team_id"] == 1)
	# A game may be clinched before all ten kicks. At 3-0 after three
	# apiece, only two regulation attempts remain for the trailing side.
	_kick(shootout, 1, "saved")
	_kick(shootout, 0, "goal")
	_kick(shootout, 1, "missed")
	_kick(shootout, 0, "goal")
	assert(not shootout.finished)
	_kick(shootout, 1, "saved")
	assert(shootout.finished and shootout.winner_team_id == 0)
	assert(shootout.snapshot()["scores"] == [3, 0])
	assert(shootout.snapshot()["kicks_taken"] == [3, 3])
	assert(shootout.current_attempt().is_empty())
	assert(not shootout.record_attempt(first_id, 0, "goal"))
	assert(shootout.snapshot()["history"].size() == 6)

	# Retry invalidates old IDs and removes all past scoring/events.
	shootout.reset(1)
	assert(shootout.snapshot()["scores"] == [0, 0])
	assert(shootout.snapshot()["history"].is_empty())
	assert(shootout.current_attempt()["team_id"] == 1)
	assert(shootout.current_attempt()["id"] != first_id)
	assert(not shootout.record_attempt(first_id, 0, "goal"))
	# CPU-first and opponent early victory also work.
	for i in range(3):
		_kick(shootout, 1, "goal")
		_kick(shootout, 0, "missed")
	assert(shootout.finished and shootout.winner_team_id == 1)
	assert(shootout.snapshot()["kicks_taken"] == [3, 3])

	# Five-five tie continues to sudden death. The first extra goal
	# MUST NOT win before the opponent has taken its matching shot.
	shootout.reset()
	for i in range(5):
		_kick(shootout, 0, "goal")
		_kick(shootout, 1, "goal")
	assert(not shootout.finished)
	assert(shootout.current_attempt()["sudden_death"])
	assert(shootout.current_attempt()["kick_number"] == 6)
	var extra_id: int = int(shootout.current_attempt()["id"])
	_kick(shootout, 0, "goal")
	assert(not shootout.finished)
	assert(not shootout.current_attempt()["sudden_death"] == false)
	assert(shootout.current_attempt()["team_id"] == 1)
	_kick(shootout, 1, "saved")
	assert(shootout.finished and shootout.winner_team_id == 0)
	assert(shootout.snapshot()["scores"] == [6, 5])
	assert(shootout.snapshot()["kicks_taken"] == [6, 6])
	assert(not shootout.record_attempt(extra_id, 0, "goal"))

	# Equal sudden-death pairs continue; misses and saves are both
	# scoreless, but their authentic outcomes stay distinct in history.
	shootout.reset()
	for i in range(5):
		_kick(shootout, 0, "missed")
		_kick(shootout, 1, "saved")
	assert(not shootout.finished)
	_kick(shootout, 0, "saved")
	_kick(shootout, 1, "missed")
	assert(not shootout.finished)
	assert(shootout.snapshot()["scores"] == [0, 0])
	_kick(shootout, 0, "missed")
	_kick(shootout, 1, "goal")
	assert(shootout.finished and shootout.winner_team_id == 1)
	assert(shootout.snapshot()["kicks_taken"] == [7, 7])
	assert(shootout.snapshot()["history"].size() == 14)

	print("FOOTBALL_PENALTY_SHOOTOUT_RULES_OK turn_order=1 early_clinch=1 sudden_death=1 stale_callback=1 replay_isolation=1")
	quit(0)
