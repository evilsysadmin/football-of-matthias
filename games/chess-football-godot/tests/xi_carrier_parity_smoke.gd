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
			assert(is_equal_approx(offset.length(), player.ball_anchor().length()))
		player.dribble_direction = Vector2.UP
		player.dribble_burst_seconds = player.DRIBBLE_BURST_SECONDS * 0.50
		game.ball.tick_ball(0.0)
		assert((game.ball.global_position - player.global_position).dot(Vector2.UP) > 36.5)
		assert(not game.ball.airborne())
		game.ball.release(Vector2.RIGHT, 200.0)
		assert(game.ball.carrier == null)
		# Keeper's hold keeps its existing chest/glove rig and legacy anchor.
		var keeper: Footballer = game.teams[team_id][0]
		assert(is_equal_approx(absf(keeper.ball_anchor().x), 18.0 * absf(keeper.scale.x)))
		assert(is_equal_approx(keeper.ball_anchor().y, -5.0))
	# 5v5 is a historical test fixture: preserve its old physics/ball anchor.
	var small = scene.instantiate()
	small.match_team_size = 5
	root.add_child(small)
	await process_frame
	await process_frame
	assert(small.teams[0][1].ball_anchor().is_equal_approx(Vector2(18.0, -5.0)))
	print("FOOTBALL_XI_CARRIER_PARITY_OK teams=2 animations=5 directions=6 ball_lead=37 fallback_5v5=unchanged")
	quit(0)
