extends SceneTree

# The previous outfield-frame smoke only covered the default five-a-side
# scene. These assertions exercise the 22-actor XI raster the user sees.
# In particular, an off-ball actor with real movement must never slide in
# a frozen 3D idle pose when the hidden 2D sprite was not updated.
func _initialize() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	var game = scene.instantiate()
	game.match_team_size = 11
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var stage: ChessFootball3DPresenter = game.presentation_3d
	assert(stage != null and stage.xi_raster_meshes.size() == 22)
	assert(ChessFootball3DPresenter.xi_outfield_motion_animation(
		Vector2.ZERO, true
	) == &"idle")
	assert(ChessFootball3DPresenter.xi_outfield_motion_animation(
		Vector2.RIGHT * 250.0, false
	) == &"run")
	assert(ChessFootball3DPresenter.xi_outfield_motion_animation(
		Vector2.UP * 335.0, true
	) == &"sprint")

	var samples: Array[Footballer] = []
	for team_id in range(2):
		for slot in [2, 7]:
			var player: Footballer = game.teams[team_id][slot]
			assert(player.role != "keeper")
			assert(not player.has_ball and player != game.ball.carrier)
			player.action_lock_seconds = 0.0
			player.velocity = (
				Vector2.DOWN * player.base_speed if slot == 2
				else Vector2.RIGHT * player.base_speed * player.SPRINT_SPEED_MULTIPLIER
			)
			player.last_sprinting = slot == 7
			# Simulate a stale, hidden 2D state while authoritative movement
			# continues. Previously the 3D quad would remain idle and skate.
			player.visual.play(&"idle")
			player.visual.pause()
			var key: int = player.get_instance_id()
			stage.outfield_visual_names.erase(key)
			stage.outfield_visual_phases.erase(key)
			var observed_frames: Dictionary = {}
			var observed_textures: Dictionary = {}
			for tick in range(55):
				stage.sync_presentation(1.0 / 60.0, "broadcast")
				var visible: AnimatedSprite3D = stage.player_sprites[key]
				var mesh: MeshInstance3D = stage.xi_raster_meshes[key]
				var canvas: StandardMaterial3D = mesh.material_override
				assert(String(visible.animation).begins_with(
					"sprint" if slot == 7 else "run"
				), "Moving off-ball XI player is still visually idle")
				assert(visible.sprite_frames.get_frame_count(visible.animation) >= 8)
				var texture: Texture2D = visible.sprite_frames.get_frame_texture(
					visible.animation, visible.frame
				)
				assert(canvas.albedo_texture == texture,
					"Actual visible XI quad does not display the gait frame")
				observed_frames[visible.frame] = true
				observed_textures[texture.get_instance_id()] = true
			assert(observed_frames.size() >= 6,
				"Off-ball XI gait did not advance through its authored poses")
			assert(observed_textures.size() >= 6,
				"Off-ball XI quad kept one image despite moving")
			assert(player.visual.animation == &"idle",
				"Renderer must not mutate authoritative 2D actor state")
			samples.append(player)

	# A moving player retains locked tackle/shot animation, and a player
	# that actually stops returns to idle even with a stale hidden run.
	var sample: Footballer = samples[0]
	var sample_key: int = sample.get_instance_id()
	sample.play_action("tackle", 0.55)
	stage.sync_presentation(1.0 / 60.0, "broadcast")
	assert(stage.player_sprites[sample_key].animation == &"tackle")
	sample.action_lock_seconds = 0.0
	sample.velocity = Vector2.ZERO
	sample.last_sprinting = false
	sample.visual.play(&"run")
	stage.sync_presentation(1.0 / 60.0, "broadcast")
	assert(String(stage.player_sprites[sample_key].animation).begins_with("idle"),
		"Stopped XI player must not run on the spot")

	# Capture three REAL pixels snapshots of two off-ball athletes, not
	# a synthesized spritesheet. Freeze simulation while visible gait
	# advances to expose any apparent skating in the actual 3D quad.
	if DisplayServer.get_name() != "headless":
		var center: Vector2 = game.match_pitch.get_center()
		for i in range(samples.size()):
			var athlete: Footballer = samples[i]
			athlete.action_lock_seconds = 0.0
			athlete.global_position = center + Vector2(
				-190.0 if athlete.team_id == 0 else 190.0,
				-250.0 if i % 2 == 0 else 250.0
			)
			athlete.velocity = Vector2.RIGHT * athlete.base_speed
			athlete.last_sprinting = false
			athlete.visual.play(&"idle")
			athlete.visual.pause()
		var start_location: Vector2 = samples[0].global_position
		for frame_id in range(3):
			for tick in range(11):
				# Real body displacement as well as active foot frames. The old
				# three-frame capture animated mannequins standing in one tile.
				for athlete in samples:
					athlete.global_position += athlete.velocity / 60.0
				stage.sync_presentation(1.0 / 60.0, "broadcast")
			for _settle in range(3):
				await process_frame
				await RenderingServer.frame_post_draw
			var shot: Image = root.get_viewport().get_texture().get_image()
			var path: String = "user://xi-offball-run-phase-%d.png" % frame_id
			assert(shot.get_size() == Vector2i(1280, 720))
			assert(shot.save_png(path) == OK)
			print("FOOTBALL_XI_OFFBALL_CAPTURE_%d=%s" % [
				frame_id, ProjectSettings.globalize_path(path)
			])
		assert(samples[0].global_position.distance_to(start_location) > 115.0,
			"Real visual capture must move the athlete while legs animate")
	# A distinct-colour 12-pose V3 club swap is validated on the ACTUAL
	# off-ball AI pathway, not on a runner whose velocity was assigned by a
	# test while he stood still. Every index must be rendered during normal
	# support play, in both team materials, without skipping frames.
	var atlas := Image.create(1536, 720, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for row in range(5):
		for frame_id in range(12):
			var frame_color := Color.from_hsv(float(frame_id) / 12.0, 0.72, 0.87)
			atlas.fill_rect(
				Rect2i(frame_id * 128 + 28 + frame_id % 4, row * 144 + 7, 68, 128),
				frame_color
			)
	var v3_textures: Array[Texture2D] = ChessFootballRunV3R2.frames_from_image(atlas)
	assert(v3_textures.size() == 60)
	for team_id in range(2):
		stage._apply_verified_run_v3(v3_textures, team_id)
		assert(stage._run_v3_r2_loaded.has(team_id))
		var runner: Footballer = game.teams[team_id][6]
		assert(runner != game.controlled and not runner.has_ball)
		runner.action_lock_seconds = 0.0
		runner.velocity = Vector2.ZERO
		runner.last_sprinting = false
		runner.global_position = game.match_pitch.get_center() + Vector2(
			-650.0, -360.0 if team_id == 0 else 360.0
		)
		var origin: Vector2 = runner.global_position
		var target: Vector2 = origin + Vector2(1200.0, 0.0)
		var runner_key: int = runner.get_instance_id()
		stage.outfield_visual_phases.erase(runner_key)
		stage.outfield_visual_names.erase(runner_key)
		var observed: Dictionary = {}
		var last_index := -1
		var travelled: float = 0.0
		var advanced: float = 0.0
		for tick in range(120):
			# CharacterBody2D.move_and_slide() must run on a physics tick.
			# The old synchronous SceneTree test advanced its visual clock
			# but did not reliably move the actor's collision body.
			await physics_frame
			var before: Vector2 = runner.global_position
			runner.move_ai(1.0 / 60.0, target, 0.70)
			travelled += before.distance_to(runner.global_position)
			stage.sync_presentation(1.0 / 60.0, "broadcast")
			var sprite: AnimatedSprite3D = stage.player_sprites[runner_key]
			var quad: MeshInstance3D = stage.xi_raster_meshes[runner_key]
			var material: StandardMaterial3D = quad.material_override
			assert(sprite.sprite_frames.get_frame_count(sprite.animation) == 12)
			assert(String(sprite.animation).begins_with("run"))
			var now_index: int = sprite.frame
			if last_index >= 0:
				assert((now_index - last_index + 12) % 12 <= 1,
					"12-pose AI runner skipped a painted stride frame")
			last_index = now_index
			observed[now_index] = true
			assert(material.albedo_texture ==
				sprite.sprite_frames.get_frame_texture(sprite.animation, now_index),
				"Visible QuadMesh is out of sync with the active V3 frame")
			advanced += stage.xi_offball_stride_advance(
				runner.velocity.length(), 1.0 / 60.0, 12,
				sprite.sprite_frames.get_animation_speed(sprite.animation), false
			)
		print("FOOTBALL_XI_OFFBALL_REAL_TRAVEL team=%d turf=%.2f v=%.2f frames=%d" %
			[team_id, travelled, runner.velocity.length(), observed.size()])
		assert(travelled > 200.0 and travelled < 430.0,
			"AI test must cover real, sustained grass displacement")
		assert(observed.size() == 12,
			"Moving off-ball V3 must render ALL twelve stride poses, not six")
		assert(absf(advanced / 12.0 - travelled / stage.XI_OFFBALL_RUN_CYCLE_PX) < 0.22,
			"Visible off-ball gait does not follow actual physical travel distance")
		print("FOOTBALL_XI_OFFBALL_12_FRAME_SEQUENCE team=%d frames=%d travel=%.1f" %
			[team_id, observed.size(), travelled])
	print("FOOTBALL_XI_OFFBALL_GAIT_OK teams=2 noncarriers=4 poses=6 visual_source=velocity legacy_5v5=unchanged")
	quit(0)
