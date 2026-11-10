#!/usr/bin/env python3
"""Regression gates for the disabled XI directional-feint art intake."""
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

import football_directional_art_gate as gate


class DirectionalArtGateTests(unittest.TestCase):
    def contract(self):
        return {
            "version": 1, "enabled": False, "status": "ART_NOT_APPROVED",
            "quality_contract": "football-xi-directional-feint-art-review-v1",
            "cell": {"width": 128, "height": 144},
            "columns": 8, "rows": 4, "footline": 134,
            "views": list(gate.VIEWS),
            "candidate_filenames": [
                f"{name}_feint_4views_v1.webp" for name in gate.TEAMS
            ],
        }

    def test_manifest_never_actively_enables_unapproved_r2(self):
        path = (
            Path(__file__).resolve().parents[1] /
            "games/chess-football-godot/optional_directional_feint_v1.json"
        )
        self.assertEqual(gate.validate_disabled_contract(path)["status"], "ART_NOT_APPROVED")
        with tempfile.TemporaryDirectory() as root:
            temp = Path(root) / "manifest.json"
            for field, value in [
                ("enabled", True), ("status", "APPROVED"),
                ("columns", 12), ("views", ["side"]),
                ("candidate_filenames", ["x.webp"]),
            ]:
                corrupted = self.contract()
                corrupted[field] = value
                temp.write_text(json.dumps(corrupted), encoding="utf-8")
                with self.subTest(field=field), self.assertRaises(gate.ArtworkRejected):
                    gate.validate_disabled_contract(temp)

    def cell(self, offset: int = 0):
        img = Image.new("RGBA", (128, 144))
        d = ImageDraw.Draw(img)
        d.ellipse((37 + offset, 10, 92 + offset, 44), fill=(36, 105, 167, 255))
        d.rectangle((44 + offset, 32, 83 + offset, 100), fill=(36, 105, 167, 255))
        d.rectangle((41 + offset, 98, 57 + offset, 134), fill=(36, 105, 167, 255))
        d.rectangle((72 + offset, 98, 88 + offset, 134), fill=(36, 105, 167, 255))
        return img

    def test_alpha_distance_and_distinct_contact(self):
        left = self.cell(-3)
        right = self.cell(3)
        self.assertEqual(gate.silhouette_distance(left, left), 0)
        self.assertGreater(gate.silhouette_distance(left, right), 0.1)
        self.assertGreater(abs(gate.foot_center(left) - gate.foot_center(right)), 2.5)
        self.assertEqual(gate.largest_component_fraction(left.getchannel("A")), 1.0)

    def test_detached_boot_rejected(self):
        whole = self.cell()
        m = whole.getchannel("A")
        self.assertGreater(gate.largest_component_fraction(gate.mask(whole)), 0.87)
        broken = whole.copy()
        # Delete a horizontal strip between torso and both lower legs.
        ImageDraw.Draw(broken).rectangle((0, 98, 127, 104), fill=(0, 0, 0, 0))
        self.assertLess(gate.largest_component_fraction(gate.mask(broken)), 0.87)

    def test_duplicated_run_frames_fail_even_when_image_geometry_valid(self):
        run = Image.new("RGBA", (1536, 720))
        for row in range(5):
            for col in range(12):
                run.alpha_composite(self.cell((col % 5) - 2), (col * 128, row * 144))
        candidate = Image.new("RGBA", (1024, 576))
        for row in range(4):
            for col in range(8):
                frame = gate.crop(run, col, gate.RUN_ROWS[row])
                candidate.alpha_composite(frame, (col * 128, row * 144))
        result = gate.inspect_candidate(candidate, run)
        self.assertFalse(result["accepted_for_human_review"])
        self.assertTrue(any("RUN_CLONE" in item for item in result["problems"]))
        self.assertTrue(any("REPEATED_FRAMES" in item for item in result["problems"]))

    def test_painted_disconnected_duplicate_is_not_human_approval(self):
        run = Image.new("RGBA", (1536, 720))
        for row in range(5):
            for col in range(12):
                run.alpha_composite(self.cell((col % 5) - 2), (col * 128, row * 144))
        candidate = Image.new("RGBA", (1024, 576))
        for row in range(4):
            for col in range(8):
                frame = self.cell((col % 4) - 2)
                if col == 5:
                    ImageDraw.Draw(frame).rectangle((0, 99, 127, 103), fill=(0, 0, 0, 0))
                candidate.alpha_composite(frame, (col * 128, row * 144))
        result = gate.inspect_candidate(candidate, run)
        self.assertFalse(result["accepted_for_human_review"])
        self.assertTrue(any("DETACHED_BODY_OR_BOOTS" in item for item in result["problems"]))


if __name__ == "__main__":
    unittest.main()
