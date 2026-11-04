#!/usr/bin/env python3
"""Fail-closed gate for Football's two optional authored action WebPs.

CI (never a browser secret) downloads from the *dedicated* Football R2
origin and verifies exact bytes + CORS before real Godot screenshots.
"""
import hashlib
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "games/chess-football-godot/optional_pass_shoot_v1.json"
BASE = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v1"
ORIGIN = "https://staging.football.shadowops.dpdns.org"
EXPECTED = {
    "fc_matthias": ("fc_matthias_pass_shoot_v1.webp", "ad286ff56d0f1461efaa9aad20fc349203ed9a90b3ea3e45f60d41493b9c2b24"),
    "real_enroque": ("real_enroque_pass_shoot_v1.webp", "5dae02988c73e1353a17d3ef521949049a1b41c89b97fc01a5042cca691afc36"),
}


def webp_dimensions(raw: bytes) -> tuple[int, int]:
    if len(raw) < 25 or raw[:4] != b"RIFF" or raw[8:12] != b"WEBP" or raw[12:16] != b"VP8L" or raw[20] != 0x2F:
        raise ValueError("Only canonical lossless VP8L WebP is allowed")
    bits = int.from_bytes(raw[21:25], "little")
    return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)


def main() -> None:
    contract = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert contract["enabled"] is True, "R2 action manifest must be enabled for activation PR"
    assert contract["bucket"] == "football" and contract["prefix"] == "atlases/v1/"
    assert contract["cdn_base"] == BASE
    assert contract["quality_contract"] == "football-pass-shoot-v1"
    assert contract["cell"] == {"width": 128, "height": 144}
    assert (contract["columns"], contract["rows"], contract["fps"], contract["footline"]) == (8, 2, 10, 132)
    assert contract["animations"] == ["pass", "shoot"]
    entries = contract["entries"]
    assert isinstance(entries, list) and len(entries) == 2
    assert {e["team"] for e in entries} == set(EXPECTED)
    output = Path(os.environ["RUNNER_TEMP"]) / "football-pass-shoot-r2"
    output.mkdir(parents=True, exist_ok=True)
    for entry in entries:
        kind = entry["team"]
        filename, sha = EXPECTED[kind]
        assert entry["file"] == filename and entry["sha256"] == sha
        request = Request(f"{BASE}/{filename}", headers={"Origin": ORIGIN, "User-Agent": "Football-actions-R2-CI/1"})
        with urlopen(request, timeout=20) as response:
            assert response.status == 200, (kind, response.status)
            assert "image/webp" in response.headers.get("Content-Type", ""), kind
            assert response.headers.get("Access-Control-Allow-Origin", "") in ("*", ORIGIN), kind
            data = response.read(4_194_305)
        assert len(data) <= 4_194_304, kind
        assert webp_dimensions(data) == (1024, 288), kind
        assert hashlib.sha256(data).hexdigest() == sha, f"wrong R2 bytes for {kind}"
        (output / filename).write_bytes(data)
        print(f"FOOTBALL_PASS_SHOOT_R2_VERIFIED team={kind} sha256={sha} bytes={len(data)}")
    print("FOOTBALL_PASS_SHOOT_R2_ALL_VERIFIED teams=2")


if __name__ == "__main__":
    main()
