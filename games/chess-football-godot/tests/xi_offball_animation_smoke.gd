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
		for frame_id in range(3):
			for tick in range(11):
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
	print("FOOTBALL_XI_OFFBALL_GAIT_OK teams=2 noncarriers=4 poses=6 visual_source=velocity legacy_5v5=unchanged")
	quit(0)
