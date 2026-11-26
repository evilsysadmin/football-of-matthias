#!/usr/bin/env python3
"""Synthetic geometry fixtures, not candidate artwork or visual approval."""
import unittest

from PIL import Image, ImageDraw

from football_dense_diagonal_gate import W, H, FRAMES, inspect
from football_directional_art_gate import ArtworkRejected


def fixture():
    sheet = Image.new("RGBA", (W * FRAMES, H * 2))
    draw = ImageDraw.Draw(sheet)
    for row in range(2):
        for col in range(FRAMES):
            x, y = col * W, row * H
            draw.rectangle((x + 36, y + 12, x + 91, y + 133), fill="white")
            draw.rectangle((x + 28, y + 28 + col, x + 35, y + 50 + col), fill="white")
    return sheet


class DenseGateTest(unittest.TestCase):
    def test_distinct_geometry_review_only(self):
        result = inspect(fixture())
        self.assertTrue(result["accepted_for_human_review"])
        for metrics in result["metrics"].values():
            self.assertEqual(metrics["unique_silhouettes"], 24)
            self.assertEqual(len(metrics["adjacent_silhouette_deltas"]), 24)

    def test_duplicate_rejected(self):
        sheet = fixture()
        sheet.paste(sheet.crop((0, 0, W, H)), (W, 0))
        result = inspect(sheet)
        self.assertFalse(result["accepted_for_human_review"])
        self.assertIn("front_diagonal:REPEATED_SILHOUETTES:23/24", result["problems"])

    def test_rgb_noise_does_not_count_as_pose(self):
        sheet = fixture()
        duplicate = sheet.crop((0, 0, W, H))
        duplicate.putpixel((1, 1), (255, 0, 0, 0))
        sheet.paste(duplicate, (W, 0))
        self.assertFalse(inspect(sheet)["accepted_for_human_review"])

    def test_border_and_empty_rejected(self):
        sheet = fixture()
        sheet.putpixel((0, 60), (255, 255, 255, 255))
        sheet.paste((0, 0, 0, 0), (W, H, W * 2, H * 2))
        result = inspect(sheet)
        self.assertIn("front_diagonal:0:DIRTY_BORDER", result["problems"])
        self.assertIn("back_diagonal:1:EMPTY", result["problems"])

    def test_wrong_grid_rejected(self):
        with self.assertRaises(ArtworkRejected):
            inspect(Image.new("RGBA", (W * 16, H * 2)))


    def test_review_reference_search_pins_exact_bytes(self):
        from io import BytesIO
        from prepare_football_direction_review import find_pinned_webps, sha
        stream = BytesIO()
        Image.new("RGBA", (128, 144), (10, 20, 30, 255)).save(stream, "WEBP", lossless=True)
        raw = stream.getvalue()
        pins = {sha(raw): ("reference.webp", (128, 144))}
        self.assertEqual(find_pinned_webps(b"GDPC" + raw + b"extra", pins), {"reference.webp": raw})
        with self.assertRaisesRegex(ValueError, "Missing exact pinned"):
            find_pinned_webps(b"GDPC" + raw[:-1], pins)

    def test_review_candidate_coverage_and_hash(self):
        import json
        from io import BytesIO
        from zipfile import ZipFile
        from prepare_football_direction_review import CLUBS, read_candidates, sha
        raw_file = BytesIO()
        Image.new("RGBA", (3072, 144), (10, 20, 30, 255)).save(raw_file, "WEBP", lossless=True)
        raw = raw_file.getvalue()
        names = [f"{club}_run_{view}_24_candidate_v3.webp" for club in CLUBS for view in ("side", "back", "back_diagonal")]
        doc = {"status": "candidate_only", "cell": {"width": 128, "height": 144},
               "entries": [{"file": n, "sha256": sha(raw), "bytes": len(raw), "columns": 24, "rows": 1} for n in names]}
        with ZipFile(BytesIO(), "w") as archive:
            for name in names:
                archive.writestr(name, raw)
            archive.writestr("phase-review.json", json.dumps(doc))
            self.assertEqual(set(read_candidates(archive, True)), set(names))
            with self.assertRaisesRegex(ValueError, "coverage mismatch"):
                read_candidates(archive)
        doc["entries"][0]["sha256"] = "0" * 64
        with ZipFile(BytesIO(), "w") as archive:
            for name in names:
                archive.writestr(name, raw)
            archive.writestr("phase-review.json", json.dumps(doc))
            with self.assertRaisesRegex(ValueError, "manifest mismatch"):
                read_candidates(archive, True)


if __name__ == "__main__":
    unittest.main()
