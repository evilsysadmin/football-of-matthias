#!/usr/bin/env python3
"""Fail-closed OFFLINE review of proposed XI directional feint art.

This tool never publishes to R2, edits the source atlases, or enables a
runtime animation. Reference sheets must be exact SHA-verified original bytes.
Candidates are independent lossless WebPs, NEVER pasted V3 run frames.
Requires Pillow for image inspection (no new game/runtime dependency).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

TEAMS = ("fc_matthias", "real_enroque")
VIEWS = ("front", "back", "front_diagonal", "back_diagonal")
RUN_ROWS = (0, 1, 3, 4)
RUN_SHA = (
    "8208785adbda34a893c8445299c32a04714932feabcb8aa41ae39b8a1f9177af",
    "be73bb8fee9b1fa830ae7f405c533cb4e2fc7538c9fe248c65b0f9e63a655e01",
)
CUT_SHA = (
    "0ebe3ed766f9adf90e3c8327315cbf53282bdb3e1d6dbceac1fa0e4e81cd8c93",
    "6acec93d0e91c227c9367ba326330083a4d358b965f78b1df339d588353c37aa",
)
W, H, FRAMES, ROWS = 128, 144, 8, 4
MAX_BYTES = 4_194_304


class ArtworkRejected(ValueError):
    pass


def verified_image(path: Path, expected_sha: str | None, size: tuple[int, int]) -> Image.Image:
    if not path.is_file():
        raise ArtworkRejected(f"MISSING {path}")
    raw = path.read_bytes()
    if not (25 <= len(raw) <= MAX_BYTES):
        raise ArtworkRejected(f"SIZE {path.name}")
    if raw[:4] != b"RIFF" or raw[8:16] != b"WEBPVP8L" or raw[20] != 0x2F:
        raise ArtworkRejected(f"LOSSLESS_WEBP_REQUIRED {path.name}")
    if expected_sha and hashlib.sha256(raw).hexdigest() != expected_sha:
        raise ArtworkRejected(f"REFERENCE_SHA_MISMATCH {path.name}")
    try:
        with Image.open(path) as opened:
            if opened.format != "WEBP" or opened.size != size:
                raise ArtworkRejected(f"GEOMETRY {path.name}: {opened.size}")
            return opened.convert("RGBA")
    except (OSError, ValueError) as exc:
        raise ArtworkRejected(f"DECODE {path.name}: {exc}") from exc


def validate_disabled_contract(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if (
        data.get("enabled") is not False or data.get("version") != 1
        or data.get("quality_contract") != "football-xi-directional-feint-art-review-v1"
        or data.get("cell") != {"width": W, "height": H}
        or data.get("views") != list(VIEWS)
        or data.get("columns") != FRAMES or data.get("rows") != ROWS
        or data.get("footline") != 134
        or data.get("status") != "ART_NOT_APPROVED"
    ):
        raise ArtworkRejected("CONTRACT_MUST_REMAIN_DISABLED")
    expected = [f"{team}_feint_4views_v1.webp" for team in TEAMS]
    if data.get("candidate_filenames") != expected:
        raise ArtworkRejected("CONTRACT_CANDIDATE_NAMES")
    return data


def crop(sheet: Image.Image, col: int, row: int) -> Image.Image:
    return sheet.crop((col * W, row * H, (col + 1) * W, (row + 1) * H))


def mask(cell: Image.Image) -> Image.Image:
    return cell.getchannel("A").point(lambda a: 255 if a >= 48 else 0)


def silhouette_distance(a: Image.Image, b: Image.Image) -> float:
    """Symmetric difference divided by union of visible alpha pixels."""
    ma, mb = mask(a), mask(b)
    aa, bb = ma.tobytes(), mb.tobytes()
    both = sum(x != 0 or y != 0 for x, y in zip(aa, bb))
    if not both:
        return 0.0
    changed = sum((x != 0) != (y != 0) for x, y in zip(aa, bb))
    return changed / both


def largest_component_fraction(binary_mask: Image.Image) -> float:
    pixels = binary_mask.tobytes()
    live = {i for i, value in enumerate(pixels) if value != 0}
    total = len(live)
    if not total:
        return 0.0
    largest = 0
    while live:
        start = live.pop()
        pending = deque([start])
        size = 1
        while pending:
            point = pending.popleft()
            x, y = point % W, point // W
            for neighbor in (
                point - 1 if x > 0 else -1,
                point + 1 if x < W - 1 else -1,
                point - W if y > 0 else -1,
                point + W if y < H - 1 else -1,
            ):
                if neighbor in live:
                    live.remove(neighbor)
                    pending.append(neighbor)
                    size += 1
        largest = max(largest, size)
    return largest / total


def foot_center(cell: Image.Image) -> float:
    """Center of opaque lower-leg pixels, independent of shadow or background."""
    m = mask(cell)
    area = m.crop((0, 101, W, 135))
    raw = area.tobytes()
    xs = [i % W for i, value in enumerate(raw) if value]
    return sum(xs) / len(xs) if xs else -1.0


def inspect_candidate(candidate: Image.Image, run: Image.Image) -> dict:
    problems: list[str] = []
    metrics: dict[str, dict] = {}
    for row, view in enumerate(VIEWS):
        authored = [crop(candidate, i, row) for i in range(FRAMES)]
        sources = [crop(run, i, RUN_ROWS[row]) for i in range(12)]
        unique = len({mask(frame).tobytes() for frame in authored})
        if unique < 6:
            problems.append(f"{view}:REPEATED_FRAMES:{unique}/8")
        for index, frame in enumerate(authored):
            m = mask(frame)
            bounds = m.getbbox()
            if bounds is None:
                problems.append(f"{view}:{index}:EMPTY")
                continue
            left, top, right, bottom = bounds
            if not (4 <= left <= 48 and 80 <= right <= 124 and top <= 38
                    and 129 <= bottom <= 139 and right - left >= 46
                    and bottom - top >= 93):
                problems.append(f"{view}:{index}:BODY_OR_FOOTLINE:{bounds}")
            if (frame.getpixel((0, 0))[3] > 12
                    or frame.getpixel((W - 1, 0))[3] > 12):
                problems.append(f"{view}:{index}:DIRTY_GUTTER")
            if largest_component_fraction(m) < 0.87:
                problems.append(f"{view}:{index}:DETACHED_BODY_OR_BOOTS")
        distances = [
            min(silhouette_distance(author_frame, old) for old in sources)
            for author_frame in authored
        ]
        # The two actual planted contacts must not be disguised/cloned
        # copies of any of the 12 approved directional RUN frames.
        for contact in (2, 5):
            if distances[contact] < 0.095:
                problems.append(f"{view}:{contact}:RUN_CLONE:{distances[contact]:.3f}")
        opposite_delta = abs(foot_center(authored[2]) - foot_center(authored[5]))
        contact_difference = silhouette_distance(authored[2], authored[5])
        if opposite_delta < 2.5 or contact_difference < 0.11:
            problems.append(f"{view}:NO_OPPOSITE_PLANT:{opposite_delta:.2f}/{contact_difference:.3f}")
        metrics[view] = {
            "unique_silhouettes": unique,
            "nearest_run_silhouette_difference": [round(x, 3) for x in distances],
            "opposite_foot_center_delta_px": round(opposite_delta, 2),
            "opposite_contact_difference": round(contact_difference, 3),
        }
    return {"accepted_for_human_review": not problems, "problems": problems, "metrics": metrics}


def contact_sheet(sheets: list[Image.Image], labels: list[str], output: Path) -> None:
    # A truthful visual reference, not a fabricated animation or a human
    # approval. Original raster is pasted WITHOUT resizing or recoloring.
    board = Image.new("RGBA", (W * FRAMES, len(sheets) * (H + 28)), "#173126")
    draw = ImageDraw.Draw(board)
    for idx, (image, label) in enumerate(zip(sheets, labels)):
        y = idx * (H + 28)
        draw.text((8, y + 6), label, fill="white")
        board.alpha_composite(image, (0, y + 28))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.convert("RGB").save(output, "PNG")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("references", "inspect"))
    parser.add_argument("--source-dir", type=Path, required=True,
                        help="Root of SHA-verified CI artifact directories")
    parser.add_argument("--candidate-dir", type=Path, help="Two independent unapproved lossless WebPs")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--contract", type=Path, default=Path(__file__).resolve().parents[1]
                        / "games/chess-football-godot/optional_directional_feint_v1.json")
    args = parser.parse_args()
    validate_disabled_contract(args.contract)
    if args.mode == "inspect" and args.candidate_dir is None:
        parser.error("--candidate-dir is mandatory for inspect")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    results = {}
    for index, team in enumerate(TEAMS):
        run = verified_image(
            args.source_dir / "football-run-v3-r2" / f"{team}_run_v3_clean.webp",
            RUN_SHA[index], (W * 12, H * 5),
        )
        cut = verified_image(
            args.source_dir / "football-action-poses-r2" / f"{team}_dribble_cut_poses_v2.webp",
            CUT_SHA[index], (W * 8, H),
        )
        source_sheet = Image.new("RGBA", (W * FRAMES, H * ROWS))
        for row in range(ROWS):
            for col in range(FRAMES):
                source_sheet.alpha_composite(crop(run, col, RUN_ROWS[row]), (col * W, row * H))
        contact_sheet(
            [source_sheet.crop((0, row * H, W * FRAMES, (row + 1) * H))
             for row in range(ROWS)] + [cut],
            [f"{team} / V3 RUN / {view}" for view in VIEWS]
            + [f"{team} / AUTHORED SIDE CUT (reference only)"],
            args.output_dir / f"{team}_directional_feint_references.png",
        )
        if args.mode == "inspect":
            candidate = verified_image(
                args.candidate_dir / f"{team}_feint_4views_v1.webp",
                None, (W * FRAMES, H * ROWS),
            )
            results[team] = inspect_candidate(candidate, run)
            contact_sheet(
                [candidate.crop((0, row * H, W * FRAMES, (row + 1) * H))
                 for row in range(ROWS)],
                [f"{team} / CANDIDATE / {view}" for view in VIEWS],
                args.output_dir / f"{team}_directional_feint_candidate.png",
            )
    if args.mode == "references":
        print("FOOTBALL_DIRECTIONAL_FEINT_REFERENCE_OK teams=2 approved_v3=2 approved_cut=2 activation=off")
        return 0
    report = {
        "quality_contract": "football-xi-directional-feint-art-review-v1",
        "status": "CANDIDATE_REJECTED" if any(not x["accepted_for_human_review"]
              for x in results.values()) else "STRUCTURAL_PREFLIGHT_ONLY",
        "teams": results,
        "runtime_activated": False,
        "human_review_approved": False,
    }
    (args.output_dir / "directional-feint-art-review.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"FOOTBALL_DIRECTIONAL_FEINT_ART_{report['status']} activation=off")
    return 1 if report["status"] == "CANDIDATE_REJECTED" else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ArtworkRejected, OSError, json.JSONDecodeError) as exc:
        print(f"FOOTBALL_DIRECTIONAL_FEINT_ART_REJECTED reason={exc}")
        raise SystemExit(1) from exc
