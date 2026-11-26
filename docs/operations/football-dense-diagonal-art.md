# XI dense diagonal art review

Issue #287. This is an offline candidate gate, not a runtime asset activation.

First deliver two independent lossless WebP candidates:
- `fc_matthias_diagonal_24_candidate.webp`
- `real_enroque_diagonal_24_candidate.webp`

Each is 3072 x 288 px: 24 columns, two rows (front diagonal, back diagonal),
128 x 144 px cells, transparent margins, common grounded footline near 134.
Use a common normalized gait phase and foot contacts across the two directions.
No duplicated frames, recoloured copies, translucent ghost interpolation or
painted ball. Match the already approved club silhouettes and kits.

Run with Pillow installed:

```sh
python scripts/test_football_dense_diagonal_gate.py
python scripts/football_dense_diagonal_gate.py --candidate-dir ./candidates --output-dir .artifacts/dense-diagonal
```

The report and contact boards expose distinct silhouettes, geometry, the
24 adjacent differences including the loop seam, and SHA-256. Automated
acceptance is only a request for human review; it cannot prove coherent limbs,
foot contacts, temporal phase, kit fidelity or art quality. Reject questionable
poses even if the script accepts them. The 4 MiB loader cap applies.

Do not upload or enable any candidate until actual art approval, immutable
R2 verification, runtime integration and both-club Web/visual validation.
The existing V5 and fallback remain authoritative until then.
