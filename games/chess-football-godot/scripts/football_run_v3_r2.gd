class_name ChessFootballRunV3R2
extends RefCounted

# Only the exact two user-uploaded, SHA-pinned 12 x 5 R2 atlases.
# Never replace the approved v2 fallback or change the 2D match authority.
const META_PATH := "res://optional_run_v3.json"
const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v3/"
const KINDS := ["fc_matthias", "real_enroque"]
const ANIMATIONS := ["run_front", "run_back", "run", "run_front_diagonal", "run_back_diagonal"]
const EXPECTED_SHA := [
	"8208785adbda34a893c8445299c32a04714932feabcb8aa41ae39b8a1f9177af",
	"be73bb8fee9b1fa830ae7f405c533cb4e2fc7538c9fe248c65b0f9e63a655e01",
]
const WIDTH := 128
const HEIGHT := 144
const COLUMNS := 12
const ROWS := 5
const FPS := 18.0

static func sheet_meta(team_id: int) -> Dictionary:
	if team_id not in [0, 1]:
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if not parsed is Dictionary:
		return {}
	var contract: Dictionary = parsed
	if contract.get("enabled") != true or int(contract.get("version", 0)) != 3:
		return {}
	if contract.get("quality_contract") != "football-run-5views-v3":
		return {}
	if contract.get("bucket") != "football" or contract.get("prefix") != "atlases/v3/":
		return {}
	if contract.get("cdn_base") != TRUSTED_ROOT.trim_suffix("/"):
		return {}
	var cell: Variant = contract.get("cell", {})
	if not cell is Dictionary or int(cell.get("width", 0)) != WIDTH or int(cell.get("height", 0)) != HEIGHT:
		return {}
	if int(contract.get("columns", 0)) != COLUMNS or int(contract.get("rows", 0)) != ROWS:
		return {}
	var views: Variant = contract.get("views", [])
	if not views is Array or views.size() != ROWS:
		return {}
	var expected_views := ["front", "back", "side", "front_diagonal", "back_diagonal"]
	for row in range(ROWS):
		if String(views[row]) != expected_views[row]:
			return {}
	if float(contract.get("fps", 0.0)) != FPS:
		return {}
	var entries: Variant = contract.get("entries", [])
	if not entries is Array or entries.size() != 2:
		return {}
	for index in range(2):
		var entry: Variant = entries[index]
		if not entry is Dictionary:
			return {}
		var kind: String = String(KINDS[index])
		if String(entry.get("kind", "")) != kind or String(entry.get("file", "")) != kind + "_run_v3_clean.webp":
			return {}
		if String(entry.get("sha256", "")) != String(EXPECTED_SHA[index]):
			return {}
	var file_name: String = String(KINDS[team_id]) + "_run_v3_clean.webp"
	var meta := {
		"url": TRUSTED_ROOT + file_name,
		"sha256": EXPECTED_SHA[team_id],
		"cell": {"width": WIDTH, "height": HEIGHT},
		"columns": COLUMNS,
		"rows": ROWS,
	}
	return meta if ChessFootballR2AtlasLoader.valid_metadata(meta, TRUSTED_ROOT) else {}


static func frames_from_image(image: Image) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	if image == null or image.get_size() != Vector2i(WIDTH * COLUMNS, HEIGHT * ROWS):
		return textures
	var source: Image = image
	if source.get_format() != Image.FORMAT_RGBA8:
		source = image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var regions: Array[Image] = []
	# Validate every pose before replacing even one player. The 128x144
	# authored frames have clean transparent gutters and a stable bootline.
	for row in range(ROWS):
		for column in range(COLUMNS):
			var crop := source.get_region(Rect2i(column * WIDTH, row * HEIGHT, WIDTH, HEIGHT))
			var bounds: Rect2i = crop.get_used_rect()
			if bounds.size.y < 95 or bounds.position.y > 32 or bounds.end.y < 125 or bounds.end.y > 140:
				return []
			if bounds.size.x < 46 or bounds.position.x < 4 or bounds.end.x > WIDTH - 4:
				return []
			if crop.get_pixel(0, 0).a > 0.05 or crop.get_pixel(WIDTH - 1, 0).a > 0.05:
				return []
			regions.append(crop)
	for crop in regions:
		var texture := ImageTexture.create_from_image(crop)
		ChessFootballSpriteBank._register_frame_bottom(texture, crop)
		textures.append(texture)
	return textures
