# Football of Matthias

Football owns its Godot match, React manager, tests and artwork here. Chess Studio only links to its dedicated staging. No new game implementation belongs back in Chess Studio.

- Start every PR in Draft. The `Football · required visual gate` must pass on its exact head before Ready/merge. Inspect the real PNGs and embed them in the user chat with PR/SHA and viewport/state. Do not enable automerge until that review is complete. Reuse the product contract in docs/operations/chess-football-product.md.
- Keep Godot as match authority and the deterministic journal as manager authority. Do not couple manager standings to played match outcomes until the explicit integration contract exists.
- Preserve approved atlases, actor scale, tonal parity, boots/shadows and current gameplay during migration. Compare captures against the exact Chess source baseline in migration/source.json.
- Only staging is authorized initially: staging.football.shadowops.dpdns.org. Infra owns Cloudflare credentials, Pages, DNS and the bounded shared R2 publication. No cloud secrets in this repository or browser, no extra VM, no paid capacity.
- The initial standalone career is local to this origin; do not pretend an old origin's storage or an unverified browser claim is a shared account. Transfers include only a strictly replay-validated Football journal, never a Chess profile or credential. Preserve future/corrupt saves until explicit replacement.
