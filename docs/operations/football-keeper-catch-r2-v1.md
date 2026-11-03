# Recepción del portero · R2 independiente de Football

Football has its own Cloudflare R2 bucket, **`football`**. The operator-confirmed
Cloudflare dashboard object identifies an uploaded atlas at `atlases/v1/`.
This is distinct from the shared `chess-studio-assets` bucket used by older
ShadowOps Infra delivery workflows.

| Bucket | Object key | Expected SHA-256 |
| --- | --- | --- |
| `football` | `atlases/v1/fc_matthias_keeper_catch_v1.webp` | `b6d0beb2bc26f2ef816ef2cdd3ce631d88f5489099d745fd14b3dcf796138089` |
| `football` | `atlases/v1/real_enroque_keeper_catch_v1.webp` | `8afa136c5c07a8e7be67d0952ef2cc9a7fcbfca08b8313d75c0157e14d613e41` |

Each atlas has eight transparent original reception poses, 128 × 144 pixels per
cell (1024 × 144 per sheet). The match ball is separate 3D geometry.
The canonical goalkeeper run atlas and the 3D glove rig remain the fallback.

**Cloudflare Dashboard object-detail URLs are NOT playable public asset URLs.**
The existing URL under
`https://assets.chess-studio.shadowops.dpdns.org/football/atlases/v1/`
returned HTTP 404 in CI because it is **not** the public endpoint of the new
bucket. Do not point the game to that old shared CDN, and do not move/re-upload
these objects to `chess-studio-assets` merely to make that URL work.

## Before enabling the optional atlas

1. In Cloudflare R2 > bucket `football` > Settings > Public Access, find the
   bucket's actual **Custom Domain** public origin. Prefer a dedicated custom
   domain with Cloudflare cache for staging and production. For temporary
   development only, a Cloudflare-managed `r2.dev` public URL can be used,
   but it is rate-limited.
2. Record the **actual** HTTPS base URL including `/atlases/v1`; do not
   guess its hostname. Confirm both public object URLs return HTTP 200 and
   `Content-Type: image/webp`. The origin
   `https://staging.football.shadowops.dpdns.org` must receive a matching
   `Access-Control-Allow-Origin` response. Configure the CORS policy on the
   **`football`** bucket, not the shared bucket.
3. Compare each response's exact SHA-256 with the pinned hashes above.
   Confirm the images decode to 1024 × 144, eight non-clipped cells.
4. Only then configure `cdn_base` and set `enabled=true`.
   The loader now supports an explicitly pinned, verified additional root
   for **keeper catch only**, while all other R2 consumers remain restricted
   to the original shared CDN. The dedicated root is derived from the
   versioned local manifest, must be HTTPS with a full `/atlases/v1`
   path, and rejects the old shared-CDN host, IPs, port overrides,
   credentials, queries and fragments. No public origin is assumed or
   hard-coded before operator verification.
5. Re-run the required PR CI including **actual Godot 1280 × 720 captures**
   of both teams at catch open, closing, held, broadcast and release, plus
   Chromium Web boot and fallback. Only after visual approval may a Draft
   PR become Ready/merged.

Current manifest deliberately has `enabled=false` and empty `cdn_base`.
Do not publish a broken active configuration. Failed requests, invalid bytes,
or missing sheets always retain the original keeper frames and glove rig.

Rollback: set `enabled=false`, deploy the previous SHA; keep the original
atlases untouched. No cloud keys, secrets or R2 object mutation are required.
