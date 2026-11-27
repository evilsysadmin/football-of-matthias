#!/usr/bin/env python3
"""Verify operator-uploaded directional WebPs before real Godot review.

These are immutable review inputs, not a runtime activation manifest.
No credentials, writes to R2, or changes to existing approved objects.
"""
import argparse
import hashlib
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.request import Request, urlopen

from check_football_dense_v1_r2 import BASE, ORIGIN
from check_football_pass_shoot_r2 import webp_dimensions

EXPECTED = {
    "fc_matthias_run_back_24_v1.webp": [
        "5f54ec132fe5d9cc098a298d3d08905d7bd55f8bef15662b139529330614e533",
        185312
    ],
    "fc_matthias_run_back_diagonal_24_v1.webp": [
        "f7a94fa8aa6dcca4edc3f441fec2596e83dab5d8230ebb9d6f935fcafa61050a",
        200452
    ],
    "fc_matthias_run_front_24_v1.webp": [
        "37686ce1c624c2de6003466be99db3a8ec549fe222949940e237074269d0d070",
        185028
    ],
    "fc_matthias_run_side_24_v1.webp": [
        "4369fdac5a9d2b8da246ea729d2406193a92258d8bb2e136b689803847e0bba0",
        217922
    ],
    "real_enroque_run_back_24_v1.webp": [
        "6b1939812dfb87d7854d6b2f0bb8907db061c07040dd0c4f70334adfb375bd9e",
        201252
    ],
    "real_enroque_run_back_diagonal_24_v1.webp": [
        "2109f65679eeeea844a94985ad2580e144488155f70e4e55fe6041c127e8a198",
        220334
    ],
    "real_enroque_run_front_24_v1.webp": [
        "5ccf3d8e9abed40cd3694bfb5b2c5a14796d7921b3d71c6cedccd6a06462ad9d",
        232038
    ],
    "real_enroque_run_side_24_v1.webp": [
        "bdb01a00b13c22091d66e8a6b1be6ac28c42a2b1e9cd39f5d94c3aa72eaa09e4",
        233044
    ]
}


def fetch(item):
    name, (digest, size) = item
    url = BASE + "/" + name
    request = Request(url, headers={"Origin": ORIGIN, "User-Agent": "Football-direction-review/1"})
    with urlopen(request, timeout=20) as response:
        if response.status != 200 or response.geturl() != url:
            raise ValueError("HTTP or redirect mismatch: " + name)
        if "image/webp" not in response.headers.get("Content-Type", ""):
            raise ValueError("Content-Type mismatch: " + name)
        if response.headers.get("Access-Control-Allow-Origin", "") not in ("*", ORIGIN):
            raise ValueError("CORS mismatch: " + name)
        raw = response.read(size + 1)
    if len(raw) != size or hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError("Exact uploaded bytes mismatch: " + name)
    if webp_dimensions(raw) != (3072, 144):
        raise ValueError("Lossless WebP dimensions mismatch: " + name)
    if int.from_bytes(raw[4:8], "little") + 8 != size:
        raise ValueError("RIFF size mismatch: " + name)
    print("FOOTBALL_DIRECTION_R2_VERIFIED", name, digest, size, flush=True)
    return name, raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with ThreadPoolExecutor(max_workers=4) as pool:
        verified = list(pool.map(fetch, EXPECTED.items()))
    # No partial directory on a rejected pack. Adapt names solely for the
    # offline review CLI; the immutable published R2 keys remain _v1.webp.
    args.output.mkdir(parents=True, exist_ok=False)
    for name, raw in verified:
        (args.output / name.replace("_v1.webp", "_candidate_v3.webp")).write_bytes(raw)
    print("FOOTBALL_DIRECTION_R2_ALL_VERIFIED sheets=8 review_only=true")


if __name__ == "__main__":
    main()
