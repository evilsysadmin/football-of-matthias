#!/usr/bin/env python3
"""Fail closed on both published Football R2 ball-control sprite atlases."""
import hashlib
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "games/chess-football-godot/optional_carry_dribble_v1.json"
BASE = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v1"
ORIGIN = "https://staging.football.shadowops.dpdns.org"
EXPECTED = {
    "fc_matthias": ("fc_matthias_carry_dribble_v1.webp", "d77d23b1a19bd454a829e6a2368aeefbeaa0ca42ee5b1a2ec530218437a0ef9d"),
    "real_enroque": ("real_enroque_carry_dribble_v1.webp", "39606797cb05c582c598cb5b599cc59104e3926a963bbc445dc0444aaa80bbeb"),
}


def webp_dimensions(raw: bytes) -> tuple[int, int]:
    if len(raw) < 25 or raw[:4] != b"RIFF" or raw[8:12] != b"WEBP" or raw[12:16] != b"VP8L" or raw[20] != 0x2F:
        raise ValueError("Expected lossless VP8L WebP")
    bits = int.from_bytes(raw[21:25], "little")
    return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)


def main() -> None:
    contract = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert contract["enabled"] is True
    assert contract["bucket"] == "football" and contract["prefix"] == "atlases/v1/"
    assert contract["cdn_base"] == BASE and contract["quality_contract"] == "football-carry-dribble-side-v1"
    assert contract["cell"] == {"width": 128, "height": 144}
    assert (contract["columns"], contract["rows"], contract["footline"]) == (8, 2, 132)
    assert contract["animations"] == ["carry", "dribble"]
    assert contract["fps"] == {"carry": 12, "dribble": 36}
    entries = contract["entries"]
    assert len(entries) == 2 and {e["team"] for e in entries} == set(EXPECTED)
    output = Path(os.environ["RUNNER_TEMP"]) / "football-carry-dribble-r2"
    output.mkdir(parents=True, exist_ok=True)
    for entry in entries:
        filename, sha = EXPECTED[entry["team"]]
        assert entry["file"] == filename and entry["sha256"] == sha
        request = Request(f"{BASE}/{filename}", headers={"Origin": ORIGIN, "User-Agent": "Football-carry-R2-CI/1"})
        with urlopen(request, timeout=20) as response:
            assert response.status == 200, (filename, response.status)
            assert "image/webp" in response.headers.get("Content-Type", "").lower(), filename
            assert response.headers.get("Access-Control-Allow-Origin", "") in ("*", ORIGIN), filename
            data = response.read(4_194_305)
        assert 25 <= len(data) <= 4_194_304, filename
        assert webp_dimensions(data) == (1024, 288), filename
        assert hashlib.sha256(data).hexdigest() == sha, f"R2 SHA mismatch: {filename}"
        (output / filename).write_bytes(data)
        print(f"FOOTBALL_CARRY_DRIBBLE_R2_VERIFIED team={entry['team']} bytes={len(data)} sha256={sha}")
    print("FOOTBALL_CARRY_DRIBBLE_R2_ALL_VERIFIED teams=2")


if __name__ == "__main__":
    main()
