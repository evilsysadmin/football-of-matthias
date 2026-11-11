class_name ChessFootballR2AtlasLoader
extends Node

# One instance per requested sheet, never one request per player. The browser
# starts with the approved local assets; R2 is strictly optional.
signal atlas_ready(image: Image)

const CDN_ROOT := "https://assets.chess-studio.shadowops.dpdns.org/football/atlases/"
const REQUEST_TIMEOUT_SECONDS := 8.0
const MAX_PAYLOAD_BYTES := 4194304
const MAX_DIMENSION := 4096

var _started := false
var _request_node: HTTPRequest


# The original shared CDN remains the default for every existing caller.
# A separate trusted caller can pin one complete origin + atlas prefix (e.g.
# the independent Football R2 bucket). Never accept a root from the response.
static func valid_metadata(meta: Dictionary, allowed_root: String = CDN_ROOT) -> bool:
	if not allowed_root.begins_with("https://") or not allowed_root.ends_with("/"):
		return false
	if allowed_root != CDN_ROOT and not (allowed_root.ends_with("/atlases/v1/") or allowed_root.ends_with("/atlases/v2/") or allowed_root.ends_with("/atlases/v3/") or allowed_root.ends_with("/atlases/v4/") or allowed_root.ends_with("/atlases/v5/")):
		return false
	var url := String(meta.get("url", ""))
	if not url.begins_with(allowed_root):
		return false
	var relative := url.substr(allowed_root.length())
	if relative.is_empty() or not relative.ends_with(".webp"):
		return false
	# Do not allow another origin, a URL query, traversal or encoded redirects.
	for ch in relative:
		if "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./".find(ch) < 0:
			return false
	if ".." in relative or "//" in relative:
		return false
	var sha := String(meta.get("sha256", ""))
	if sha.length() != 64:
		return false
	for ch in sha:
		if "0123456789abcdef".find(ch) < 0:
			return false
	var cell: Dictionary = meta.get("cell", {})
	var width := int(cell.get("width", 0))
	var height := int(cell.get("height", 0))
	var columns := int(meta.get("columns", 0))
	var rows := int(meta.get("rows", 0))
	if width < 1 or height < 1 or columns < 1 or rows < 1:
		return false
	if width * columns > MAX_DIMENSION or height * rows > MAX_DIMENSION:
		return false
	return true


static func decode_verified_webp(
	payload: PackedByteArray, meta: Dictionary, allowed_root: String = CDN_ROOT
) -> Image:
	if not valid_metadata(meta, allowed_root) or payload.is_empty() or payload.size() > MAX_PAYLOAD_BYTES:
		return null
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(payload) != OK:
		return null
	if hash.finish().hex_encode() != String(meta["sha256"]):
		return null
	var image := Image.new()
	if image.load_webp_from_buffer(payload) != OK:
		return null
	var cell: Dictionary = meta["cell"]
	var expected := Vector2i(
		int(cell["width"]) * int(meta["columns"]),
		int(cell["height"]) * int(meta["rows"])
	)
	if image.get_size() != expected:
		return null
	return image


func start(meta: Dictionary, allowed_root: String = CDN_ROOT) -> void:
	# Prevent retries or duplicate requests in one presenter lifetime.
	if _started:
		return
	_started = true
	if not OS.has_feature("web") or not valid_metadata(meta, allowed_root):
		return
	_request_node = HTTPRequest.new()
	_request_node.name = "AtlasHTTP"
	_request_node.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(_request_node)
	_request_node.request_completed.connect(
		_on_request_completed.bind(meta.duplicate(true), allowed_root)
	)
	if _request_node.request(String(meta["url"])) != OK:
		_request_node.queue_free()
		_request_node = null


func _on_request_completed(
	result: int, status: int, _headers: PackedStringArray,
	body: PackedByteArray, meta: Dictionary, allowed_root: String
) -> void:
	if _request_node != null:
		_request_node.queue_free()
		_request_node = null
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		return
	var image := decode_verified_webp(body, meta, allowed_root)
	if image != null:
		atlas_ready.emit(image)
