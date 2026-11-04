#!/usr/bin/env python3
"""Verify the exact, user-uploaded Football R2 v2 WebPs.

The 40-cell shadow sheet was preflighted locally and found sparse (39/40
empty). Its bytes are checked but it MUST stay disabled. Runtime shadows
are procedurally rendered in Godot instead. No secrets or uploads here.
"""
import hashlib
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
META = ROOT / "games/chess-football-godot/optional_run_v2.json"
PUBLIC_BASE = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v2"
ORIGIN = "https://staging.football.shadowops.dpdns.org"
EXPECTED = {
    "fc_matthias": ("fc_matthias_run_v2_clean.webp", "d686ad08291910bdbfb8454135f917e939b727c7498e3a3b8a93f919cbe48a2f"),
    "real_enroque": ("real_enroque_run_v2_clean.webp", "4f02d84e6a337389d1bdbeac22ef78eacea8dd32076bc8807bd80ed1466172dd"),
}
SHADOW = ("outfield_soft_shadows_v2_clean.webp", "5bc31e03a2eaba6c18a9c03bd9e2bccbccced76b131320556a36c8af970547e6")


def dimensions(raw: bytes) -> tuple[int, int]:
    if len(raw) < 25 or raw[:4] != b"RIFF" or raw[8:12] != b"WEBP" or raw[12:16] != b"VP8L" or raw[20] != 0x2F:
        raise ValueError("Expected lossless VP8L WebP sheet")
    bits = int.from_bytes(raw[21:25], "little")
    return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1


def verify_object(filename: str, sha: str) -> None:
    req = Request(f"{PUBLIC_BASE}/{filename}", headers={"Origin": ORIGIN, "User-Agent": "Football-run-v2-CI/1"})
    with urlopen(req, timeout=20) as response:
        assert response.status == 200, filename
        assert "image/webp" in response.headers.get("Content-Type", "").lower(), filename
        cors = response.headers.get("Access-Control-Allow-Origin", "")
        assert cors in ("*", ORIGIN), f"Staging CORS missing for {filename}"
        body = response.read(4_194_305)
    assert 0 < len(body) <= 4_194_304
    assert hashlib.sha256(body).hexdigest() == sha, f"R2 SHA mismatch for {filename}"
    assert dimensions(body) == (1024, 720), f"R2 size mismatch for {filename}"
    if os.environ.get("RUNNER_TEMP") and filename != SHADOW[0]:
        directory = Path(os.environ["RUNNER_TEMP"]) / "football-run-v2-r2"
        directory.mkdir(exist_ok=True)
        (directory / filename).write_bytes(body)
    print(f"FOOTBALL_RUN_V2_R2_VERIFIED filename={filename} bytes={len(body)} sha256={sha} cors={cors}")


def main() -> None:
    cfg = json.loads(META.read_text())
    assert cfg["enabled"] is True and cfg["version"] == 2
    assert cfg["bucket"] == "football" and cfg["prefix"] == "atlases/v2/"
    assert cfg["cdn_base"] == PUBLIC_BASE
    assert cfg["quality_contract"] == "football-run-5views-v2"
    assert (cfg["columns"], cfg["rows"], cfg["cell"], cfg["fps"]) == (8, 5, {"width": 128, "height": 144}, 12)
    assert cfg["views"] == ["front", "back", "side", "front_diagonal", "back_diagonal"]
    assert len(cfg["entries"]) == 2
    seen = set()
    for entry in cfg["entries"]:
        kind = entry["kind"]
        assert kind in EXPECTED and kind not in seen
        seen.add(kind)
        assert (entry["file"], entry["sha256"]) == EXPECTED[kind]
        verify_object(*EXPECTED[kind])
    assert seen == EXPECTED.keys()
    shadow = cfg["shadow_candidate"]
    assert shadow["enabled"] is False, "Bad v2 shadow sheet must never be enabled"
    assert (shadow["file"], shadow["sha256"]) == SHADOW
    verify_object(*SHADOW)
    print("FOOTBALL_SHADOW_V2_REJECTED 39 sparse frames; procedural soft shadow enabled")


if __name__ == "__main__":
    main()
