extends SceneTree

# Offline candidate review only: no Web export flag, no R2 requests, no
# public installation. Strict review requires eight local Dense-style sheets
# plus the two approved Dense front-diagonal originals. An optional V5 dir
# explicitly enables comparison with the OLD frontal art, never parity proof.
# godot --path games/chess-football-godot --resolution 1280x720 --script res://scripts/review_xi_directional_candidates.gd -- CANDIDATES DENSE OUTPUT [V5_COMPARISON]
const VIEWS := ["side", "front", "front_diagonal", "back", "back_diagonal"]
const MOVES := [Vector2.RIGHT, Vector2.DOWN, Vector2(1, 1), Vector2.UP, Vector2(1, -1)]
const CLUBS := ["fc_matthias", "real_enroque"]
const EXPECTED := [24, 24, 24, 24, 24]

const DenseRunBank = preload("res://scripts/football_dense_run_bank.gd")
const DirectionPack = preload("res://scripts/football_dense_direction_pack.gd")

static func expected_count(view: String, compare_v5: bool = false) -> int:
	return DenseRunBank.expected_count(view, compare_v5)

static func build_preview_bank(original: SpriteFrames, rows: Dictionary, compare_v5: bool = false) -> SpriteFrames:
	return DenseRunBank.build_bank(original, rows, compare_v5)


func _load_club(club: int, args: PackedStringArray) -> Dictionary:
	var rows := {}
	var compare_v5 := args.size() == 4
	if compare_v5:
		var v5meta := ChessFootballHeroV5R2.sheet_meta(club, "locomotion")
		var v5 := ChessFootballR2AtlasLoader.decode_verified_webp(
			FileAccess.get_file_as_bytes(args[3].path_join(String(v5meta.get("url", "")).get_file())),
			v5meta, ChessFootballHeroV5R2.TRUSTED_ROOT)
		var original := ChessFootballHeroV5R2.frames_from_image(v5, "locomotion")
		if original.size() != 48:
			return {}
		rows["front"] = original.slice(16, 32)
	var meta := ChessFootballDenseV1R2.sheet_meta(club, &"run_front_diagonal")
	var diagonal := ChessFootballR2AtlasLoader.decode_verified_webp(
		FileAccess.get_file_as_bytes(args[1].path_join(String(meta.get("url", "")).get_file())),
		meta, ChessFootballDenseV1R2.TRUSTED_ROOT)
	rows["front_diagonal"] = ChessFootballDenseV1R2.frames_from_image(diagonal, 24)
	var candidate_views := ["side", "back", "back_diagonal"] if compare_v5 else ["side", "front", "back", "back_diagonal"]
	for view in candidate_views:
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
	if args.size() not in [3, 4] or DisplayServer.get_name() == "headless":
		printerr("Expected windowed Godot and -- CANDIDATES DENSE OUTPUT [V5_COMPARISON]")
		quit(2)
		return
	var compare_v5 := args.size() == 4
	if compare_v5:
		print("FOOTBALL_XI_PREVIEW_MODE mixed_v5_front_comparison_not_parity")
	if DirAccess.make_dir_recursive_absolute(args[2]) != OK:
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
	var rows_by_club := {}
	if compare_v5:
		for club in range(2):
			var rows := _load_club(club, args)
			if rows.is_empty():
				quit(1)
				return
			rows_by_club[club] = rows
	else:
		# Strict mode now validates the exact published generation within
		# Godot as well as the upstream Python verification.
		rows_by_club = DirectionPack.load_pack(func(_club: int, view: String, filename: String) -> PackedByteArray:
			var path: String = args[1].path_join(filename) if view == "front_diagonal" else args[0].path_join(filename.replace("_v1.webp", "_candidate_v3.webp"))
			return FileAccess.get_file_as_bytes(path)
		)
		if rows_by_club.size() != 2:
			quit(1)
			return
		print("FOOTBALL_DENSE_PACK_SHA_OK clubs=2 sheets=10")
	if not DenseRunBank.install_all(game.teams, stage.player_sprites,
		stage.outfield_visual_phases, stage.outfield_visual_names, rows_by_club, compare_v5):
		printerr("Complete two-club locomotion transaction rejected")
		quit(1)
		return
	print("FOOTBALL_DENSE_RUN_BANK_INSTALLED clubs=2 outfield=20 review_only=true")
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
					if driver.animation != wanted or driver.sprite_frames.get_frame_count(wanted) != expected_count(VIEWS[i], compare_v5):
						printerr("Wrong visible bank ", club, " ", VIEWS[i], " ", driver.animation)
						quit(1)
						return
					var material: StandardMaterial3D = stage.xi_raster_meshes[id].material_override
					var source: Texture2D = driver.sprite_frames.get_frame_texture(wanted, driver.frame)
					# Rear views render a roster-numbered COPY, not the raw
					# atlas texture. Verify the exact source AND the existing
					# derived texture contract without disabling dorsals.
					var expected: Texture2D = stage._xi_numbered_rear_frame(player, source, wanted)
					if material.albedo_texture != expected or stage._xi_frame_texture(player, driver) != source:
						printerr("Wrong mesh texture ", club, " ", VIEWS[i])
						quit(1)
						return
					if VIEWS[i] in ["back", "back_diagonal"]:
						if player.shirt_number >= 1 and player.shirt_number <= 99:
							if expected == source or expected.get_size() != source.get_size():
								printerr("Missing derived dorsal texture ", club, " ", VIEWS[i])
								quit(1)
								return
							if expected.get_image().get_used_rect() != source.get_image().get_used_rect():
								printerr("Dorsal changed source silhouette bounds ", club, " ", VIEWS[i])
								quit(1)
								return
					elif expected != source:
						printerr("Unexpected dorsal on non-rear view ", club, " ", VIEWS[i])
						quit(1)
						return
			await process_frame
			await RenderingServer.frame_post_draw
			var capture := game.get_viewport().get_texture().get_image()
			if capture.save_png(args[2].path_join("%s-%s-%02d.png" % ["mixed-v5" if compare_v5 else "dense", mode, tick])) != OK:
				quit(1)
				return
	print("FOOTBALL_XI_CANDIDATE_PREVIEW_OK clubs=2 views=5 captures=48 review_only=true mixed_v5_front=" + str(compare_v5))
	quit(0)
