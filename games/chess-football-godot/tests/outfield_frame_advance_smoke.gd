extends SceneTree

# The ten 3D raster sprites are the *visible* match actors. Outfield runners
# must advance through their authored eight poses even when the hidden 2D
# AnimatedSprite2D does not tick. This also verifies readable turns and actions.
func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var presenter: ChessFootball3DPresenter = game.presentation_3d
	assert(presenter != null)
	for team_id in range(2):
		for index in [1, 3]:
			var player: Footballer = game.teams[team_id][index]
			var sprite: AnimatedSprite3D = presenter.player_sprites[player.get_instance_id()]
			assert(sprite != null)
			player.action_lock_seconds = 0.0
			player.velocity = Vector2.DOWN * player.base_speed
			player.visual.play("run")
			player.visual.frame = 0
			player._sync_locomotion(false)
			var poses := {}
			for tick in range(48):
				player.visual.frame = 0 # deliberately freeze the hidden 2D source
				presenter.sync_presentation(1.0 / 60.0, "broadcast")
				assert(sprite.animation == &"run_front")
				poses[sprite.frame] = true
			assert(poses.size() >= 6)
			assert(not sprite.is_playing())
			# A diagonal turn must not restart the player's visible stride.
			var before_turn: int = sprite.frame
			player.velocity = Vector2(-1.0, -1.0).normalized() * player.base_speed
			presenter.sync_presentation(0.0, "broadcast")
			assert(sprite.animation == &"run_back_diagonal")
			assert(sprite.frame == before_turn)
			for tick in range(12):
				player.visual.frame = 0
				presenter.sync_presentation(1.0 / 60.0, "broadcast")
			assert(sprite.frame != before_turn)
			# Sprint changes cadence, without snapping to the initial frame.
			var before_sprint: int = sprite.frame
			player.velocity = Vector2.UP * player.base_speed * player.SPRINT_SPEED_MULTIPLIER
			player._sync_locomotion(true)
			player.visual.frame = 0
			presenter.sync_presentation(0.0, "broadcast")
			assert(sprite.animation == &"sprint_back")
			assert(sprite.frame == before_sprint)
			var sprint_poses := {}
			for tick in range(40):
				player.visual.frame = 0
				presenter.sync_presentation(1.0 / 60.0, "broadcast")
				sprint_poses[sprite.frame] = true
			assert(sprint_poses.size() >= 6)
			# Passing/shooting animations have their own eight-frame raster
			# sequence, then give way to idle without looping in place.
			player.velocity = Vector2.ZERO
			player._sync_locomotion(false)
			presenter.sync_presentation(1.0 / 60.0, "broadcast")
			assert(sprite.animation == &"idle_back")
			assert(sprite.frame == 0)
			for action in ["pass", "shoot"]:
				player.play_action(action, 0.62)
				var action_poses := {}
				for tick in range(36):
					player.visual.frame = 0
					presenter.sync_presentation(1.0 / 60.0, "broadcast")
					assert(sprite.animation == StringName(action))
					action_poses[sprite.frame] = true
				assert(action_poses.size() >= 4)
				player.action_lock_seconds = 0.0
				player._sync_locomotion(false)
				presenter.sync_presentation(0.0, "broadcast")
				assert(sprite.animation == &"idle_back")
				assert(sprite.frame == 0)
			# Movement within a single authored frame must still shift weight
			# smoothly. The pose remains frame zero while the visual sub-frame
			# phase advances; only presentation changes, never match velocity.
			var key: int = player.get_instance_id()
			var proxy: Node3D = presenter.player_nodes[key]
			player.velocity = Vector2.DOWN * player.base_speed
			player.visual.speed_scale = 1.0
			sprite.play(&"run_front")
			sprite.pause()
			sprite.frame = 0
			presenter.outfield_visual_names[key] = &"run_front"
			presenter.outfield_visual_phases[key] = 0.0
			presenter._sync_player_secondary_motion(player, sprite, proxy)
			var initial_sway: float = sprite.position.x
			var fps: float = sprite.sprite_frames.get_animation_speed(&"run_front")
			presenter._sync_visible_animation(key, player, sprite, &"run_front", 0.25 / fps)
			assert(sprite.frame == 0)
			presenter._sync_player_secondary_motion(player, sprite, proxy)
			assert(absf(sprite.position.x - initial_sway) > 0.002)
			print("OUTFIELD_3D_POSES team=%d slot=%d run=%d sprint=%d" % [
				team_id, index, poses.size(), sprint_poses.size()
			])
	print("chess-football outfield frame-advance smoke: OK")
	quit(0)
