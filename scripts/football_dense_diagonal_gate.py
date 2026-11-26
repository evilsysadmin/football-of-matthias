#!/usr/bin/env python3
"""Offline review of candidate 24-pose XI diagonal atlases (issue #287).

Never enables or publishes artwork. Automated acceptance is necessary,
not sufficient: check the resulting contact sheet and actual runtime.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

from football_directional_art_gate import (
    ArtworkRejected, verified_image, mask, silhouette_distance,
)

W, H, FRAMES = 128, 144, 24
TEAMS = ("fc_matthias", "real_enroque")
VIEWS = ("front_diagonal", "back_diagonal")


def inspect(sheet: Image.Image) -> dict:
    if sheet.size != (W * FRAMES, H * len(VIEWS)):
        raise ArtworkRejected("DENSE_DIAGONAL_GEOMETRY")
    problems = []
    metrics = {}
    for row, view in enumerate(VIEWS):
        poses = [
            sheet.crop((col * W, row * H, (col + 1) * W, (row + 1) * H))
            for col in range(FRAMES)
        ]
        # Ignore RGB noise in fully transparent pixels. Distinct opacity
        # silhouettes additionally reject recoloured copies of old poses.
        masks = [mask(pose) for pose in poses]
        unique = len({m.tobytes() for m in masks})
        if unique != FRAMES:
            problems.append(f"{view}:REPEATED_SILHOUETTES:{unique}/{FRAMES}")
        for i, (pose, silhouette) in enumerate(zip(poses, masks)):
            bounds = silhouette.getbbox()
            if bounds is None:
                problems.append(f"{view}:{i}:EMPTY")
                continue
            left, top, right, bottom = bounds
            if not (4 <= left < right <= 124 and right - left >= 38
                    and 4 <= top <= 42 and 129 <= bottom <= 139
                    and bottom - top >= 90):
                problems.append(f"{view}:{i}:BODY_OR_FOOTLINE:{bounds}")
            # Check every border, not merely two corner pixels.
            alpha = pose.getchannel("A")
            if any(edge.getextrema()[1] > 12 for edge in (
                alpha.crop((0, 0, W, 1)), alpha.crop((0, H - 1, W, H)),
                alpha.crop((0, 0, 1, H)), alpha.crop((W - 1, 0, W, H)),
            )):
                problems.append(f"{view}:{i}:DIRTY_BORDER")
        # Include the last-to-first seam. Motion metrics are reported
        # for manual review, not claimed to prove anatomical correctness.
        steps = [
            round(silhouette_distance(poses[i], poses[(i + 1) % FRAMES]), 4)
            for i in range(FRAMES)
        ]
        metrics[view] = {
            "unique_silhouettes": unique,
            "adjacent_silhouette_deltas": steps,
            "loop_seam_delta": steps[-1],
            "max_step_delta": max(steps),
        }
    return {"accepted_for_human_review": not problems,
            "problems": problems, "metrics": metrics}


def review_board(sheet: Image.Image, output: Path, team: str) -> None:
    # Split 24 poses into three readable eight-frame strips per view.
    board = Image.new("RGBA", (W * 8, 6 * (H + 24)), "#173126")
    draw = ImageDraw.Draw(board)
    for row, view in enumerate(VIEWS):
        for strip in range(3):
            y = (row * 3 + strip) * (H + 24)
            draw.text((8, y + 4), f"{team} / {view} / {strip * 8 + 1}-{strip * 8 + 8}",
                      fill="white")
            board.alpha_composite(sheet.crop((strip * 8 * W, row * H,
                                              (strip + 1) * 8 * W, (row + 1) * H)),
                                  (0, y + 24))
    board.convert("RGB").save(output, "PNG")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    results = {}
    for team in TEAMS:
        path = args.candidate_dir / f"{team}_diagonal_24_candidate.webp"
        try:
            sheet = verified_image(path, None, (W * FRAMES, H * len(VIEWS)))
            result = inspect(sheet)
            result["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            review_board(sheet, args.output_dir / f"{team}_review.png", team)
        except (ArtworkRejected, OSError) as exc:
            result = {"accepted_for_human_review": False, "problems": [str(exc)]}
        results[team] = result
    accepted = all(result["accepted_for_human_review"] for result in results.values())
    report = {"status": "HUMAN_REVIEW_REQUIRED" if accepted else "REJECTED",
              "runtime_activation": False, "teams": results}
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, sort_keys=True))
    return 0 if accepted else 1


if __name__ == "__main__":
    raise SystemExit(main())
