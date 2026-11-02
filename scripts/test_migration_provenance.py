"""Regression coverage for immutable art and mutable post-extraction runtime."""
import tempfile
import unittest
from pathlib import Path

from check_migration import git_blob_sha, verify_migration


class MigrationProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.script = "games/chess-football-godot/scripts/game.gd"
        self.art = "games/chess-football-godot/assets/players/canon.png"
        for path, body in [(self.script, b"old code"), (self.art, b"approved art")]:
            dest = self.root / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(body)
        self.source = {"files": [
            {"path": self.script, "sha": git_blob_sha(b"old code")},
            {"path": self.art, "sha": git_blob_sha(b"approved art")},
        ]}
        self.additions = {"files": []}

    def test_original_assets_and_runtime_pass(self):
        self.assertEqual(verify_migration(self.root, self.source, self.additions), (1, 1))

    def test_standalone_runtime_can_evolve_without_rewriting_origin(self):
        (self.root / self.script).write_bytes(b"new independent game code")
        self.assertEqual(verify_migration(self.root, self.source, self.additions), (1, 1))
        self.assertEqual(self.source["files"][0]["sha"], git_blob_sha(b"old code"))

    def test_canonical_art_drift_is_rejected(self):
        (self.root / self.art).write_bytes(b"changed art")
        with self.assertRaisesRegex(AssertionError, "Canonical art provenance"):
            verify_migration(self.root, self.source, self.additions)

    def test_missing_migrated_runtime_is_rejected(self):
        (self.root / self.script).unlink()
        with self.assertRaises(FileNotFoundError):
            verify_migration(self.root, self.source, self.additions)

    def test_provenance_traversal_is_rejected(self):
        bad = {"files": [{"path": "games/../../another-repo/file.gd", "sha": "0" * 40}]}
        with self.assertRaises(ValueError):
            verify_migration(self.root, bad, self.additions)


if __name__ == "__main__":
    unittest.main()
