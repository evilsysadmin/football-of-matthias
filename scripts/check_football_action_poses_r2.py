#!/usr/bin/env python3
"""Do not publish the visually rejected v1 action WebPs in staging."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "games/chess-football-godot/optional_action_poses_v1.json"
BASE = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v2"
ORIGIN = "https://staging.football.shadowops.dpdns.org"
EXPECTED = {
    ("fc_matthias", "dribble_cut"): "08d1f14578b5081e90cb3177e13ebff4eefc6d6a4ead238d50dc2566da0835c1",
    ("fc_matthias", "dribble_burst"): "9f28275a1275dfe62c78f39f3b4e584eb3fa23adabb95ab802653d1275370068",
    ("fc_matthias", "tackle"): "86863025bd79a686afd23b1d6355d456f387e044fa9108e9a53f1e1315076e52",
    ("fc_matthias", "slide_tackle"): "66caf6a528c29d9be96db23ed2968d3be7656aa2d5cf33ac4d50d977714ac631",
    ("real_enroque", "dribble_cut"): "7114bac7f966449d1db645d9ceb1b4a2d65f97b903bfba57305e2505eebf7120",
    ("real_enroque", "dribble_burst"): "cf85bf0c1a9003e197ac1ef5d20590471dace55ad246c4725043a6ed40bc7988",
    ("real_enroque", "tackle"): "854e912dbd21e2a66f42faeaec4cefe274747fe5ce69d196585ab7ed45c26d8e",
    ("real_enroque", "slide_tackle"): "20a057e9de63bef269472f2a7f5880a7789ab6753d4716dfe7e274a992dff4c3",
}


def main() -> None:
    contract = json.loads(MANIFEST.read_text(encoding="utf-8"))
    # v1 passes transport/integrity checks but FAILS canonical human visual QA.
    # Never fetch or publish it merely because the bucket still serves 200s.
    assert contract["enabled"] is False, "Rejected v1 poses must remain disabled"
    assert contract["version"] == 1 and contract["quality_contract"] == "football-action-poses-native-v1"
    assert contract["bucket"] == "football" and contract["prefix"] == "atlases/v2/"
    assert contract["cdn_base"] == BASE
    assert contract["cell"] == {"width": 128, "height": 144}
    assert (contract["columns"], contract["rows"], contract["footline"]) == (8, 1, 134)
    assert contract["animations"] == ["dribble_cut", "dribble_burst", "tackle", "slide_tackle"]
    entries = contract["entries"]
    assert len(entries) == len(EXPECTED)
    assert {(e["team"], e["animation"]) for e in entries} == set(EXPECTED)
    for entry in entries:
        key = (entry["team"], entry["animation"])
        assert entry["file"] == f"{key[0]}_{key[1]}_poses_v1.webp"
        assert entry["sha256"] == EXPECTED[key]
    print("FOOTBALL_ACTION_POSES_V1_VISUAL_HOLD_OK enabled=false clubs=2 actions=4 fallback=1")


if __name__ == "__main__":
    main()
