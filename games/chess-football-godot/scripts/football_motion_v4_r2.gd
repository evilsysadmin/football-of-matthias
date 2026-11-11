class_name ChessFootballMotionV4R2
extends RefCounted

# Optional, inactive until the operator uploads and approves exact WebP bytes.
# Preserve verified v1-v3 assets if any request, SHA, geometry or frame fails.
const META_PATH := "res://optional_motion_v4.json"
const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v4/"
const CLUBS := ["fc_matthias", "real_enroque"]
const FAMILIES := ["run", "carry_dribble", "pass_shoot"]
const ROWS := {"run": 5, "carry_dribble": 2, "pass_shoot": 2}
const COLUMNS := {"run": 24, "carry_dribble": 16, "pass_shoot": 16}
const WIDTH := 128
const HEIGHT := 144
const HASHES := {
	"fc_matthias:run": "7ecd05a314c7fe0a1ea2a8425bd2e9b3ed2b9414112946b59fe1ffd6afc1ecef",
	"fc_matthias:carry_dribble": "3930519b22b9ec4c7a128835a13939f9a1cbe8f6f08d1424ff29151f3ac1875f",
	"fc_matthias:pass_shoot": "5e63f567c618a94019c60cfc6e2d0f49240f2ccddbc4e17284bfc296e70bd0d2",
	"real_enroque:run": "13ecba09fb61a26a239b278c4bd3fc0f7a29fac335fed94daf760a8ba46d42ce",
	"real_enroque:carry_dribble": "feec3b22a79299c2366c596bf3cccbf9e6aeb893514aeb0f4363307afb85357f",
	"real_enroque:pass_shoot": "9879aa2a88f06b2f6a1b5c1fee971f178a199361c028cee4a93f843325b1d2d7",
}


static func sheet_meta(team_id: int, family: String) -> Dictionary:
	if team_id not in [0, 1] or family not in FAMILIES:
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if not parsed is Dictionary:
		return {}
	var contract: Dictionary = parsed
	if (
		contract.get("enabled") != true
		or int(contract.get("version", 0)) != 4
		or contract.get("quality_contract") != "football-motion-optical-flow-v4-candidates"
		or contract.get("bucket") != "football"
		or contract.get("prefix") != "atlases/v4/"
		or contract.get("cdn_base") != TRUSTED_ROOT.trim_suffix("/")
	):
		return {}
	var cell: Variant = contract.get("cell", {})
	if not cell is Dictionary or int(cell.get("width", 0)) != WIDTH or int(cell.get("height", 0)) != HEIGHT:
		return {}
	var entries: Variant = contract.get("entries", [])
	if not entries is Array or entries.size() != HASHES.size():
		return {}
	var seen: Dictionary = {}
	for item in entries:
		if not item is Dictionary:
			return {}
		var club: String = String(item.get("team", ""))
		var name: String = String(item.get("family", ""))
		var key: String = club + ":" + name
		if key not in HASHES or seen.has(key):
			return {}
		if (
			item.get("file") != club + "_" + name + "_v4.webp"
			or item.get("sha256") != HASHES[key]
			or int(item.get("columns", 0)) != int(COLUMNS.get(name, 0))
			or int(item.get("rows", 0)) != int(ROWS.get(name, 0))
		):
			return {}
		seen[key] = true
	var wanted: String = CLUBS[team_id] + ":" + family
	if not seen.has(wanted):
		return {}
	var meta := {
		"url": TRUSTED_ROOT + CLUBS[team_id] + "_" + family + "_v4.webp",
		"sha256": HASHES[wanted],
		"cell": {"width": WIDTH, "height": HEIGHT},
		"columns": int(COLUMNS[family]), "rows": int(ROWS[family]),
	}
	return meta if ChessFootballR2AtlasLoader.valid_metadata(meta, TRUSTED_ROOT) else {}


static func frames_from_image(image: Image, family: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if image == null or family not in FAMILIES:
		return frames
	var columns: int = int(COLUMNS[family])
	var rows: int = int(ROWS[family])
	if image.get_size() != Vector2i(WIDTH * columns, HEIGHT * rows):
		return frames
	var source: Image = image
	if image.get_format() != Image.FORMAT_RGBA8:
		source = image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var regions: Array[Image] = []
	for row in range(rows):
		for column in range(columns):
			var crop := source.get_region(Rect2i(column * WIDTH, row * HEIGHT, WIDTH, HEIGHT))
			var box: Rect2i = crop.get_used_rect()
			if (
				box.size.x < 43 or box.position.x < 3 or box.end.x > 125
				or box.size.y < 86 or box.position.y > 35 or box.end.y < 124 or box.end.y > 140
				or crop.get_pixel(0, 0).a > 0.05
				or crop.get_pixel(WIDTH - 1, 0).a > 0.05
			):
				return []
			regions.append(crop)
	for crop in regions:
		var texture := ImageTexture.create_from_image(crop)
		ChessFootballSpriteBank._register_frame_bottom(texture, crop)
		frames.append(texture)
	return frames
