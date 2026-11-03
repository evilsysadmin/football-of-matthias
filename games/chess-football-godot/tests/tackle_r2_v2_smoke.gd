extends SceneTree

# Offline contract: source-sized, operator-uploaded artwork is normalized only
# after a complete verified sheet. No URL, network or R2 credentials required.
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
	var manifest := ChessFootballTackleR2.metadata()
	assert(manifest.get("bucket") == "football")
	assert(manifest.get("prefix") == "atlases/v1/")
	assert(manifest.get("enabled") == false)
	assert(String(manifest.get("cdn_base", "")).is_empty())
	assert((manifest.get("entries", []) as Array).size() == 4)
	for team_id in range(2):
		for animation in [&"tackle", &"slide_tackle"]:
			var source := ChessFootballTackleR2.source_entry(team_id, animation)
			assert(not source.is_empty())
			assert(source.get("file", "").ends_with("_v2.webp"))
			assert(String(source.get("sha256", "")).length() == 64)
			assert((source.get("rects", []) as Array).size() == 8)
			assert(ChessFootballTackleR2.active_entry(team_id, animation).is_empty())
			var fake := Image.create(2172, 724, false, Image.FORMAT_RGBA8)
			fake.fill(Color.TRANSPARENT)
			for i in range(8):
				var coords: Array = source["rects"][i]
				fake.fill_rect(Rect2i(
					int(coords[0]) + 4, int(coords[1]) + 4,
					int(coords[2]) - 8, int(coords[3]) - 8
				), Color(0.20 + float(i) * 0.08, 0.60, 0.25, 1.0))
			var normalized := ChessFootballTackleR2.frames_from_image(fake, source)
			assert(normalized.size() == 8)
			for i in range(8):
				var frame: Image = normalized[i].get_image()
				assert(frame.get_size() == Vector2i(128, 144))
				var used := frame.get_used_rect()
				assert(used.size.y >= 55 and used.end.y <= 135)
				assert(used.position.x >= 4 and used.end.x <= 124)
			var bad_source: Dictionary = source.duplicate(true)
			bad_source["rects"] = source["rects"].slice(0, 7)
			assert(ChessFootballTackleR2.frames_from_image(fake, bad_source).is_empty())
			assert(ChessFootballTackleR2.frames_from_image(
				Image.create(1024, 144, false, Image.FORMAT_RGBA8), source
			).is_empty())
			var outfielder: Footballer = match_node.teams[team_id][1]
			var player_sprite: AnimatedSprite3D = presenter.player_sprites[outfielder.get_instance_id()]
			var keeper: Footballer = match_node.teams[team_id][0]
			var keeper_sprite: AnimatedSprite3D = presenter.player_sprites[keeper.get_instance_id()]
			var original_run := player_sprite.sprite_frames.get_frame_texture(&"run", 0)
			var original_other := player_sprite.sprite_frames.get_frame_texture(
					&"slide_tackle" if animation == &"tackle" else &"tackle", 0
			)
			var original_keeper := keeper_sprite.sprite_frames.get_frame_texture(animation, 0)
			var original_fps := player_sprite.sprite_frames.get_animation_speed(animation)
			presenter._apply_verified_tackle_frames([], team_id, animation)
			assert(player_sprite.sprite_frames.get_frame_texture(animation, 0) != normalized[0])
			presenter._apply_verified_tackle_frames(normalized, team_id, animation)
			assert(player_sprite.sprite_frames.get_frame_texture(animation, 0) == normalized[0])
			assert(player_sprite.sprite_frames.get_frame_texture(animation, 7) == normalized[7])
			assert(player_sprite.sprite_frames.get_frame_texture(&"run", 0) == original_run)
			assert(player_sprite.sprite_frames.get_animation_speed(animation) == original_fps)
			assert(player_sprite.sprite_frames.get_frame_texture(
					&"slide_tackle" if animation == &"tackle" else &"tackle", 0
			) == original_other)
			assert(keeper_sprite.sprite_frames.get_frame_texture(animation, 0) == original_keeper)
	print("football tackle v2 R2 four-sheet staging, frames and fallback: OK")
	quit(0)
