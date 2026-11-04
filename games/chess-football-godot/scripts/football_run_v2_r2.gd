class_name ChessFootballRunV2R2
extends RefCounted

# Version 2 is a separate, hash-pinned content bundle. No runtime-generated
# URLs or credentials: only exact known Football R2 objects can be requested.
const META_PATH := "res://optional_run_v2.json"
const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v2/"
const KINDS := ["fc_matthias", "real_enroque"]
const ANIMATIONS := ["run_front", "run_back", "run", "run_front_diagonal", "run_back_diagonal"]
const WIDTH := 128
const HEIGHT := 144
const COLUMNS := 8
const ROWS := 5

static func sheet_meta(team_id: int) -> Dictionary:
	if team_id not in [0, 1]:
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if not value is Dictionary:
		return {}
	var contract: Dictionary = value
	if contract.get("enabled") != true or contract.get("quality_contract") != "football-run-5views-v2":
		return {}
	if contract.get("bucket") != "football" or contract.get("prefix") != "atlases/v2/":
		return {}
	if contract.get("cdn_base") != TRUSTED_ROOT.trim_suffix("/"):
		return {}
	var cell: Variant = contract.get("cell", {})
	if not cell is Dictionary or int(cell.get("width", 0)) != WIDTH or int(cell.get("height", 0)) != HEIGHT:
		return {}
	if int(contract.get("columns", 0)) != COLUMNS or int(contract.get("rows", 0)) != ROWS:
		return {}
	if contract.get("views") != ["front", "back", "side", "front_diagonal", "back_diagonal"]:
		return {}
	var entries: Variant = contract.get("entries", [])
	if not entries is Array or entries.size() != 2:
		return {}
	var kind: String = String(KINDS[team_id])
	for entry in entries:
		if not entry is Dictionary or entry.get("kind") != kind:
			continue
		var file_name: String = kind + "_run_v2_clean.webp"
		if entry.get("file") != file_name:
			return {}
		var meta := {
			"url": TRUSTED_ROOT + file_name,
			"sha256": entry.get("sha256", ""),
			"cell": {"width": WIDTH, "height": HEIGHT},
			"columns": COLUMNS,
			"rows": ROWS,
		}
		if ChessFootballR2AtlasLoader.valid_metadata(meta, TRUSTED_ROOT):
			return meta
	return {}


static func frames_from_image(image: Image) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	if image == null or image.get_size() != Vector2i(WIDTH * COLUMNS, HEIGHT * ROWS):
		return textures
	var source := image
	if source.get_format() != Image.FORMAT_RGBA8:
		source = image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var regions: Array[Image] = []
	# Fail closed on sparse, oversized or transparent 5x8 sheets.
	# Validate every cell before replacing even one actor frame.
	for row in range(ROWS):
		for column in range(COLUMNS):
			var region := source.get_region(Rect2i(column * WIDTH, row * HEIGHT, WIDTH, HEIGHT))
			var box := region.get_used_rect()
			if box.size.y < 94 or box.position.y > 20 or box.end.y < 125 or box.end.y > 142:
				return []
			if box.size.x < 45 or box.size.x > 113:
				return []
			if region.get_pixel(0, 0).a > 0.05 or region.get_pixel(WIDTH - 1, 0).a > 0.05:
				return []
			regions.append(region)
	for region in regions:
		var texture := ImageTexture.create_from_image(region)
		ChessFootballSpriteBank._register_frame_bottom(texture, region)
		textures.append(texture)
	return textures
