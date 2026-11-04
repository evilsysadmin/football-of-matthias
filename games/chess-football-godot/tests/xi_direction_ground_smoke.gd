extends SceneTree

# XI players are upright, grounded quads with a single directional/idle
# animation clock. Test from actual runtime transforms; the screenshot gate
# also checks that distant coloured player bodies remain visible.
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

	# Covers both teams, vertical directions, the original lateral run,
	# stationary idle, and tactical/broadcast camera tilt. No R2 required.
	for mode in ["broadcast", "tactical"]:
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.RIGHT, Vector2.ZERO]:
			for team_id in range(2):
				var player: Footballer = game.teams[team_id][1]
				var key: int = player.get_instance_id()
				player.action_lock_seconds = 0.0
				player.velocity = direction * player.base_speed
				player._sync_locomotion(false)
				stage.sync_presentation(1.0 / 60.0, mode)
				var sprite: AnimatedSprite3D = stage.player_sprites[key]
				var expected_view := ChessFootballRunDirection.view_for_velocity(
					player.velocity, String(stage.player_run_views.get(key, "front"))
				)
				var expected := ChessFootballRunDirection.animation_for(
					StringName(player.visual.animation), expected_view
				)
				if sprite.sprite_frames.has_animation(expected):
					assert(sprite.animation == expected)
				var quad: MeshInstance3D = stage.xi_raster_meshes[key]
				assert(quad.is_visible_in_tree())
				var material := quad.material_override as StandardMaterial3D
				assert(material != null)
				assert(material.billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y)
				assert(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
				assert(material.alpha_scissor_threshold < 0.05)
				var actual_frame: Texture2D = stage._xi_frame_texture(player, sprite)
				assert(actual_frame != null and material.albedo_texture == actual_frame)
				assert(quad.position == sprite.position and quad.scale == sprite.scale)
				var frame_foot := ChessFootballSpriteBank.frame_bottom(actual_frame)
				var half_height := float(actual_frame.get_height()) * 0.5
				# The billboard faces the camera only around Y. Its local
				# negative Y points down to the boots regardless of pitch.
				var boot_world := quad.to_global(Vector3(
					0.0, -(frame_foot - half_height) * sprite.pixel_size, 0.0
				))
				var shadow := stage.player_nodes[key].get_node("ContactShadow") as MeshInstance3D
				var shadow_world := shadow.global_position
				assert(absf(boot_world.y - shadow_world.y) < 0.050,
					"Boots float above the shadow in " + mode + " " + String(expected))
				var boot_pixel := stage.camera.unproject_position(boot_world)
				var shadow_pixel := stage.camera.unproject_position(shadow_world)
				assert(absf(boot_pixel.y - shadow_pixel.y) < 4.0,
					"Projected boots visibly detach from grass: " + mode)
				assert(stage.player_nodes[key].get_node_or_null("XI_KitSculpt") == null
					or not stage.player_nodes[key].get_node("XI_KitSculpt").visible)
	# 5v5 stays on the original Sprite3D renderer and has no XI quads.
	var small = scene.instantiate()
	small.match_team_size = 5
	root.add_child(small)
	await process_frame
	await process_frame
	assert(small.presentation_3d.xi_raster_meshes.is_empty())
	print("FOOTBALL_XI_DIRECTION_GROUND_OK clubs=2 views=4 cameras=2 boot_gap_px_lt_4")
	quit(0)
