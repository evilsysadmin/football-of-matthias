class_name ChessFootballDenseV1R2
extends RefCounted

const TRUSTED_ROOT := "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/dense-v1/"
const TEAMS := ["fc_matthias", "real_enroque"]
const CELL := Vector2i(128, 144)
const ACTIONS := [&"pass", &"shoot"]
const PINNED := {
	"fc_matthias_pass_16_v1.webp": "85f06fb25ce9f688d948cdec8d16e35a8b8b9ccc2c31dfe9df63e0bdc6195086",
	"fc_matthias_shoot_16_v1.webp": "02657c4c59bbeeea7403cd6dc66cf95d75d24a81553a19c61f60842047e5da60",
	"fc_matthias_run_front_diagonal_24_v1.webp": "c900c992044056b7e36d42c8e42c8e7aea00d4fa9e01cab2f96a79d12992a01d",
	"real_enroque_pass_16_v1.webp": "b5a78aaf2b77f254389f87e17ba612677ff89a1d7441791906ade247a1fc4ad0",
	"real_enroque_shoot_16_v1.webp": "2a61e6dd266c1c25499c9e26d4ac6581acd9f614901cc24589b24ff1213925a6",
	"real_enroque_run_front_diagonal_24_v1.webp": "e95bed24beeeadf4f2abd53ec090411dd0798d29be045db6bb502cde2689c0dd",
}

static func sheet_meta(team_id: int, action: StringName) -> Dictionary:
	if team_id not in [0, 1] or (action not in ACTIONS and action != &"run_front_diagonal"):
		return {}
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://optional_dense_v1.json"))
	if not manifest is Dictionary:
		return {}
	if manifest.get("cdn_base") != TRUSTED_ROOT.trim_suffix("/") or manifest.get("enabled_actions") != ["pass", "shoot"]:
		return {}
	var count: int = 24 if action == &"run_front_diagonal" else 16
	if count == 24 and manifest.get("enabled_diagonal") != true:
		return {}
	var filename: String = TEAMS[team_id] + "_" + String(action) + "_%d_v1.webp" % count
	for entry in manifest.get("entries", []):
		if entry.get("file") != filename:
			continue
		if entry.get("sha256") != PINNED[filename] or entry.get("team") != TEAMS[team_id] or entry.get("animation") != String(action) or entry.get("columns") != count or entry.get("rows") != 1:
			return {}
		var meta := {"url": TRUSTED_ROOT + filename, "sha256": PINNED[filename],
			"cell": {"width": 128, "height": 144}, "columns": count, "rows": 1}
		return meta if ChessFootballR2AtlasLoader.valid_metadata(meta, TRUSTED_ROOT) else {}
	return {}


# Shared by production decode and offline art review. Empty means only
# the geometry passed, not that gait, anatomy or art have been approved.
static func frame_geometry_error(image: Image, count: int = 16) -> String:
	if count not in [16, 24]:
		return "unsupported_frame_count"
	if image == null or image.get_size() != Vector2i(CELL.x * count, CELL.y):
		return "invalid_sheet_dimensions"
	for col in range(count):
		var region := image.get_region(Rect2i(col * CELL.x, 0, CELL.x, CELL.y))
		var bounds := region.get_used_rect()
		if bounds.position.x < 4 or bounds.end.x > 124 or bounds.position.y < 4 or bounds.position.y > 32 or bounds.end.y < 129 or bounds.end.y > 139 or bounds.size.x < 38:
			return "frame=%d bounds=%s" % [col + 1, str(bounds)]
	return ""


static func frames_from_image(image: Image, count: int = 16) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var error := frame_geometry_error(image, count)
	if not error.is_empty():
		return textures
	# Complete geometry validation precedes any texture allocation.
	for col in range(count):
		var region := image.get_region(Rect2i(col * CELL.x, 0, CELL.x, CELL.y))
		var texture := ImageTexture.create_from_image(region)
		ChessFootballSpriteBank._register_frame_bottom(texture, region)
		textures.append(texture)
	return textures
