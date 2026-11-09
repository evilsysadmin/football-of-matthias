#!/usr/bin/env python3
"""Fail closed on all eight operator-uploaded native action pose WebPs."""
import hashlib
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "games/chess-football-godot/optional_action_poses_v2.json"
BASE = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v2"
ORIGIN = "https://staging.football.shadowops.dpdns.org"
EXPECTED = {
    ("fc_matthias", "dribble_cut"): "0ebe3ed766f9adf90e3c8327315cbf53282bdb3e1d6dbceac1fa0e4e81cd8c93",
    ("fc_matthias", "dribble_burst"): "d516759fb53668d5fc02daf0581b8d61e1bddbb29b9725e9e4fa3edcd9729d9b",
    ("fc_matthias", "tackle"): "a3c50d36bc62104bb88e60e96da2134c99180bd4afe50dc7d92115271d08b18c",
    ("fc_matthias", "slide_tackle"): "21b1f297d52752977d20d7d6d4f2952c5158605922157bf1edb6a063fdd76071",
    ("real_enroque", "dribble_cut"): "6acec93d0e91c227c9367ba326330083a4d358b965f78b1df339d588353c37aa",
    ("real_enroque", "dribble_burst"): "2625c30ae31784008c3f2c665ec22ce79bfa664f663510ce5d463933c67f54b5",
    ("real_enroque", "tackle"): "1e64f42753f9a30d4361008abb99e6f71092d74dc85f05104a822ae9fa82fb77",
    ("real_enroque", "slide_tackle"): "819e008a135797e4d3fd901457f2433e08f94358bc43b8b3ef0f1ddc756ec564",
}


def dimensions(raw: bytes) -> tuple[int, int]:
    if len(raw) < 25 or raw[:4] != b"RIFF" or raw[8:12] != b"WEBP" or raw[12:16] != b"VP8L" or raw[20] != 0x2F:
        raise ValueError("Expected lossless VP8L WebP")
    bits = int.from_bytes(raw[21:25], "little")
    return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)


def main() -> None:
    contract = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert contract["enabled"] is True and contract["version"] == 2
    assert contract["quality_contract"] == "football-approved-r2-action-recomposition-v2"
    assert contract["bucket"] == "football" and contract["prefix"] == "atlases/v2/"
    assert contract["cdn_base"] == BASE
    assert contract["cell"] == {"width": 128, "height": 144}
    assert (contract["columns"], contract["rows"], contract["footline"]) == (8, 1, 134)
    assert contract["animations"] == ["dribble_cut", "dribble_burst", "tackle", "slide_tackle"]
    entries = contract["entries"]
    assert len(entries) == len(EXPECTED)
    assert {(e["team"], e["animation"]) for e in entries} == set(EXPECTED)
    out = Path(os.environ["RUNNER_TEMP"]) / "football-action-poses-r2"
    out.mkdir(parents=True, exist_ok=True)
    for entry in entries:
        key = (entry["team"], entry["animation"])
        name = f"{key[0]}_{key[1]}_poses_v2.webp"
        sha = EXPECTED[key]
        assert entry["file"] == name and entry["sha256"] == sha
        request = Request(BASE + "/" + name, headers={
            "Origin": ORIGIN, "User-Agent": "Football-native-action-R2-CI/1.0"
        })
        with urlopen(request, timeout=20) as response:
            assert response.status == 200, (name, response.status)
            assert "image/webp" in response.headers.get("Content-Type", "").lower(), name
            assert response.headers.get("Access-Control-Allow-Origin", "") in ("*", ORIGIN), name
            raw = response.read(4_194_305)
        assert 25 <= len(raw) <= 4_194_304
        assert dimensions(raw) == (1024, 144), name
        assert hashlib.sha256(raw).hexdigest() == sha, "SHA mismatch: " + name
        (out / name).write_bytes(raw)
        print(f"FOOTBALL_ACTION_POSES_R2_VERIFIED team={key[0]} action={key[1]} bytes={len(raw)}")
    print("FOOTBALL_ACTION_POSES_R2_ALL_VERIFIED teams=2 actions=4 files=8")


if __name__ == "__main__":
    main()
