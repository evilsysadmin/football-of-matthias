"""Recreate derived PNGs from the exact approved base64 sources."""
import base64
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'games/chess-football-godot/assets/players'
for name,digest in [('keeper_canon_v1/keeper_run_v1','41ca02f757545eb39c4f80e99eb358c167e8f9044153bedfd799ad488a88ca9c'),('run_directions_v1/directional_run_v1','7d23e79dd5f9b23d1a04cf27f4d725d249e37f528c23d696ea260cd498644e70')]:
 raw=base64.b64decode((ROOT/(name+'.b64')).read_text())
 assert hashlib.sha256(raw).hexdigest()==digest
 (ROOT/(name+'.png')).write_bytes(raw)
print('FOOTBALL_CANONICAL_PNG_BYTES_VERIFIED')
