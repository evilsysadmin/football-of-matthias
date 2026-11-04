# Football pass/shoot · optional candidate v1

This is a visual-only extension to the 3D outfield sprite bank. The canonical
local run-frame action fallbacks remain as both authored WebPs are now operator-published
to the **dedicated** R2 bucket `football` and reviewed in real Godot captures.

- Bucket: `football`; prefix: `atlases/v1/`
- Upload `fc_matthias_pass_shoot_v1.webp` and `real_enroque_pass_shoot_v1.webp`
- Each atlas is **1024 × 288**, with 128 × 144 lossless RGBA cells.
- Row 0: pass (8 poses, 10 FPS, once); row 1: shoot (8 poses, 10 FPS, once).
- SHA-256 and filenames are pinned in `optional_pass_shoot_v1.json`.
- Physical football stays under Godot authority; the ball must never be
  baked into a character sprite.

This activation PR independently verifies HTTP 200, CORS for
`https://staging.football.shadowops.dpdns.org`, exact SHA-256, WebP decode,
all 16 alpha/footline bounds and real 1280 × 720 captures of both clubs at
early/impact/follow-through phases. The manifest is now `enabled: true` only on the Draft branch; its HTTP/CORS/SHA and real Godot captures fail closed in CI. Do not merge until those actual images have been reviewed.
Do not approve a visual PR based only on CI. Revert `enabled` for rollback.
