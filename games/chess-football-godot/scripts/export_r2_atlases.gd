extends SceneTree

# Build-only exporter of the already approved 3D raster atlas families.
# Do NOT publish automatically: Infra owns R2, and the standalone game must
# keep its local canon until CDN, CORS, offline fallback and visual parity pass.
const OUTPUT_DIR := "res://build/r2-atlases"

func _initialize() -> void:
	var root := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		push_error("FOOTBALL_ATLAS_EXPORT_ERROR unable to create output directory")
		quit(1)
		return
	var manifest: Dictionary = {
		"schema": 1,
		"source": "approved Football sprite bank; no art regenerated",
		"codec": "webp-lossless",
		"cell": {"width": 128, "height": 144},
		"assets": []
	}
	var families := [
		{"name": "lateral_run", "columns": 8, "rows": 1},
		{"name": "directional_run", "columns": 8, "rows": 4},
		{"name": "goalkeeper_run", "columns": 8, "rows": 4},
	]
	for team_id in range(2):
		var team_name := "fc_matthias" if team_id == 0 else "real_enroque"
		for family in families:
			var name: String = String(family["name"])
			var source: Texture2D = null
			match name:
				"lateral_run":
					source = ChessFootballSpriteBank._canonical_run_texture(team_id)
				"directional_run":
					source = ChessFootballSpriteBank._directional_run_texture(team_id)
				"goalkeeper_run":
					source = ChessFootballSpriteBank._keeper_texture(team_id)
			if source == null:
				push_error("FOOTBALL_ATLAS_EXPORT_ERROR missing approved source " + name)
				quit(1)
				return
			var image: Image = source.get_image()
			if image.has_mipmaps():
				image.clear_mipmaps()
			if image.get_format() != Image.FORMAT_RGBA8:
				image.convert(Image.FORMAT_RGBA8)
			var expected := Vector2i(128 * int(family["columns"]), 144 * int(family["rows"]))
			if image.get_size() != expected:
				push_error("FOOTBALL_ATLAS_EXPORT_ERROR invalid source dimensions " + name)
				quit(1)
				return
			var webp: PackedByteArray = image.save_webp_to_buffer(false)
			if webp.is_empty():
				push_error("FOOTBALL_ATLAS_EXPORT_ERROR encoder failed " + name)
				quit(1)
				return
			var decoded := Image.new()
			if decoded.load_webp_from_buffer(webp) != OK:
				push_error("FOOTBALL_ATLAS_EXPORT_ERROR decoder failed " + name)
				quit(1)
				return
			if decoded.get_format() != Image.FORMAT_RGBA8:
				decoded.convert(Image.FORMAT_RGBA8)
			# A lossless migration must preserve EVERY pixel, including alpha.
			if decoded.get_size() != image.get_size() or decoded.get_data() != image.get_data():
				push_error("FOOTBALL_ATLAS_EXPORT_ERROR pixel parity failed " + name)
				quit(1)
				return
			var basename := "%s_%s_v1.webp" % [team_name, name]
			var handle := FileAccess.open(root.path_join(basename), FileAccess.WRITE)
			if handle == null:
				push_error("FOOTBALL_ATLAS_EXPORT_ERROR failed to write " + basename)
				quit(1)
				return
			handle.store_buffer(webp)
			handle.close()
			var hash := HashingContext.new()
			if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(webp) != OK:
				push_error("FOOTBALL_ATLAS_EXPORT_ERROR failed to hash " + basename)
				quit(1)
				return
			(manifest["assets"] as Array).append({
				"family": name,
				"team": team_name,
				"file": basename,
				"sha256": hash.finish().hex_encode(),
				"bytes": webp.size(),
				"columns": family["columns"],
				"rows": family["rows"]
			})
	var json_path := root.path_join("atlas-manifest-v1.json")
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		push_error("FOOTBALL_ATLAS_EXPORT_ERROR cannot write manifest")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("FOOTBALL_ATLAS_WEBP_EXPORT_OK families=3 teams=2 sheets=6")
	quit(0)
