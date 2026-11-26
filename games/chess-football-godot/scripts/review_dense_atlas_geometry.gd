extends SceneTree

# Offline geometry check with the exact runtime decoder. No uploads,
# activation, R2 requests or changes to the scene. Usage:
# godot --headless --path games/chess-football-godot --script res://scripts/review_dense_atlas_geometry.gd -- /absolute/path/sheet.webp
func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		printerr("Usage: -- /absolute/path/sheet.webp [more sheets]")
		quit(2)
		return
	var rejected := 0
	for path in paths:
		var bytes := FileAccess.get_file_as_bytes(path)
		var image := Image.new()
		if bytes.is_empty() or bytes.size() > ChessFootballR2AtlasLoader.MAX_PAYLOAD_BYTES or image.load_webp_from_buffer(bytes) != OK:
			printerr("FOOTBALL_DENSE_GEOMETRY_REJECTED ", path.get_file(), " invalid_webp_or_size")
			rejected += 1
			continue
		var count := 24 if image.get_width() == 3072 else 16
		var reason := ChessFootballDenseV1R2.frame_geometry_error(image, count)
		if not reason.is_empty():
			printerr("FOOTBALL_DENSE_GEOMETRY_REJECTED ", path.get_file(), " ", reason)
			rejected += 1
			continue
		print("FOOTBALL_DENSE_GEOMETRY_OK ", path.get_file(), " cells=", count, " geometry_only=true")
	quit(1 if rejected > 0 else 0)
