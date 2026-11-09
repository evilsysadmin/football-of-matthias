class_name ChessFootballActionPosesR2
extends RefCounted

# Separate native 8x128x144 action sheets uploaded by the operator to R2 v2.
# DO NOT feed these into the legacy 2172x724 tackle source crop decoder.
# Exact HTTPS path + SHA-256 + dimensions are checked by the shared loader.
const META_PATH := "res://optional_action_poses_v1.json"
const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v2/"
const CLUBS := ["fc_matthias", "real_enroque"]
const ANIMATIONS := [&"dribble_cut", &"dribble_burst", &"tackle", &"slide_tackle"]
const WIDTH := 128
const HEIGHT := 144
const COLUMNS := 8
const ROWS := 1
const FOOTLINE := 134
const PINNED_SHA := {
	"fc_matthias:dribble_cut": "08d1f14578b5081e90cb3177e13ebff4eefc6d6a4ead238d50dc2566da0835c1",
	"fc_matthias:dribble_burst": "9f28275a1275dfe62c78f39f3b4e584eb3fa23adabb95ab802653d1275370068",
	"fc_matthias:tackle": "86863025bd79a686afd23b1d6355d456f387e044fa9108e9a53f1e1315076e52",
	"fc_matthias:slide_tackle": "66caf6a528c29d9be96db23ed2968d3be7656aa2d5cf33ac4d50d977714ac631",
	"real_enroque:dribble_cut": "7114bac7f966449d1db645d9ceb1b4a2d65f97b903bfba57305e2505eebf7120",
	"real_enroque:dribble_burst": "cf85bf0c1a9003e197ac1ef5d20590471dace55ad246c4725043a6ed40bc7988",
	"real_enroque:tackle": "854e912dbd21e2a66f42faeaec4cefe274747fe5ce69d196585ab7ed45c26d8e",
	"real_enroque:slide_tackle": "20a057e9de63bef269472f2a7f5880a7789ab6753d4716dfe7e274a992dff4c3",
}


static func metadata() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	return data if data is Dictionary else {}


static func sheet_meta(team_id: int, animation: StringName) -> Dictionary:
	if team_id not in [0, 1] or animation not in ANIMATIONS:
		return {}
	var contract := metadata()
	if contract.get("enabled") != true or contract.get("quality_contract") != "football-action-poses-native-v1":
		return {}
	if contract.get("bucket") != "football" or contract.get("prefix") != "atlases/v2/":
		return {}
	if contract.get("cdn_base") != TRUSTED_ROOT.trim_suffix("/"):
		return {}
	if contract.get("cell") != {"width": WIDTH, "height": HEIGHT}:
		return {}
	if int(contract.get("columns", 0)) != COLUMNS or int(contract.get("rows", 0)) != ROWS:
		return {}
	if int(contract.get("footline", 0)) != FOOTLINE:
		return {}
	if contract.get("animations") != ["dribble_cut", "dribble_burst", "tackle", "slide_tackle"]:
		return {}
	var entries: Variant = contract.get("entries", [])
	if not entries is Array or entries.size() != PINNED_SHA.size():
		return {}
	# Reject an altered, duplicated or partially configured pack in full.
	var seen: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary:
			return {}
		var team := String(entry.get("team", ""))
		var action := String(entry.get("animation", ""))
		var key := team + ":" + action
		var expected_filename := team + "_" + action + "_poses_v1.webp"
		if not PINNED_SHA.has(key) or seen.has(key):
			return {}
		if entry.get("file") != expected_filename or entry.get("sha256") != PINNED_SHA[key]:
			return {}
		seen[key] = true
	var selected_key := CLUBS[team_id] + ":" + String(animation)
	if not seen.has(selected_key):
		return {}
	var filename := CLUBS[team_id] + "_" + String(animation) + "_poses_v1.webp"
	var meta := {
		"url": TRUSTED_ROOT + filename,
		"sha256": PINNED_SHA[selected_key],
		"cell": {"width": WIDTH, "height": HEIGHT},
		"columns": COLUMNS, "rows": ROWS,
	}
	return meta if ChessFootballR2AtlasLoader.valid_metadata(meta, TRUSTED_ROOT) else {}


# Change ONLY a real sideways carrier's animation; untouched front/back,
# goalkeeper, off-ball players and in-flight pass/shot actions keep canon.
static func animation_for(
	base: StringName, view: String, role: String,
	owns_ball: bool, dribbling: bool, dribble_mode: String
) -> StringName:
	if role == "keeper" or view != "side" or not owns_ball or not dribbling:
		return base
	if base not in [&"run", &"sprint", &"carry", &"dribble"]:
		return base
	if dribble_mode == "cut":
		return &"dribble_cut"
	if dribble_mode == "burst":
		return &"dribble_burst"
	return base


# Called AFTER the shared loader verifies SHA-256 and true WebP geometry.
# Validate all eight silhouettes before creating ANY GPU textures.
static func frames_from_image(image: Image) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if image == null or image.get_size() != Vector2i(WIDTH * COLUMNS, HEIGHT):
		return result
	var source := image
	if source.get_format() != Image.FORMAT_RGBA8:
		source = image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var cells: Array[Image] = []
	for i in range(COLUMNS):
		var cell := source.get_region(Rect2i(i * WIDTH, 0, WIDTH, HEIGHT))
		var box := cell.get_used_rect()
		# The authored slide can be low to the ground, but it still has
		# a grounded boot/hip line. Reject blank, clipped and opaque sheets.
		if (
			box.size.x < 45 or box.size.x > 118 or box.size.y < 55
			or box.position.x < 4 or box.end.x > 124
			or box.position.y < 8 or box.position.y > 78
			or box.end.y < 130 or box.end.y > 139
			or cell.get_pixel(0, 0).a > 0.05
			or cell.get_pixel(WIDTH - 1, 0).a > 0.05
		):
			return []
		cells.append(cell)
	for cell in cells:
		var texture := ImageTexture.create_from_image(cell)
		ChessFootballSpriteBank._register_frame_bottom(texture, cell)
		result.append(texture)
	return result
