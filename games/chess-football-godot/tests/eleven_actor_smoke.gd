extends SceneTree

# Integration slice: the existing #50 4-3-3 catalog must drive REAL
# Footballer instances on #49's bigger pitch before any live toggle.
# No 11v11 match, AI, camera or restart activation in this smoke.
const Formation = preload("res://scripts/football_match_formation.gd")
const Scouting = preload("res://scripts/football_match_scouting.gd")
const STEP := 1.0 / 60.0

func _initialize() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var live = scene.instantiate()
	root.add_child(live)
	await process_frame
	await process_frame
	live.set_process(false)
	live.set_physics_process(false)
	assert(live.debug_team_counts() == [5, 5])
	var five_pitch: Rect2 = ChessFootballMath.PITCH_RECT
	var eleven_pitch: Rect2 = Formation.ELEVEN_PITCH_RECT
	assert(eleven_pitch.size == Vector2(4000.0, 2600.0))
	assert(eleven_pitch.get_center() == five_pitch.get_center())
	assert(ChessFootballMath.clamp_to_pitch(Vector2(-100.0, -100.0)) == Vector2(100.0, -30.0))
	assert(ChessFootballMath.clamp_to_pitch(Vector2(-100.0, -100.0), eleven_pitch) == Vector2(-100.0, -100.0))
	var ids: Dictionary = {}
	var created: Array[Footballer] = []
	var team_actors: Array[Array] = [[], []]
	for team_id in range(2):
		for index in range(11):
			var profile: Dictionary = Scouting.starter(team_id, index, 11)
			assert(not profile.is_empty())
			var role: String = Formation.role_for(11, index)
			var point: Vector2 = Formation.home_position(11, team_id, index, eleven_pitch)
			var actor := Footballer.new()
			root.add_child(actor)
			actor.configure(team_id, index, role, point, Color(0.24, 0.44, 0.88), 11)
			actor.set_process(false)
			assert(actor.match_pitch == eleven_pitch)
			assert(actor.scouting_player_id == String(profile["id"]))
			assert(actor.scouting_player_name == String(profile["name"]))
			assert(actor.scouting_pace == int(profile["scouting"]["pace"]))
			assert(actor.scouting_endurance == int(profile["scouting"]["stamina"]))
			assert(actor.scouting_technique == int(profile["scouting"]["technique"]))
			assert(actor.scouting_passing == int(profile["scouting"]["passing"]))
			assert(actor.scouting_shooting == int(profile["scouting"]["shooting"]))
			assert(actor.scouting_tackling == int(profile["scouting"]["tackling"]))
			assert(actor.scouting_keeping == int(profile["scouting"]["keeping"]))
			assert(not ids.has(actor.scouting_player_id))
			ids[actor.scouting_player_id] = true
			assert(eleven_pitch.has_point(actor.global_position))
			created.append(actor)
			team_actors[team_id].append(actor)
	assert(created.size() == 22 and ids.size() == 22)
	assert(team_actors[0][0].role == "keeper")
	assert(team_actors[0][8].role == "wing")
	assert(team_actors[0][10].role == "forward")
	# A real XI human winger can advance in the new wide left flank rather
	# than being teleported to the old five-a-side touchline.
	var winger: Footballer = team_actors[0][8]
	winger.global_position = Vector2(-320.0, -280.0)
	winger.velocity = Vector2.ZERO
	for tick in range(40):
		winger.move_human(STEP, Vector2.RIGHT, false)
	assert(winger.global_position.x < five_pitch.position.x)
	assert(eleven_pitch.has_point(winger.global_position))
	# The same enlarged field applies to a real CPU actor.
	var rival: Footballer = team_actors[1][8]
	rival.global_position = Vector2(eleven_pitch.end.x - 220.0, eleven_pitch.get_center().y)
	rival.velocity = Vector2.ZERO
	for tick in range(40):
		rival.move_ai(STEP, Vector2(eleven_pitch.end.x - 100.0, rival.global_position.y), 0.84)
	assert(rival.global_position.x > five_pitch.end.x)
	assert(eleven_pitch.has_point(rival.global_position))
	# The old playable team still has its five original identities and
	# movement limits; its keeper and scoring geometry remain unchanged.
	for team_id in range(2):
		for i in range(5):
			var old: Footballer = live.teams[team_id][i]
			assert(old.match_pitch == five_pitch)
			assert(old.scouting_player_id == String(Scouting.starter(team_id, i)["id"]))
	var legacy: Footballer = live.teams[0][1]
	legacy.global_position = Vector2(-320.0, -280.0)
	legacy.move_human(STEP, Vector2.RIGHT, false)
	assert(legacy.global_position.x >= five_pitch.position.x + 20.0)
	assert(legacy.global_position.y >= five_pitch.position.y + 20.0)
	# At the new full-pitch edge, a real actor is still bounded safely.
	winger.global_position = Vector2(eleven_pitch.end.x + 30.0, eleven_pitch.end.y + 30.0)
	winger.move_human(STEP, Vector2.RIGHT, false)
	assert(winger.global_position.x <= eleven_pitch.end.x - 20.0)
	assert(winger.global_position.y <= eleven_pitch.end.y - 20.0)
	print("FOOTBALL_ELEVEN_ACTORS_OK real=22 distinct=22 wide_human=1 wide_cpu=1 live_five=unchanged")
	quit(0)
