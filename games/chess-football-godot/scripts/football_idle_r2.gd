class_name ChessFootballIdleR2
extends RefCounted

# Optional full idle cycles. Local canonical animations always exist first.
# This asset set belongs to the independent Football R2 bucket, NOT Chess CDN.
const META_PATH := "res://optional_animated_idle_v1.json"
const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v1/"
const KINDS := ["fc_matthias", "real_enroque", "keeper"]
const IDLE_ANIMATIONS := [
	"idle_front", "idle_back", "idle", "idle_front_diagonal", "idle_back_diagonal"
]
const FRAME_COUNT := 8
const WIDTH := 128
const HEIGHT := 144
const ROW_COUNT := 5

static func sheet_meta(kind: String) -> Dictionary:
	if kind not in KINDS:
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if not value is Dictionary:
		return {}
	var contract: Dictionary = value
	if contract.get("enabled") != true or contract.get("quality_contract") != "football-idle-5views-v1":
		return {}
	if contract.get("bucket") != "football" or contract.get("prefix") != "atlases/v1/":
		return {}
	if contract.get("cdn_base") != TRUSTED_ROOT.trim_suffix("/"):
		return {}
	if contract.get("cell") != {"width": WIDTH, "height": HEIGHT}:
		return {}
	if contract.get("columns") != FRAME_COUNT or contract.get("rows") != ROW_COUNT:
		return {}
	if contract.get("fps") != 7 or contract.get("footline") != 132:
		return {}
	if contract.get("views") != ["front", "back", "side", "front_diagonal", "back_diagonal"]:
		return {}
	var entries: Variant = contract.get("entries", [])
	if not entries is Array or entries.size() != KINDS.size():
		return {}
	for entry in entries:
		if not entry is Dictionary or entry.get("kind") != kind:
			continue
		var file_name := kind + "_idle_v1.webp"
		if entry.get("file") != file_name:
			return {}
		var meta := {
			"url": TRUSTED_ROOT + file_name,
			"sha256": entry.get("sha256", ""),
			"cell": {"width": WIDTH, "height": HEIGHT},
			"columns": FRAME_COUNT,
			"rows": ROW_COUNT
		}
		if ChessFootballR2AtlasLoader.valid_metadata(meta, TRUSTED_ROOT):
			return meta
	return {}


static func frames_from_image(image: Image, kind: String, away_keeper: bool = false) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if kind not in KINDS or image == null or image.get_size() != Vector2i(WIDTH * FRAME_COUNT, HEIGHT * ROW_COUNT):
		return result
	# Accept the decoded image only as a complete, transparent, boot-grounded sheet.
	# Preflight all 40 cells BEFORE creating a single GPU texture.
	var source := image
	if source.get_format() != Image.FORMAT_RGBA8:
		source = image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var regions: Array[Image] = []
	for row in range(ROW_COUNT):
		for column in range(FRAME_COUNT):
			var region := source.get_region(Rect2i(column * WIDTH, row * HEIGHT, WIDTH, HEIGHT))
			var box := region.get_used_rect()
			if box.size.y < 90 or box.position.y > 20 or box.end.y < 126 or box.end.y > 139:
				return []
			if region.get_pixel(0, 0).a > 0.05 or region.get_pixel(WIDTH - 1, 0).a > 0.05:
				return []
			regions.append(region)
	for region in regions:
		if kind == "keeper" and away_keeper:
			# Preserve the already-approved teal away keeper kit. Do not tint
			# gloves, shoes, black sleeves or skin; only yellow-gold fabric.
			var teal := Color("#2bafad")
			for y in range(HEIGHT):
				for x in range(WIDTH):
					var pixel := region.get_pixel(x, y)
					if pixel.a > 0.1 and pixel.h >= 0.105 and pixel.h <= 0.19 and pixel.s >= 0.43 and pixel.v >= 0.28:
						region.set_pixel(x, y, Color.from_hsv(teal.h, pixel.s, pixel.v, pixel.a))
		var texture := ImageTexture.create_from_image(region)
		ChessFootballSpriteBank._register_frame_bottom(texture, region)
		result.append(texture)
	return result
