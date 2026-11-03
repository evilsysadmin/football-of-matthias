class_name ChessFootballTackleR2
extends RefCounted

# The four operator-uploaded WebPs are 2172x724 illustrations, NOT 8x128
# rasters. Their measured figure rectangles are pinned beside their SHA256.
# This decoder normalizes poses without rewriting or resending R2 objects.
const META_PATH := "res://optional_tackles_v2.json"
const SOURCE_SIZE := Vector2i(2172, 724)
const OUTPUT_SIZE := Vector2i(128, 144)
const POSE_SCALE := 0.43
const BOOT_BASELINE := 135
const FRAME_MARGIN := 2

static var _meta_cache: Dictionary = {}


static func metadata() -> Dictionary:
	if not _meta_cache.is_empty():
		return _meta_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if parsed is Dictionary:
		_meta_cache = parsed
	return _meta_cache


static func source_entry(team_id: int, animation: StringName) -> Dictionary:
	var team := "fc_matthias" if team_id == 0 else "real_enroque"
	if team_id not in [0, 1] or animation not in [&"tackle", &"slide_tackle"]:
		return {}
	var entries: Array = metadata().get("entries", [])
	for candidate in entries:
		if candidate is Dictionary and candidate.get("team") == team and candidate.get("animation") == String(animation):
			return candidate
	return {}


static func active_entry(team_id: int, animation: StringName) -> Dictionary:
	var source := source_entry(team_id, animation)
	var meta := metadata()
	if source.is_empty() or meta.get("enabled") != true:
		return {}
	# A private Cloudflare Dashboard bucket path is NOT a public URL.
	# Invalid/unconfigured public origins must not start requests.
	var cdn_base := String(meta.get("cdn_base", "")).trim_suffix("/")
	if not cdn_base.begins_with("https://"):
		return {}
	var selected: Dictionary = source.duplicate(true)
	selected["url"] = cdn_base + "/" + String(source["file"])
	if not ChessFootballR2AtlasLoader.valid_metadata(selected):
		return {}
	return selected


static func frames_from_image(image: Image, source: Dictionary) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if image == null or image.get_size() != SOURCE_SIZE:
		print("TACKLE_DEBUG size mismatch")
		return frames
	var rects: Array = source.get("rects", [])
	if rects.size() != 8 or source.get("cell", {}) != {"width": SOURCE_SIZE.x, "height": SOURCE_SIZE.y}:
		print("TACKLE_DEBUG layout mismatch: ", rects.size(), " ", source.get("cell", {}))
		return frames
	var rgba: Image = image.duplicate()
	if rgba.has_mipmaps():
		rgba.clear_mipmaps()
	if rgba.get_format() != Image.FORMAT_RGBA8:
		rgba.convert(Image.FORMAT_RGBA8)
	var normalized: Array[Image] = []
	for coords in rects:
		if not coords is Array or coords.size() != 4:
			return []
		var x := int(coords[0])
		var y := int(coords[1])
		var width := int(coords[2])
		var height := int(coords[3])
		if x < FRAME_MARGIN or y < FRAME_MARGIN or width < 60 or height < 80:
			return []
		if x + width + FRAME_MARGIN > SOURCE_SIZE.x or y + height + FRAME_MARGIN > SOURCE_SIZE.y:
			return []
		# Keep a two-pixel antialias fringe. Figure rectangles come from
		# connected components, not equal divisions of the original sheet.
		var crop: Image = rgba.get_region(Rect2i(
			x - FRAME_MARGIN, y - FRAME_MARGIN,
			width + FRAME_MARGIN * 2, height + FRAME_MARGIN * 2
		))
		var target_width := maxi(1, roundi(float(crop.get_width()) * POSE_SCALE))
		var target_height := maxi(1, roundi(float(crop.get_height()) * POSE_SCALE))
		if target_width > OUTPUT_SIZE.x - 8 or target_height > BOOT_BASELINE - 8:
			print("TACKLE_DEBUG target width/height mismatch: ", target_width, " ", target_height)
			return []
		crop.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
		var target: Image = Image.create(OUTPUT_SIZE.x, OUTPUT_SIZE.y, false, Image.FORMAT_RGBA8)
		target.fill(Color.TRANSPARENT)
		target.blit_rect(
			crop, Rect2i(Vector2i.ZERO, crop.get_size()),
			Vector2i((OUTPUT_SIZE.x - target_width) / 2, BOOT_BASELINE - target_height)
		)
		if target.get_used_rect().size.y < 40:
			print("TACKLE_DEBUG empty crop ", target.get_used_rect())
			return []
		normalized.append(target)
	# Atomic conversion: never return partially decoded action animations.
	for target in normalized:
		var texture: ImageTexture = ImageTexture.create_from_image(target)
		ChessFootballSpriteBank._register_frame_bottom(texture, target)
		frames.append(texture)
	return frames
