#!/usr/bin/env python3
"""Verify the six operator-published dense V1 sheets; no credentials."""
import hashlib
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen
from check_football_pass_shoot_r2 import webp_dimensions

BASE = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/dense-v1"
ORIGIN = "https://staging.football.shadowops.dpdns.org"
EXPECTED = {
    "fc_matthias_pass_16_v1.webp": ("85f06fb25ce9f688d948cdec8d16e35a8b8b9ccc2c31dfe9df63e0bdc6195086", 16),
    "fc_matthias_shoot_16_v1.webp": ("02657c4c59bbeeea7403cd6dc66cf95d75d24a81553a19c61f60842047e5da60", 16),
    "fc_matthias_run_front_diagonal_24_v1.webp": ("c900c992044056b7e36d42c8e42c8e7aea00d4fa9e01cab2f96a79d12992a01d", 24),
    "real_enroque_pass_16_v1.webp": ("b5a78aaf2b77f254389f87e17ba612677ff89a1d7441791906ade247a1fc4ad0", 16),
    "real_enroque_shoot_16_v1.webp": ("2a61e6dd266c1c25499c9e26d4ac6581acd9f614901cc24589b24ff1213925a6", 16),
    "real_enroque_run_front_diagonal_24_v1.webp": ("e95bed24beeeadf4f2abd53ec090411dd0798d29be045db6bb502cde2689c0dd", 24),
}
def main():
    root = Path(__file__).resolve().parents[1]
    meta = json.loads((root / "games/chess-football-godot/optional_dense_v1.json").read_text())
    assert meta["cdn_base"] == BASE and meta["prefix"] == "atlases/dense-v1/"
    assert meta["cell"] == {"width": 128, "height": 144}
    assert meta["enabled_actions"] == ["pass", "shoot"]
    assert len(meta["entries"]) == len(EXPECTED)
    assert {e["file"] for e in meta["entries"]} == set(EXPECTED)
    output = Path(os.environ["RUNNER_TEMP"]) / "football-dense-v1"
    output.mkdir(parents=True, exist_ok=True)
    for entry in meta["entries"]:
        name = entry["file"]
        digest, count = EXPECTED[name]
        assert (entry["sha256"], entry["columns"], entry["rows"]) == (digest, count, 1)
        request = Request(BASE + "/" + name, headers={"Origin": ORIGIN, "User-Agent": "Football-dense-v1-CI"})
        with urlopen(request, timeout=20) as response:
            assert response.status == 200
            assert "image/webp" in response.headers.get("Content-Type", "")
            assert response.headers.get("Access-Control-Allow-Origin", "") in ("*", ORIGIN)
            data = response.read(4_194_305)
        assert len(data) <= 4_194_304
        assert webp_dimensions(data) == (128 * count, 144)
        assert hashlib.sha256(data).hexdigest() == digest
        (output / name).write_bytes(data)
        print("FOOTBALL_DENSE_V1_VERIFIED", name, digest, len(data))

if __name__ == "__main__":
    main()
