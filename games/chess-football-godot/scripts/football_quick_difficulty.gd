extends RefCounted

# Bounded CPU-only decision modifiers. Normal preserves existing tactics.
# Never modify an individual's pace, stamina, keeper physics or ball rules.
const DEFAULT := "normal"
const PROFILES := {
	"easy": {"decision": 1.45, "pressure": 0.84, "effort": 0.82, "shoot": 0.82},
	"normal": {"decision": 1.0, "pressure": 1.0, "effort": 1.0, "shoot": 1.0},
	"hard": {"decision": 0.82, "pressure": 1.10, "effort": 1.08, "shoot": 1.08},
	"expert": {"decision": 0.67, "pressure": 1.18, "effort": 1.15, "shoot": 1.12},
}

static func normalize(level: String) -> String:
	return level if PROFILES.has(level) else DEFAULT

static func from_hash(fragment: String) -> String:
	var prefix := "#football-difficulty="
	if not fragment.begins_with(prefix):
		return DEFAULT
	return normalize(fragment.trim_prefix(prefix))

static func read_browser() -> String:
	if not OS.has_feature("web"):
		return DEFAULT
	var fragment: Variant = JavaScriptBridge.eval("window.location.hash")
	if not (fragment is String):
		return DEFAULT
	return from_hash(fragment)

static func profile(level: String) -> Dictionary:
	return PROFILES[normalize(level)]
