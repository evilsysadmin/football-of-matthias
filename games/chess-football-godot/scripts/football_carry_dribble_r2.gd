class_name ChessFootballCarryDribbleR2
extends RefCounted

# Visual-only side-view movement while the real Godot ball remains authoritative.
# Disabled until exact user-published WebPs pass HTTPS/CORS/SHA and visual review.
const META_PATH := "res://optional_carry_dribble_v1.json"
const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v1/"
const KINDS := ["fc_matthias", "real_enroque"]
const ANIMATIONS := [&"carry", &"dribble"]
const WIDTH := 128
const HEIGHT := 144
const COLUMNS := 8
const ROWS := 2
const HASHES := [
	"d77d23b1a19bd454a829e6a2368aeefbeaa0ca42ee5b1a2ec530218437a0ef9d",
	"39606797cb05c582c598cb5b599cc59104e3926a963bbc445dc0444aaa80bbeb",
]

static func metadata() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	return data if data is Dictionary else {}


static func sheet_meta(team_id: int) -> Dictionary:
	if team_id not in [0, 1]:
		return {}
	var contract := metadata()
	if contract.get("enabled") != true or contract.get("quality_contract") != "football-carry-dribble-side-v1":
		return {}
	if contract.get("bucket") != "football" or contract.get("prefix") != "atlases/v1/":
		return {}
	if contract.get("cdn_base") != TRUSTED_ROOT.trim_suffix("/"):
		return {}
	var cell: Variant = contract.get("cell", {})
	if not cell is Dictionary or int(cell.get("width", 0)) != WIDTH or int(cell.get("height", 0)) != HEIGHT:
		return {}
	if int(contract.get("columns", 0)) != COLUMNS or int(contract.get("rows", 0)) != ROWS:
		return {}
	if contract.get("animations") != ["carry", "dribble"]:
		return {}
	if contract.get("fps") != {"carry": 12, "dribble": 36}:
		return {}
	var entries: Variant = contract.get("entries", [])
	if not entries is Array or entries.size() != 2:
		return {}
	var kind: String = String(KINDS[team_id])
	var file_name: String = kind + "_carry_dribble_v1.webp"
	for entry in entries:
		if not entry is Dictionary or entry.get("team") != kind:
			continue
		if entry.get("file") != file_name or entry.get("sha256") != HASHES[team_id]:
			return {}
		var meta := {
			"url": TRUSTED_ROOT + file_name,
			"sha256": HASHES[team_id],
			"cell": {"width": WIDTH, "height": HEIGHT},
			"columns": COLUMNS, "rows": ROWS,
		}
		return meta if ChessFootballR2AtlasLoader.valid_metadata(meta, TRUSTED_ROOT) else {}
	return {}


# Do not replace authored front/back/diagonal motion with a sideways body.
# An in-flight pass, shot, tackle or keeper action always wins over this overlay.
static func animation_for(
	base: StringName, view: String, role: String, owns_ball: bool, burst: bool
) -> StringName:
	if role == "keeper" or not owns_ball or view != "side":
		return base
	if base not in [&"run", &"sprint"]:
		return base
	return &"dribble" if burst else &"carry"


static func frames_from_image(image: Image) -> Array[Texture2D]:
	var output: Array[Texture2D] = []
	if image == null or image.get_size() != Vector2i(WIDTH * COLUMNS, HEIGHT * ROWS):
		return output
	var source := image
	if image.get_format() != Image.FORMAT_RGBA8:
		source = image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var cells: Array[Image] = []
	for row in range(ROWS):
		for col in range(COLUMNS):
			var region := source.get_region(Rect2i(col * WIDTH, row * HEIGHT, WIDTH, HEIGHT))
			var bounds := region.get_used_rect()
			if bounds.size.x < 45 or bounds.size.x > 114:
				return []
			if bounds.size.y < 95 or bounds.position.y > 28 or bounds.end.y < 125 or bounds.end.y > 139:
				return []
			if region.get_pixel(0, 0).a > 0.05 or region.get_pixel(WIDTH - 1, 0).a > 0.05:
				return []
			cells.append(region)
	# All-or-nothing: do not allocate any GPU frame on an invalid sheet.
	for region in cells:
		var texture := ImageTexture.create_from_image(region)
		ChessFootballSpriteBank._register_frame_bottom(texture, region)
		output.append(texture)
	return output
