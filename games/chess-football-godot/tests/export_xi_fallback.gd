extends SceneTree

# Extract tiny local fallback frames ONLY from hash-pinned, CORS-verified
# R2 sources supplied by CI. Review the candidate PNGs before committing
# their base64 to Git; do not package the full 1024x720 source atlases.
func _initialize() -> void:
	var run_dir := OS.get_environment("FOOTBALL_RUN_V2_PREVIEW_DIR")
	var idle_dir := OS.get_environment("FOOTBALL_IDLE_R2_PREVIEW_DIR")
	var output := OS.get_environment("FOOTBALL_XI_FALLBACK_EXPORT_DIR")
	assert(not run_dir.is_empty() and not idle_dir.is_empty() and not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var made := 0
	for team_id in range(2):
		var kind: String = String(ChessFootballRunV2R2.KINDS[team_id])
		var meta := ChessFootballRunV2R2.sheet_meta(team_id)
		assert(not meta.is_empty())
		var bytes := FileAccess.get_file_as_bytes(run_dir.path_join(kind + "_run_v2_clean.webp"))
		var atlas := ChessFootballR2AtlasLoader.decode_verified_webp(bytes, meta, ChessFootballRunV2R2.TRUSTED_ROOT)
		assert(atlas != null)
		var candidates := ChessFootballRunV2R2.frames_from_image(atlas)
		assert(candidates.size() == 40)
		# A front-view adult footballer, already approved and fully grounded.
		_write_frame(output, kind + "_xi_fallback.b64", (candidates[0] as Texture2D).get_image())
		made += 1
	var keeper_meta := ChessFootballIdleR2.sheet_meta("keeper")
	assert(not keeper_meta.is_empty())
	var keeper_bytes := FileAccess.get_file_as_bytes(idle_dir.path_join("keeper_idle_v1.webp"))
	var keeper_atlas := ChessFootballR2AtlasLoader.decode_verified_webp(keeper_bytes, keeper_meta, ChessFootballIdleR2.TRUSTED_ROOT)
	assert(keeper_atlas != null)
	for team_id in range(2):
		var keeper_frames := ChessFootballIdleR2.frames_from_image(keeper_atlas, "keeper", team_id == 1)
		assert(keeper_frames.size() == 40)
		_write_frame(output, "keeper_%d_xi_fallback.b64" % team_id, (keeper_frames[0] as Texture2D).get_image())
		made += 1
	print("FOOTBALL_XI_FALLBACK_EXPORTED actors=%d" % made)
	quit(0)


func _write_frame(folder: String, filename: String, image: Image) -> void:
	assert(image.get_size() == Vector2i(128, 144))
	var rect := image.get_used_rect()
	assert(rect.size.x >= 45 and rect.size.y >= 90 and rect.end.y <= 142)
	var raw := image.save_png_to_buffer()
	assert(raw.size() > 1000 and raw.size() < 180000)
	var file := FileAccess.open(folder.path_join(filename), FileAccess.WRITE)
	assert(file != null)
	file.store_string(Marshalls.raw_to_base64(raw))
	file.close()
