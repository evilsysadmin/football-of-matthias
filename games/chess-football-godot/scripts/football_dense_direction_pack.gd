extends RefCounted

# Exact published Dense locomotion set. This is a read-only preparation
# boundary; no installation, network, or public art-policy decision here.
const Bank = preload("res://scripts/football_dense_run_bank.gd")
const PINNED := {
	"fc_matthias_run_back_24_v1.webp": "5f54ec132fe5d9cc098a298d3d08905d7bd55f8bef15662b139529330614e533",
	"fc_matthias_run_back_diagonal_24_v1.webp": "f7a94fa8aa6dcca4edc3f441fec2596e83dab5d8230ebb9d6f935fcafa61050a",
	"fc_matthias_run_front_24_v1.webp": "37686ce1c624c2de6003466be99db3a8ec549fe222949940e237074269d0d070",
	"fc_matthias_run_side_24_v1.webp": "4369fdac5a9d2b8da246ea729d2406193a92258d8bb2e136b689803847e0bba0",
	"real_enroque_run_back_24_v1.webp": "6b1939812dfb87d7854d6b2f0bb8907db061c07040dd0c4f70334adfb375bd9e",
	"real_enroque_run_back_diagonal_24_v1.webp": "2109f65679eeeea844a94985ad2580e144488155f70e4e55fe6041c127e8a198",
	"real_enroque_run_front_24_v1.webp": "5ccf3d8e9abed40cd3694bfb5b2c5a14796d7921b3d71c6cedccd6a06462ad9d",
	"real_enroque_run_side_24_v1.webp": "bdb01a00b13c22091d66e8a6b1be6ac28c42a2b1e9cd39f5d94c3aa72eaa09e4",
}


static func sheet_meta(club: int, view: String) -> Dictionary:
	if club not in [0, 1] or view not in Bank.VIEWS:
		return {}
	if view == "front_diagonal":
		return ChessFootballDenseV1R2.sheet_meta(club, &"run_front_diagonal")
	var filename: String = ChessFootballDenseV1R2.TEAMS[club] + "_run_" + view + "_24_v1.webp"
	if not PINNED.has(filename):
		return {}
	var meta := {"url": ChessFootballDenseV1R2.TRUSTED_ROOT + filename,
		"sha256": PINNED[filename], "cell": {"width": 128, "height": 144},
		"columns": 24, "rows": 1}
	return meta if ChessFootballR2AtlasLoader.valid_metadata(meta, ChessFootballDenseV1R2.TRUSTED_ROOT) else {}


# The reader supplies bytes by club/view and canonical filename. Validate
# all ten images before allocating any frame textures. A single missing or
# corrupt sheet returns no rows for EITHER club.
static func load_pack(reader: Callable) -> Dictionary:
	var images := {}
	for club in range(2):
		var club_images := {}
		for view: String in Bank.VIEWS:
			var meta := sheet_meta(club, view)
			if meta.is_empty():
				return {}
			var filename: String = String(meta["url"]).get_file()
			var payload: PackedByteArray = reader.call(club, view, filename)
			var image := ChessFootballR2AtlasLoader.decode_verified_webp(
				payload, meta, ChessFootballDenseV1R2.TRUSTED_ROOT)
			if not ChessFootballDenseV1R2.frame_geometry_error(image, 24).is_empty():
				printerr("FOOTBALL_DENSE_PACK_REJECTED ", filename)
				return {}
			club_images[view] = image
		images[club] = club_images
	var rows_by_club := {}
	for club in range(2):
		var rows := {}
		for view: String in Bank.VIEWS:
			var frames := ChessFootballDenseV1R2.frames_from_image(images[club][view], 24)
			if frames.size() != 24:
				return {}
			rows[view] = frames
		rows_by_club[club] = rows
	return rows_by_club


static func load_bundled_pack() -> Dictionary:
	return load_pack(func(_club: int, _view: String, filename: String) -> PackedByteArray:
		var path := ChessFootballR2AtlasLoader.BUNDLED_ATLAS_DIR + filename + ".bin"
		return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	)
