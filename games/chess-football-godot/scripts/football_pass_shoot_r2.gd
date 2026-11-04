class_name ChessFootballPassShootR2
extends RefCounted

# Authored action candidates. Disabled until the operator publishes both
# immutable WebPs to the dedicated Football R2 bucket and visual QA passes.
const META_PATH := "res://optional_pass_shoot_v1.json"
const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v1/"
const TEAMS := ["fc_matthias", "real_enroque"]
const ANIMATIONS := [&"pass", &"shoot"]
const CELL := Vector2i(128, 144)
const COLUMNS := 8
const ROWS := 2

static func metadata() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	return parsed if parsed is Dictionary else {}


static func sheet_meta(team_id: int) -> Dictionary:
	if team_id not in [0, 1]:
		return {}
	var meta := metadata()
	if meta.get("enabled") != true or meta.get("quality_contract") != "football-pass-shoot-v1":
		return {}
	if meta.get("bucket") != "football" or meta.get("prefix") != "atlases/v1/":
		return {}
	if meta.get("cdn_base") != TRUSTED_ROOT.trim_suffix("/"):
		return {}
	var cell: Variant = meta.get("cell", {})
	if not cell is Dictionary or int(cell.get("width", 0)) != CELL.x or int(cell.get("height", 0)) != CELL.y:
		return {}
	if int(meta.get("columns", 0)) != COLUMNS or int(meta.get("rows", 0)) != ROWS:
		return {}
	if meta.get("animations") != ["pass", "shoot"] or int(meta.get("fps", 0)) != 10:
		return {}
	var entries: Variant = meta.get("entries", [])
	if not entries is Array or entries.size() != TEAMS.size():
		return {}
	var key: String = String(TEAMS[team_id])
	for entry in entries:
		if not entry is Dictionary or entry.get("team") != key:
			continue
		var file_name := key + "_pass_shoot_v1.webp"
		if entry.get("file") != file_name:
			return {}
		var candidate := {
			"url": TRUSTED_ROOT + file_name,
			"sha256": entry.get("sha256", ""),
			"cell": {"width": CELL.x, "height": CELL.y},
			"columns": COLUMNS,
			"rows": ROWS,
		}
		return candidate if ChessFootballR2AtlasLoader.valid_metadata(candidate, TRUSTED_ROOT) else {}
	return {}


static func frames_from_image(image: Image) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	if image == null or image.get_size() != Vector2i(CELL.x * COLUMNS, CELL.y * ROWS):
		return textures
	var source := image
	if source.get_format() != Image.FORMAT_RGBA8:
		source = image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var regions: Array[Image] = []
	# Preflight every cell before creating GPU textures. Prevent cards,
	# missing heads, cut boots, or partially accepted sheets.
	for row in range(ROWS):
		for col in range(COLUMNS):
			var region := source.get_region(Rect2i(col * CELL.x, row * CELL.y, CELL.x, CELL.y))
			var box := region.get_used_rect()
			if box.size.x < 50 or box.size.x > 114:
				return []
			if box.size.y < 86 or box.position.y > 30 or box.end.y < 125 or box.end.y > 139:
				return []
			if region.get_pixel(0, 0).a > 0.05 or region.get_pixel(CELL.x - 1, 0).a > 0.05:
				return []
			regions.append(region)
	for region in regions:
		var texture := ImageTexture.create_from_image(region)
		ChessFootballSpriteBank._register_frame_bottom(texture, region)
		textures.append(texture)
	return textures
