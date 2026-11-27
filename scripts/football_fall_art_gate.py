#!/usr/bin/env python3
"""Offline review of two-club XI fall/recovery candidates (#325).

Passing only permits human review, never installation or R2 publication.
The low prone silhouette is intentional: do not apply running geometry.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw
from football_directional_art_gate import ArtworkRejected, mask, verified_image

W, H, FRAMES = 128, 144, 16
CLUBS = ("fc_matthias", "real_enroque")


def inspect(sheet: Image.Image) -> dict:
    if sheet.size != (W * FRAMES, H):
        raise ArtworkRejected("FALL_GEOMETRY")
    problems, bounds_list, shapes = [], [], set()
    for i in range(FRAMES):
        cell = sheet.crop((i * W, 0, (i + 1) * W, H))
        silhouette = mask(cell)
        bounds = silhouette.getbbox()
        bounds_list.append(bounds)
        if bounds is None:
            problems.append(f"{i}:EMPTY")
            continue
        x, y, right, bottom = bounds
        width, height = right - x, bottom - y
        # Use full alpha bounds too: faint scraps must not touch cell edges.
        alpha_bounds = cell.getchannel("A").getbbox()
        if not (4 <= x < right <= 124 and 4 <= y < bottom
                and 129 <= bottom <= 139 and width >= 25 and height >= 20):
            problems.append(f"{i}:BODY_OR_GROUND:{bounds}")
        if alpha_bounds and (alpha_bounds[0] < 4 or alpha_bounds[1] < 4
                             or alpha_bounds[2] > 124 or alpha_bounds[3] > 140):
            problems.append(f"{i}:ALPHA_MARGIN:{alpha_bounds}")
        # Normalize translation; moving the same standing sprite is not new art.
        shapes.add((width, height, silhouette.crop(bounds).tobytes()))
        if i in (0, 15) and height < 95:
            problems.append(f"{i}:UPRIGHT_ENDPOINT_REQUIRED")
        if 6 <= i <= 9 and not (width >= 70 and height <= 70 and width >= 1.2 * height):
            problems.append(f"{i}:PRONE_POSE_REQUIRED")
        if i in (4, 11) and height >= 95:
            problems.append(f"{i}:TRANSITION_POSE_REQUIRED")
    if len(shapes) != FRAMES:
        problems.append(f"REPEATED_SHAPES:{len(shapes)}/{FRAMES}")
    return {"accepted_for_human_review": not problems, "problems": problems,
            "unique_shapes": len(shapes), "bounds": bounds_list}


def review_board(sheet: Image.Image, output: Path, club: str) -> None:
    board = Image.new("RGBA", (W * 8, 2 * (H + 24)), "#173126")
    draw = ImageDraw.Draw(board)
    for row in range(2):
        y = row * (H + 24)
        draw.text((8, y + 4), f"{club} / poses {row * 8 + 1}-{row * 8 + 8}", fill="white")
        board.alpha_composite(sheet.crop((row * 8 * W, 0, (row + 1) * 8 * W, H)), (0, y + 24))
    board.convert("RGB").save(output, "PNG")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    # A fresh output directory prevents stale review PNGs from being mistaken
    # for the candidate that just failed.
    args.output_dir.mkdir(parents=True, exist_ok=False)
    results = {}
    for club in CLUBS:
        path = args.candidate_dir / f"{club}_fall_recover_16_candidate.webp"
        try:
            sheet = verified_image(path, None, (W * FRAMES, H))
            result = inspect(sheet)
            result["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            review_board(sheet, args.output_dir / f"{club}_review.png", club)
        except (ArtworkRejected, OSError) as exc:
            result = {"accepted_for_human_review": False, "problems": [str(exc)]}
        results[club] = result
    accepted = all(r["accepted_for_human_review"] for r in results.values())
    report = {"status": "HUMAN_REVIEW_REQUIRED" if accepted else "REJECTED",
              "runtime_activation": False, "clubs": results}
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, sort_keys=True))
    return 0 if accepted else 1


if __name__ == "__main__":
    raise SystemExit(main())
