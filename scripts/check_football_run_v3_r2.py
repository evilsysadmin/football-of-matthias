#!/usr/bin/env python3
"""Gate user-uploaded 12-pose Football R2 v3: HTTPS, CORS, bytes and shape.

Read-only; stores only the exact, verified WebPs for real Godot PNG review.
No secrets, R2 writes, unchecked external origins or silent acceptance of 404.
"""
import hashlib
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
META = ROOT / "games/chess-football-godot/optional_run_v3.json"
CDN_BASE = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v3"
ORIGIN = "https://staging.football.shadowops.dpdns.org"
EXPECTED = {
    "fc_matthias": ("fc_matthias_run_v3_clean.webp", "8208785adbda34a893c8445299c32a04714932feabcb8aa41ae39b8a1f9177af"),
    "real_enroque": ("real_enroque_run_v3_clean.webp", "be73bb8fee9b1fa830ae7f405c533cb4e2fc7538c9fe248c65b0f9e63a655e01"),
}


def dimensions(raw: bytes) -> tuple[int, int]:
    if len(raw) < 25 or raw[:4] != b"RIFF" or raw[8:12] != b"WEBP" or raw[12:16] != b"VP8L" or raw[20] != 0x2F:
        raise ValueError("Expected lossless VP8L WebP")
    bits = int.from_bytes(raw[21:25], "little")
    return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1


def verify_object(filename: str, sha: str) -> None:
    req = Request(f"{CDN_BASE}/{filename}", headers={"Origin": ORIGIN, "User-Agent": "Football-run-v3-CI/1"})
    with urlopen(req, timeout=20) as response:
        assert response.status == 200, filename
        assert response.headers.get_content_type() == "image/webp", filename
        cors = response.headers.get("Access-Control-Allow-Origin", "")
        assert cors in ("*", ORIGIN), f"Staging CORS missing for {filename}"
        body = response.read(4_194_305)
    assert 0 < len(body) <= 4_194_304, filename
    assert hashlib.sha256(body).hexdigest() == sha, f"R2 SHA-256 mismatch for {filename}"
    assert dimensions(body) == (1536, 720), f"R2 dimensions mismatch for {filename}"
    if os.environ.get("RUNNER_TEMP"):
        directory = Path(os.environ["RUNNER_TEMP"]) / "football-run-v3-r2"
        directory.mkdir(parents=True, exist_ok=True)
        (directory / filename).write_bytes(body)
    print(f"FOOTBALL_RUN_V3_R2_VERIFIED filename={filename} bytes={len(body)} sha256={sha} cors={cors}")


def main() -> None:
    cfg = json.loads(META.read_text(encoding="utf-8"))
    assert cfg["enabled"] is True and cfg["version"] == 3
    assert cfg["bucket"] == "football" and cfg["prefix"] == "atlases/v3/"
    assert cfg["cdn_base"] == CDN_BASE and cfg["quality_contract"] == "football-run-5views-v3"
    assert (cfg["columns"], cfg["rows"], cfg["cell"], cfg["fps"]) == (12, 5, {"width": 128, "height": 144}, 18)
    assert cfg["views"] == ["front", "back", "side", "front_diagonal", "back_diagonal"]
    assert len(cfg["entries"]) == 2
    for entry, kind in zip(cfg["entries"], EXPECTED, strict=True):
        assert entry["kind"] == kind
        assert (entry["file"], entry["sha256"]) == EXPECTED[kind]
        verify_object(*EXPECTED[kind])
    print("FOOTBALL_RUN_V3_R2_BOTH_TEAMS_OK poses=12 views=5")


if __name__ == "__main__":
    main()
