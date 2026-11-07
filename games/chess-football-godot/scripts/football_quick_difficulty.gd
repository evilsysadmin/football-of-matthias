extends RefCounted

# Bounded CPU-only decision modifiers. Normal preserves existing tactics.
# Never modify an individual's pace, stamina, keeper physics or ball rules.
const DEFAULT := "normal"
const PROFILES := {
	"easy": {"decision": 1.45, "pressure": 0.84, "effort": 0.82, "shoot": 0.82, "shot_read": 0.25, "pass_error": 0.38, "pass_error_degrees": 13.0},
	"normal": {"decision": 1.0, "pressure": 1.0, "effort": 1.0, "shoot": 1.0, "shot_read": 0.50, "pass_error": 0.24, "pass_error_degrees": 9.0},
	"hard": {"decision": 0.82, "pressure": 1.10, "effort": 1.08, "shoot": 1.08, "shot_read": 0.70, "pass_error": 0.14, "pass_error_degrees": 6.0},
	"expert": {"decision": 0.67, "pressure": 1.18, "effort": 1.15, "shoot": 1.12, "shot_read": 0.84, "pass_error": 0.07, "pass_error_degrees": 4.0},
}

static func normalize(level: String) -> String:
	return level if PROFILES.has(level) else DEFAULT

static func from_hash(fragment: String) -> String:
	var prefix := "#football-difficulty="
	if not fragment.begins_with(prefix):
		return DEFAULT
	return normalize(fragment.trim_prefix(prefix).get_slice("&", 0))

static func read_browser() -> String:
	if not OS.has_feature("web"):
		return DEFAULT
	var fragment: Variant = JavaScriptBridge.eval("window.location.hash")
	if not (fragment is String):
		return DEFAULT
	return from_hash(fragment)

static func profile(level: String) -> Dictionary:
	return PROFILES[normalize(level)]
