#!/usr/bin/env python3
"""Fail-closed staging gate for the three user-published Football animated idle sheets.

No credentials or R2 mutation; test the dedicated bucket's public URL and
staging CORS against the SHA-pinned, local Godot contract.
"""
import hashlib
import json
import os
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "games/chess-football-godot/optional_animated_idle_v1.json"
ORIGIN = "https://staging.football.shadowops.dpdns.org"
KNOWN_FILES = {
    "fc_matthias": ("fc_matthias_idle_v1.webp", "ff410746fbb6bfe20b39b7fb99d6e7185d6a27f1416922d0742e0325e9ccb5ed"),
    "real_enroque": ("real_enroque_idle_v1.webp", "71835fc75eb1e3e9f59c3ebb128ba74dd145ec7df7f6f43562f7af12f5fdc87f"),
    "keeper": ("keeper_idle_v1.webp", "2ef0cc83f5ba2801ae47cabdfa3c337e9ef7dc75104bef9d3d587c87f42283e3"),
}


def dimensions(data: bytes) -> tuple[int, int]:
    if data[:4] != b"RIFF" or data[8:12] != b"WEBP" or data[12:16] != b"VP8L":
        raise ValueError("expected lossless WebP VP8L data")
    if len(data) < 25 or data[20] != 0x2F:
        raise ValueError("invalid VP8L header")
    bits = int.from_bytes(data[21:25], "little")
    return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)


def main() -> None:
    meta = json.loads(MANIFEST.read_text())
    if meta.get("enabled") is not True:
        print("FOOTBALL_IDLE_R2_DISABLED canonical sprite fallback active")
        return
    assert meta["bucket"] == "football" and meta["prefix"] == "atlases/v1/"
    assert meta["cell"] == {"width": 128, "height": 144}
    assert (meta["columns"], meta["rows"], meta["fps"], meta["footline"]) == (8, 5, 7, 132)
    assert meta["views"] == ["front", "back", "side", "front_diagonal", "back_diagonal"]
    base = meta["cdn_base"]
    expected_base = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v1"
    assert base == expected_base, "unexpected public R2 origin or prefix"
    assert urlsplit(base).hostname != "assets.chess-studio.shadowops.dpdns.org"
    assert len(meta["entries"]) == len(KNOWN_FILES)
    seen = set()
    for entry in meta["entries"]:
        kind = entry["kind"]
        assert kind not in seen and kind in KNOWN_FILES
        seen.add(kind)
        filename, sha = KNOWN_FILES[kind]
        assert (entry["file"], entry["sha256"]) == (filename, sha)
        url = f"{base}/{filename}"
        req = Request(url, headers={"Origin": ORIGIN, "User-Agent": "Football-idle-R2-CI/1"})
        with urlopen(req, timeout=20) as response:
            assert response.status == 200
            assert "image/webp" in response.headers.get("Content-Type", ""), (kind, response.headers)
            cors = response.headers.get("Access-Control-Allow-Origin", "")
            assert cors in (ORIGIN, "*"), (kind, cors)
            data = response.read(4_194_305)
        assert len(data) <= 4_194_304, "oversized R2 atlas"
        assert hashlib.sha256(data).hexdigest() == sha, f"R2 SHA mismatch: {kind}"
        assert dimensions(data) == (1024, 720), f"R2 dimensions mismatch: {kind}"
        # Keep exact SHA/CORS-verified bytes for the real Godot visual gate.
        # Do not ever write downloaded CDN images into the Git checkout.
        if os.environ.get("RUNNER_TEMP"):
            folder = Path(os.environ["RUNNER_TEMP"]) / "football-idle-r2"
            folder.mkdir(parents=True, exist_ok=True)
            (folder / filename).write_bytes(data)
        print(f"FOOTBALL_IDLE_R2_VERIFIED kind={kind} bytes={len(data)} sha256={sha} cors={cors}")
    assert seen == KNOWN_FILES.keys()


if __name__ == "__main__":
    main()
