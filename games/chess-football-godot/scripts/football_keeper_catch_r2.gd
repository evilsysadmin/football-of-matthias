class_name ChessFootballKeeperCatchR2
extends RefCounted

# Two original 8-frame front-view reception sheets, each derived from its
# club's approved keeper run raster. No ball painted in the sheet; the match
# retains authority over its one 3D ball. Disabled until operator R2 upload.
const META_PATH := "res://optional_keeper_catch_v1.json"
const SHEET_SIZE := Vector2i(1024, 144)
const CELL_SIZE := Vector2i(128, 144)
const FRAMES := 8

static var _meta_cache: Dictionary = {}


static func metadata() -> Dictionary:
	if not _meta_cache.is_empty():
		return _meta_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if parsed is Dictionary:
		_meta_cache = parsed
	return _meta_cache


static func source_entry(team_id: int) -> Dictionary:
	if team_id not in [0, 1]:
		return {}
	var team_key := "fc_matthias" if team_id == 0 else "real_enroque"
	var entries: Array = metadata().get("entries", [])
	for entry in entries:
		if entry is Dictionary and String(entry.get("team", "")) == team_key:
			return entry
	return {}


# The signed game manifest, not downloaded content or URL query data,
# chooses which single independent public origin to trust. The old shared
# Chess Studio CDN does not serve the operator's dedicated 'football' bucket.
static func trusted_public_root(config: Dictionary) -> String:
	if config.get("enabled") != true:
		return ""
	if config.get("bucket") != "football" or config.get("prefix") != "atlases/v1/":
		return ""
	var base := String(config.get("cdn_base", ""))
	if not base.begins_with("https://") or not base.ends_with("/atlases/v1"):
		return ""
	var host := base.trim_prefix("https://").get_slice("/", 0)
	if host == "assets.chess-studio.shadowops.dpdns.org":
		return ""
	if not host.contains(".") or host.begins_with(".") or host.ends_with("."):
		return ""
	if host.is_valid_ip_address():
		return ""
	for label in host.split("."):
		if label.is_empty() or label.begins_with("-") or label.ends_with("-"):
			return ""
	for ch in host:
		if "abcdefghijklmnopqrstuvwxyz0123456789-.".find(ch) < 0:
			return ""
	return base + "/"


static func public_root() -> String:
	return trusted_public_root(metadata())


static func active_entry(team_id: int) -> Dictionary:
	var config := metadata()
	var source := source_entry(team_id)
	var root := trusted_public_root(config)
	if root.is_empty() or source.is_empty():
		return {}
	var selected: Dictionary = source.duplicate(true)
	selected["url"] = root + String(source["file"])
	selected["cell"] = config.get("cell", {})
	selected["columns"] = config.get("columns", 0)
	selected["rows"] = config.get("rows", 0)
	if not ChessFootballR2AtlasLoader.valid_metadata(selected, root):
		return {}
	return selected


static func frames_from_image(image: Image, source: Dictionary) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	if image == null or image.get_size() != SHEET_SIZE:
		return textures
	if String(source.get("sha256", "")).length() != 64:
		return textures
	var rgba: Image = image.duplicate()
	if rgba.has_mipmaps():
		rgba.clear_mipmaps()
	if rgba.get_format() != Image.FORMAT_RGBA8:
		rgba.convert(Image.FORMAT_RGBA8)
	var crops: Array[Image] = []
	for index in range(FRAMES):
		var region: Image = rgba.get_region(Rect2i(index * CELL_SIZE.x, 0, CELL_SIZE.x, CELL_SIZE.y))
		var visible: Rect2i = region.get_used_rect()
		# Reject empty cells, clipped boots, transparent junk and full-cell
		# placeholder art before mutating even one live SpriteFrames bank.
		if visible.size.x < 40 or visible.size.y < 116:
			return []
		if visible.position.x < 8 or visible.end.x > 120:
			return []
		if visible.position.y < 4 or visible.end.y > 135 or visible.end.y < 125:
			return []
		crops.append(region)
	for region in crops:
		var texture: ImageTexture = ImageTexture.create_from_image(region)
		ChessFootballSpriteBank._register_frame_bottom(texture, region)
		textures.append(texture)
	return textures
