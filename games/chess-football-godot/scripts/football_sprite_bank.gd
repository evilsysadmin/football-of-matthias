class_name ChessFootballSpriteBank
extends RefCounted

const MANIFEST_PATH := "res://assets/players/manifest.json"
const ASSET_ROOT := "res://assets/players/"
const XI_FALLBACK_ROOT := ASSET_ROOT + "xi_fallback/"
# Four audited PNG frames extracted from SHA-pinned, user-owned R2 assets.
# The full multi-view atlases remain in R2; only these 128x144 sprites ship.
const XI_FALLBACK_DIGESTS := {
	"fc_matthias_xi_fallback": "7d8f0afb254d602e4f4dda67381992f52dcf705d27a8a24c4c27a1a128ab60b7",
	"real_enroque_xi_fallback": "671b5ede72470bd57c9fe945bf15b4cad2f888b07323dc5b3f8746f038be1a38",
	"keeper_0_xi_fallback": "a11dc07e3453a713865e0d97709b39594dcc963879c97973339351cd669142f3",
	"keeper_1_xi_fallback": "6ccc426686e99207c3eb8365f5c3a8d43f0f19b499782552d8e542474355d0ac",
}
const OPTIONAL_IDLE_META_PATH := "res://optional_idle_front_v1.json"
const OPTIONAL_LATERAL_META_PATH := "res://optional_lateral_run_v1.json"
const TEAM_KEYS := ["fc_matthias", "real_enroque"]

# Temporary action poses are composed from the already approved lateral
# raster run canon. Keep gameplay timing and unique action animation names;
# never flash back to a differently styled vector footballer mid-match.
# Authored action-specific raster art can replace these holds later.
const CANONICAL_ACTION_POSES := {
	"pass": [0, 0, 2, 3, 4, 4, 6, 6],
	"shoot": [1, 1, 3, 3, 5, 5, 7, 7],
	"tackle": [5, 6, 7, 7, 4, 3, 2, 1],
	"celebrate": [0, 2, 4, 6, 4, 2, 0, 0],
}

static var _cached_manifest: Dictionary = {}
static var _cached_xi_fallback: Dictionary = {}
static var _cached_optional_idle_meta: Dictionary = {}
static var _cached_run_textures: Dictionary = {}
static var _cached_3d_run_frames: Dictionary = {}
static var _cached_directional_textures: Dictionary = {}
static var _cached_3d_directional_frames: Dictionary = {}
static var _cached_keeper_textures: Dictionary = {}
static var _cached_keeper_frames: Dictionary = {}
# Every 3D raster frame has a known alpha boot baseline. Cache it while the
# CPU image is being cropped, not by reading textures back from WebGL each tick.
static var _cached_3d_frame_bottoms: Dictionary = {}
static var _cached_3d_frame_heights: Dictionary = {}
# Per-frame opaque-pixel luminance is gathered from already decoded CPU
# pixels during atlas slicing. No texture readbacks in the 3D game loop.
static var _cached_3d_frame_luminance: Dictionary = {}

# Always provide a visible player-shaped local raster for an XI actor.
# Unavailable or tampered files cannot silently become a coloured manikin.
static func xi_fallback_texture(team_id: int, is_keeper: bool = false) -> Texture2D:
	if team_id not in [0, 1]:
		return null
	var key: String = ("keeper_%d_xi_fallback" % team_id) if is_keeper else (
		"fc_matthias_xi_fallback" if team_id == 0 else "real_enroque_xi_fallback"
	)
	if not XI_FALLBACK_DIGESTS.has(key):
		return null
	if _cached_xi_fallback.has(key):
		return _cached_xi_fallback[key]
	var encoded := FileAccess.get_file_as_string(XI_FALLBACK_ROOT + key + ".b64").strip_edges()
	if encoded.is_empty():
		push_error("Football XI: missing approved local sprite: " + key)
		return null
	var raw := Marshalls.base64_to_raw(encoded)
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(raw) != OK:
		return null
	if hash.finish().hex_encode() != String(XI_FALLBACK_DIGESTS[key]):
		push_error("Football XI: local sprite SHA mismatch: " + key)
		return null
	var image := Image.new()
	if image.load_png_from_buffer(raw) != OK or image.get_size() != Vector2i(128, 144):
		push_error("Football XI: invalid local raster: " + key)
		return null
	var box := image.get_used_rect()
	if box.size.x < 45 or box.size.y < 90 or box.end.y > 142:
		return null
	var texture := ImageTexture.create_from_image(image)
	_register_frame_bottom(texture, image)
	_cached_xi_fallback[key] = texture
	return texture


static func manifest() -> Dictionary:
	if not _cached_manifest.is_empty():
		return _cached_manifest
	var raw := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	assert(parsed is Dictionary, "Chess Football sprite manifest inválido")
	_cached_manifest = parsed
	return _cached_manifest

# Optional asset load path: all callers already have approved raster fallbacks.
# Return no textures unless the complete sheet passes origin/hash/shape checks.
static func optional_idle_meta() -> Dictionary:
	if not _cached_optional_idle_meta.is_empty():
		return _cached_optional_idle_meta
	var raw := FileAccess.get_file_as_string(OPTIONAL_IDLE_META_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_cached_optional_idle_meta = parsed
	return _cached_optional_idle_meta


static func idle_front_url() -> String:
	return String(optional_idle_meta().get("url", ""))


static func decode_idle_front_webp(payload: PackedByteArray) -> Array[Texture2D]:
	# The shared loader checks CDN metadata, SHA, WebP and sheet dimensions.
	# This compatibility entry point remains useful for offline smoke tests.
	var image := ChessFootballR2AtlasLoader.decode_verified_webp(payload, optional_idle_meta())
	if image == null:
		return []
	return idle_front_textures_from_image(image)

static func idle_front_textures_from_image(image: Image) -> Array[Texture2D]:
	# Exposed independently for deterministic offline tests; network source
	# verification occurs ONLY in decode_idle_front_webp().
	var textures: Array[Texture2D] = []
	var meta: Dictionary = optional_idle_meta()
	if meta.is_empty() or image == null:
		return textures
	var cell: Dictionary = meta.get("cell", {})
	var width := int(cell.get("width", 0))
	var height := int(cell.get("height", 0))
	if width != 128 or height != 144 or image.get_size() != Vector2i(width * 3, height):
		return textures
	if image.get_format() != Image.FORMAT_RGBA8:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)
	var regions: Array[Image] = []
	for index in range(3):
		var region := image.get_region(Rect2i(index * width, 0, width, height))
		var rect := region.get_used_rect()
		if rect.size.y < 60 or rect.end.y > height or rect.position.y > 40:
			return []
		# A missing transparency channel would render an opaque card over turf.
		if region.get_pixel(0, 0).a > 0.05 or region.get_pixel(width - 1, 0).a > 0.05:
			return []
		regions.append(region)
	# Retain the approved teal keeper kit for Real Enroque: recolour only
	# yellow fabric, not skin, gloves, socks or hair.
	var away_keeper: Image = regions[2].duplicate()
	var teal := Color("#2bafad")
	for y in range(height):
		for x in range(width):
			var pixel: Color = away_keeper.get_pixel(x, y)
			if pixel.a > 0.10 and pixel.h >= 0.105 and pixel.h <= 0.19 and pixel.s >= 0.43 and pixel.v >= 0.28:
				away_keeper.set_pixel(x, y, Color.from_hsv(teal.h, pixel.s, pixel.v, pixel.a))
	regions.append(away_keeper)
	for region in regions:
		var texture := ImageTexture.create_from_image(region)
		_register_frame_bottom(texture, region)
		textures.append(texture)
	return textures


# Separate, reviewable optional CDN contract. Never change the forge manifest.
# Both club sheets remain disabled until the public R2/CORS gate is proven.
static func lateral_run_meta(team_id: int) -> Dictionary:
	var raw := FileAccess.get_file_as_string(OPTIONAL_LATERAL_META_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary or parsed.get("enabled") != true:
		return {}
	var teams: Dictionary = parsed.get("teams", {})
	var sheet: Variant = teams.get(_team_key(team_id))
	return sheet if sheet is Dictionary else {}


static func validated_lateral_run_frames(image: Image, team_id: int) -> Array[Texture2D]:
	# A hash and valid sheet dimensions are necessary but insufficient:
	# reject replacement unless each RGBA byte is identical to the approved
	# LOCAL canonical raster. Preserve the local sprite on any mismatch.
	var result: Array[Texture2D] = []
	if image == null or image.get_size() != Vector2i(1024, 144):
		return result
	var local_texture := _canonical_run_texture(team_id)
	if local_texture == null:
		return result
	var reference := local_texture.get_image()
	if reference.has_mipmaps():
		reference.clear_mipmaps()
	if reference.get_format() != Image.FORMAT_RGBA8:
		reference.convert(Image.FORMAT_RGBA8)
	var candidate := image.duplicate()
	if candidate.has_mipmaps():
		candidate.clear_mipmaps()
	if candidate.get_format() != Image.FORMAT_RGBA8:
		candidate.convert(Image.FORMAT_RGBA8)
	if candidate.get_data() != reference.get_data():
		return result
	for index in range(8):
		var crop: Image = candidate.get_region(Rect2i(index * 128, 0, 128, 144))
		if crop.get_used_rect().size.y < 60:
			return []
		var texture := ImageTexture.create_from_image(crop)
		_register_frame_bottom(texture, crop)
		result.append(texture)
	return result


# Transitional visual contract until the dedicated tackle and slide atlases
# are available from R2. Both animations retain the exact approved fallback
# frames: the sliding action now has its own stable name, FPS and duration.
static func _add_slide_tackle_fallback(frames: SpriteFrames) -> void:
	if frames.has_animation(&"slide_tackle") or not frames.has_animation(&"tackle"):
		return
	frames.add_animation(&"slide_tackle")
	frames.set_animation_speed(&"slide_tackle", frames.get_animation_speed(&"tackle"))
	frames.set_animation_loop(&"slide_tackle", frames.get_animation_loop(&"tackle"))
	for i in range(frames.get_frame_count(&"tackle")):
		frames.add_frame(&"slide_tackle", frames.get_frame_texture(&"tackle", i))


static func _team_key(team_id: int) -> String:
	return TEAM_KEYS[clampi(team_id, 0, TEAM_KEYS.size() - 1)]

static func _canonical_run_meta() -> Dictionary:
	return manifest().get("canonical_run", {})

static func _canonical_run_target(team_id: int) -> Color:
	return Color("#245fc2") if clampi(team_id, 0, 1) == 0 else Color("#ad2936")

static func _recolor_canonical_run(image: Image, team_id: int) -> void:
	var target := _canonical_run_target(team_id)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.03:
				continue
			if color.h >= 0.43 and color.h <= 0.60 and color.s >= 0.25 and color.v >= 0.18:
				var saturation := clampf(color.s * 0.72 + target.s * 0.28, 0.20, 1.0)
				image.set_pixel(x, y, Color.from_hsv(target.h, saturation, color.v, color.a))

static func _canonical_run_texture(team_id: int) -> Texture2D:
	var key := _team_key(team_id)
	if _cached_run_textures.has(key):
		return _cached_run_textures[key]
	var meta := _canonical_run_meta()
	assert(not meta.is_empty(), "Falta canonical run meta para Chess Football")
	var encoded := ""
	for part_variant in meta["encoded_parts"]:
		var encoded_path := ASSET_ROOT + String(part_variant)
		encoded += FileAccess.get_file_as_string(encoded_path).strip_edges()
	assert(not encoded.is_empty(), "Canonical run atlas vacío")
	var bytes := Marshalls.base64_to_raw(encoded)
	var hash := HashingContext.new()
	# Never perform required work inside assert(): release Web exports strip assertions.
	var hash_start := hash.start(HashingContext.HASH_SHA256)
	assert(hash_start == OK, "No se pudo iniciar SHA-256")
	var hash_update := hash.update(bytes)
	assert(hash_update == OK, "No se pudo hashear canonical run")
	var digest := hash.finish().hex_encode()
	assert(digest == String(meta["sha256"]), "Canonical run SHA-256 inválido")
	var image := Image.new()
	var decode_result := image.load_png_from_buffer(bytes)
	assert(decode_result == OK, "Canonical run PNG inválido")
	if decode_result != OK:
		push_error("Chess Football: cannot decode canonical run PNG; Web export may be missing .b64 assets")
		return null
	_recolor_canonical_run(image, team_id)
	var mipmap_result := image.generate_mipmaps()
	assert(mipmap_result == OK, "No se pudieron generar mipmaps del canonical run")
	var texture := ImageTexture.create_from_image(image)
	_cached_run_textures[key] = texture
	return texture

static func _directional_run_texture(team_id: int) -> Texture2D:
	var key := _team_key(team_id)
	if _cached_directional_textures.has(key):
		return _cached_directional_textures[key]
	var meta: Dictionary = manifest().get("directional_run", {})
	if meta.is_empty():
		return null
	var encoded := ""
	for part in meta["encoded_parts"]:
		encoded += FileAccess.get_file_as_string(ASSET_ROOT + String(part)).strip_edges()
	if encoded.is_empty():
		push_error("Chess Football: directional run atlas missing from Web export")
		return null
	var bytes := Marshalls.base64_to_raw(encoded)
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(bytes) != OK:
		push_error("Chess Football: directional atlas SHA-256 failed")
		return null
	if hash.finish().hex_encode() != String(meta["sha256"]):
		push_error("Chess Football: directional run atlas SHA-256 mismatch")
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		push_error("Chess Football: directional run PNG could not be decoded")
		return null
	var size_meta: Dictionary = meta["cell"]
	var expected_size := Vector2i(
		int(size_meta["width"]) * int(meta["frames"]),
		int(size_meta["height"]) * int((meta["views"] as Dictionary).size()),
	)
	if image.get_size() != expected_size:
		push_error("Chess Football: directional run atlas dimensions mismatch")
		return null
	# This source's authored blue is slightly more violet than the side run.
	# Remap kit blues to each team's hue; never recolor white fabric or skin.
	var target := _canonical_run_target(team_id)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.03:
				continue
			if color.h >= 0.54 and color.h <= 0.74 and color.s >= 0.25 and color.v >= 0.12:
				var saturation := clampf(color.s * 0.72 + target.s * 0.28, 0.20, 1.0)
				image.set_pixel(x, y, Color.from_hsv(target.h, saturation, color.v, color.a))
	var mipmap_result := image.generate_mipmaps()
	assert(mipmap_result == OK, "Chess Football: directional run mipmaps failed")
	var texture := ImageTexture.create_from_image(image)
	_cached_directional_textures[key] = texture
	return texture

static func _register_frame_bottom(texture: ImageTexture, cropped: Image) -> void:
	var visible: Rect2i = cropped.get_used_rect()
	assert(visible.size.y >= 60 and visible.end.y <= cropped.get_height())
	_cached_3d_frame_bottoms[texture.get_instance_id()] = float(visible.end.y)
	_cached_3d_frame_heights[texture.get_instance_id()] = float(visible.size.y)
	var rgba := cropped
	if rgba.get_format() != Image.FORMAT_RGBA8:
		rgba = cropped.duplicate()
		rgba.convert(Image.FORMAT_RGBA8)
	var bytes := rgba.get_data()
	var total := 0.0
	var opaque_count := 0
	for offset in range(0, bytes.size(), 4):
		if bytes[offset + 3] < 128:
			continue
		total += (
			0.2126 * float(bytes[offset])
			+ 0.7152 * float(bytes[offset + 1])
			+ 0.0722 * float(bytes[offset + 2])
		) / 255.0
		opaque_count += 1
	_cached_3d_frame_luminance[texture.get_instance_id()] = (
		total / float(opaque_count) if opaque_count > 0 else 0.0
	)


static func frame_luminance(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	return float(_cached_3d_frame_luminance.get(texture.get_instance_id(), 0.0))


static func frame_height(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	return float(_cached_3d_frame_heights.get(texture.get_instance_id(), 0.0))


static func frame_bottom(texture: Texture2D) -> float:
	if texture == null:
		return footline()
	return float(_cached_3d_frame_bottoms.get(texture.get_instance_id(), footline()))


static func has_frame_bottom(texture: Texture2D) -> bool:
	return texture != null and _cached_3d_frame_bottoms.has(texture.get_instance_id())


static func _direction_frame_3d(
	team_id: int, row: int, column: int, atlas: Texture2D, cell: Vector2
) -> Texture2D:
	var key := "%d:%d:%d" % [team_id, row, column]
	if _cached_3d_directional_frames.has(key):
		return _cached_3d_directional_frames[key]
	# WebGL cannot reliably draw AtlasTexture as AnimatedSprite3D frames.
	var source := atlas.get_image()
	var region := source.get_region(Rect2i(
		column * int(cell.x), row * int(cell.y), int(cell.x), int(cell.y)
	))
	assert(not region.is_empty(), "Empty directional 3D football frame")
	var texture := ImageTexture.create_from_image(region)
	_register_frame_bottom(texture, region)
	_cached_3d_directional_frames[key] = texture
	return texture

# Keeper runtime uses the accepted 4x8 raster bank, never the SVG silhouettes
# or another team's field-player animations. Four authored views are available.
static func _keeper_texture(team_id: int) -> Texture2D:
	var key := _team_key(team_id)
	if _cached_keeper_textures.has(key):
		return _cached_keeper_textures[key]
	var meta: Dictionary = manifest().get("goalkeeper_run", {})
	if meta.is_empty():
		push_error("Chess Football: canonical keeper metadata missing")
		return null
	var encoded := ""
	for part in meta["encoded_parts"]:
		# The approved payload has fixed-width base64 lines, unlike old run chunks.
		encoded += FileAccess.get_file_as_string(ASSET_ROOT + String(part)).replace("\n", "").replace("\r", "").strip_edges()
	if encoded.is_empty():
		push_error("Chess Football: approved keeper payload missing from Web export")
		return null
	var bytes := Marshalls.base64_to_raw(encoded)
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(bytes) != OK:
		push_error("Chess Football: cannot verify keeper atlas SHA")
		return null
	if hash.finish().hex_encode() != String(meta["sha256"]):
		push_error("Chess Football: keeper asset does not match approved SHA")
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		push_error("Chess Football: cannot decode approved keeper atlas")
		return null
	var cell: Dictionary = meta["cell"]
	if image.get_size() != Vector2i(int(cell["width"]) * int(meta["frames"]), int(cell["height"]) * 4):
		push_error("Chess Football: keeper atlas has invalid dimensions")
		return null
	if team_id == 1:
		# Recolor jersey/shorts/socks ONLY. Cap, white gloves and skin stay intact.
		var target := Color("#2bafad")
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color := image.get_pixel(x, y)
				if color.a < 0.10:
					continue
				if color.h >= 0.105 and color.h <= 0.19 and color.s >= 0.43 and color.v >= 0.28:
					image.set_pixel(x, y, Color.from_hsv(target.h, color.s, color.v, color.a))
	var mipmap_result := image.generate_mipmaps()
	assert(mipmap_result == OK, "Chess Football: keeper mipmap creation failed")
	var texture := ImageTexture.create_from_image(image)
	_cached_keeper_textures[key] = texture
	return texture


static func _keeper_frame_3d(team_id: int, row: int, column: int, atlas: Texture2D, cell: Vector2) -> ImageTexture:
	var key := "%d:%d:%d" % [team_id, row, column]
	if _cached_keeper_frames.has(key):
		return _cached_keeper_frames[key]
	var image := atlas.get_image()
	var region := image.get_region(Rect2i(column * int(cell.x), row * int(cell.y), int(cell.x), int(cell.y)))
	assert(region.get_size() == Vector2i(128, 144), "Chess Football: invalid goalkeeper frame")
	var texture := ImageTexture.create_from_image(region)
	_register_frame_bottom(texture, region)
	_cached_keeper_frames[key] = texture
	return texture


static func _build_keeper_frames(team_id: int) -> SpriteFrames:
	var data := manifest()
	var meta: Dictionary = data["goalkeeper_run"]
	var atlas := _keeper_texture(team_id)
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	if atlas == null:
		push_error("Chess Football: keeper raster bank unavailable")
		return frames
	var cell := Vector2(float(meta["cell"]["width"]), float(meta["cell"]["height"]))
	var side_row := int(meta["side_fallback_row"])
	var front_row := int(meta["views"]["front"])
	for item in data["animations"]:
		var anim: StringName = StringName(item["name"])
		frames.add_animation(anim)
		frames.set_animation_speed(anim, maxf(float(item["fps"]), 15.0) if anim == &"sprint" else float(item["fps"]))
		frames.set_animation_loop(anim, bool(item["loop"]))
		if anim == &"idle":
			frames.add_frame(anim, _keeper_frame_3d(team_id, front_row, 0, atlas, cell))
			continue
		for frame_id in range(int(item["frames"])):
			var source_frame := frame_id
			if anim not in [&"run", &"sprint"]:
				var poses: Array = CANONICAL_ACTION_POSES.get(String(anim), [])
				if poses.is_empty():
					push_error("Chess Football: no keeper raster for " + String(anim))
					break
				source_frame = int(poses[frame_id % poses.size()])
			frames.add_frame(anim, _keeper_frame_3d(team_id, side_row, source_frame, atlas, cell))
	for view_name in ["front", "back", "back_diagonal", "front_diagonal"]:
		var authored_row: int = int(meta["views"][view_name])
		var idle_name := StringName("idle_" + view_name)
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 1.0)
		frames.add_frame(idle_name, _keeper_frame_3d(team_id, authored_row, 0, atlas, cell))
		for base_name in ["run", "sprint"]:
			var named := StringName(base_name + "_" + view_name)
			frames.add_animation(named)
			frames.set_animation_speed(named, 15.0 if base_name == "sprint" else 12.0)
			frames.set_animation_loop(named, true)
			for frame_id in range(int(meta["frames"])):
				frames.add_frame(named, _keeper_frame_3d(team_id, authored_row, frame_id, atlas, cell))
	_add_slide_tackle_fallback(frames)
	return frames


static func _run_frame_3d(team_id: int, column: int, atlas: Texture2D, cell: Vector2) -> Texture2D:
	var key := "%d:%d" % [team_id, column]
	if _cached_3d_run_frames.has(key):
		return _cached_3d_run_frames[key]
	# Sprite3D needs a standalone texture: AtlasTexture regions can vanish on WebGL.
	var source := atlas.get_image()
	var region := source.get_region(Rect2i(column * int(cell.x), 0, int(cell.x), int(cell.y)))
	assert(not region.is_empty(), "Empty 3D football frame")
	var texture := ImageTexture.create_from_image(region)
	_register_frame_bottom(texture, region)
	_cached_3d_run_frames[key] = texture
	return texture

static func atlas_key(team_id: int, role: String = "", squad_index: int = -1) -> String:
	var key: String = TEAM_KEYS[clampi(team_id, 0, TEAM_KEYS.size() - 1)]
	if role == "keeper":
		return key + "_keeper"
	if squad_index < 1:
		return key
	var variant_map: Dictionary = manifest().get("field_variants", {})
	var variants: Array = variant_map.get(key, [])
	if variants.is_empty():
		return key
	var field_slot := clampi(squad_index - 1, 0, variants.size() - 1)
	return String(variants[field_slot])

static func build_frames(team_id: int, role: String = "", squad_index: int = -1, for_3d: bool = false) -> SpriteFrames:
	if role == "keeper" and for_3d:
		return _build_keeper_frames(team_id)
	var data := manifest()
	var key: String = atlas_key(team_id, role, squad_index)
	var atlas_meta: Dictionary = data["atlases"][key]
	# The vector bank is kept for the authoritative 2D simulation only.
	# Never load/show its inconsistent body silhouettes in the 3D stadium.
	var texture: Texture2D = null
	var cell_data: Dictionary = data["cell"]
	var cell := Vector2(float(cell_data["width"]), float(cell_data["height"]))
	if not for_3d:
		texture = load(ASSET_ROOT + String(atlas_meta["file"])) as Texture2D
		assert(texture != null, "No se pudo cargar el atlas de Chess Football")
		var expected_size := Vector2(cell.x * int(data["columns"]), cell.y * int(data["rows"]))
		assert(texture.get_size() == expected_size, "Dimensiones de atlas incompatibles con manifest")

	var run_meta := _canonical_run_meta()
	var run_texture := _canonical_run_texture(team_id)
	var run_cell_data: Dictionary = run_meta["cell"]
	var run_cell := Vector2(float(run_cell_data["width"]), float(run_cell_data["height"]))
	var run_frames := int(run_meta["frames"])
	assert(
		run_texture.get_size() == Vector2(run_cell.x * run_frames, run_cell.y),
		"Dimensiones de canonical run incompatibles con manifest"
	)

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for item in data["animations"]:
		var animation: Dictionary = item
		var animation_name := StringName(animation["name"])
		frames.add_animation(animation_name)
		var animation_fps := float(animation["fps"])
		if animation_name == &"sprint":
			animation_fps = maxf(animation_fps, 15.0)
		frames.set_animation_speed(animation_name, animation_fps)
		frames.set_animation_loop(animation_name, bool(animation["loop"]))
		if animation_name == &"idle":
			var idle_region := AtlasTexture.new()
			idle_region.atlas = run_texture
			idle_region.region = Rect2(Vector2.ZERO, run_cell)
			frames.add_frame(animation_name, _run_frame_3d(team_id, 0, run_texture, run_cell) if for_3d else idle_region)
			continue
		if animation_name in [&"run", &"sprint"]:
			assert(run_frames == int(animation["frames"]), "Canonical locomotion frame count inválido")
			for column in range(run_frames):
				var run_region := AtlasTexture.new()
				run_region.atlas = run_texture
				run_region.region = Rect2(Vector2(float(column) * run_cell.x, 0.0), run_cell)
				frames.add_frame(animation_name, _run_frame_3d(team_id, column, run_texture, run_cell) if for_3d else run_region)
			continue
		if for_3d:
			var action_poses: Array = CANONICAL_ACTION_POSES.get(String(animation_name), [])
			if action_poses.is_empty():
				push_error("Chess Football: no canonical 3D raster for action " + String(animation_name))
				continue
			for action_frame in range(int(animation["frames"])):
				var source_frame: int = int(action_poses[action_frame % action_poses.size()])
				frames.add_frame(
					animation_name,
					_run_frame_3d(team_id, source_frame, run_texture, run_cell),
				)
			continue
		var row := int(animation["row"])
		for column in range(int(animation["frames"])):
			var region := AtlasTexture.new()
			region.atlas = texture
			region.region = Rect2(Vector2(float(column) * cell.x, float(row) * cell.y), cell)
			frames.add_frame(animation_name, region)
	# Add the four supplementary canonical views while preserving the original
	# side run/sprint and all action animations, including their existing phases.
	var directional_meta: Dictionary = data.get("directional_run", {})
	if not directional_meta.is_empty():
		var directional_atlas := _directional_run_texture(team_id)
		if directional_atlas != null:
			var directional_cell_data: Dictionary = directional_meta["cell"]
			var directional_cell := Vector2(
				float(directional_cell_data["width"]), float(directional_cell_data["height"])
			)
			for view_name in ["front", "back", "back_diagonal", "front_diagonal"]:
				var row: int = int(directional_meta["views"][view_name])
				if for_3d:
					var idle_name := StringName("idle_" + view_name)
					frames.add_animation(idle_name)
					frames.set_animation_speed(idle_name, 1.0)
					frames.add_frame(idle_name, _direction_frame_3d(team_id, row, 0, directional_atlas, directional_cell))
				for base_name in ["run", "sprint"]:
					var directional_name := StringName(base_name + "_" + view_name)
					frames.add_animation(directional_name)
					frames.set_animation_speed(directional_name, 15.0 if base_name == "sprint" else 12.0)
					frames.set_animation_loop(directional_name, true)
					for column in range(int(directional_meta["frames"])):
						var region := AtlasTexture.new()
						region.atlas = directional_atlas
						region.region = Rect2(
							Vector2(column * directional_cell.x, row * directional_cell.y),
							directional_cell,
						)
						frames.add_frame(
							directional_name,
							_direction_frame_3d(team_id, row, column, directional_atlas, directional_cell)
							if for_3d else region,
						)
	_add_slide_tackle_fallback(frames)
	return frames

static func cell_size() -> Vector2:
	var cell: Dictionary = manifest()["cell"]
	return Vector2(float(cell["width"]), float(cell["height"]))

static func footline() -> float:
	return float(manifest()["footline"])

static func display_scale() -> float:
	return float(manifest()["display_scale"])

static func animation_names() -> PackedStringArray:
	var names := PackedStringArray()
	for item in manifest()["animations"]:
		names.append(String(item["name"]))
	return names
