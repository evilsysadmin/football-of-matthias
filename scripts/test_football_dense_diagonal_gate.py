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


if __name__ == "__main__":
    unittest.main()
