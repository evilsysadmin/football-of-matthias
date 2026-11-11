extends SceneTree

# Capture the real attack/defense HUD at native 1280x720. Never mock a
# label, recompose a screenshot, or bypass the normal XI match scene.
# Its rendering is visual evidence; it does not change gameplay or inputs.
func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var match_node = packed.instantiate()
	match_node.match_team_size = 11
	root.add_child(match_node)
	for _i in range(8):
		await process_frame
		await physics_frame
	match_node.set_process(false)
	match_node.set_physics_process(false)
	match_node.kickoff_active = false
	match_node.goal_restart_active = false
	match_node.set_piece_active = false

	var carrier: Footballer = match_node.teams[0][10]
	match_node._select_player(carrier)
	match_node.ball.attach_to(carrier)
	match_node._refresh_hud()
	assert(match_node.help_label.text == match_node.contextual_help_text(false))
	assert(match_node.help_label.text.contains("E quieto: amago"))
	assert(match_node.help_label.text.contains("E en marcha: recorte"))
	assert(match_node.help_label.text.contains("F toque largo"))
	assert(match_node.help_label.size.x >= 800.0)
	await _save_camera(match_node, "attack")

	var rival: Footballer = match_node.teams[1][10]
	match_node.ball.attach_to(rival)
	match_node._refresh_hud()
	assert(match_node.help_label.text == match_node.contextual_help_text(false))
	assert(match_node.help_label.text.contains("E entrada"))
	assert(not match_node.help_label.text.contains("E quieto"))
	await _save_camera(match_node, "defense")

	print("FOOTBALL_XI_E_HINT_VISUAL_OK native=1280x720 states=2 keyboard=1 gameplay_unchanged=1")
	quit(0)


func _save_camera(match_node: Node, state: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := match_node.get_viewport().get_texture().get_image()
	assert(image != null and image.get_size() == Vector2i(1280, 720))
	var path := "user://xi-e-hint-%s-1280x720.png" % state
	assert(image.save_png(path) == OK)
	print("FOOTBALL_XI_E_HINT_CAPTURE_%s=%s" % [
		state.to_upper(), ProjectSettings.globalize_path(path)
	])
