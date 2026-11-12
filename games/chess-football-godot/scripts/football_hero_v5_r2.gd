class_name ChessFootballHeroV5R2
extends RefCounted

# SHA-pinned operator upload, not enabled until all four published R2 objects
# have been independently verified. Keep existing V1-V4 atlases on any error.
const META_PATH := "res://optional_hero_v5.json"
const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v5/"
const CLUBS := ["fc_matthias", "real_enroque"]
const FAMILIES := ["locomotion", "dribbles"]
const ROWS := {"locomotion": 3, "dribbles": 2}
const COLS := 16
const WIDTH := 128
const HEIGHT := 144
const SHA256 := {
	"fc_matthias:locomotion": "332d71b141db33af14ae755c80d00d26fc90eb9e3810e279de2e6a3b05c059e2",
	"fc_matthias:dribbles": "0d98a751d53354f77fabf40ddb10fefa848ee70408e05e811cf88f0d409a26ad",
	"real_enroque:locomotion": "b551b67dde35cd1a7df7c6e1c67004ab8650ef22b750b610d8e78efc049f1529",
	"real_enroque:dribbles": "d8a90faccd102db66afd1f2c19096738974b54a6f8ea3bb32f09136a7f218da3"
}


static func sheet_meta(team_id: int, family: String) -> Dictionary:
	if team_id not in [0, 1] or family not in FAMILIES:
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if not raw is Dictionary:
		return {}
	var doc: Dictionary = raw
	if (
		doc.get("enabled") != true or int(doc.get("schema", 0)) != 5
		or int(doc.get("version", 0)) != 5
		or doc.get("quality_contract") != "football-generated-hero-v5-8pose"
		or doc.get("bucket") != "football" or doc.get("prefix") != "atlases/v5/"
		or doc.get("cdn_base") != TRUSTED_ROOT.trim_suffix("/")
		or int(doc.get("columns", 0)) != COLS
	):
		return {}
	var cell: Variant = doc.get("cell", {})
	if not cell is Dictionary or int(cell.get("width", 0)) != WIDTH or int(cell.get("height", 0)) != HEIGHT:
		return {}
	var entries: Variant = doc.get("entries", [])
	if not entries is Array or entries.size() != SHA256.size():
		return {}
	# A single bad family or unapproved hash rejects the ENTIRE pack.
	var seen: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary:
			return {}
		var club: String = String(entry.get("team", ""))
		var name: String = String(entry.get("family", ""))
		var key: String = club + ":" + name
		if key not in SHA256 or seen.has(key):
			return {}
		if (
			entry.get("file") != club + "_" + name + "_v5.webp"
			or entry.get("sha256") != SHA256[key]
			or int(entry.get("columns", 0)) != COLS
			or int(entry.get("rows", 0)) != int(ROWS.get(name, 0))
			or int(entry.get("bytes", 0)) < 10000
		):
			return {}
		seen[key] = true
	var wanted: String = CLUBS[team_id] + ":" + family
	if not seen.has(wanted):
		return {}
	var meta := {
		"url": TRUSTED_ROOT + CLUBS[team_id] + "_" + family + "_v5.webp",
		"sha256": SHA256[wanted],
		"cell": {"width": WIDTH, "height": HEIGHT},
		"columns": COLS, "rows": int(ROWS[family])
	}
	return meta if ChessFootballR2AtlasLoader.valid_metadata(meta, TRUSTED_ROOT) else {}


static func frames_from_image(image: Image, family: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if family not in FAMILIES or image == null:
		return frames
	var count: int = int(ROWS[family])
	if image.get_size() != Vector2i(WIDTH * COLS, HEIGHT * count):
		return frames
	var source := image
	if source.get_format() != Image.FORMAT_RGBA8:
		source = image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var regions: Array[Image] = []
	# Validate the COMPLETE image before allocating any GPU texture.
	for row in range(count):
		for column in range(COLS):
			var crop := source.get_region(Rect2i(column * WIDTH, row * HEIGHT, WIDTH, HEIGHT))
			var box := crop.get_used_rect()
			if (
				box.size.x < 35 or box.size.y < 75
				or box.position.x < 3 or box.end.x > 125
				or box.position.y < 3 or box.position.y > 36
				or box.end.y < 105 or box.end.y > 139
				or crop.get_pixel(0, 0).a > 0.05
				or crop.get_pixel(WIDTH - 1, 0).a > 0.05
			):
				return []
			regions.append(crop)
	for index in range(regions.size()):
		# The pinned V5 dribble sources deliberately include ghosted
		# in-between poses at odd columns (double arms/legs/torso).
		# Gameplay needs the eight SOLID authored poses instead: repeat
		# the preceding verified even texture at the odd time slots.
		# Keep 16 time slots and the original immutable R2 hash intact.
		# Locomotion is deliberately untouched.
		if family == "dribbles" and index % 2 == 1:
			frames.append(frames[index - 1])
			continue
		var crop: Image = regions[index]
		var texture := ImageTexture.create_from_image(crop)
		ChessFootballSpriteBank._register_frame_bottom(texture, crop)
		frames.append(texture)
	return frames


# Animation names are dedicated so a 3D-only action cannot affect the real
# 2D collision sprite or the R2 cut/slide atlas prior to V5 approval.
static func action_animation(mode: String, active: bool, verified: bool) -> StringName:
	if not active or not verified:
		return &""
	if mode == "feint":
		return &"hero_feint"
	if mode in ["cut", "burst"]:
		return &"hero_cut"
	return &""
