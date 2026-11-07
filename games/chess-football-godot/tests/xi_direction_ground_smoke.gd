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

	# Compare actual bundled fallback silhouettes at identical render depth.
	# Any disparity here is an atlas/view scale problem, NOT perspective.
	for team_id in range(2):
		var sample: Footballer = game.teams[team_id][2]
		var driver: AnimatedSprite3D = stage.player_sprites[sample.get_instance_id()]
		for animation in [
			&"idle", &"idle_front", &"run", &"run_front", &"run_back",
			&"run_front_diagonal", &"run_back_diagonal", &"sprint",
			&"pass", &"shoot",
		]:
			if not driver.sprite_frames.has_animation(animation):
				continue
			driver.play(animation)
			driver.pause()
			var texture := driver.sprite_frames.get_frame_texture(animation, 0)
			var rect := (texture as ImageTexture).get_image().get_used_rect()
			var scale := stage._canonical_body_scale(driver, sample.role, team_id)
			var normalized_height := float(rect.size.y) * scale
			assert(absf(normalized_height - stage.CANONICAL_BODY_HEIGHT_PIXELS) < 8.0,
				"XI pose height drifted between teams, facing views or locomotion")
			print("FOOTBALL_XI_SIZE_AUDIT team=%d animation=%s opaque=%dx%d scaled_height=%.2f" % [
				team_id, String(animation), rect.size.x, rect.size.y,
				normalized_height,
			])

	# The XI ball is visually proportional to the approved sprites, while
	# its collision/possession authority and the legacy 5v5 remain unchanged.
	var xi_ball_mesh := stage.ball_node.mesh as SphereMesh
	assert(xi_ball_mesh != null)
	assert(is_equal_approx(
		xi_ball_mesh.radius, ChessFootball3DPresenter.XI_BALL_VISUAL_RADIUS
	))
	assert(is_equal_approx(xi_ball_mesh.height, xi_ball_mesh.radius * 2.0))
	var xi_shadow_mesh := stage.ball_shadow.mesh as CylinderMesh
	assert(xi_shadow_mesh != null)
	assert(is_equal_approx(xi_shadow_mesh.top_radius, 0.082))
	assert(is_equal_approx(xi_shadow_mesh.bottom_radius, 0.082))
	var authoritative_ball_position: Vector2 = game.ball.global_position
	var authoritative_ball_velocity: Vector2 = game.ball.velocity
	stage.sync_presentation(0.0, "broadcast")
	assert(is_equal_approx(
		stage.ball_node.position.y,
		xi_ball_mesh.radius + ChessFootball3DPresenter.BALL_VISUAL_GROUND_CLEARANCE
	))
	assert(game.ball.global_position == authoritative_ball_position)
	assert(game.ball.velocity == authoritative_ball_velocity)

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
				# Otherwise the driver scale updates but the GPU billboard
				# silently drops that scale, recreating the old fat diagonals.
				assert(material.billboard_keep_scale,
					"XI billboard must preserve actual per-orientation raster size")
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
					# At the far touchline a deliberately damped lean must remain
					# nonzero; requiring the old full 2° there rejected the fix.
					var body_depth: float = stage.perspective_body_scale(
						stage.camera, stage.player_nodes[key].global_position
					)
					var min_lean := deg_to_rad(
						2.0 * stage.xi_distant_stride_weight(body_depth)
					)
					assert(absf(quad.rotation.z) >= min_lean,
						"Running XI pose must retain a depth-calibrated tilted billboard")
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
				var expected_depth: float = (
					stage.xi_projected_body_scale(stage.camera, stage.player_nodes[key].global_position)
					if mode == "broadcast"
					else stage.perspective_body_scale(stage.camera, stage.player_nodes[key].global_position)
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
	var marker_proxy: Node3D = stage.player_nodes[winger_key]
	var active_ring := marker_proxy.get_node("ActiveDisc") as MeshInstance3D
	var receiver_ring := marker_proxy.get_node("SetPieceReceiverDisc") as MeshInstance3D
	var far_ring_scale: float = active_ring.scale.x
	assert(is_equal_approx(far_ring_scale, far_shadow_scale))
	assert(is_equal_approx(receiver_ring.scale.x, far_shadow_scale))
	assert(is_equal_approx(active_ring.scale.z, far_shadow_scale))
	assert(is_equal_approx(receiver_ring.scale.z, far_shadow_scale))
	assert(is_equal_approx(active_ring.scale.y, 1.0))
	winger.global_position = Vector2(center_x, game.match_pitch.end.y - 110.0)
	stage.sync_presentation(0.0, "broadcast")
	var near_body_scale: float = stage.player_sprites[winger_key].scale.x
	var near_shadow_scale: float = (
		stage.player_nodes[winger_key].get_node("ContactShadow") as MeshInstance3D
	).scale.x
	var near_ring_scale: float = active_ring.scale.x
	assert(is_equal_approx(near_ring_scale, near_shadow_scale))
	assert(is_equal_approx(receiver_ring.scale.x, near_shadow_scale))
	assert(is_equal_approx(active_ring.scale.z, near_shadow_scale))
	assert(is_equal_approx(receiver_ring.scale.z, near_shadow_scale))
	assert(far_body_scale > near_body_scale)
	assert(far_shadow_scale > near_shadow_scale)
	assert(far_ring_scale > near_ring_scale)
	# A ring should stay proportionate to its actor, rather than shrink
	# on the far touchline while the approved body scales to stay readable.
	var far_ring_to_body: float = far_ring_scale / far_body_scale
	var near_ring_to_body: float = near_ring_scale / near_body_scale
	assert(absf(far_ring_to_body / near_ring_to_body - 1.0) < 0.08)
	# Only additional synthetic motion fades with distance. Both runners
	# keep their approved atlas, identical locomotion phase and actual pace.
	assert(is_equal_approx(stage.xi_distant_stride_weight(0.80), 1.0))
	assert(is_equal_approx(stage.xi_distant_stride_weight(1.00), 1.0))
	assert(stage.xi_distant_stride_weight(1.25) < 1.0)
	assert(is_equal_approx(stage.xi_distant_stride_weight(1.80), 0.35))
	var far_weight: float = stage.xi_distant_stride_weight(far_shadow_scale)
	var near_weight: float = stage.xi_distant_stride_weight(near_shadow_scale)
	assert(far_weight < near_weight)
	# Fix the sub-frame phase and hold the same runner/velocity at both
	# depth extremes; the projected lean must be milder on the far side.
	winger.global_position = Vector2(center_x, game.match_pitch.position.y + 110.0)
	stage.sync_presentation(0.0, "broadcast")
	stage.outfield_visual_phases[winger_key] = 1.50
	stage.sync_presentation(0.0, "broadcast")
	var far_sprite: AnimatedSprite3D = stage.player_sprites[winger_key]
	var far_lean: float = absf(far_sprite.rotation.z)
	winger.global_position = Vector2(center_x, game.match_pitch.end.y - 110.0)
	stage.sync_presentation(0.0, "broadcast")
	var near_sprite: AnimatedSprite3D = stage.player_sprites[winger_key]
	var near_lean: float = absf(near_sprite.rotation.z)
	assert(far_lean < near_lean)
	# Existing tilted-boot anchoring must remain true at BOTH depth extremes.
	for point in [
		Vector2(center_x, game.match_pitch.position.y + 110.0),
		Vector2(center_x, game.match_pitch.end.y - 110.0),
	]:
		winger.global_position = point
		stage.sync_presentation(0.0, "broadcast")
		var frame: Texture2D = stage._xi_frame_texture(winger, near_sprite)
		var contact_y: float = (
			ChessFootballSpriteBank.frame_bottom(frame) - float(frame.get_height()) * 0.5
		) * near_sprite.pixel_size * near_sprite.scale.y
		var quad: MeshInstance3D = stage.xi_raster_meshes[winger_key]
		var shadow: MeshInstance3D = stage.player_nodes[winger_key].get_node("ContactShadow")
		var boot_world: Vector3 = (
			quad.global_position
			+ (Vector3.RIGHT * sin(quad.rotation.z) - Vector3.UP * cos(quad.rotation.z)) * contact_y
		)
		assert(absf(boot_world.y - shadow.global_position.y) < 0.050)

	# The contact decal tracks camera perspective exactly; the raster's
	# *additional* width squash now eases by depth (a few percent). Do not
	# demand identical ratios from two deliberately different transforms.
	var shadow_ratio: float = far_shadow_scale / near_shadow_scale
	var body_ratio: float = far_body_scale / near_body_scale
	assert(absf(body_ratio / shadow_ratio - 1.0) < 0.05)
	# XI-only pose clock follows real travel distance, not a near-fixed
	# 2D animation speed. Slowing down must slow the feet without altering
	# physical velocity or the older 5v5 / keeper clocks.
	assert(is_equal_approx(stage.xi_outfield_stride_advance(0.0, 0.2, 8, 12.0, false), 0.0))
	assert(is_equal_approx(stage.xi_outfield_stride_advance(250.0, 0.0, 8, 12.0, false), 0.0))
	var slow_advance := stage.xi_outfield_stride_advance(75.0, 0.10, 8, 12.0, false)
	var run_advance := stage.xi_outfield_stride_advance(250.0, 0.10, 8, 12.0, false)
	var sprint_advance := stage.xi_outfield_stride_advance(335.0, 0.10, 8, 15.0, true)
	assert(run_advance > slow_advance * 3.0)
	assert(sprint_advance > run_advance)
	assert(is_equal_approx(
		stage.xi_outfield_stride_advance(250.0, 0.10, 12, 18.0, false)
		/ run_advance, 1.5
	))
	assert(is_equal_approx(stage.xi_outfield_stride_advance(10000.0, 0.10, 8, 12.0, false), 1.62))
	# At ordinary 60 Hz the short XI off-ball cycle still follows real
	# support speed exactly. At a slower Web tick it must NEVER jump over
	# any painted frame, even if a sprint consumes several stride pixels.
	var visual_delta := 1.0 / 60.0
	var old_support: float = stage.xi_outfield_stride_advance(175.0, visual_delta, 12, 18.0, false)
	var new_support: float = stage.xi_offball_stride_advance(175.0, visual_delta, 12, 18.0, false)
	assert(new_support > old_support * 1.4)
	assert(is_equal_approx(
		new_support, 175.0 * 12.0 / stage.XI_OFFBALL_RUN_CYCLE_PX * visual_delta
	))
	assert(stage.xi_offball_stride_advance(0.0, 0.1, 12, 18.0, false) == 0.0)
	assert(stage.xi_offball_stride_advance(175.0, 0.0, 12, 18.0, false) == 0.0)
	assert(stage.xi_offball_stride_advance(330.0, visual_delta, 12, 22.5, true) >
		stage.xi_outfield_stride_advance(330.0, visual_delta, 12, 22.5, true))
	assert(is_equal_approx(
		stage.xi_offball_stride_advance(10000.0, 0.1, 12, 18.0, false), 0.99
	))
	assert(stage.xi_offball_stride_advance(330.0, 1.0 / 15.0, 12, 22.5, true) <= 0.99)

	var runner: Footballer = game.teams[0][2]
	var runner_key: int = runner.get_instance_id()
	var runner_sprite: AnimatedSprite3D = stage.player_sprites[runner_key]
	runner.action_lock_seconds = 0.0
	runner.velocity = Vector2.RIGHT * runner.base_speed * 0.30
	runner._sync_locomotion(false)
	stage.outfield_visual_names.erase(runner_key)
	stage.outfield_visual_phases.erase(runner_key)
	stage._sync_visible_animation(runner_key, runner, runner_sprite, &"run", 0.0)
	stage.outfield_visual_phases[runner_key] = 0.0
	stage._sync_visible_animation(runner_key, runner, runner_sprite, &"run", visual_delta)
	var slow_phase: float = stage.outfield_visual_phases[runner_key]
	runner.velocity = Vector2.RIGHT * runner.base_speed
	runner._sync_locomotion(false)
	stage.outfield_visual_phases[runner_key] = 0.0
	stage._sync_visible_animation(runner_key, runner, runner_sprite, &"run", visual_delta)
	var fast_phase: float = stage.outfield_visual_phases[runner_key]
	# A bounded high-speed frame clock saturates at 1.35× authored FPS.
	# Pace ratings above the neutral 250 px/s should not be forced to
	# exceed that cap just to satisfy the old >3.0 acceleration heuristic.
	assert(fast_phase > slow_phase * 2.65)
	assert(is_equal_approx(
		fast_phase, stage.xi_offball_stride_advance(
			runner.base_speed, visual_delta, runner_sprite.sprite_frames.get_frame_count(&"run"),
			runner_sprite.sprite_frames.get_animation_speed(&"run"), false
		)
	))
	# Rendering cadence must not mutate physics or move any actor.
	assert(is_equal_approx(runner.velocity.length(), runner.base_speed))
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
	var small_marker: Node3D = small.presentation_3d.player_nodes[
		small_player.get_instance_id()
	]
	assert((small_marker.get_node("ActiveDisc") as MeshInstance3D).scale == Vector3.ONE)
	assert((small_marker.get_node("SetPieceReceiverDisc") as MeshInstance3D).scale == Vector3.ONE)
	print("FOOTBALL_XI_DIRECTION_GROUND_OK clubs=2 views=4 cameras=2 boot_gap_px_lt_4 shadow_depth=1 markers_match_body=1 small_unchanged=1")
	quit(0)
