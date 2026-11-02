extends SceneTree

# A genuine standalone slide state permits new R2 art later. Today its frames
# must remain byte-identical to canonical tackle, without affecting physics.
func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var match_node = packed.instantiate()
	root.add_child(match_node)
	await process_frame
	await process_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	var presenter: ChessFootball3DPresenter = match_node.presentation_3d
	for team_id in range(2):
		var player: Footballer = match_node.teams[team_id][1]
		var visual: AnimatedSprite2D = player.visual
		var sprite: AnimatedSprite3D = presenter.player_sprites[player.get_instance_id()]
		for bank in [visual.sprite_frames, sprite.sprite_frames]:
			assert(bank.has_animation(&"tackle") and bank.has_animation(&"slide_tackle"))
			assert(bank.get_frame_count(&"tackle") == 8)
			assert(bank.get_frame_count(&"slide_tackle") == 8)
			assert(bank.get_animation_speed(&"tackle") == bank.get_animation_speed(&"slide_tackle"))
			assert(bank.get_animation_loop(&"tackle") == bank.get_animation_loop(&"slide_tackle"))
			for i in range(8):
				assert(bank.get_frame_texture(&"slide_tackle", i) == bank.get_frame_texture(&"tackle", i))
		player.has_ball = false
		player.sent_off = false
		player.action_lock_seconds = 0.0
		player.tackle_cooldown_seconds = 0.0
		assert(player.start_tackle(false))
		assert(visual.animation == &"tackle")
		assert(is_equal_approx(player.tackle_active_seconds, Footballer.TACKLE_ACTIVE_SECONDS))
		assert(is_equal_approx(player.action_lock_seconds, 0.50))
		presenter.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"tackle")
		player.action_lock_seconds = 0.0
		player.tackle_cooldown_seconds = 0.0
		player.tackle_recovery_seconds = 0.0
		assert(player.start_tackle(true))
		assert(visual.animation == &"slide_tackle")
		assert(is_equal_approx(player.tackle_active_seconds, Footballer.SLIDE_TACKLE_ACTIVE_SECONDS))
		assert(is_equal_approx(player.action_lock_seconds, 0.64))
		assert(player.tackle_aggressive_active())
		presenter.sync_presentation(0.0, "broadcast")
		assert(sprite.animation == &"slide_tackle")
		# The new visual state does not redefine cooldown, card or physics rules.
		assert(is_equal_approx(player.tackle_cooldown_seconds, 1.45))
		assert(is_equal_approx(player.tackle_recovery_seconds, 0.68))
	print("football separate standing/slide tackles with canonical fallback: OK")
	quit(0)
