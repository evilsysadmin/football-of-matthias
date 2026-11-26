#!/usr/bin/env python3
"""Prepare local, review-only Godot inputs from a candidate ZIP and CI release ZIP.

No network, uploads, release activation, or trusted art approval. Strict mode
requires the eight candidate run sheets; --compare-v5 explicitly accepts the
six-sheet historical candidate pack for a mixed-generation control.
"""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

from check_football_pass_shoot_r2 import webp_dimensions
from check_football_dense_v1_r2 import EXPECTED as DENSE
from verify_football_v5_r2 import EXPECTED as V5

MAX_WEBP = 4 * 1024 * 1024
MAX_PCK = 128 * 1024 * 1024
CLUBS = ("fc_matthias", "real_enroque")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def bounded_read(archive, name, limit):
    entries = [entry for entry in archive.infolist() if entry.filename == name]
    if len(entries) != 1 or not 0 < entries[0].file_size <= limit:
        raise ValueError("Missing, duplicate or oversized ZIP entry: " + name)
    with archive.open(entries[0]) as stream:
        data = stream.read(limit + 1)
    if len(data) != entries[0].file_size or len(data) > limit:
        raise ValueError("ZIP length mismatch: " + name)
    return data


def verify_webp(raw, dimensions):
    if not 25 <= len(raw) <= MAX_WEBP or int.from_bytes(raw[4:8], "little") + 8 != len(raw):
        raise ValueError("Invalid WebP RIFF length")
    if webp_dimensions(raw) != dimensions:
        raise ValueError("Invalid WebP dimensions")


def read_candidates(archive, compare_v5=False):
    views = ("side", "back", "back_diagonal") if compare_v5 else ("side", "front", "back", "back_diagonal")
    names = {f"{club}_run_{view}_24_candidate_v3.webp" for club in CLUBS for view in views}
    doc = json.loads(bounded_read(archive, "phase-review.json", 65536))
    entries = doc.get("entries", [])
    if doc.get("status") != "candidate_only" or doc.get("cell") != {"width": 128, "height": 144}:
        raise ValueError("Expected review-only candidate manifest")
    if len(entries) != len(names) or {e["file"] for e in entries} != names:
        raise ValueError("Candidate coverage mismatch; expected: " + ", ".join(sorted(names)))
    result = {}
    for entry in entries:
        name = entry["file"]
        raw = bounded_read(archive, name, MAX_WEBP)
        if (entry["bytes"], entry["sha256"], entry["columns"], entry["rows"]) != (len(raw), sha(raw), 24, 1):
            raise ValueError("Candidate manifest mismatch: " + name)
        verify_webp(raw, (3072, 144))
        result[name] = raw
    return result


def find_pinned_webps(pck, pins):
    """Locate raw RIFF payloads, trusting only complete pinned SHA-256 bytes."""
    remaining = dict(pins)
    result = {}
    offset = 0
    while remaining:
        pos = pck.find(b"RIFF", offset)
        if pos < 0:
            break
        offset = pos + 4
        if pck[pos+8:pos+12] != b"WEBP":
            continue
        size = int.from_bytes(pck[pos+4:pos+8], "little") + 8
        if not 25 <= size <= MAX_WEBP or pos + size > len(pck):
            continue
        raw = pck[pos:pos+size]
        digest = sha(raw)
        if digest in remaining:
            name, dimensions = remaining.pop(digest)
            verify_webp(raw, dimensions)
            result[name] = raw
    if remaining:
        raise ValueError("Missing exact pinned reference(s): " + ", ".join(v[0] for v in remaining.values()))
    return result


def read_references(archive, compare_v5=False):
    release = json.loads(bounded_read(archive, "web/release.json", 65536))
    pck = bounded_read(archive, "runtime/index.pck", MAX_PCK)
    if (release.get("application"), release.get("environment")) != ("football-of-matthias", "staging"):
        raise ValueError("Not a Football staging artifact")
    if release["files"]["index.pck"] != {"bytes": len(pck), "sha256": sha(pck)}:
        raise ValueError("PCK differs from release manifest")
    pins = {digest: (name, (128 * count, 144)) for name, (digest, count) in DENSE.items() if "_run_front_diagonal_" in name}
    if compare_v5:
        pins.update({digest: (name, (128 * columns, 144 * rows)) for name, (digest, _, columns, rows) in V5.items() if "_locomotion_" in name})
    return release["source_sha"], find_pinned_webps(pck, pins)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidates", type=Path)
    parser.add_argument("release", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--compare-v5", action="store_true")
    args = parser.parse_args()
    with ZipFile(args.candidates) as candidate_zip, ZipFile(args.release) as release_zip:
        candidates = read_candidates(candidate_zip, args.compare_v5)
        source_sha, references = read_references(release_zip, args.compare_v5)
    # All inputs verified before creating any output. New directory prevents
    # stale sheets from a previous review silently surviving.
    args.output.mkdir(parents=True, exist_ok=False)
    for folder in ("candidates", "dense", "v5"):
        (args.output / folder).mkdir()
    for name, data in candidates.items():
        (args.output / "candidates" / name).write_bytes(data)
    for name, data in references.items():
        folder = "v5" if name.endswith("_locomotion_v5.webp") else "dense"
        (args.output / folder / name).write_bytes(data)
    print("FOOTBALL_REVIEW_INPUTS_READY source_sha=" + source_sha +
          " mode=" + ("mixed_v5_comparison" if args.compare_v5 else "dense_strict") +
          " review_only=true")
    print("Godot review arguments:", args.output / "candidates", args.output / "dense", args.output / "captures",
          args.output / "v5" if args.compare_v5 else "")


if __name__ == "__main__":
    main()
