# Football carry/dribble side-view R2 candidate v1

These sheets **do not add a new gameplay action**. The existing Godot ball,
possession, 0.22-second dribble burst and regular sprint are authoritative.
The 3D outfield presenter may replace only the **side-view raster** for a real
ball carrier with a verified two-row animation. The front/back/diagonal views,
keeper, passes, shots, tackles, score and 2D gameplay stay unchanged.

The 16 poses are recomposed from existing clean pass/shoot v1 artwork;
this v1 is a conservative visual transition, not 16 newly drawn characters.
No ball is baked into the art. Both clubs use 128x144 cells with a shared
132px boot contact line. Carry loops at 12 FPS. The 0.22s burst uses a
36 FPS nonlooping dribble, recovering to carry/run under existing physics.

Upload only these files to dedicated Cloudflare R2 bucket **football**:
- `atlases/v1/fc_matthias_carry_dribble_v1.webp`
- `atlases/v1/real_enroque_carry_dribble_v1.webp`

`optional_carry_dribble_v1.json` pins SHA-256 and is now **enabled:true only on the PR branch**.
CI fails closed unless both real public objects pass HTTP 200, staging-origin
CORS, exact SHA-256, layout and runtime decoding, plus 1280x720 before/after
Godot screenshots for broadcast and tactical views. Do not merge until the real visual gate is green on the exact PR
SHA and those screenshots are personally inspected. Rollback simply disables
the metadata or reverts the PR. No new paid infra or R2 writes from GitHub.
