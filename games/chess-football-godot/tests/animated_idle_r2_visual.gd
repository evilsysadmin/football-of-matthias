extends SceneTree

# Real 1280x720 Godot renderer captures, not a synthetic PNG montage.
# The CI download has already verified HTTPS/CORS/SHA of all three public
# R2 WebPs. Re-verify exact bytes through the SAME runtime decoder.
const VIEWS := ["front", "back", "side", "front_diagonal", "back_diagonal"]
const CROP_SIZE := Vector2i(240, 320)

func _initialize() -> void:
	var asset_dir := OS.get_environment("FOOTBALL_IDLE_R2_PREVIEW_DIR")
	assert(not asset_dir.is_empty(), "Missing verified R2 sheet directory")
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var game = packed.instantiate()
	root.add_child(game)
	for _frame in range(8):
		await process_frame
		await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var presenter: ChessFootball3DPresenter = game.presentation_3d
	assert(presenter != null)

	var targets: Array[Footballer] = [
		game.teams[0][1], game.teams[1][1], game.teams[0][0], game.teams[1][0]
	]
	# Keep the same camera/actor geometry before and after. Isolate the
	# subject so nearby footballers never occlude boots or action poses.
	for team in game.teams:
		for actor in team:
			actor.action_lock_seconds = 0.0
			actor.velocity = Vector2.ZERO
			actor.global_position = Vector2(-9999.0, -9999.0)
	game.ball.global_position = Vector2(-9999.0, -9999.0)

	var before := Image.create(CROP_SIZE.x * 5, CROP_SIZE.y * 4, false, Image.FORMAT_RGBA8)
	before.fill(Color("#103a2d"))
	for row in range(targets.size()):
		var actor: Footballer = targets[row]
		actor.global_position = ChessFootballMath.PITCH_RECT.get_center()
		for column in range(VIEWS.size()):
			var shot: Image = await _capture_actor(game, actor, VIEWS[column], 0)
			before.blit_rect(shot, Rect2i(Vector2i.ZERO, CROP_SIZE),
				Vector2i(column * CROP_SIZE.x, row * CROP_SIZE.y))
		actor.global_position = Vector2(-9999.0, -9999.0)

	for kind in ChessFootballIdleR2.KINDS:
		var meta := ChessFootballIdleR2.sheet_meta(kind)
		assert(not meta.is_empty())
		var file_path := asset_dir.path_join(kind + "_idle_v1.webp")
		assert(FileAccess.file_exists(file_path), "Required R2 WebP missing: " + file_path)
		var bytes := FileAccess.get_file_as_bytes(file_path)
		var decoded := ChessFootballR2AtlasLoader.decode_verified_webp(
			bytes, meta, ChessFootballIdleR2.TRUSTED_ROOT
		)
		assert(decoded != null, "Runtime SHA/format verification failed: " + kind)
		presenter._on_animated_idle_ready(decoded, kind)
		assert(bool(presenter._animated_idle_r2_loaded.get(kind, false)))

	var after := Image.create(CROP_SIZE.x * 5, CROP_SIZE.y * 4, false, Image.FORMAT_RGBA8)
	after.fill(Color("#103a2d"))
	var motion := Image.create(CROP_SIZE.x * 2, CROP_SIZE.y * 4, false, Image.FORMAT_RGBA8)
	motion.fill(Color("#103a2d"))
	for row in range(targets.size()):
		var actor: Footballer = targets[row]
		actor.global_position = ChessFootballMath.PITCH_RECT.get_center()
		for column in range(VIEWS.size()):
			var shot: Image = await _capture_actor(game, actor, VIEWS[column], 0)
			after.blit_rect(shot, Rect2i(Vector2i.ZERO, CROP_SIZE),
				Vector2i(column * CROP_SIZE.x, row * CROP_SIZE.y))
			if column == 0:
				motion.blit_rect(shot, Rect2i(Vector2i.ZERO, CROP_SIZE),
					Vector2i(0, row * CROP_SIZE.y))
		var late: Image = await _capture_actor(game, actor, "front", 35)
		motion.blit_rect(late, Rect2i(Vector2i.ZERO, CROP_SIZE),
			Vector2i(CROP_SIZE.x, row * CROP_SIZE.y))
		actor.global_position = Vector2(-9999.0, -9999.0)

	await _save(before, "BEFORE", "football-idle-r2-before.png")
	await _save(after, "AFTER", "football-idle-r2-after.png")
	await _save(motion, "MOTION", "football-idle-r2-motion.png")
	print("FOOTBALL_IDLE_R2_REAL_GODOT_REVIEW_OK actors=4 views=5 phases=2")
	quit(0)


static func _movement_for_view(view: String) -> Vector2:
	match view:
		"front":
			return Vector2.DOWN
		"back":
			return Vector2.UP
		"side":
			return Vector2.RIGHT
		"front_diagonal":
			return Vector2(1.0, 1.0).normalized()
		"back_diagonal":
			return Vector2(1.0, -1.0).normalized()
	return Vector2.DOWN


func _capture_actor(game: Node, actor: Footballer, view: String, ticks: int) -> Image:
	var presenter: ChessFootball3DPresenter = game.presentation_3d
	var key := actor.get_instance_id()
	actor.velocity = _movement_for_view(view) * actor.base_speed
	actor._sync_locomotion(false)
	presenter.sync_presentation(0.0, "broadcast")
	actor.velocity = Vector2.ZERO
	actor._sync_locomotion(false)
	if actor.role == "keeper":
		presenter.keeper_visual_names.erase(key)
		presenter.keeper_visual_phases.erase(key)
	else:
		presenter.outfield_visual_names.erase(key)
		presenter.outfield_visual_phases.erase(key)
	presenter.sync_presentation(0.0, "broadcast")
	var sprite: AnimatedSprite3D = presenter.player_sprites[key]
	var expected := ChessFootballRunDirection.animation_for(&"idle", view)
	assert(sprite.animation == expected, "Idle facing does not match authored view")
	for _tick in range(ticks):
		presenter.sync_presentation(1.0 / 60.0, "broadcast")
	if ticks > 0:
		assert(sprite.sprite_frames.get_frame_count(expected) == 8)
		assert(sprite.frame >= 3 and sprite.frame <= 5)
	# Same physical scene and camera geometry for old and new assets.
	var target := presenter.world_to_stage(actor.global_position)
	presenter.camera.position = target + Vector3(0.0, 1.7, 4.8)
	presenter.camera.look_at(target + Vector3(0.0, 0.78, 0.0), Vector3.UP)
	await process_frame
	var viewport := game.get_viewport()
	var image := viewport.get_texture().get_image()
	assert(image != null and image.get_size() == Vector2i(1280, 720))
	var center: Vector2 = presenter.camera.unproject_position(sprite.global_position)
	var x := clampi(int(center.x) - CROP_SIZE.x / 2, 0, image.get_width() - CROP_SIZE.x)
	var y := clampi(int(center.y) - CROP_SIZE.y / 2, 0, image.get_height() - CROP_SIZE.y)
	return image.get_region(Rect2i(x, y, CROP_SIZE.x, CROP_SIZE.y))


func _save(image: Image, marker: String, name: String) -> void:
	var path := "user://" + name
	assert(image.save_png(path) == OK)
	print("FOOTBALL_IDLE_R2_CAPTURE_" + marker + "=" + ProjectSettings.globalize_path(path))
