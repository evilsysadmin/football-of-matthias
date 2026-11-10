# XI directional feint art · offline acceptance contract (v1)

## Purpose

Stable XI feint #159 has two 15-FPS-visible opposing boots. Experimental
#160 kept frontal facing using V3 RUN poses, but looked like ordinary running.
A second local composition trial pasted R2 SIDE legs onto V3 torsos: detached
joints and floating boots made it unacceptable. Neither was merged.

The next actual animation needs NEW authored directional feint drawings, not
a more elaborate distortion of approved run sprites. This is an ART INTAKE
WORKBENCH, not a new game animation or a publishing mechanism.

## Proposed exact candidate pack

- Two independently authored lossless VP8L WebP atlases:
  fc_matthias_feint_4views_v1.webp and real_enroque_feint_4views_v1.webp.
- Each atlas is 1024 x 576 RGBA (eight columns of 128 x 144 and four rows).
  Row order must be front, back, front_diagonal, back_diagonal.
- Preserve canonical footline 134, actual shirt colors, anatomy, height,
  consistent perspective, transparency and natural boot-to-shadow contact.
- Distinct *opposite* painted foot plants at columns 2 and 5.
  Columns 0 and 7 must transition naturally to the corresponding V3 run.
  No ball painted inside the actor: the real single ball is rendered separately.
- Reject mirrored SIDE stand-ins, generic body shears, duplicated RUN poses,
  synthetic/doubled ground shadows, disconnected legs or floating boots.
- No candidate files have been approved. The OFF contract
  games/chess-football-godot/optional_directional_feint_v1.json
  deliberately has enabled=false, no R2 URL and no candidate SHA.

## Offline intake and preview

Download the exact, SHA-verified original CI art-reference ZIP and extract it
so that football-run-v3-r2 and football-action-poses-r2 are under one
directory. The tool validates the bytes against pinned production references.
Install Pillow in a throwaway Python virtual environment:

    python3 -m venv .venv-football-art
    .venv-football-art/bin/python -m pip install --no-deps Pillow==12.0.0
    .venv-football-art/bin/python scripts/football_directional_art_gate.py references \
      --source-dir /path/to/extracted-art --output-dir /tmp/football-feint-review

This generates two PNG visual SOURCE boards (V3 directional RUN and original
approved SIDE cut). These are references, NOT invented directional dribbles.

Once BOTH original candidate WebPs have actually been authored, run:

    .venv-football-art/bin/python scripts/football_directional_art_gate.py inspect \
      --source-dir /path/to/extracted-art \
      --candidate-dir /path/to/new-feint-webps \
      --output-dir /tmp/football-feint-review

It writes JSON + per-club candidate boards. It REJECTS missing/corrupt input,
incorrect baseline SHA, non-lossless WebP, incorrect geometry, dirty gutters,
missing boots/body, repeated frames, reused run silhouettes and nonexistent
opposing leg contacts. A passing result is STRUCTURAL_PREFLIGHT_ONLY,
NEVER human artistic approval. It cannot guarantee a convincing football move.

## Separate subsequent release only with real art

Humans must review Godot screenshots of the genuine XI 1280x720 broadcast and
tactical cameras, at near/mid/far pitch depth, each club and direction:

1. Entry from V3 run preserves actual orientation, height, lighting and kit.
2. Two separate foot plants are readable on a real 15 FPS capture.
3. Ball touch and boot contact correspond; only one grass contact shadow.
4. Exit to directional run has no facing jump, mirror glitch or rubber limb.
5. No physics, AI, goalkeeper, 5v5, tackle or manager changes.
6. Reject candidates that still look like running, even if the metrics pass.

Only a *separate PR* after this review may request a guarded runtime loader,
immutable content-addressed R2 assets through ShadowOps Infra, pinned SHA/
geometry/CORS and an exact-head Football visual gate. Until then the existing
stable #159 is the only authorised regate animation; no guessed URLs, no
publication and no runtime enablement from this workbench.
