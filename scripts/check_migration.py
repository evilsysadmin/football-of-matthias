"""Verify historical source references without freezing independently owned code.

migration/source.json remains the immutable extraction provenance. Canonical
player art / art-forge sources must still match it byte-for-byte, but the
standalone game's scripts and tests are expected to evolve after extraction.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OWNED_PATHS = ("games/", "scripts/art/")
IMMUTABLE_ART_PATHS = ("games/chess-football-godot/assets/", "scripts/art/")


def git_blob_sha(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def verify_migration(root: Path, source: dict, additions: dict) -> tuple[int, int]:
    root = root.resolve()
    art_checked = 0
    runtime_present = 0
    for item in source["files"] + additions["files"]:
        path_str = item["path"]
        path = Path(path_str)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"Invalid provenance path: {path_str}")
        if not path_str.startswith(OWNED_PATHS):
            continue
        target = root / path
        if not target.is_file():
            raise FileNotFoundError(f"Missing migrated file: {path_str}")
        if path_str.startswith(IMMUTABLE_ART_PATHS):
            raw = target.read_bytes()
            if git_blob_sha(raw) != item["sha"]:
                raise AssertionError(f"Canonical art provenance changed: {path_str}")
            art_checked += 1
        else:
            # Presence is checked, but historical SHA is not a code freeze.
            runtime_present += 1
    return art_checked, runtime_present


def main() -> None:
    source = json.loads((ROOT / "migration/source.json").read_text())
    additions_path = ROOT / "migration/additions.json"
    additions = json.loads(additions_path.read_text()) if additions_path.exists() else {"files": []}
    art_count, runtime_count = verify_migration(ROOT, source, additions)
    print(f"FOOTBALL_CANONICAL_ART_PROVENANCE_OK assets={art_count} evolving_files={runtime_count}")


if __name__ == "__main__":
    main()
