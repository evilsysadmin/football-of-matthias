extends SceneTree

func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var game = packed.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	var directory := OS.get_environment("RUNNER_TEMP").path_join("football-dense-v1")
	var owner = game.ball.carrier
	var pack = preload("res://scripts/football_dense_direction_pack.gd")
	assert(pack.PINNED.size() == 8)
	var seen := {}
	for club in range(2):
		for view in ["side", "front", "front_diagonal", "back", "back_diagonal"]:
			var metadata: Dictionary = pack.sheet_meta(club, view)
			assert(not metadata.is_empty())
			assert(metadata["columns"] == 24 and metadata["rows"] == 1)
			assert(ChessFootballR2AtlasLoader.valid_metadata(metadata, ChessFootballDenseV1R2.TRUSTED_ROOT))
			seen[metadata["url"]] = true
	assert(seen.size() == 10)
	assert(pack.sheet_meta(-1, "side").is_empty())
	assert(pack.sheet_meta(0, "../side").is_empty())
	assert(pack.sheet_meta(0, "pass").is_empty())
	assert(pack.load_pack(func(_club: int, _view: String, _file: String) -> PackedByteArray:
		return PackedByteArray()
	).is_empty())
	var invalid := Image.create(3072, 144, false, Image.FORMAT_RGBA8)
	invalid.fill(Color.WHITE)
	var wrong_bytes: PackedByteArray = invalid.save_webp_to_buffer(true)
	assert(pack.load_pack(func(_club: int, _view: String, _file: String) -> PackedByteArray:
		return wrong_bytes
	).is_empty())
	print("FOOTBALL_DENSE_PACK_METADATA_OK sheets=10 missing_and_wrong_sha_rejected=true")
	# Correct dimensions alone are not sufficient: transparent sheets must
	# never replace visible fallback frames or advance the installed state.
	var blank_kick := Image.create(16 * 128, 144, false, Image.FORMAT_RGBA8)
	blank_kick.fill(Color.TRANSPARENT)
	var blank_diagonal := Image.create(24 * 128, 144, false, Image.FORMAT_RGBA8)
	blank_diagonal.fill(Color.TRANSPARENT)
	assert(ChessFootballDenseV1R2.frame_geometry_error(blank_diagonal, 24).begins_with("frame=1 "))
	assert(ChessFootballDenseV1R2.frame_geometry_error(blank_diagonal, 16) == "invalid_sheet_dimensions")
	assert(ChessFootballDenseV1R2.frame_geometry_error(blank_diagonal, 20) == "unsupported_frame_count")
	var geometry := Image.create(24 * 128, 144, false, Image.FORMAT_RGBA8)
	geometry.fill(Color.TRANSPARENT)
	for i in range(24):
		geometry.fill_rect(Rect2i(i * 128 + 4, 10, 90, 124), Color.WHITE)
	assert(ChessFootballDenseV1R2.frame_geometry_error(geometry, 24).is_empty())
	# A single one-pixel violation in a later frame rejects the whole sheet.
	geometry.set_pixel(15 * 128 + 3, 80, Color.WHITE)
	assert(ChessFootballDenseV1R2.frame_geometry_error(geometry, 24).begins_with("frame=16 "))
	assert(ChessFootballDenseV1R2.frames_from_image(geometry, 24).is_empty())
	print("FOOTBALL_DENSE_FRAME_GEOMETRY_OK one_pixel_margin=true exact_cell=true")
	for club in range(2):
		var actor: Footballer = game.teams[club][1]
		var sprite: AnimatedSprite3D = stage.player_sprites[actor.get_instance_id()]
		var keeper: AnimatedSprite3D = stage.player_sprites[game.teams[club][0].get_instance_id()]
		var keeper_before := keeper.sprite_frames.get_frame_texture(&"shoot", 0)
		var run_before := sprite.sprite_frames.get_frame_texture(&"run", 0)
		# A pass and a shot can be in flight when the second R2 sheet
		# arrives. Exercise both active action clocks independently.
		var shooter: Footballer = game.teams[club][2]
		var shot_driver: AnimatedSprite3D = stage.player_sprites[shooter.get_instance_id()]
		actor.play_action("pass", 0.58)
		shooter.play_action("shoot", 0.82)
		actor.action_lock_seconds = 0.58 * 0.40
		shooter.action_lock_seconds = 0.82 * 0.20
		stage._sync_visible_animation(actor.get_instance_id(), actor, sprite, &"pass", 0.0)
		stage._sync_visible_animation(shooter.get_instance_id(), shooter, shot_driver, &"shoot", 0.0)
		assert(sprite.frame == 4 and shot_driver.frame == 6)
		var fallback_pass := sprite.sprite_frames.get_frame_texture(&"pass", 4)
		var fallback_shoot := shot_driver.sprite_frames.get_frame_texture(&"shoot", 6)
		stage._on_dense_kick_ready(blank_kick, club, &"pass")
		assert(not stage._dense_kick_loaded.has(club))
		assert(not stage._dense_kick_pending.has(club))
		assert(sprite.sprite_frames.get_frame_texture(&"pass", 4) == fallback_pass)
		assert(shot_driver.sprite_frames.get_frame_texture(&"shoot", 6) == fallback_shoot)
		for action in ChessFootballDenseV1R2.ACTIONS:
			var meta := ChessFootballDenseV1R2.sheet_meta(club, action)
			assert(not meta.is_empty())
			var filename: String = String(meta["url"]).get_file()
			var decoded := ChessFootballR2AtlasLoader.decode_verified_webp(
				FileAccess.get_file_as_bytes(directory.path_join(filename)), meta, ChessFootballDenseV1R2.TRUSTED_ROOT)
			assert(decoded != null)
			stage._on_dense_kick_ready(decoded, club, action)
			if action == &"pass":
				assert(sprite.sprite_frames.get_frame_count(&"pass") == 8)
				assert(not stage._dense_kick_loaded.has(club))
				# A valid pass plus an invalid shoot must still be atomic.
				stage._on_dense_kick_ready(blank_kick, club, &"shoot")
				assert(not stage._dense_kick_loaded.has(club))
				assert(stage._dense_kick_pending[club].has(&"pass"))
				assert(not stage._dense_kick_pending[club].has(&"shoot"))
				assert(sprite.sprite_frames.get_frame_texture(&"pass", 4) == fallback_pass)
				assert(shot_driver.sprite_frames.get_frame_texture(&"shoot", 6) == fallback_shoot)
				assert(sprite.frame == 4 and shot_driver.frame == 6)
		assert(stage._dense_kick_loaded.has(club))
		assert(sprite.animation == &"pass" and sprite.frame == 9)
		assert(shot_driver.animation == &"shoot" and shot_driver.frame == 12)
		assert(float(stage.outfield_visual_phases[actor.get_instance_id()]) == 9.0)
		assert(float(stage.outfield_visual_phases[shooter.get_instance_id()]) == 12.0)
		assert(is_equal_approx(actor.action_lock_seconds, 0.58 * 0.40))
		assert(is_equal_approx(shooter.action_lock_seconds, 0.82 * 0.20))
		actor.action_lock_seconds = 0.0
		shooter.action_lock_seconds = 0.0
		for teammate: Footballer in game.teams[club]:
			if teammate.role == "keeper":
				continue
			var driver: AnimatedSprite3D = stage.player_sprites[teammate.get_instance_id()]
			for action in ChessFootballDenseV1R2.ACTIONS:
				assert(driver.sprite_frames.get_frame_count(action) == 16)
				assert(not driver.sprite_frames.get_animation_loop(action))
		assert(keeper.sprite_frames.get_frame_texture(&"shoot", 0) == keeper_before)
		assert(sprite.sprite_frames.get_frame_texture(&"run", 0) == run_before)
		assert(game.ball.carrier == owner)
		var diagonal_meta := ChessFootballDenseV1R2.sheet_meta(club, &"run_front_diagonal")
		assert(not diagonal_meta.is_empty())
		var diagonal := ChessFootballR2AtlasLoader.decode_verified_webp(
			FileAccess.get_file_as_bytes(directory.path_join(String(diagonal_meta["url"]).get_file())),
			diagonal_meta, ChessFootballDenseV1R2.TRUSTED_ROOT)
		assert(diagonal != null)
		var diagonal_count: int = sprite.sprite_frames.get_frame_count(&"run_front_diagonal")
		stage._on_dense_diagonal_ready(diagonal, club)
		assert(not stage._dense_diagonal_loaded.has(club))
		assert(sprite.sprite_frames.get_frame_count(&"run_front_diagonal") == diagonal_count)
		# Exercise arrival precedence with a synthetic V5 bank; the dense
		# poses themselves are actual SHA-verified public R2 textures.
		var v5: Array[Texture2D] = []
		for i in range(48):
			v5.append(run_before)
		stage._apply_hero_v5_locomotion(v5, club)
		assert(stage._hero_v5_loaded.has("%d:locomotion" % club))
		var bank := sprite.sprite_frames
		var front_before := bank.get_frame_texture(&"run_front", 0)
		var back_before := bank.get_frame_texture(&"run_back_diagonal", 0)
		var old_fps := bank.get_animation_speed(&"run_front_diagonal")
		sprite.play(&"run_front_diagonal")
		sprite.pause()
		stage.outfield_visual_phases[actor.get_instance_id()] = 10.0
		var fallback_diagonal := bank.get_frame_texture(&"run_front_diagonal", 0)
		var fallback_frame := sprite.frame
		stage._on_dense_diagonal_ready(blank_diagonal, club)
		assert(not stage._dense_diagonal_loaded.has(club))
		assert(bank.get_frame_texture(&"run_front_diagonal", 0) == fallback_diagonal)
		assert(bank.get_frame_count(&"run_front_diagonal") == 16)
		assert(sprite.frame == fallback_frame)
		assert(is_equal_approx(float(stage.outfield_visual_phases[actor.get_instance_id()]), 10.0))
		stage._on_dense_diagonal_ready(diagonal, club)
		assert(stage._dense_diagonal_loaded.has(club))
		assert(sprite.frame == 15)
		assert(is_equal_approx(float(stage.outfield_visual_phases[actor.get_instance_id()]), 15.0))
		assert(is_equal_approx(bank.get_animation_speed(&"run_front_diagonal"), old_fps * 1.5))
		for teammate: Footballer in game.teams[club]:
			if teammate.role == "keeper":
				continue
			var driver: AnimatedSprite3D = stage.player_sprites[teammate.get_instance_id()]
			for name in [&"run_front_diagonal", &"sprint_front_diagonal"]:
				assert(driver.sprite_frames.get_frame_count(name) == 24)
				assert(driver.sprite_frames.get_animation_loop(name))
		var first := bank.get_frame_texture(&"run_front_diagonal", 0)
		stage._apply_hero_v5_locomotion(v5, club)
		stage._on_dense_diagonal_ready(diagonal, club)
		assert(bank.get_frame_texture(&"run_front_diagonal", 0) == first)
		assert(bank.get_frame_texture(&"run_front", 0) == front_before)
		assert(bank.get_frame_texture(&"run_back_diagonal", 0) == back_before)
		assert(bank.get_frame_texture(&"run", 0) == run_before)
		assert(game.ball.carrier == owner)
	# Exercise the live-only contact clock on the actual pinned pass sheets,
	# not the legacy preview path above. Use a real pass and keep its
	# release and lock authoritative; no synthetic delayed ball motion.
	stage._dense_live_outfield_installed = true
	for club in range(2):
		var passer: Footballer = game.teams[club][1]
		var key: int = passer.get_instance_id()
		var driver: AnimatedSprite3D = stage.player_sprites[key]
		var material: StandardMaterial3D = stage.xi_raster_meshes[key].material_override
		game.ball.attach_to(passer)
		# Incoming running momentum must be stopped at the real kick.
		passer.velocity = Vector2(170.0, 20.0)
		passer.last_sprinting = true
		var planted_at: Vector2 = passer.global_position
		game._pass_from(passer, Vector2.RIGHT if club == 0 else Vector2.LEFT)
		assert(passer.xi_pass_plant_active())
		assert(passer.velocity == Vector2.ZERO and not passer.last_sprinting)
		for tick in range(6):
			passer.move_human(1.0 / 60.0, Vector2.RIGHT, true)
			passer.move_ai(1.0 / 60.0, planted_at + Vector2(400.0, 0.0), 1.0)
			assert(passer.global_position == planted_at and passer.velocity == Vector2.ZERO)

		assert(game.ball.carrier == null and game.ball.velocity.length() > 0.0)
		var duration: float = passer.action_visual_duration_seconds
		assert(is_equal_approx(duration, 0.72))
		var release_velocity: Vector2 = game.ball.velocity
		stage.sync_presentation(0.0, "broadcast")
		assert(driver.animation == &"pass" and driver.frame == 7)
		assert(material.albedo_texture == driver.sprite_frames.get_frame_texture(&"pass", 7))
		assert(is_equal_approx(passer.action_lock_seconds, duration))
		var previous := driver.frame
		for step in range(1, 16):
			passer.action_lock_seconds = duration * (1.0 - float(step) / 16.0)
			stage._sync_visible_animation(key, passer, driver, &"pass", 0.0)
			assert(driver.frame >= previous and driver.frame <= 15)
			previous = driver.frame
		assert(previous == 15)
		# Follow-through finishes in 250ms, not after the simulation lock.
		assert(ChessFootball3DPresenter.xi_dense_live_pass_phase(16, duration, duration - 0.125) >= 11.0)
		assert(ChessFootball3DPresenter.xi_dense_live_pass_phase(16, duration, duration - 0.24) == 15.0)
		passer.velocity = Vector2.ZERO
		passer.action_lock_seconds = duration - 0.20
		stage.sync_presentation(0.0, "broadcast")
		assert(driver.animation == &"pass")
		passer.action_lock_seconds = duration - 0.26
		stage.sync_presentation(0.0, "broadcast")
		assert(String(driver.animation).begins_with("idle"))
		assert(not passer.xi_pass_plant_active())
		# Both movement entry points resume after the shared window even
		# while the original action/cooldown lock still has time remaining.
		passer.move_human(1.0 / 60.0, Vector2.RIGHT, false)
		assert(passer.velocity.x > 0.0)
		passer.velocity = Vector2.ZERO
		passer.move_ai(1.0 / 60.0, passer.global_position + Vector2(400.0, 0.0), 1.0)
		assert(passer.velocity.x > 0.0)
		assert(is_equal_approx(passer.action_lock_seconds, duration - 0.26))
		assert(game.ball.carrier == null and game.ball.velocity == release_velocity)
		passer.action_lock_seconds = 0.0
	assert(ChessFootball3DPresenter.xi_dense_live_pass_phase(8, 0.72, 0.72) == 0.0)
	print("FOOTBALL_DENSE_LIVE_PASS_QUICK_RECOVERY_OK clubs=2 visual_seconds=0.25 gameplay_lock_unchanged=true")
	print("FOOTBALL_XI_PASS_PLANT_OK clubs=2 human_and_ai=true no_slide=true resume=true")
	# Exercise each actual pinned shoot sheet on the real charged-shot
	# release path. The two clubs have different authored contact frames.
	for club in range(2):
		var shooter: Footballer = game.teams[club][2]
		var key: int = shooter.get_instance_id()
		var driver: AnimatedSprite3D = stage.player_sprites[key]
		var material: StandardMaterial3D = stage.xi_raster_meshes[key].material_override
		shooter.velocity = Vector2.ZERO
		game._select_player(shooter)
		game.ball.attach_to(shooter)
		game._begin_shot_charge(0.0)
		game.shot_charge_seconds = 0.11
		game._release_charged_shot()
		assert(game.ball.carrier == null and game.ball.last_release_was_shot)
		assert(game.ball.velocity.length() > 0.0)
		var release_velocity: Vector2 = game.ball.velocity
		var duration: float = shooter.action_visual_duration_seconds
		var contact: int = 7 if club == 0 else 10
		stage.sync_presentation(0.0, "broadcast")
		assert(driver.animation == &"shoot" and driver.frame == contact)
		assert(material.albedo_texture == driver.sprite_frames.get_frame_texture(&"shoot", contact))
		var previous := driver.frame
		for tick in range(1, 16):
			shooter.action_lock_seconds = duration - float(tick) * 0.02
			stage._sync_visible_animation(key, shooter, driver, &"shoot", 0.0)
			assert(driver.frame >= previous and driver.frame <= 15)
			previous = driver.frame
		assert(previous == 15)
		shooter.action_lock_seconds = duration - 0.33
		stage.sync_presentation(0.0, "broadcast")
		assert(String(driver.animation).begins_with("idle"))
		assert(is_equal_approx(shooter.action_lock_seconds, duration - 0.33))
		assert(game.ball.velocity == release_velocity and game.ball.carrier == null)
		shooter.action_lock_seconds = 0.0
	assert(ChessFootball3DPresenter.xi_dense_live_shot_phase(0, 8, 0.72, 0.72) == 0.0)
	print("FOOTBALL_DENSE_LIVE_SHOT_CONTACT_OK clubs=2 contact_frames=7,10 visible_seconds=0.32 physics_unchanged=true")
	# The actual live camera must still widen the pitch at the touchline,
	# but the same stationary raster must keep a comparable screen height.
	_check_dense_broadcast_size(game, stage)
	stage._dense_live_outfield_installed = false
	print("FOOTBALL_DENSE_LIVE_PASS_CONTACT_OK clubs=2 immediate_release=true contact_frame=7 recovery=true")
	await _dense_diagonal_live(game, stage)
	await _check_dense_positional_arrival(game, stage)
	print("FOOTBALL_DENSE_DIAGONAL_NATIVE_OK clubs=2 frames=24 phase=true precedence=true")
	print("FOOTBALL_DENSE_KICKS_NATIVE_OK teams=2 frames=16 atomic=true")
	quit(0)


func _check_dense_broadcast_size(game: Node2D, stage: ChessFootball3DPresenter) -> void:
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	game.ball.release(Vector2.ZERO, 0.0)
	var runner: Footballer = game.teams[0][1]
	var key: int = runner.get_instance_id()
	var driver: AnimatedSprite3D = stage.player_sprites[key]
	var quad: MeshInstance3D = stage.xi_raster_meshes[key]
	var view_size: Vector2 = stage.get_viewport().get_visible_rect().size
	var reference := ChessFootball3DPresenter.xi_dense_broadcast_reference_pixels(view_size)
	assert(reference > 0.0)
	game._select_player(runner)
	runner.velocity = Vector2.ZERO
	runner.action_lock_seconds = 0.0
	runner._sync_locomotion(false)
	stage.player_run_views[key] = "side"
	var middle: Vector2 = game.match_pitch.get_center()
	var heights: Array[float] = []
	var fovs: Array[float] = []
	for y in [middle.y, game.match_pitch.position.y + 110.0, game.match_pitch.end.y - 110.0]:
		runner.global_position = Vector2(middle.x, y)
		game.ball.global_position = runner.global_position
		# Settle the actual camera and its continuous compensation, not
		# a synthetic projection or manually assigned mesh scale.
		for tick in range(24):
			stage.sync_presentation(0.25, "broadcast")
		assert(String(driver.animation).begins_with("idle"))
		var frame: Texture2D = stage._xi_frame_texture(runner, driver)
		var extent: float = (
			ChessFootballSpriteBank.frame_bottom(frame) - float(frame.get_height()) * 0.5
		) * driver.pixel_size * quad.scale.y
		var boot: Vector3 = quad.global_position - Vector3.UP * extent
		var head: Vector3 = boot + Vector3.UP * (
			ChessFootballSpriteBank.frame_height(frame) * driver.pixel_size * quad.scale.y
		)
		assert(quad.scale == driver.scale)
		var height: float = stage.camera.unproject_position(head).distance_to(stage.camera.unproject_position(boot))
		heights.append(height)
		fovs.append(stage.camera.fov)
		var shadow: MeshInstance3D = stage.player_nodes[key].get_node("ContactShadow")
		var ring: MeshInstance3D = stage.player_nodes[key].get_node("ActiveDisc")
		assert(is_equal_approx(shadow.scale.x, ring.scale.x))
		assert(absf(boot.y - shadow.global_position.y) < 0.05)
	assert(fovs[1] > fovs[0] + 2.0 and fovs[2] > fovs[0] + 2.0)
	for height in heights:
		assert(absf(height / heights[0] - 1.0) < 0.10,
			"Live Dense touchline sprite must not shrink with lens: " + str(heights))
	print("FOOTBALL_DENSE_TOUCHLINE_SIZE_OK heights=", heights, " fovs=", fovs)
	stage._dense_broadcast_size_mix = 0.0


# Use the actual SHA-verified new bank, physical CharacterBody2D motion
# and visible QuadMesh material, not just a synthetic clock or index test.
func _dense_diagonal_live(game: Node2D, stage: ChessFootball3DPresenter) -> void:
	const DT := 1.0 / 60.0
	game.kickoff_active = false
	game.goal_restart_active = false
	game.set_piece_active = false
	for team in game.teams:
		for athlete: Footballer in team:
			athlete.set_process(false)
			athlete.set_physics_process(false)
			athlete.global_position = Vector2(-9999.0, -9999.0)
			athlete.velocity = Vector2.ZERO
			athlete.action_lock_seconds = 0.0
	for club in range(2):
		for carries_ball in [true, false]:
			game.ball.release(Vector2.ZERO, 0.0)
			var runner: Footballer = game.teams[club][6]
			var key: int = runner.get_instance_id()
			var driver: AnimatedSprite3D = stage.player_sprites[key]
			var material: StandardMaterial3D = stage.xi_raster_meshes[key].material_override
			var direction := Vector2(1.0 if carries_ball else -1.0, 1.0).normalized()
			var origin: Vector2 = game.match_pitch.get_center()
			runner.global_position = origin
			runner.velocity = Vector2.ZERO
			runner.action_lock_seconds = 0.0
			runner.dribble_burst_seconds = 0.0
			runner.contact_stun_seconds = 0.0
			runner.tackle_recovery_seconds = 0.0
			if carries_ball:
				game._select_player(runner)
				game.ball.attach_to(runner)
			else:
				game._select_player(game.teams[1 - club][1])
			stage.outfield_visual_names.erase(key)
			stage.outfield_visual_phases.erase(key)
			stage.player_run_views[key] = "front_diagonal"
			var target := origin + direction * 1100.0
			var sample_every: int = 1 if carries_ball else 4
			var seen: Dictionary = {}
			var textures: Dictionary = {}
			var previous := -1
			for tick in range(156):
				await physics_frame
				if carries_ball:
					runner.move_human(DT, direction, false)
					game.ball.tick_ball(DT)
				else:
					runner.move_ai(DT, target, 0.70)
				# Ignore acceleration startup; still advance the real
				# presentation at the specified cadence.
				if tick % sample_every != 0:
					continue
				stage.sync_presentation(DT * float(sample_every), "broadcast")
				if tick < 12:
					continue
				assert(driver.animation == &"run_front_diagonal")
				assert(driver.flip_h == (direction.x < 0.0))
				assert(driver.sprite_frames.get_frame_count(driver.animation) == 24)
				var current: int = driver.frame
				if previous >= 0:
					assert((current - previous + 24) % 24 <= 1)
				previous = current
				var texture: Texture2D = driver.sprite_frames.get_frame_texture(driver.animation, current)
				assert(material.albedo_texture == texture)
				seen[current] = true
				textures[texture.get_instance_id()] = true
			assert(seen.size() == 24 and textures.size() == 24,
				"Actual dense diagonal must display all 24 poses")
			assert(runner.global_position.distance_to(origin) > 180.0)
			assert((game.ball.carrier == runner) == carries_ball)
			print("FOOTBALL_DENSE_DIAGONAL_LIVE_OK club=%d carrier=%s fps=%d frames=%d" %
				[club, str(carries_ball), 60 / sample_every, seen.size()])
			runner.global_position = Vector2(-9999.0, -9999.0)
			runner.velocity = Vector2.ZERO
	game.ball.release(Vector2.ZERO, 0.0)


# Real body movement + actual Dense frames: a positional runner should
# settle at a destination and stay still, then follow a new destination.
# No fake displacement, target changes or manual velocity during the run.
func _check_dense_positional_arrival(game: Node2D, stage: ChessFootball3DPresenter) -> void:
	const DT := 1.0 / 60.0
	stage._dense_live_outfield_installed = true
	var centre: Vector2 = game.match_pitch.get_center()
	for club in range(2):
		var runner: Footballer = game.teams[club][6]
		var key: int = runner.get_instance_id()
		var driver: AnimatedSprite3D = stage.player_sprites[key]
		var target: Vector2 = centre + Vector2(240.0, 0.0)
		game._select_player(game.teams[1 - club][1])
		runner.global_position = centre
		runner.velocity = Vector2.ZERO
		runner.action_lock_seconds = 0.0
		runner.contact_stun_seconds = 0.0
		runner.tackle_recovery_seconds = 0.0
		runner.xi_collision_down_seconds = 0.0
		var overshoot := 0.0
		var reversals := 0
		for tick in range(150):
			await physics_frame
			runner.move_ai(DT, target, 0.83, true)
			stage.sync_presentation(DT, "broadcast")
			overshoot = maxf(overshoot, runner.global_position.x - target.x)
			if runner.velocity.x < -12.0:
				reversals += 1
		assert(overshoot <= 8.0 and reversals == 0)
		assert(runner.global_position.distance_to(target) <= 9.0)
		assert(runner.velocity.length() < 1.0)
		assert(String(driver.animation).begins_with("idle"))
		var settled: Vector2 = runner.global_position
		for tick in range(12):
			await physics_frame
			runner.move_ai(DT, target, 0.83, true)
			stage.sync_presentation(DT, "broadcast")
			assert(runner.global_position.distance_to(settled) < 0.1)
			assert(String(driver.animation).begins_with("idle"))
		target += Vector2(280.0, 0.0)
		for tick in range(36):
			await physics_frame
			runner.move_ai(DT, target, 0.83, true)
			stage.sync_presentation(DT, "broadcast")
		assert(runner.global_position.x > settled.x + 50.0)
		assert(String(driver.animation).begins_with("run"))
		assert(driver.sprite_frames.get_frame_count(driver.animation) == 24)
		print("FOOTBALL_DENSE_POSITIONAL_ARRIVAL_OK club=%d overshoot=%.2f reversals=%d resumed=true" % [club, overshoot, reversals])
		runner.global_position = Vector2(-9999.0, -9999.0)
		runner.velocity = Vector2.ZERO
	stage._dense_live_outfield_installed = false
