extends SceneTree

# Offline candidate review only: no Web export flag, no R2 requests, no
# public installation. Run with the six local candidate sheets plus exact
# approved V5 and dense originals, using the normal Godot scene and mesh.
# godot --path games/chess-football-godot --resolution 1280x720 --script res://scripts/review_xi_directional_candidates.gd -- CANDIDATES V5 DENSE OUTPUT
const VIEWS := ["side", "front", "front_diagonal", "back", "back_diagonal"]
const MOVES := [Vector2.RIGHT, Vector2.DOWN, Vector2(1, 1), Vector2.UP, Vector2(1, -1)]
const CLUBS := ["fc_matthias", "real_enroque"]
const EXPECTED := [24, 16, 24, 24, 24]

static func build_preview_bank(original: SpriteFrames, rows: Dictionary) -> SpriteFrames:
	# Build the entire replacement on a copy. Any missing/invalid view leaves
	# the original untouched. This helper is not an approval or release gate.
	if original == null or rows.size() != VIEWS.size():
		return null
	for i in range(VIEWS.size()):
		var view: String = VIEWS[i]
		var row: Variant = rows.get(view)
		if not row is Array or row.size() != EXPECTED[i]:
			return null
		for texture in row:
			if not texture is Texture2D or texture.get_size() != Vector2(128, 144):
				return null
		for base in [&"run", &"sprint"]:
			var name := ChessFootballRunDirection.animation_for(base, view)
			if not original.has_animation(name) or original.get_frame_count(name) < 1:
				return null
	var result := original.duplicate() as SpriteFrames
	for view in VIEWS:
		var row: Array = rows[view]
		for base in [&"run", &"sprint"]:
			var name := ChessFootballRunDirection.animation_for(base, view)
			var fps := original.get_animation_speed(name)
			var old_count := original.get_frame_count(name)
			result.clear(name)
			result.set_animation_loop(name, true)
			result.set_animation_speed(name, fps * float(row.size()) / float(old_count))
			for texture in row:
				result.add_frame(name, texture)
	return result


func _load_club(club: int, args: PackedStringArray) -> Dictionary:
	var rows := {}
	var v5meta := ChessFootballHeroV5R2.sheet_meta(club, "locomotion")
	var v5 := ChessFootballR2AtlasLoader.decode_verified_webp(
		FileAccess.get_file_as_bytes(args[1].path_join(String(v5meta.get("url", "")).get_file())),
		v5meta, ChessFootballHeroV5R2.TRUSTED_ROOT)
	var original := ChessFootballHeroV5R2.frames_from_image(v5, "locomotion")
	if original.size() != 48:
		return {}
	rows["front"] = original.slice(16, 32)
	var meta := ChessFootballDenseV1R2.sheet_meta(club, &"run_front_diagonal")
	var diagonal := ChessFootballR2AtlasLoader.decode_verified_webp(
		FileAccess.get_file_as_bytes(args[2].path_join(String(meta.get("url", "")).get_file())),
		meta, ChessFootballDenseV1R2.TRUSTED_ROOT)
	rows["front_diagonal"] = ChessFootballDenseV1R2.frames_from_image(diagonal, 24)
	for view in ["side", "back", "back_diagonal"]:
		var file: String = CLUBS[club] + "_run_" + view + "_24_candidate_v3.webp"
		var raw := FileAccess.get_file_as_bytes(args[0].path_join(file))
		var image := Image.new()
		if raw.is_empty() or raw.size() > ChessFootballR2AtlasLoader.MAX_PAYLOAD_BYTES or image.load_webp_from_buffer(raw) != OK:
			printerr("Cannot decode candidate ", file)
			return {}
		rows[view] = ChessFootballDenseV1R2.frames_from_image(image, 24)
		if rows[view].size() != 24:
			printerr("Invalid candidate geometry ", file)
			return {}
	return rows


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or DisplayServer.get_name() == "headless":
		printerr("Expected windowed Godot and -- CANDIDATES V5 DENSE OUTPUT")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(args[3]) != OK:
		quit(2)
		return
	var scene := load("res://main.tscn") as PackedScene
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	var stage: ChessFootball3DPresenter = game.presentation_3d
	var prepared := {}
	for club in range(2):
		var rows := _load_club(club, args)
		if rows.is_empty():
			quit(1)
			return
		for athlete: Footballer in game.teams[club]:
			if athlete.role == "keeper":
				continue
			var driver: AnimatedSprite3D = stage.player_sprites[athlete.get_instance_id()]
			var bank := build_preview_bank(driver.sprite_frames, rows)
			if bank == null:
				quit(1)
				return
			prepared[athlete.get_instance_id()] = bank
	if prepared.size() != 20:
		quit(1)
		return
	for id in prepared:
		var driver: AnimatedSprite3D = stage.player_sprites[id]
		driver.sprite_frames = prepared[id]
	# Compare all five orientations in ONE actual pitch/camera frame, both
	# clubs. This is a controlled visual fixture, not live match gameplay.
	game.ball.release(Vector2.ZERO, 0.0)
	for team in game.teams:
		for athlete: Footballer in team:
			athlete.set_process(false)
			athlete.set_physics_process(false)
			athlete.global_position = Vector2(-9999, -9999)
			athlete.velocity = Vector2.ZERO
			athlete.action_lock_seconds = 0.0
	var centre: Vector2 = game.match_pitch.get_center()
	for club in range(2):
		for i in range(VIEWS.size()):
			var player: Footballer = game.teams[club][i + 1]
			player.global_position = centre + Vector2((i - 2) * 170.0, (club * 2 - 1) * 150.0)
			player.velocity = MOVES[i].normalized() * player.base_speed
			player.last_sprinting = false
			stage.player_run_views[player.get_instance_id()] = VIEWS[i]
	for mode in ["broadcast", "tactical"]:
		stage._sync_camera(10.0, mode)
		for tick in range(24):
			stage.sync_presentation(1.0 / 30.0, mode)
			for club in range(2):
				for i in range(VIEWS.size()):
					var player: Footballer = game.teams[club][i + 1]
					var id: int = player.get_instance_id()
					var driver: AnimatedSprite3D = stage.player_sprites[id]
					var wanted := ChessFootballRunDirection.animation_for(&"run", VIEWS[i])
					if driver.animation != wanted or driver.sprite_frames.get_frame_count(wanted) != EXPECTED[i]:
						printerr("Wrong visible bank ", club, " ", VIEWS[i], " ", driver.animation)
						quit(1)
						return
					var material: StandardMaterial3D = stage.xi_raster_meshes[id].material_override
					if material.albedo_texture != driver.sprite_frames.get_frame_texture(wanted, driver.frame):
						printerr("Wrong mesh texture ", club, " ", VIEWS[i])
						quit(1)
						return
			await process_frame
			await RenderingServer.frame_post_draw
			var capture := game.get_viewport().get_texture().get_image()
			if capture.save_png(args[3].path_join("%s-%02d.png" % [mode, tick])) != OK:
				quit(1)
				return
	print("FOOTBALL_XI_CANDIDATE_PREVIEW_OK clubs=2 views=5 captures=48 review_only=true")
	quit(0)
