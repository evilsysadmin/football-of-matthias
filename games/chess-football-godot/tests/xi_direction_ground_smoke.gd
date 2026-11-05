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
				var tactical: bool = mode == "tactical"
				assert(material.billboard_mode == (
					BaseMaterial3D.BILLBOARD_ENABLED if tactical
					else BaseMaterial3D.BILLBOARD_FIXED_Y
				))
				assert(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
				assert(material.alpha_scissor_threshold < 0.05)
				var actual_frame: Texture2D = stage._xi_frame_texture(player, sprite)
				assert(actual_frame != null and material.albedo_texture == actual_frame)
				assert(quad.scale == sprite.scale)
				var frame_foot := ChessFootballSpriteBank.frame_bottom(actual_frame)
				var half_height := float(actual_frame.get_height()) * 0.5
				var foot_extent: float = (frame_foot - half_height) * sprite.pixel_size * sprite.scale.y
				var up_axis: Vector3 = (
					stage.camera.global_transform.basis.y.normalized() if tactical
					else Vector3.UP
				)
				var right_axis: Vector3 = stage.camera.global_transform.basis.x.normalized()
				if not tactical:
					right_axis.y = 0.0
					right_axis = right_axis.normalized()
				var required_offset: Vector3 = stage.xi_rotated_foot_anchor_offset(
					stage.camera, actual_frame, sprite.pixel_size, sprite.scale.y,
					quad.rotation.z, tactical
				)
				assert(quad.position.is_equal_approx(sprite.position + required_offset))
				if direction != Vector2.ZERO:
					assert(absf(quad.rotation.z) >= deg_to_rad(2.0),
						"Running XI pose must test a real tilted billboard")
				else:
					assert(absf(quad.rotation.z) < 0.001)
				# The GPU rotates the billboard, so reconstruct its lowest opaque
				# pixel using the same local lean and camera axes as the renderer.
				# An unrotated foot estimate can hide a genuine floating runner.
				var boot_world: Vector3 = (
					quad.global_position
					+ (right_axis * sin(quad.rotation.z) - up_axis * cos(quad.rotation.z)) * foot_extent
				)
				var shadow := stage.player_nodes[key].get_node("ContactShadow") as MeshInstance3D
				# The far-side shadow must grow with the same compensation as
				# its visible XI body; otherwise the player appears airborne.
				var expected_depth: float = stage.perspective_body_scale(
					stage.camera, stage.player_nodes[key].global_position
				)
				assert(is_equal_approx(shadow.scale.x, expected_depth))
				assert(is_equal_approx(shadow.scale.z, expected_depth))
				var shadow_world := shadow.global_position
				assert(absf(boot_world.y - shadow_world.y) < 0.050,
					"Boots float above the shadow in " + mode + " " + String(expected))
				var boot_pixel := stage.camera.unproject_position(boot_world)
				var shadow_pixel := stage.camera.unproject_position(shadow_world)
				assert(absf(boot_pixel.y - shadow_pixel.y) < 4.0,
					"Projected boots visibly detach from grass: " + mode)
				assert(stage.player_nodes[key].get_node_or_null("XI_KitSculpt") == null
					or not stage.player_nodes[key].get_node("XI_KitSculpt").visible)
	# Move a single runner from far to near turf. The body's depth
	# compensation and the contact mark must track the *same* ratio.
	var winger: Footballer = game.teams[1][4]
	var winger_key: int = winger.get_instance_id()
	winger.action_lock_seconds = 0.0
	winger.velocity = Vector2.RIGHT * winger.base_speed
	winger._sync_locomotion(false)
	var center_x: float = game.match_pitch.get_center().x
	winger.global_position = Vector2(center_x, game.match_pitch.position.y + 110.0)
	stage.sync_presentation(0.0, "broadcast")
	var far_body_scale: float = stage.player_sprites[winger_key].scale.x
	var far_shadow_scale: float = (
		stage.player_nodes[winger_key].get_node("ContactShadow") as MeshInstance3D
	).scale.x
	winger.global_position = Vector2(center_x, game.match_pitch.end.y - 110.0)
	stage.sync_presentation(0.0, "broadcast")
	var near_body_scale: float = stage.player_sprites[winger_key].scale.x
	var near_shadow_scale: float = (
		stage.player_nodes[winger_key].get_node("ContactShadow") as MeshInstance3D
	).scale.x
	assert(far_body_scale > near_body_scale)
	assert(far_shadow_scale > near_shadow_scale)
	assert(is_equal_approx(
		far_shadow_scale / near_shadow_scale, far_body_scale / near_body_scale
	))
	# 5v5 stays on the original Sprite3D renderer and has no XI quads.
	var small = scene.instantiate()
	small.match_team_size = 5
	root.add_child(small)
	await process_frame
	await process_frame
	assert(small.presentation_3d.xi_raster_meshes.is_empty())
	var small_player: Footballer = small.teams[1][1]
	small_player.velocity = Vector2.ZERO
	small_player.action_lock_seconds = 0.0
	small_player._sync_locomotion(false)
	small.presentation_3d.sync_presentation(0.0, "broadcast")
	var small_shadow := small.presentation_3d.player_nodes[
		small_player.get_instance_id()
	].get_node("ContactShadow") as MeshInstance3D
	assert(is_equal_approx(small_shadow.scale.x, 1.0))
	assert(is_equal_approx(small_shadow.scale.z, 1.0))
	print("FOOTBALL_XI_DIRECTION_GROUND_OK clubs=2 views=4 cameras=2 boot_gap_px_lt_4 shadow_depth=1 small_unchanged=1")
	quit(0)
