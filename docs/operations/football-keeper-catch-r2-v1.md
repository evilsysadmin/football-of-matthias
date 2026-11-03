# Football keeper reception · two original R2 WebPs (staged)

This is **not** a replacement of the approved goalkeeper run atlas. It stages
one 8-frame (128×144 per cell, 1024×144 full canvas) transparent **lossless WebP**
for each club, with real arms/palms in the raster; the ball is still a separate
Godot 3D object. The original front-view approved keeper body, boots, cap and
team-specific fabric are retained. These are an initial frontal reception pass,
not a lateral diving-atlas redesign.

Upload these two operator-provided assets to the existing shared R2 bucket `chess-studio-assets` (owned by ShadowOps Infra; **not** a separate bucket named `football`):

| Object key | SHA-256 |
| --- | --- |
| `football/atlases/v1/fc_matthias_keeper_catch_v1.webp` | `b6d0beb2bc26f2ef816ef2cdd3ce631d88f5489099d745fd14b3dcf796138089` |
| `football/atlases/v1/real_enroque_keeper_catch_v1.webp` | `8afa136c5c07a8e7be67d0952ef2cc9a7fcbfca08b8313d75c0157e14d613e41` |

Expected public URLs after Infra exposes them:

- `https://assets.chess-studio.shadowops.dpdns.org/football/atlases/v1/fc_matthias_keeper_catch_v1.webp`
- `https://assets.chess-studio.shadowops.dpdns.org/football/atlases/v1/real_enroque_keeper_catch_v1.webp`

Do not turn on the feature merely because the R2 dashboard shows the objects.
Check public status 200, correct content type, **exact** bytes/SHA, HTTPS
and game-origin CORS, plus a staging screenshot at each real catch phase.

The metadata in `optional_keeper_catch_v1.json` starts `enabled=false` and
`cdn_base=""`. Once verified, set `cdn_base` to the public
`https://assets.chess-studio.shadowops.dpdns.org/football/atlases/v1`,
then enable in a *separate reviewed PR*. A single R2 request is made per
club, with the shared strict URL/SHA/WebP/dimension validation. Eight
individual cells are checked for alpha footprint before installing their
`keeper_catch` animation atomically. Invalid/missing data leaves the
existing glove-rig fallback. Catch animation affects no physics, score,
possession, save chance, keeper reach or authoritative action timer.

Rollback is immediate: set `enabled=false` and deploy. No source art or
existing canonical atlas needs removal. The required Godot smoke in CI
validates both sources, the disabled gate, the eight-frame conversion, and
the old/new presentation switch without contacting R2.

The former `bucket: football` / `prefix: atlases/v1/` labels were inaccurate. The shared public CDN maps bucket `chess-studio-assets` with keys under `football/atlases/v1/`. An upload to a different bucket or key may succeed without appearing at the game's public URL.
