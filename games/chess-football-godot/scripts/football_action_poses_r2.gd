class_name ChessFootballActionPosesR2
extends RefCounted

# Separate original-runtime-derived action sheets under eight immutable v2 R2 keys.
# DO NOT feed these into the legacy 2172x724 tackle source crop decoder.
# Exact HTTPS path + SHA-256 + dimensions are checked by the shared loader.
const META_PATH := "res://optional_action_poses_v2.json"
const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v2/"
const CLUBS := ["fc_matthias", "real_enroque"]
const ANIMATIONS := [&"dribble_cut", &"dribble_burst", &"tackle", &"slide_tackle"]
# Stage all four action sheets only after immutable v2 SHA verification.
# The slide's oversized painted ground shadow is removed deterministically
# from three middle frames, so the game's own contact shadow stays canonical.
const ACTIVE_ANIMATIONS := [&"dribble_cut", &"dribble_burst", &"tackle", &"slide_tackle"]
const WIDTH := 128
const HEIGHT := 144
const COLUMNS := 8
const ROWS := 1
const FOOTLINE := 134
const PINNED_SHA := {
	"fc_matthias:dribble_cut": "0ebe3ed766f9adf90e3c8327315cbf53282bdb3e1d6dbceac1fa0e4e81cd8c93",
	"fc_matthias:dribble_burst": "d516759fb53668d5fc02daf0581b8d61e1bddbb29b9725e9e4fa3edcd9729d9b",
	"fc_matthias:tackle": "a3c50d36bc62104bb88e60e96da2134c99180bd4afe50dc7d92115271d08b18c",
	"fc_matthias:slide_tackle": "21b1f297d52752977d20d7d6d4f2952c5158605922157bf1edb6a063fdd76071",
	"real_enroque:dribble_cut": "6acec93d0e91c227c9367ba326330083a4d358b965f78b1df339d588353c37aa",
	"real_enroque:dribble_burst": "2625c30ae31784008c3f2c665ec22ce79bfa664f663510ce5d463933c67f54b5",
	"real_enroque:tackle": "1e64f42753f9a30d4361008abb99e6f71092d74dc85f05104a822ae9fa82fb77",
	"real_enroque:slide_tackle": "819e008a135797e4d3fd901457f2433e08f94358bc43b8b3ef0f1ddc756ec564",
}


static func metadata() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	return data if data is Dictionary else {}


static func sheet_meta(team_id: int, animation: StringName) -> Dictionary:
	if team_id not in [0, 1] or animation not in ACTIVE_ANIMATIONS:
		return {}
	var contract := metadata()
	if contract.get("enabled") != true or contract.get("version") != 2 or contract.get("quality_contract") != "football-approved-r2-action-recomposition-v2":
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
	if int(contract.get("footline", 0)) != FOOTLINE:
		return {}
	if contract.get("animations") != ["dribble_cut", "dribble_burst", "tackle", "slide_tackle"]:
		return {}
	if contract.get("enabled_actions") != ["dribble_cut", "dribble_burst", "tackle", "slide_tackle"]:
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
		var expected_filename := team + "_" + action + "_poses_v2.webp"
		if not PINNED_SHA.has(key) or seen.has(key):
			return {}
		if entry.get("file") != expected_filename or entry.get("sha256") != PINNED_SHA[key]:
			return {}
		seen[key] = true
	var selected_key: String = String(CLUBS[team_id]) + ":" + String(animation)
	if not seen.has(selected_key):
		return {}
	var filename: String = String(CLUBS[team_id]) + "_" + String(animation) + "_poses_v2.webp"
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
# Only the verified slide v2 contains a *second* baked floor shadow.
# Keep every authored body pixel (including black boots) while erasing the
# broad, faint dark band drawn BELOW the player's foot contact. This pass
# only touches central sliding poses; other 5 frames and all other actions
# are byte-for-byte equivalent to the decoded sheet.
static func _trim_slide_ground_shadow(cell: Image, pose_index: int) -> Image:
	if pose_index not in [3, 4, 5]:
		return cell
	var clean: Image = cell.duplicate() as Image
	for y in range(126, HEIGHT):
		for x in range(WIDTH):
			var px: Color = clean.get_pixel(x, y)
			if (
				px.a > 0.0 and px.a < 0.53
				and px.r < 0.23 and px.g < 0.23 and px.b < 0.26
			):
				clean.set_pixel(x, y, Color.TRANSPARENT)
	return clean


static func frames_from_image(image: Image, action: StringName = &"") -> Array[Texture2D]:
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
		if action == &"slide_tackle":
			cell = _trim_slide_ground_shadow(cell, i)
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
