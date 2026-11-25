extends SceneTree

# One real Godot XI scene, no CDN required: prove directional possession
# and independent v3-run/v1-carrier body normalization for both clubs.
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
	var v3 := Image.create(1536, 720, false, Image.FORMAT_RGBA8)
	v3.fill(Color.TRANSPARENT)
	for row in range(5):
		for col in range(12):
			var top := 7 if row == 2 else 15
			v3.fill_rect(Rect2i(col * 128 + 30, row * 144 + top, 69, 135 - top), Color("#3273bd"))
	var run_textures := ChessFootballRunV3R2.frames_from_image(v3)
	assert(run_textures.size() == 60)
	var carry := Image.create(1024, 288, false, Image.FORMAT_RGBA8)
	carry.fill(Color.TRANSPARENT)
	for row in range(2):
		for col in range(8):
			var top := 20 if row == 0 else 27
			carry.fill_rect(Rect2i(col * 128 + 28, row * 144 + top, 70, 135 - top), Color("#e35b5b"))
	var carry_textures := ChessFootballCarryDribbleR2.frames_from_image(carry)
	assert(carry_textures.size() == 16)
	for team_id in range(2):
		stage._apply_verified_run_v3(run_textures, team_id)
		stage._apply_verified_carry_dribble_frames(carry_textures, team_id)
		assert(stage._run_v3_r2_loaded.has(team_id))
		assert(stage._carry_dribble_r2_loaded.has(team_id))
		var player: Footballer = game.teams[team_id][1]
		var sprite: AnimatedSprite3D = stage.player_sprites[player.get_instance_id()]
		assert(sprite.sprite_frames.get_frame_count(&"run") == 12)
		assert(sprite.sprite_frames.get_frame_count(&"carry") == 8)
		for animation in [&"run", &"run_front_diagonal", &"run_back_diagonal", &"carry", &"dribble"]:
			sprite.play(animation)
			sprite.pause()
			var source: Texture2D = sprite.sprite_frames.get_frame_texture(animation, 0)
			var body_h: float = ChessFootballSpriteBank.frame_height(source)
			var adjusted: float = body_h * stage._canonical_body_scale(sprite, player.role, team_id)
			assert(absf(adjusted - stage.CANONICAL_BODY_HEIGHT_PIXELS) < 3.0,
				"Animation uses wrong silhouette reference: " + String(animation))
		# PR #89 normalized silhouette HEIGHT only; it left the authored
		# V3 oblique torso too bulky next to the slimmer side-facing carrier.
		# The 0.91 legacy width fix was insufficient on the new atlas.
		var diag_names := [
			&"run_front_diagonal", &"run_back_diagonal",
			&"sprint_front_diagonal", &"sprint_back_diagonal",
		]
		for name in diag_names:
			assert(is_equal_approx(
				stage.xi_v3_diagonal_width_trim(name, 11, false, true),
				stage.XI_V3_DIAGONAL_WIDTH_TRIM
			))
			assert(is_equal_approx(stage.xi_v3_diagonal_width_trim(name, 5, false, true), 1.0))
			assert(is_equal_approx(stage.xi_v3_diagonal_width_trim(name, 11, true, true), 1.0))
			assert(is_equal_approx(stage.xi_v3_diagonal_width_trim(name, 11, false, false), 1.0))
		assert(is_equal_approx(stage.xi_v3_diagonal_width_trim(&"carry", 11, false, true), 1.0))
		assert(is_equal_approx(stage.xi_v3_diagonal_width_trim(&"run", 11, false, true), 1.0))
		# Also verify the actual 3D sprite transform, not merely the helper:
		# equivalent speed/pose at identical pitch depth must be narrower
		# diagonally but keep exactly the same vertical body/boot geometry.
		var key: int = player.get_instance_id()
		player.velocity = Vector2.RIGHT * player.base_speed
		stage.outfield_visual_phases[key] = 2.0
		sprite.play(&"run")
		sprite.pause()
		stage._sync_player_secondary_motion(player, sprite, stage.player_nodes[key])
		var side_norm_x: float = sprite.scale.x / (
			stage._canonical_body_scale(sprite, player.role, team_id) *
			stage.view_compensation(sprite.animation).x
		)
		for name in [&"run_front_diagonal", &"run_back_diagonal"]:
			sprite.play(name)
			sprite.pause()
			stage._sync_player_secondary_motion(player, sprite, stage.player_nodes[key])
			var diag_norm_x: float = sprite.scale.x / (
				stage._canonical_body_scale(sprite, player.role, team_id) *
				stage.view_compensation(sprite.animation).x
			)
			assert(absf(diag_norm_x / side_norm_x - stage.XI_V3_DIAGONAL_WIDTH_TRIM) < 0.015,
				"XI oblique V3 run still has untrimmed torso bulk")
		# Independently cache and test the two clubs, not just animation labels.
		assert(stage.body_scale_cache.has("%s:%d:%s" % [player.role, team_id, "carry"]))
		for axis in [
			Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
			Vector2(1.0, 1.0).normalized(), Vector2(-1.0, -1.0).normalized()
		]:
			player.dribble_burst_seconds = 0.0
			player.velocity = axis * player.base_speed
			game.ball.attach_to(player)
			game.ball.tick_ball(0.016)
			var offset: Vector2 = game.ball.global_position - player.global_position
			assert(offset.dot(axis) >= 36.5, "Ball is not ahead of travel")
			assert(absf(offset.cross(axis)) <= 4.0, "Ball has wrong lateral offset")
			assert(offset.length() >= player.ball_anchor().length())
			assert(offset.length() <= player.ball_anchor().length() + 31.0)
		# The XI ball advances in small rolling touches and then closes the gap
		# with the moving carrier. A static boot offset would have zero variance.
		player.dribble_burst_seconds = 0.0
		player.global_position = game.match_pitch.get_center()
		player.velocity = Vector2.RIGHT * player.base_speed
		game.ball.attach_to(player)
		var nearest := INF
		var farthest := 0.0
		for _touch_step in range(45):
			player.global_position += player.velocity / 60.0
			game.ball.tick_ball(1.0 / 60.0)
			var forward_gap: float = (game.ball.global_position - player.global_position).dot(Vector2.RIGHT)
			nearest = minf(nearest, forward_gap)
			farthest = maxf(farthest, forward_gap)
			assert(forward_gap > 30.0 and forward_gap < 84.0)
		assert(farthest - nearest >= 8.0, "Ball is still magnetically fixed to the boots")
		assert(absf(game.ball.rotation) > 0.05, "Ball must roll while carried")
		stage.ball_node.rotation = Vector3.ZERO
		stage._sync_ball_visual_roll(0.10)
		assert(stage.ball_node.rotation.length() > 0.01,
			"3D ball still freezes its spin while the XI carrier runs")
		var rolling_release: Vector2 = game.ball.global_position
		game.ball.release(Vector2.RIGHT, 200.0)
		assert(game.ball.global_position.is_equal_approx(rolling_release))
		# Dribble checks require a new legal possession after release.
		game.ball.attach_to(player)
		player.dribble_direction = Vector2.UP
		player.dribble_burst_seconds = player.DRIBBLE_BURST_SECONDS * 0.50
		game.ball.tick_ball(0.0)
		assert((game.ball.global_position - player.global_position).dot(Vector2.UP) > 36.5)
		assert(not game.ball.airborne())
		game.ball.release(Vector2.RIGHT, 200.0)
		assert(game.ball.carrier == null)
		# CPU sprint must actually outrun a normal jog, not just spend stamina.
		var cpu_runner: Footballer = game.teams[1][2]
		var old_cpu_position := cpu_runner.global_position
		cpu_runner.global_position = game.match_pitch.get_center() + Vector2(0.0, 300.0)
		cpu_runner.velocity = Vector2.ZERO
		cpu_runner.debug_set_stamina(100.0)
		var chase_point := cpu_runner.global_position + Vector2(1000.0, 0.0)
		for _chase_step in range(7):
			cpu_runner.move_ai(0.10, chase_point, 1.0)
		assert(cpu_runner.velocity.length() > cpu_runner.base_speed * 1.15,
			"CPU sprint still uses jogging speed")
		assert(cpu_runner.stamina_ratio() < 0.75)
		cpu_runner.global_position = old_cpu_position
		cpu_runner.velocity = Vector2.ZERO
		cpu_runner.debug_set_stamina(100.0)
		# A pressing defender should target the carrier's upcoming lane.
		var human_runner: Footballer = game.teams[0][4]
		var old_human_position := human_runner.global_position
		var old_human_velocity := human_runner.velocity
		human_runner.global_position = game.match_pitch.get_center()
		human_runner.velocity = Vector2.RIGHT * human_runner.base_speed
		cpu_runner.global_position = human_runner.global_position + Vector2(250.0, 120.0)
		var intercept: Vector2 = game._ai_press_target(cpu_runner, human_runner)
		assert(intercept.x > human_runner.global_position.x + 25.0)
		assert(intercept.x <= human_runner.global_position.x + 130.0)
		human_runner.global_position = old_human_position
		human_runner.velocity = old_human_velocity
		cpu_runner.global_position = old_cpu_position
		# Keeper's hold keeps its existing chest/glove rig and legacy anchor.
		var keeper: Footballer = game.teams[team_id][0]
		assert(is_equal_approx(absf(keeper.ball_anchor().x), 18.0 * absf(keeper.scale.x)))
		assert(is_equal_approx(keeper.ball_anchor().y, -5.0))
		stage.ball_node.rotation = Vector3.ZERO
		game.ball.attach_to(keeper)
		keeper.velocity = Vector2.RIGHT * keeper.base_speed
		stage._sync_ball_visual_roll(0.10)
		assert(stage.ball_node.rotation == Vector3.ZERO,
			"Keeper-held balls must not rotate")
	# XI human responsiveness: test the real movement and kick paths, not just
	# tuning constants. A carrier pivots more promptly, without a speed buff.
	var agile_carrier: Footballer = game.teams[0][3]
	var no_ball_runner: Footballer = game.teams[0][4]
	for runner in [agile_carrier, no_ball_runner]:
		runner.global_position = game.match_pitch.get_center()
		runner.velocity = Vector2.RIGHT * 250.0
		runner.base_speed = 250.0
		runner.debug_set_stamina(100.0)
		runner.dribble_burst_seconds = 0.0
		runner.dribble_cooldown_seconds = 0.0
	game.ball.attach_to(agile_carrier)
	agile_carrier.move_human(1.0 / 60.0, Vector2.LEFT, false)
	no_ball_runner.move_human(1.0 / 60.0, Vector2.LEFT, false)
	assert(agile_carrier.velocity.x < no_ball_runner.velocity.x - 12.0,
		"XI carrier must pivot more responsively than an off-ball runner")
	assert(agile_carrier.velocity.length() <= 250.01,
		"XI carrying must not gain free sprint speed")
	# E is a physical plant, not a teleport in the requested cut direction.
	agile_carrier.velocity = Vector2.RIGHT * 250.0
	assert(agile_carrier.start_dribble(Vector2.UP, "cut"))
	assert(agile_carrier.velocity.x > 245.0)
	assert(absf(agile_carrier.velocity.y) < 0.01)
	agile_carrier.dribble_burst_seconds = 0.0
	agile_carrier.dribble_cooldown_seconds = 0.0
	var moving_receiver: Footballer = game.teams[0][6]
	moving_receiver.global_position = agile_carrier.global_position + Vector2(360.0, 0.0)
	moving_receiver.velocity = Vector2.UP * 240.0
	var lead_aim: Vector2 = game._human_pass_aim_point(agile_carrier, moving_receiver, 680.0)
	assert(lead_aim.y < moving_receiver.global_position.y - 30.0)
	assert(lead_aim.distance_to(moving_receiver.global_position) <= 72.01)
	game._select_player(agile_carrier)
	assert(game._begin_pass_charge(moving_receiver))
	game.pass_charge_seconds = 0.25
	assert(game._release_charged_pass())
	assert(game.ball.carrier == null)
	assert(game.ball.velocity.normalized().dot(
		(lead_aim - agile_carrier.global_position).normalized()
	) > 0.999, "XI real pass must use the moving receiver lead")
	moving_receiver.velocity = Vector2.ZERO
	assert(game._human_pass_aim_point(
		agile_carrier, moving_receiver, 680.0
	).is_equal_approx(moving_receiver.global_position))
	# In XI, a short Space tap chooses a near teammate, a deliberately
	# charged Space targets a farther run. Small score fluctuations must not
	# bounce the receiver between every physics frame.
	agile_carrier.global_position = game.match_pitch.get_center()
	for teammate: Footballer in game.teams[0]:
		if teammate != agile_carrier:
			teammate.global_position = game.match_pitch.position + Vector2(
				140.0, 130.0 + float(teammate.squad_index) * 165.0
			)
	var short_receiver: Footballer = game.teams[0][5]
	var long_receiver: Footballer = game.teams[0][7]
	var upper_receiver: Footballer = game.teams[0][8]
	short_receiver.global_position = agile_carrier.global_position + Vector2(320.0, 35.0)
	long_receiver.global_position = agile_carrier.global_position + Vector2(780.0, -25.0)
	upper_receiver.global_position = agile_carrier.global_position + Vector2(330.0, -180.0)
	# Neutral receiving runs make the target-choice test independent from
	# unrelated earlier velocity fixtures and the new pass-leading feature.
	short_receiver.velocity = Vector2.ZERO
	long_receiver.velocity = Vector2.ZERO
	upper_receiver.velocity = Vector2.ZERO
	game._select_player(agile_carrier)
	game.ball.attach_to(agile_carrier)
	assert(game._begin_directional_pass_charge(Vector2.RIGHT))
	assert(game.pass_target == short_receiver,
		"Quick XI Space must prefer the nearby outlet over a distant run")
	Input.action_press("move_right")
	game.pass_charge_seconds = game.PASS_CHARGE_SECONDS * 0.50
	game._handle_human(1.0 / 60.0)
	assert(game.pass_target == short_receiver,
		"XI recipient must stay stable when a rival becomes only marginally better")
	game.pass_charge_seconds = game.PASS_CHARGE_SECONDS * 0.96
	game._handle_human(1.0 / 60.0)
	assert(game.pass_target == long_receiver,
		"Holding XI Space must select the farther teammate in the aimed lane")
	Input.action_release("move_right")
	# A real release uses that receiver's physical position; no instant
	# handoff or fake completed pass is allowed.
	var expected_long_aim: Vector2 = (
		long_receiver.global_position - agile_carrier.global_position
	).normalized()
	assert(game._release_charged_pass())
	assert(game.ball.carrier == null)
	assert(game.controlled == agile_carrier)
	assert(game.ball.velocity.normalized().dot(expected_long_aim) > 0.999)
	# An explicit change of direction must discard an out-of-cone incumbent.
	assert(game._best_directional_pass_target(
		agile_carrier, Vector2.UP, 0.2, long_receiver
	) == upper_receiver, "Receiver hysteresis may not override the aiming cone")
	# A fallen directional recipient must lose selection even when the
	# previous candidate would otherwise be retained by hysteresis.
	short_receiver.xi_collision_down_seconds = 0.5
	assert(game._best_directional_pass_target(
		agile_carrier, Vector2.RIGHT, 0.0, short_receiver
	) != short_receiver)
	short_receiver.xi_collision_down_seconds = 0.0
	game._select_player(agile_carrier)
	game.ball.attach_to(agile_carrier)
	assert(game._begin_directional_pass_charge(Vector2.RIGHT))
	assert(game.pass_target == short_receiver)
	# Fall after the last target update: the HUD must stop highlighting
	# the invalid player, and release must keep raw manual aim without
	# secretly choosing a different target or requesting a wall.
	short_receiver.xi_collision_down_seconds = 0.5
	assert(game._xi_pass_charge_receiver() == null)
	assert(game._release_charged_pass())
	assert(game.ball.carrier == null)
	assert(game.ball.velocity.normalized().is_equal_approx(Vector2.RIGHT))
	assert(game.pending_human_pass_receiver == null)
	assert(game.xi_one_two_receiver == null)
	short_receiver.xi_collision_down_seconds = 0.0
	assert(game._best_directional_pass_target(
		agile_carrier, Vector2.RIGHT, 0.0
	) == short_receiver)
	print("FOOTBALL_XI_PASS_AVAILABLE_RECEIVER_OK fall=true raw_aim=true recovery=true")
	# Real XI movement keeps the analogue magnitude of the input vector.
	# Test both an off-ball runner and a carrier; no changes to full input,
	# technique multipliers, sprint ceilings or AI movement.
	var analog_runner: Footballer = no_ball_runner
	var analog_origin: Vector2 = game.match_pitch.position + Vector2(400.0, 300.0)
	analog_runner.base_speed = 250.0
	analog_runner.dribble_burst_seconds = 0.0
	analog_runner.xi_cut_exit_run_seconds = 0.0
	analog_runner.xi_feint_exit_run_seconds = 0.0
	for carrying: bool in [false, true]:
		game.ball.attach_to(analog_runner if carrying else agile_carrier)
		var maximum: float = analog_runner.base_speed * (
			analog_runner.technique_control_multiplier if carrying else 1.0
		)
		for strength: float in [0.25, 0.5, 1.0]:
			analog_runner.global_position = analog_origin
			analog_runner.velocity = Vector2.ZERO
			analog_runner.move_human(0.25, Vector2.RIGHT * strength, false)
			assert(absf(analog_runner.velocity.length() - maximum * strength) < 0.1,
				"XI analogue input must proportionally control real movement speed")
		analog_runner.global_position = analog_origin
		analog_runner.velocity = Vector2.ZERO
		analog_runner.move_human(0.25, Vector2(1.0, 1.0).normalized(), false)
		assert(absf(analog_runner.velocity.length() - maximum) < 0.1)
	print("FOOTBALL_XI_ANALOG_MOVEMENT_OK off_ball=true carry=true digital_diagonal=true")
	# 5v5 is a historical test fixture: preserve its old physics/ball anchor.
	var small = scene.instantiate()
	small.match_team_size = 5
	root.add_child(small)
	await process_frame
	await process_frame
	assert(small.teams[0][1].ball_anchor().is_equal_approx(Vector2(18.0, -5.0)))
	var small_receiver: Footballer = small.teams[0][2]
	small_receiver.velocity = Vector2.UP * 240.0
	assert(small._human_pass_aim_point(
		small.teams[0][1], small_receiver, 680.0
	).is_equal_approx(small_receiver.global_position),
		"5v5 must not inherit XI pass leading")
	# Even with a charge ratio passed by a caller, the old 5v5 selection
	# must stay independent of the new XI target-distance preference.
	var five_passer: Footballer = small.teams[0][3]
	five_passer.global_position = small.match_pitch.get_center()
	for teammate: Footballer in small.teams[0]:
		if teammate != five_passer:
			teammate.global_position = five_passer.global_position + Vector2(-450.0, 0.0)
	var five_near: Footballer = small.teams[0][1]
	var five_far: Footballer = small.teams[0][4]
	five_near.global_position = five_passer.global_position + Vector2(320.0, 0.0)
	five_far.global_position = five_passer.global_position + Vector2(780.0, 0.0)
	assert(small._best_directional_pass_target(
		five_passer, Vector2.RIGHT, 1.0
	) == five_near, "5v5 must retain its historical closest aligned target")
	print("FOOTBALL_XI_CARRIER_PARITY_OK teams=2 animations=5 directions=6 touch_variance=true cpu_sprint=true intercept=true fallback_5v5=unchanged")
	quit(0)
